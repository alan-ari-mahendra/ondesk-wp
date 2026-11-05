#!/usr/bin/env bash
# Deploy wp-content/themes/aurelle-child to the server. Used by GitHub Actions and for manual deploys.
#   DEPLOY_HOST=<ip> DEPLOY_USER=deploy SSH_OPTS="-i ~/.ssh/aurelle-deploy" ./deploy/deploy.sh
# Backs up the current theme, rsyncs, flushes caches, runs a health check, and rolls back on failure.
set -euo pipefail
# Secrets are often pasted with stray spaces/newlines: strip CR/LF and surrounding whitespace from every input.
trim() { printf '%s' "$1" | tr -d '\r\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'; }
HOST="$(trim "${DEPLOY_HOST:?DEPLOY_HOST required}")"
DUSER="$(trim "${DEPLOY_USER:-deploy}")"; DUSER="${DUSER:-deploy}"
SITE_URL="$(trim "${SITE_URL:-}")"; SITE_URL="${SITE_URL:-http://$HOST}"
REMOTE_ROOT="$(trim "${REMOTE_ROOT:-}")"; REMOTE_ROOT="${REMOTE_ROOT:-/var/www/aurelle}"
SITE_PORT="$(trim "${SITE_PORT:-}")"                    # optional; defaults to the port in SITE_URL, else 80/443
PLUGIN_DIR="$(trim "${PLUGIN_DIR:-}")"; PLUGIN_DIR="${PLUGIN_DIR:-aurelle-child}"
THEME_DIR="$(trim "${THEME_DIR:-}")"                    # optional; if set, deploy to themes/ instead of plugins/
# Fail fast, before touching the server, if a value is malformed (a relative REMOTE_ROOT once created a stray dir in $HOME).
[[ "$REMOTE_ROOT" =~ ^/[A-Za-z0-9._/-]+$ && "$REMOTE_ROOT" != *..* ]] || { echo "::error::REMOTE_ROOT must be an absolute path like /var/www/my-site (got '${REMOTE_ROOT}')"; exit 2; }
[[ "$PLUGIN_DIR" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "::error::PLUGIN_DIR must be a plain folder name (got '${PLUGIN_DIR}')"; exit 2; }
if [ -n "$THEME_DIR" ]; then
  [[ "$THEME_DIR" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "::error::THEME_DIR must be a plain folder name (got '${THEME_DIR}')"; exit 2; }
fi
[[ "$HOST" =~ ^[A-Za-z0-9.-]+$ && "$DUSER" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "::error::bad DEPLOY_HOST/DEPLOY_USER"; exit 2; }
PROJECT="${PROJECT:-$(basename "$REMOTE_ROOT")}"
SSH_OPTS="${SSH_OPTS:-}"
HOSTPORT="$(printf '%s' "$SITE_URL" | sed -E 's#^https?://##; s#/.*$##')"
SITE_HOST="${HOSTPORT%%:*}"                             # Host header sent to nginx (nginx ignores the port when matching server_name)
if [ -z "$SITE_PORT" ]; then
  case "$HOSTPORT" in *:*) SITE_PORT="${HOSTPORT##*:}";; *) SITE_PORT=$([[ "$SITE_URL" == https://* ]] && echo 443 || echo 80);; esac
fi
[[ "$SITE_PORT" =~ ^[0-9]+$ ]] || { echo "bad SITE_PORT: $SITE_PORT"; exit 1; }
# health checks run on the server against its local nginx; TLS is terminated there once a domain/cert exists
SCHEME=http; [ "$SITE_PORT" = "443" ] && SCHEME=https

if [ -n "$THEME_DIR" ]; then
  SRC="wp-content/themes/$THEME_DIR/"
  CONTENT_DIR="$REMOTE_ROOT/wp-content/themes"
  DEST="$CONTENT_DIR/$THEME_DIR"
  DEPLOY_LABEL="$THEME_DIR"
else
  SRC="wp-content/plugins/$PLUGIN_DIR/"
  CONTENT_DIR="$REMOTE_ROOT/wp-content/plugins"
  DEST="$CONTENT_DIR/$PLUGIN_DIR"
  DEPLOY_LABEL="$PLUGIN_DIR"
fi
SHA="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo manual)}"
BK="/var/backups/$PROJECT/$DEPLOY_LABEL-$(date +%Y%m%d%H%M%S)-${SHA:0:7}.tgz"
# When connecting as root, run wp-cli as the site owner (wp refuses root) and give files back to it.
WPUSER="${WP_USER:-deploy}"
if [ "$DUSER" = root ]; then WPU="sudo -u $WPUSER "; CHOWN="chown -R $WPUSER:www-data '$DEST'"; else WPU=""; CHOWN="true"; fi
R() { ssh $SSH_OPTS -o BatchMode=yes "$DUSER@$HOST" "$@"; }

[ -d "$SRC" ] || { echo "run from repo root ($SRC missing)"; exit 1; }

echo "==> pre-flight: $REMOTE_ROOT must be a WordPress install"
R "test -f '$REMOTE_ROOT/wp-config.php' && test -d '$REMOTE_ROOT/wp-content/plugins'" \
  || { echo "::error::$REMOTE_ROOT on the server is not a WordPress root (no wp-config.php). Check the REMOTE_ROOT secret."; exit 3; }

echo "==> pre-flight: nginx must listen on port $SITE_PORT for $PROJECT"
if ! R "ss -tln | awk '{print \$4}' | grep -qE '[:.]$SITE_PORT\$'"; then
  ACTUAL="$(R "awk '/^[[:space:]]*listen/' /etc/nginx/sites-enabled/$PROJECT 2>/dev/null | tr -cs '0-9' ' '" || true)"
  echo "::error::SITE_PORT=$SITE_PORT does not match the server: nothing listens on $SITE_PORT. The nginx vhost '$PROJECT' listens on: ${ACTUAL:-unknown}. Fix the SITE_PORT secret (or run deploy/server-setup.sh with SITE_PORT=$SITE_PORT first)."
  exit 4
fi

echo "==> backup current ${THEME_DIR:+theme}${THEME_DIR:-plugin}"
R "mkdir -p '/var/backups/$PROJECT' '$DEST' && tar -czf '$BK' -C '$CONTENT_DIR' '$DEPLOY_LABEL' && echo saved $BK"

echo "==> rsync"
rsync -az --delete --no-owner --no-group --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
  --exclude='.DS_Store' --exclude='*.log' -e "ssh $SSH_OPTS -o BatchMode=yes" "$SRC" "$DUSER@$HOST:$DEST/"
R "$CHOWN"

post_deploy() {
  local flush_elementor=""
  [ -z "$THEME_DIR" ] && flush_elementor="${WPU}wp elementor flush-css >/dev/null 2>&1 || true; "
  R "cd '$REMOTE_ROOT' && ${WPU}wp cache flush >/dev/null 2>&1 || true; ${flush_elementor}$([ "$DUSER" = root ] && echo systemctl || echo sudo -n /usr/bin/systemctl) reload php8.3-fpm"
}
health() {
  local HOSTHDR="$SITE_HOST"; case "$SITE_PORT" in 80|443) ;; *) HOSTHDR="$SITE_HOST:$SITE_PORT";; esac
  local base="$SCHEME://127.0.0.1:$SITE_PORT"
  R "
    echo '--- curl homepage ---'
    HTTP=\$(curl -sSLw '\n%{http_code}' -m 25 -H 'Host: $HOSTHDR' -k $base${HEALTH_PATH:-/})
    CODE=\$(printf '%s' \"\$HTTP\" | tail -1)
    H=\$(printf '%s' \"\$HTTP\" | head -n -1)
    echo \"HTTP status: \$CODE\"
    if echo \"\$H\" | grep -q '${HEALTH_MARKER:-au-page}'; then
      echo 'marker OK: ${HEALTH_MARKER:-au-page}'
    else
      echo '::error::marker NOT found: ${HEALTH_MARKER:-au-page}'
      echo \"--- body snippet ---\"
      echo \"\$H\" | head -20
      exit 1
    fi
    echo '--- curl wp-json ---'
    WJ=\$(curl -sSLw '%{http_code}' -m 25 -o /dev/null -H 'Host: $HOSTHDR' -k $base/wp-json/)
    echo \"wp-json HTTP status: \$WJ\"
    case \"\$WJ\" in 2*) ;; *) echo '::error::wp-json returned '\$WJ; exit 1;; esac
  "
}

echo "==> post-deploy"; post_deploy
echo "==> health check"
if health; then
  echo "HEALTH_OK"
  R "ls -1t /var/backups/$PROJECT/$DEPLOY_LABEL-*.tgz 2>/dev/null | tail -n +6 | xargs -r rm -f"
else
  echo "HEALTH_FAILED -> rolling back to $BK" >&2
  R "rm -rf '$DEST' && tar -xzf '$BK' -C '$CONTENT_DIR' && $CHOWN"
  post_deploy || true
  exit 1
fi

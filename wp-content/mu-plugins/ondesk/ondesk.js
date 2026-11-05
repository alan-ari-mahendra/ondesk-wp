/* Ondesk interactive scripts */
(function () {
  'use strict';

  /* ── mobile menu ── */
  const burger = document.querySelector('.burger');
  const mobileMenu = document.querySelector('.mobile-menu');
  if (burger && mobileMenu) {
    burger.addEventListener('click', function () {
      const expanded = this.getAttribute('aria-expanded') === 'true';
      this.setAttribute('aria-expanded', String(!expanded));
      mobileMenu.classList.toggle('open', !expanded);
    });
  }

  /* ── chat demo animation ── */
  const chat = document.getElementById('chat');
  if (chat) {
    const msgs = chat.querySelectorAll('.msg');
    const typing = document.getElementById('typing');
    const booked = document.getElementById('booked');
    const statFloat = document.getElementById('statFloat');

    // Reset all messages
    msgs.forEach(function (m) { m.classList.remove('show'); });
    if (booked) booked.classList.remove('show');
    if (typing) typing.classList.remove('show');
    if (statFloat) statFloat.classList.remove('show');

    function runChat() {
      let delay = 400;
      msgs.forEach(function (m, i) {
        const d = delay;
        setTimeout(function () { m.classList.add('show'); }, d);
        // Show typing before Ondesk responses
        if (i < msgs.length - 1 && m.classList.contains('c')) {
          delay += 600;
          const td = delay;
          if (typing) {
            setTimeout(function () { typing.classList.add('show'); }, td);
            delay += 1000;
            const hide = delay;
            setTimeout(function () { typing.classList.remove('show'); }, hide);
          }
        } else {
          delay += 800;
        }
      });
      if (booked) {
        const bd = delay;
        setTimeout(function () {
          booked.classList.add('show');
          if (statFloat) statFloat.classList.add('show');
        }, bd);
      }
    }

    // Run on first viewport intersection
    if ('IntersectionObserver' in window) {
      let ran = false;
      const obs = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting && !ran) {
            ran = true;
            runChat();
            // Loop after 12s
            setInterval(function () {
              msgs.forEach(function (m) { m.classList.remove('show'); });
              if (booked) booked.classList.remove('show');
              if (typing) typing.classList.remove('show');
              if (statFloat) statFloat.classList.remove('show');
              setTimeout(runChat, 600);
            }, 12000);
          }
        });
      }, { threshold: 0.4 });
      obs.observe(chat);
    } else {
      runChat();
    }
  }

  /* ── pricing toggle ── */
  const btnMonthly = document.getElementById('billMonthly');
  const btnYearly = document.getElementById('billYearly');
  if (btnMonthly && btnYearly) {
    function setbilling(yearly) {
      btnMonthly.setAttribute('aria-pressed', String(!yearly));
      btnYearly.setAttribute('aria-pressed', String(yearly));
      const key = yearly ? 'y' : 'm';
      document.querySelectorAll('.amt[data-m]').forEach(function (el) {
        el.textContent = el.dataset[key] || el.textContent;
      });
      document.querySelectorAll('.billed[data-m]').forEach(function (el) {
        el.textContent = el.dataset[key] || el.textContent;
      });
    }
    btnMonthly.addEventListener('click', function () { setbilling(false); });
    btnYearly.addEventListener('click', function () { setbilling(true); });
  }

  /* ── use-case tabs ── */
  const tabList = document.querySelector('[role="tablist"]');
  if (tabList) {
    const tabs = tabList.querySelectorAll('[role="tab"]');
    tabs.forEach(function (tab) {
      tab.addEventListener('click', function () {
        const panelId = this.getAttribute('aria-controls');
        // Deactivate all
        tabs.forEach(function (t) {
          t.setAttribute('aria-selected', 'false');
          t.setAttribute('tabindex', '-1');
          const p = document.getElementById(t.getAttribute('aria-controls'));
          if (p) { p.classList.remove('on'); p.hidden = true; }
        });
        // Activate clicked
        this.setAttribute('aria-selected', 'true');
        this.removeAttribute('tabindex');
        const panel = document.getElementById(panelId);
        if (panel) { panel.classList.add('on'); panel.removeAttribute('hidden'); }
      });
      // Arrow key navigation
      tab.addEventListener('keydown', function (e) {
        const tArr = Array.from(tabs);
        const idx = tArr.indexOf(this);
        if (e.key === 'ArrowRight') {
          const next = tArr[(idx + 1) % tArr.length];
          next.focus(); next.click();
        } else if (e.key === 'ArrowLeft') {
          const prev = tArr[(idx - 1 + tArr.length) % tArr.length];
          prev.focus(); prev.click();
        }
      });
    });
  }

  /* ── connector draw on scroll ── */
  if ('IntersectionObserver' in window) {
    document.querySelectorAll('.conn.draw, .wire.draw').forEach(function (el) {
      const obs = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting) { e.target.classList.add('on'); obs.unobserve(e.target); }
        });
      }, { threshold: 0.2 });
      obs.observe(el);
    });
  } else {
    document.querySelectorAll('.conn.draw, .wire.draw').forEach(function (el) {
      el.classList.add('on');
    });
  }

  /* ── demo form validation ── */
  const demoForm = document.getElementById('demoForm');
  const formSuccess = document.getElementById('formSuccess');
  if (demoForm) {
    demoForm.addEventListener('submit', function (e) {
      e.preventDefault();
      let valid = true;
      this.querySelectorAll('[required]').forEach(function (field) {
        const wrap = field.closest('.field');
        const ok = field.value.trim() !== '' && (field.type !== 'email' || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(field.value));
        if (wrap) wrap.classList.toggle('err', !ok);
        if (!ok) valid = false;
      });
      if (valid && formSuccess) {
        demoForm.style.display = 'none';
        formSuccess.classList.add('on');
      }
    });
    // Clear error on input
    demoForm.querySelectorAll('[required]').forEach(function (field) {
      field.addEventListener('input', function () {
        const wrap = field.closest('.field');
        if (wrap) wrap.classList.remove('err');
      });
    });
  }

  /* ── newsletter form ── */
  document.querySelectorAll('.news').forEach(function (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      const inp = this.querySelector('input[type="email"]');
      if (inp && inp.value.trim()) { inp.value = ''; inp.placeholder = 'Subscribed!'; }
    });
  });

})();

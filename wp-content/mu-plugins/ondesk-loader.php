<?php
/**
 * Plugin Name: Ondesk Assets Loader
 * Description: Loads global CSS and JS for the Ondesk landing page.
 */

defined('ABSPATH') || exit;

add_action('wp_enqueue_scripts', function () {
    wp_enqueue_style(
        'ondesk-styles',
        content_url('mu-plugins/ondesk/ondesk.css'),
        [],
        '1.0.0'
    );
    wp_enqueue_script(
        'ondesk-scripts',
        content_url('mu-plugins/ondesk/ondesk.js'),
        [],
        '1.0.0',
        true
    );
});

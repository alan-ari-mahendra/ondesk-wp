<?php
add_theme_support( 'title-tag' );
add_theme_support( 'post-thumbnails' );
add_theme_support( 'html5', [ 'search-form','comment-form','comment-list','gallery','caption','style','script' ] );

// No default WordPress block styles
add_action( 'wp_enqueue_scripts', function() {
    wp_dequeue_style( 'wp-block-library' );
    wp_dequeue_style( 'wp-block-library-theme' );
    wp_dequeue_style( 'global-styles' );
    wp_dequeue_style( 'classic-theme-styles' );
}, 100 );

// Canvas template: fully blank
function hello_elementor_page_templates( $post_templates, $theme, $post, $post_type ) {
    $post_templates['templates/canvas.php'] = __( 'Elementor Canvas', 'hello-elementor' );
    return $post_templates;
}
add_filter( 'theme_page_templates', 'hello_elementor_page_templates', 10, 4 );

function hello_elementor_canvas_redirect() {
    if ( is_singular() && get_page_template_slug() === 'templates/canvas.php' ) {
        // Blank canvas: output nothing before/after Elementor content
        remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
    }
}
add_action( 'template_redirect', 'hello_elementor_canvas_redirect' );

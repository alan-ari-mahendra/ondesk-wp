<?php
/**
 * Template Name: Elementor Canvas
 * Template Post Type: page
 */
$post_id = (int) get_queried_object_id();
?><!doctype html>
<html <?php language_attributes(); ?>>
<head>
<meta charset="<?php bloginfo( 'charset' ); ?>">
<meta name="viewport" content="width=device-width, initial-scale=1">
<?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
<?php
if ( $post_id && class_exists( '\Elementor\Plugin' ) ) {
    $el = \Elementor\Plugin::$instance;
    if ( method_exists( $el, 'db' ) || isset( $el->db ) ) {
        if ( $el->db->is_built_with_elementor( $post_id ) ) {
            echo $el->frontend->get_builder_content_for_display( $post_id, true );
        } else {
            echo '<!-- Elementor: not built with elementor for post ' . $post_id . ' -->';
            while ( have_posts() ) : the_post(); the_content(); endwhile;
        }
    } else {
        echo '<!-- Elementor Plugin exists but db property missing -->';
        while ( have_posts() ) : the_post(); the_content(); endwhile;
    }
} else {
    echo '<!-- No Elementor: post_id=' . $post_id . ' class_exists=' . (int) class_exists('\Elementor\Plugin') . ' -->';
    while ( have_posts() ) : the_post(); the_content(); endwhile;
}
?>
<?php wp_footer(); ?>
</body>
</html>

<?php
$post_id      = (int) get_queried_object_id();
$page_tmpl    = $post_id ? get_post_meta( $post_id, '_wp_page_template', true ) : '';
$el_edit_mode = $post_id ? get_post_meta( $post_id, '_elementor_edit_mode', true ) : '';

if ( 'elementor_canvas' === $page_tmpl || 'builder' === $el_edit_mode ) {
    get_template_part( 'templates/canvas' );
    return;
}
get_header();
while ( have_posts() ) :
    the_post();
    echo '<div id="content" class="page-content">';
    the_content();
    echo '</div>';
endwhile;
get_footer();

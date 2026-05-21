# Changelog

## pdfium 0.1.0

Initial CRAN release. This is the first public version of `pdfium`, an R
wrapper for Google’s PDFium C API. The package surface is split into a
comprehensive **read** layer (parse and inspect any PDF) and a focused
**mutation** layer (open with `readwrite = TRUE` to enable; PDFs created
with
[`pdf_doc_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_new.md)
are also writable).

### Documents and pages

- [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md)
  /
  [`pdf_doc_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_close.md),
  [`pdf_doc_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_new.md),
  [`pdf_save()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save.md)
  /
  [`pdf_save_to_raw()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save_to_raw.md)
  — open existing PDFs (optionally with `readwrite = TRUE`), build new
  ones in memory, and persist the result. The `path =` argument of
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md)
  accepts either a local filesystem path or a URL (any scheme
  [`base::url()`](https://rdrr.io/r/base/connections.html) recognises —
  typically `http://` / `https://` / `ftp://` / `file://`); URL input is
  fetched into raw bytes via
  [`url()`](https://rdrr.io/r/base/connections.html) +
  [`readBin()`](https://rdrr.io/r/base/readBin.html) and loaded through
  PDFium’s `FPDF_LoadMemDocument64`, with no temporary file on disk.
- [`pdf_doc_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_info.md),
  [`pdf_doc_meta()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_meta.md),
  [`pdf_doc_text()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_text.md),
  [`pdf_doc_fonts()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_fonts.md),
  [`pdf_doc_file_id()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_file_id.md),
  [`pdf_doc_page_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_page_mode.md),
  [`pdf_doc_viewer_preferences()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_viewer_preferences.md),
  [`pdf_doc_viewer_preference_by_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_viewer_preference_by_name.md),
  [`pdf_doc_permissions()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_permissions.md),
  [`pdf_doc_user_permissions()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_user_permissions.md),
  [`pdf_doc_security()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_security.md),
  [`pdf_doc_xref_valid()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_xref_valid.md),
  [`pdf_doc_trailer_ends()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_trailer_ends.md),
  [`pdf_doc_is_tagged()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_is_tagged.md),
  [`pdf_doc_javascript()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_javascript.md),
  [`pdf_doc_focusable_subtypes()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_focusable_subtypes.md)
  — document- level inspection.
- [`pdf_doc_named_dests()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_named_dests.md),
  [`pdf_doc_named_dest_by_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_named_dest_by_name.md),
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmarks.md),
  [`pdf_doc_bookmark_find()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmark_find.md),
  [`pdf_page_label()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_label.md),
  [`pdf_page_labels()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_labels.md)
  — outlines and named destinations.
- [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md)
  /
  [`pdf_page_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_close.md),
  [`pdf_page_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_size.md),
  [`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_rotation.md),
  [`pdf_page_box()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_box.md),
  [`pdf_page_thumbnail()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_thumbnail.md)
  — per-page handles and metadata.
- [`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md)
  and
  [`pdf_pages_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_pages_summary.md)
  — one-call triage helpers.
  [`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md)
  returns a single-row tibble aggregating the most-asked-for facts about
  a PDF (path, page count, Info-dictionary metadata, feature flags,
  per-feature counts, file-ID tuple);
  [`pdf_pages_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_pages_summary.md)
  is the per-page sibling (width / height / rotation / label, all via
  the fast by-index PDFium readers). `summary(doc)` and `summary(page)`
  dispatch to the matching tibble — `summary(page)` adds the page-loaded
  counts (annotation count, page-object count, text-run count, link
  count) since the page is already loaded.
- [`summary()`](https://rdrr.io/r/base/summary.html) S3 methods for
  every `pdfium_*_list` class: `pdfium_obj_list`, `pdfium_annot_list`,
  `pdfium_attachment_list`, `pdfium_signature_list`,
  `pdfium_bookmark_list`, and `pdfium_form_field_list`. Each dispatches
  to the matching `as_tibble.*` method so `summary(x)` returns the same
  tibble view `tibble::as_tibble(x)` would — matching the R idiom of
  [`print()`](https://rdrr.io/r/base/print.html) for the one-line
  summary and [`summary()`](https://rdrr.io/r/base/summary.html) for the
  deep dive.

### Scope retraction

Two functions added during 0.1.0 development were retracted before
release on scope grounds (see `CLAUDE.md` §“Scope”):

- **`pdf_doc_open_url()`** — folded into `pdf_doc_open(path = ...)`. The
  URL-fetching layer is just
  [`base::url()`](https://rdrr.io/r/base/connections.html) +
  [`readBin()`](https://rdrr.io/r/base/readBin.html) ahead of PDFium’s
  existing in-memory path, so a separate exported symbol added surface
  for no PDFium-specific behaviour.
- **`pdf_dir_summary()`** — removed. Its body was
  [`list.files()`](https://rdrr.io/r/base/list.files.html)
  - `lapply(pdf_doc_summary)`; users with bulk-triage needs can write
    the loop themselves in three lines. Keeping it set a precedent for
    “convenience over a base R loop” creep that the package’s
    PDFium-wrapper mandate doesn’t want.

### Page objects, paths, and text

- [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
  returns a `pdfium_obj_list`; per-handle accessors
  [`pdf_obj_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_type.md),
  [`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_bounds.md),
  [`pdf_obj_rotated_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_rotated_bounds.md),
  [`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_matrix.md),
  [`pdf_obj_has_transparency()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_has_transparency.md),
  [`pdf_obj_is_active()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_is_active.md),
  [`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marks.md),
  [`pdf_obj_marked_content_id()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marked_content_id.md),
  [`pdf_obj_clip_path()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_clip_path.md)
  cover every column.
- [`pdf_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_segments.md),
  [`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_stroke.md),
  [`pdf_path_fill()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_fill.md),
  [`pdf_path_dash()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_dash.md),
  [`pdf_path_line_cap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_cap.md),
  [`pdf_path_line_join()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_join.md),
  [`pdf_path_draw_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_draw_mode.md)
  — path geometry + style.
- [`pdf_text_runs()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_runs.md),
  [`pdf_text_content()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_content.md),
  [`pdf_text_font()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_font.md),
  [`pdf_text_font_metrics()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_font_metrics.md),
  [`pdf_text_chars()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_chars.md),
  [`pdf_text_colors()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_colors.md),
  [`pdf_text_render_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_render_mode.md),
  [`pdf_text_search()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_search.md),
  [`pdf_text_char_at_point()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_char_at_point.md),
  [`pdf_text_index_from_char()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_index_from_char.md),
  [`pdf_text_char_from_text_index()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_index_from_char.md),
  [`pdf_text_char_obj_index()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_char_obj_index.md),
  [`pdf_text_obj_rendered_bitmap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_obj_rendered_bitmap.md),
  [`pdf_glyph_path()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_glyph_path.md),
  [`pdf_glyph_width()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_glyph_width.md)
  — text inspection at every granularity.
- [`pdf_image_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_info.md),
  [`pdf_image_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_size.md),
  [`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_bitmap.md),
  [`pdf_image_rendered()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_rendered.md),
  [`pdf_image_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_data.md),
  [`pdf_image_filters()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_filters.md),
  [`pdf_image_icc_profile()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_icc_profile.md)
  — image-object readouts.
- [`pdf_clip_path_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_clip_path_count.md),
  [`pdf_clip_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_clip_path_segments.md)
  — clip-path geometry.
- [`pdf_form_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_objects.md)
  — Form XObject child enumeration.
- [`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_extract_paths.md)
  — one-call helper for the path-extraction workflow that motivated the
  package.
- [`pdf_structure_tree()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_structure_tree.md)
  — tagged-PDF / accessibility structure tree walk.

### Annotations and form fields

- [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
  returns a `pdfium_annot_list`;
  [`pdf_annot_subtype()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_subtype.md),
  [`pdf_annot_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_flags.md),
  [`pdf_annot_flags_decoded()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_flags_decoded.md),
  [`pdf_annot_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_bounds.md),
  [`pdf_annot_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_contents.md),
  [`pdf_annot_title()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_title.md),
  [`pdf_annot_subject()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_subject.md),
  [`pdf_annot_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_color.md),
  [`pdf_annot_interior_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_interior_color.md),
  [`pdf_annot_border_width()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_border_width.md),
  [`pdf_annot_font_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_font_size.md),
  [`pdf_annot_font_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_font_color.md),
  [`pdf_annot_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_dict_value.md),
  [`pdf_annot_appearance()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_appearance.md),
  [`pdf_annot_quad_points()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_quad_points.md),
  [`pdf_annot_vertices()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_vertices.md),
  [`pdf_annot_ink_paths()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_ink_paths.md),
  [`pdf_annot_popup()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_popup.md),
  [`pdf_annot_in_reply_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_in_reply_to.md),
  [`pdf_annot_file_attachment_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_file_attachment_name.md),
  [`pdf_annot_at()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_at.md)
  cover the full read surface.
- [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md)
  returns a `pdfium_form_field_list`;
  [`pdf_form_field_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_type.md),
  [`pdf_form_field_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_name.md),
  [`pdf_form_field_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_value.md),
  [`pdf_form_field_export_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_export_value.md),
  [`pdf_form_field_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_flags.md),
  [`pdf_form_field_flags_decoded()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_flags_decoded.md),
  [`pdf_form_field_is_checked()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_is_checked.md),
  [`pdf_form_field_control_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_control_count.md),
  [`pdf_form_field_control_index()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_control_index.md),
  [`pdf_form_field_options()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_options.md),
  [`pdf_form_field_is_option_selected()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_is_option_selected.md),
  [`pdf_form_field_additional_actions_js()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_additional_actions_js.md),
  [`pdf_form_field_at_point()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_at_point.md)
  cover form-fill inspection.
- [`pdf_page_links()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_links.md),
  [`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_link_at_point.md),
  [`pdf_link_annot_at_point()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_link_annot_at_point.md),
  [`pdf_page_actions()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_actions.md)
  — link and action introspection.

### Attachments and signatures

- [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md)
  returns a `pdfium_attachment_list`;
  [`pdf_attachment_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_name.md),
  [`pdf_attachment_mime_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_mime_type.md),
  [`pdf_attachment_size_bytes()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_size_bytes.md),
  [`pdf_attachment_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_data.md),
  [`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_dict_value.md)
  cover the read side.
- [`pdf_signatures()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signatures.md)
  returns a `pdfium_signature_list`;
  [`pdf_signature_sub_filter()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_sub_filter.md),
  [`pdf_signature_reason()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_reason.md),
  [`pdf_signature_time()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_time.md),
  [`pdf_signature_doc_mdp_permission()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_doc_mdp_permission.md),
  [`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_contents.md),
  [`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_byte_range.md)
  — digital signature metadata.

### Rendering

- [`pdf_render_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page.md),
  [`pdf_render_page_with_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page_with_matrix.md),
  [`pdf_render_to_png()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_to_png.md)
  — page-to-bitmap and page-to-file rendering, with full
  `FPDF_RenderPageBitmap*` flag coverage.
- [`plot()`](https://rdrr.io/r/graphics/plot.default.html),
  [`as.raster()`](https://rdrr.io/r/grDevices/as.raster.html),
  [`as.array()`](https://rdrr.io/r/base/array.html),
  [`as.matrix()`](https://rdrr.io/r/base/matrix.html) methods for
  `pdfium_bitmap` — interoperate with the existing R graphics stack.

### Structural mutation (open with `readwrite = TRUE`)

- [`pdf_page_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_new.md),
  [`pdf_page_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_delete.md),
  [`pdf_pages_reorder()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_pages_reorder.md),
  [`pdf_docs_merge()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_docs_merge.md),
  [`pdf_n_up()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_n_up.md),
  [`pdf_page_set_rotation()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_set_rotation.md),
  [`pdf_page_set_box()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_set_box.md),
  [`pdf_doc_set_language()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_set_language.md),
  [`pdf_page_flush()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_flush.md)
  — add, remove, reorder, and reshape pages.

### Page-object mutation

- [`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_matrix.md),
  [`pdf_obj_set_active()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_active.md),
  [`pdf_obj_set_blend_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_blend_mode.md),
  [`pdf_path_set_stroke()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_stroke.md),
  [`pdf_path_set_fill()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_fill.md),
  [`pdf_path_set_line_cap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_line_cap.md),
  [`pdf_path_set_line_join()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_line_join.md),
  [`pdf_path_set_dash()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_dash.md),
  [`pdf_path_set_draw_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_draw_mode.md),
  [`pdf_text_set_content()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_set_content.md),
  [`pdf_text_set_render_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_set_render_mode.md),
  [`pdf_obj_add_mark()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_add_mark.md),
  [`pdf_obj_remove_mark()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_remove_mark.md)
  — styling and metadata setters.
- [`pdf_path_move_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_move_to.md),
  [`pdf_path_line_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_to.md),
  [`pdf_path_bezier_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_bezier_to.md),
  [`pdf_path_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_close.md),
  [`pdf_path_append()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_append.md)
  — append path geometry to an existing path object.
- [`pdf_path_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_new.md),
  [`pdf_rect_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_rect_new.md),
  [`pdf_text_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_new.md),
  [`pdf_obj_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_delete.md)
  — create fresh paths, rectangles, and text objects, or remove an
  existing one.

### Annotation authoring

- [`pdf_annot_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_new.md),
  [`pdf_annot_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_delete.md),
  [`pdf_annot_set_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_bounds.md),
  [`pdf_annot_set_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_color.md),
  [`pdf_annot_set_interior_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_interior_color.md),
  [`pdf_annot_set_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_flags.md),
  [`pdf_annot_set_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_contents.md),
  [`pdf_annot_set_title()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_title.md),
  [`pdf_annot_set_subject()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_subject.md),
  [`pdf_annot_set_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_dict_value.md),
  [`pdf_annot_append_quad()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_append_quad.md)
  — create, remove, and mutate annotations of the supported subtypes
  (circle, fileattachment, freetext, highlight, ink, link, popup,
  square, squiggly, stamp, strikeout, text, underline).

### Form filling

- [`pdf_form_field_set_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_set_value.md)
  — polymorphic per-field writer. Dispatches by field type: character
  for text / choice fields, logical or character for checkable fields.
  Mirrors `/V` into `/AS` for checkable widgets so PDFium picks the
  correct appearance.
- [`pdf_form_field_clear()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_clear.md)
  — restore to `/DV` (or empty / `"Off"`).
- [`pdf_form_reset()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_reset.md)
  — doc-wide loop over
  [`pdf_form_field_clear()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_clear.md).
- [`pdf_page_flatten()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_flatten.md)
  — bake form widgets and annotations into the page content stream
  (one-way; intended as the final step before saving a non-editable
  copy).

### Attachment authoring

- [`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_new.md),
  [`pdf_attachment_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_delete.md),
  [`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_data.md),
  [`pdf_attachment_set_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_dict_value.md)
  — add embedded files, populate their bytes, and write `/Params`
  metadata.

### Enum code \<-\> name helpers

- [`pdfium_annot_subtype_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_annot_subtype_name.md)
  / `_code()`,
  [`pdfium_obj_type_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_obj_type_name.md)
  / `_code()`,
  [`pdfium_segment_type_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_segment_type_name.md)
  / `_code()`,
  [`pdfium_form_field_type_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_form_field_type_name.md)
  / `_code()`,
  [`pdfium_action_type_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_action_type_name.md)
  / `_code()`,
  [`pdfium_dest_view_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_dest_view_name.md)
  / `_code()` — bidirectional converters between PDFium’s integer enum
  codes and short string names. Both vectorised; case-insensitive on
  input.

### Coercion helpers

Every `pdfium_*_list` class round-trips through `as_tibble()` and a
matching `as_pdfium_*_list()`. The tibble carries `handle` and `source`
list-columns; the inverse reads them back. See `?ADR-017` in
`dev/decisions/` for the rationale.

### Bundled PDFium binary

The package downloads a pinned PDFium binary from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
at install time (configure-time on POSIX, `configure.win` on Windows).
The pin lives in `tools/pdfium-version.txt`. CRAN’s
network-at-configure-time policy permits this; the offline fallback is
documented in `configure`.

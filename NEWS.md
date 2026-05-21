# pdfium 0.1.0

Initial CRAN release. This is the first public version of `pdfium`,
an R wrapper for Google's PDFium C API. The package surface is split
into a comprehensive **read** layer (parse and inspect any PDF) and
a focused **mutation** layer (open with `readwrite = TRUE` to enable;
PDFs created with `pdf_doc_new()` are also writable).

## Documents and pages

* `pdf_doc_open()` / `pdf_doc_close()`, `pdf_doc_new()`,
  `pdf_save()` / `pdf_save_to_raw()` — open existing PDFs (optionally
  with `readwrite = TRUE`), build new ones in memory, and persist
  the result.
* `pdf_doc_info()`, `pdf_doc_meta()`, `pdf_doc_text()`,
  `pdf_doc_fonts()`, `pdf_doc_file_id()`, `pdf_doc_page_mode()`,
  `pdf_doc_viewer_preferences()`, `pdf_doc_viewer_preference_by_name()`,
  `pdf_doc_permissions()`, `pdf_doc_user_permissions()`,
  `pdf_doc_security()`, `pdf_doc_xref_valid()`,
  `pdf_doc_trailer_ends()`, `pdf_doc_is_tagged()`,
  `pdf_doc_javascript()`, `pdf_doc_focusable_subtypes()` — document-
  level inspection.
* `pdf_doc_named_dests()`, `pdf_doc_named_dest_by_name()`,
  `pdf_doc_bookmarks()`, `pdf_doc_bookmark_find()`,
  `pdf_page_label()`, `pdf_page_labels()` — outlines and named
  destinations.
* `pdf_page_load()` / `pdf_page_close()`, `pdf_page_size()`,
  `pdf_page_rotation()`, `pdf_page_box()`, `pdf_page_thumbnail()` —
  per-page handles and metadata.

## Page objects, paths, and text

* `pdf_page_objects()` returns a `pdfium_obj_list`; per-handle
  accessors `pdf_obj_type()`, `pdf_obj_bounds()`,
  `pdf_obj_rotated_bounds()`, `pdf_obj_matrix()`,
  `pdf_obj_has_transparency()`, `pdf_obj_is_active()`,
  `pdf_obj_marks()`, `pdf_obj_marked_content_id()`,
  `pdf_obj_clip_path()` cover every column.
* `pdf_path_segments()`, `pdf_path_stroke()`, `pdf_path_fill()`,
  `pdf_path_dash()`, `pdf_path_line_cap()`, `pdf_path_line_join()`,
  `pdf_path_draw_mode()` — path geometry + style.
* `pdf_text_runs()`, `pdf_text_content()`, `pdf_text_font()`,
  `pdf_text_font_metrics()`, `pdf_text_chars()`, `pdf_text_colors()`,
  `pdf_text_render_mode()`, `pdf_text_search()`,
  `pdf_text_char_at_point()`, `pdf_text_index_from_char()`,
  `pdf_text_char_from_text_index()`, `pdf_text_char_obj_index()`,
  `pdf_text_obj_rendered_bitmap()`, `pdf_glyph_path()`,
  `pdf_glyph_width()` — text inspection at every granularity.
* `pdf_image_info()`, `pdf_image_size()`, `pdf_image_bitmap()`,
  `pdf_image_rendered()`, `pdf_image_data()`, `pdf_image_filters()`,
  `pdf_image_icc_profile()` — image-object readouts.
* `pdf_clip_path_count()`, `pdf_clip_path_segments()` — clip-path
  geometry.
* `pdf_form_objects()` — Form XObject child enumeration.
* `pdf_extract_paths()` — one-call helper for the path-extraction
  workflow that motivated the package.
* `pdf_structure_tree()` — tagged-PDF / accessibility structure tree
  walk.

## Annotations and form fields

* `pdf_annotations()` returns a `pdfium_annot_list`;
  `pdf_annot_subtype()`, `pdf_annot_flags()`,
  `pdf_annot_flags_decoded()`, `pdf_annot_bounds()`,
  `pdf_annot_contents()`, `pdf_annot_title()`, `pdf_annot_subject()`,
  `pdf_annot_color()`, `pdf_annot_interior_color()`,
  `pdf_annot_border_width()`, `pdf_annot_font_size()`,
  `pdf_annot_font_color()`, `pdf_annot_dict_value()`,
  `pdf_annot_appearance()`, `pdf_annot_quad_points()`,
  `pdf_annot_vertices()`, `pdf_annot_ink_paths()`,
  `pdf_annot_popup()`, `pdf_annot_in_reply_to()`,
  `pdf_annot_file_attachment_name()`, `pdf_annot_at()` cover the
  full read surface.
* `pdf_form_fields()` returns a `pdfium_form_field_list`;
  `pdf_form_field_type()`, `pdf_form_field_name()`,
  `pdf_form_field_value()`, `pdf_form_field_export_value()`,
  `pdf_form_field_flags()`, `pdf_form_field_flags_decoded()`,
  `pdf_form_field_is_checked()`, `pdf_form_field_control_count()`,
  `pdf_form_field_control_index()`, `pdf_form_field_options()`,
  `pdf_form_field_is_option_selected()`,
  `pdf_form_field_additional_actions_js()`,
  `pdf_form_field_at_point()` cover form-fill inspection.
* `pdf_page_links()`, `pdf_link_at_point()`,
  `pdf_link_annot_at_point()`, `pdf_page_actions()` — link and
  action introspection.

## Attachments and signatures

* `pdf_attachments()` returns a `pdfium_attachment_list`;
  `pdf_attachment_name()`, `pdf_attachment_mime_type()`,
  `pdf_attachment_size_bytes()`, `pdf_attachment_data()`,
  `pdf_attachment_dict_value()` cover the read side.
* `pdf_signatures()` returns a `pdfium_signature_list`;
  `pdf_signature_sub_filter()`, `pdf_signature_reason()`,
  `pdf_signature_time()`, `pdf_signature_doc_mdp_permission()`,
  `pdf_signature_contents()`, `pdf_signature_byte_range()` — digital
  signature metadata.

## Rendering

* `pdf_render_page()`, `pdf_render_page_with_matrix()`,
  `pdf_render_to_png()` — page-to-bitmap and page-to-file
  rendering, with full `FPDF_RenderPageBitmap*` flag coverage.
* `plot()`, `as.raster()`, `as.array()`, `as.matrix()` methods for
  `pdfium_bitmap` — interoperate with the existing R graphics stack.

## Structural mutation (open with `readwrite = TRUE`)

* `pdf_page_new()`, `pdf_page_delete()`, `pdf_pages_reorder()`,
  `pdf_docs_merge()`, `pdf_n_up()`, `pdf_page_set_rotation()`,
  `pdf_page_set_box()`, `pdf_doc_set_language()`, `pdf_page_flush()`
  — add, remove, reorder, and reshape pages.

## Page-object mutation

* `pdf_obj_set_matrix()`, `pdf_obj_set_active()`,
  `pdf_obj_set_blend_mode()`, `pdf_path_set_stroke()`,
  `pdf_path_set_fill()`, `pdf_path_set_line_cap()`,
  `pdf_path_set_line_join()`, `pdf_path_set_dash()`,
  `pdf_path_set_draw_mode()`, `pdf_text_set_content()`,
  `pdf_text_set_render_mode()`, `pdf_obj_add_mark()`,
  `pdf_obj_remove_mark()` — styling and metadata setters.
* `pdf_path_move_to()`, `pdf_path_line_to()`, `pdf_path_bezier_to()`,
  `pdf_path_close()`, `pdf_path_append()` — append path geometry to
  an existing path object.
* `pdf_path_new()`, `pdf_rect_new()`, `pdf_text_new()`,
  `pdf_obj_delete()` — create fresh paths, rectangles, and text
  objects, or remove an existing one.

## Annotation authoring

* `pdf_annot_new()`, `pdf_annot_delete()`, `pdf_annot_set_bounds()`,
  `pdf_annot_set_color()`, `pdf_annot_set_interior_color()`,
  `pdf_annot_set_flags()`, `pdf_annot_set_contents()`,
  `pdf_annot_set_title()`, `pdf_annot_set_subject()`,
  `pdf_annot_set_dict_value()`, `pdf_annot_append_quad()` — create,
  remove, and mutate annotations of the supported subtypes
  (circle, fileattachment, freetext, highlight, ink, link, popup,
  square, squiggly, stamp, strikeout, text, underline).

## Form filling

* `pdf_form_field_set_value()` — polymorphic per-field writer.
  Dispatches by field type: character for text / choice fields,
  logical or character for checkable fields. Mirrors `/V` into
  `/AS` for checkable widgets so PDFium picks the correct appearance.
* `pdf_form_field_clear()` — restore to `/DV` (or empty / `"Off"`).
* `pdf_form_reset()` — doc-wide loop over `pdf_form_field_clear()`.
* `pdf_page_flatten()` — bake form widgets and annotations into the
  page content stream (one-way; intended as the final step before
  saving a non-editable copy).

## Attachment authoring

* `pdf_attachment_new()`, `pdf_attachment_delete()`,
  `pdf_attachment_set_data()`, `pdf_attachment_set_dict_value()` —
  add embedded files, populate their bytes, and write `/Params`
  metadata.

## Enum code <-> name helpers

* `pdfium_annot_subtype_name()` / `_code()`,
  `pdfium_obj_type_name()` / `_code()`,
  `pdfium_segment_type_name()` / `_code()`,
  `pdfium_form_field_type_name()` / `_code()`,
  `pdfium_action_type_name()` / `_code()`,
  `pdfium_dest_view_name()` / `_code()` — bidirectional converters
  between PDFium's integer enum codes and short string names. Both
  vectorised; case-insensitive on input.

## Coercion helpers

Every `pdfium_*_list` class round-trips through `as_tibble()` and a
matching `as_pdfium_*_list()`. The tibble carries `handle` and
`source` list-columns; the inverse reads them back. See `?ADR-017`
in `dev/decisions/` for the rationale.

## Bundled PDFium binary

The package downloads a pinned PDFium binary from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
at install time (configure-time on POSIX, `configure.win` on
Windows). The pin lives in `tools/pdfium-version.txt`. CRAN's
network-at-configure-time policy permits this; the offline
fallback is documented in `configure`.

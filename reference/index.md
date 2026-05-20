# Package index

## Documents

- [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md)
  : Open a PDF document

- [`pdf_doc_close()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_close.md)
  : Close a PDF document

- [`pdf_page_count()`](https://humanpred.github.io/rpdfium/reference/pdf_page_count.md)
  : Count pages in a PDF document

- [`pdf_doc_info()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_info.md)
  : Document-level metadata for a PDF

- [`pdf_doc_meta()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_meta.md)
  : Read one entry from a PDF's Info dictionary

- [`pdf_parse_date()`](https://humanpred.github.io/rpdfium/reference/pdf_parse_date.md)
  : Parse a PDF date string into POSIXct

- [`pdf_doc_text()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_text.md)
  : Read every page's text in one call

- [`pdf_doc_fonts()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_fonts.md)
  : Document-level rollup of every embedded / referenced font

- [`pdf_doc_file_id()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_file_id.md)
  : Read the document's file identifier from its trailer

- [`pdf_doc_page_mode()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_page_mode.md)
  : Read the document's PageMode entry from its catalog

- [`pdf_doc_permissions()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_permissions.md)
  : Permission flags from a PDF's encryption dictionary

- [`pdf_doc_user_permissions()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_user_permissions.md)
  : User-level document permissions

- [`pdf_doc_security()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_security.md)
  : Document security handler revision

- [`pdf_doc_xref_valid()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_xref_valid.md)
  : Cross-reference table validity flag

- [`pdf_doc_trailer_ends()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_trailer_ends.md)
  :

  Byte offsets of every `%%EOF` trailer marker

- [`pdf_doc_is_tagged()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_is_tagged.md)
  : Is the document marked as tagged?

- [`pdf_doc_javascript()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_javascript.md)
  : Enumerate document-level JavaScript actions

- [`pdf_doc_focusable_subtypes()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_focusable_subtypes.md)
  : Annotation subtypes registered as keyboard-focusable

- [`pdf_doc_viewer_preferences()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_viewer_preferences.md)
  : Read the document's viewer preferences

- [`pdf_doc_viewer_preference_by_name()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_viewer_preference_by_name.md)
  :

  Look up a `/ViewerPreferences` name-typed entry by key

- [`pdf_doc_named_dests()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_named_dests.md)
  : Enumerate the document's named destinations

- [`pdf_doc_named_dest_by_name()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_named_dest_by_name.md)
  : Resolve a named destination by name

- [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md)
  : Read the bookmark outline (table of contents) of a PDF

- [`pdf_doc_bookmark_find()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmark_find.md)
  : Find a bookmark by its title

- [`pdf_page_label()`](https://humanpred.github.io/rpdfium/reference/pdf_page_label.md)
  : Read the logical page label of a PDF page

- [`pdf_page_labels()`](https://humanpred.github.io/rpdfium/reference/pdf_page_labels.md)
  : Read every page's logical label in one call

## Attachments

- [`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md)
  : List the files attached to a PDF document
- [`pdf_attachment_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_data.md)
  : Read the raw bytes of an embedded file attachment
- [`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_dict_value.md)
  : Look up an attachment-dictionary entry by key

## Signatures

- [`pdf_signatures()`](https://humanpred.github.io/rpdfium/reference/pdf_signatures.md)
  : List the digital signatures attached to a PDF document
- [`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_contents.md)
  : Read the raw bytes of a PDF signature's contents blob
- [`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_byte_range.md)
  : Read the signed byte ranges of a PDF signature

## Pages

- [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md)
  : Load a single page from an open PDF document
- [`pdf_page_close()`](https://humanpred.github.io/rpdfium/reference/pdf_page_close.md)
  : Close a page handle
- [`pdf_page_size()`](https://humanpred.github.io/rpdfium/reference/pdf_page_size.md)
  : Page dimensions in PDF points
- [`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_rotation.md)
  : Page rotation in degrees
- [`pdf_page_box()`](https://humanpred.github.io/rpdfium/reference/pdf_page_box.md)
  : Read a page's bounding box
- [`pdf_page_links()`](https://humanpred.github.io/rpdfium/reference/pdf_page_links.md)
  : List the clickable links on a page
- [`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md)
  : Hit-test for the link annotation under a point
- [`pdf_link_annot_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_annot_at_point.md)
  : Hit-test for a link annotation, returning its annotation index
- [`pdf_form_field_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_at_point.md)
  : Form-field hit-test for a point
- [`pdf_page_actions()`](https://humanpred.github.io/rpdfium/reference/pdf_page_actions.md)
  : Page additional actions (open / close handlers)
- [`pdf_page_thumbnail()`](https://humanpred.github.io/rpdfium/reference/pdf_page_thumbnail.md)
  : Page embedded thumbnail
- [`pdf_text_weblinks()`](https://humanpred.github.io/rpdfium/reference/pdf_text_weblinks.md)
  : Auto-detected web links in a page's text

## Annotations and form fields

- [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
  : List the annotations on a PDF page

- [`pdf_annot_at()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_at.md)
  :

  Construct a `pdfium_annot` handle for one annotation

- [`as_pdfium_annot_list()`](https://humanpred.github.io/rpdfium/reference/as_pdfium_annot_list.md)
  :

  Coerce input to a `pdfium_annot_list`

- [`as_tibble(`*`<pdfium_annot_list>`*`)`](https://humanpred.github.io/rpdfium/reference/as_tibble.pdfium_annot_list.md)
  :

  Tibble view of a `pdfium_annot_list`

- [`pdf_annot_subtype()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_subtype.md)
  : Annotation subtype (string)

- [`pdf_annot_subtype_code()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_subtype_code.md)
  : Annotation subtype code (integer enum)

- [`pdf_annot_flags()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_flags.md)
  : Annotation flag bitmask

- [`pdf_annot_flags_decoded()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_flags_decoded.md)
  : Annotation flags decoded as named logicals

- [`pdf_annot_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_bounds.md)
  : Annotation bounding rectangle

- [`pdf_annot_contents()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_contents.md)
  :

  Annotation `/Contents` text

- [`pdf_annot_title()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_title.md)
  :

  Annotation `/T` title (author) text

- [`pdf_annot_subject()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_subject.md)
  :

  Annotation `/Subj` subject text

- [`pdf_annot_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_color.md)
  :

  Annotation `/C` colour (RGBA, 0..1)

- [`pdf_annot_interior_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_interior_color.md)
  :

  Annotation `/IC` interior colour (RGBA, 0..1)

- [`pdf_annot_border_width()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_border_width.md)
  : Annotation border width

- [`pdf_annot_font_size()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_font_size.md)
  : Annotation font size (FreeText / Widget subtypes)

- [`pdf_annot_font_color()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_font_color.md)
  : Annotation font colour (RGB, 0..1)

- [`pdf_annot_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_dict_value.md)
  : Read an annotation-dict entry by key

- [`pdf_annot_appearance()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_appearance.md)
  : Appearance-stream string for an annotation

- [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md)
  : Enumerate AcroForm fields across the whole document

- [`as_pdfium_form_field_list()`](https://humanpred.github.io/rpdfium/reference/as_pdfium_form_field_list.md)
  :

  Coerce input to a `pdfium_form_field_list`

- [`as_tibble(`*`<pdfium_form_field_list>`*`)`](https://humanpred.github.io/rpdfium/reference/as_tibble.pdfium_form_field_list.md)
  :

  Tibble view of a `pdfium_form_field_list`

- [`pdf_form_field_type()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_type.md)
  : Form-field type (string)

- [`pdf_form_field_type_code()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_type_code.md)
  : Form-field type code (integer enum)

- [`pdf_form_field_page_num()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_page_num.md)
  : Form-field page number

## Page objects

- [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
  : Enumerate the objects on a page
- [`pdf_obj_type()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_type.md)
  : Report the type of a page object
- [`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md)
  : Axis-aligned bounding box of a page object
- [`pdf_obj_rotated_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_rotated_bounds.md)
  : Rotated bounding quadpoints of a page object
- [`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_matrix.md)
  : Transformation matrix of a page object
- [`pdf_obj_has_transparency()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_has_transparency.md)
  : Does a page object use alpha blending?
- [`pdf_obj_is_active()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_is_active.md)
  : Active flag of a page object
- [`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_marks.md)
  : Content marks attached to a page object
- [`pdf_obj_marked_content_id()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_marked_content_id.md)
  : Direct marked-content ID for a page object

## Paths

- [`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
  : Path segments of a path page-object
- [`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/reference/pdf_path_stroke.md)
  : Stroke style of a path page-object
- [`pdf_path_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_fill.md)
  : Fill color of a path page-object
- [`pdf_path_dash()`](https://humanpred.github.io/rpdfium/reference/pdf_path_dash.md)
  : Dash pattern of a path page-object
- [`pdf_path_line_cap()`](https://humanpred.github.io/rpdfium/reference/pdf_path_line_cap.md)
  : Stroke line-cap style of a path page-object
- [`pdf_path_line_join()`](https://humanpred.github.io/rpdfium/reference/pdf_path_line_join.md)
  : Stroke line-join style of a path page-object
- [`pdf_path_draw_mode()`](https://humanpred.github.io/rpdfium/reference/pdf_path_draw_mode.md)
  : Path draw mode (fill rule + stroke flag)

## Text

- [`pdf_text_font_size()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_size.md)
  : Font size of a text page-object
- [`pdf_text_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_content.md)
  : Text content of a text page-object
- [`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
  : Extract every text run on a page
- [`pdf_text_font()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font.md)
  : Font metadata of a text page-object
- [`pdf_text_font_metrics()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_metrics.md)
  : Font ascent and descent for a text page-object's font
- [`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)
  : Per-character text extraction
- [`pdf_text_colors()`](https://humanpred.github.io/rpdfium/reference/pdf_text_colors.md)
  : Per-character fill and stroke colors and text-index mapping
- [`pdf_text_render_mode()`](https://humanpred.github.io/rpdfium/reference/pdf_text_render_mode.md)
  : Text-rendering mode of a text page-object
- [`pdf_text_search()`](https://humanpred.github.io/rpdfium/reference/pdf_text_search.md)
  : Find every occurrence of a query string in a PDF
- [`pdf_text_char_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_text_char_at_point.md)
  : Locate the character index nearest a (x, y) point on a page
- [`pdf_text_index_from_char()`](https://humanpred.github.io/rpdfium/reference/pdf_text_index_from_char.md)
  [`pdf_text_char_from_text_index()`](https://humanpred.github.io/rpdfium/reference/pdf_text_index_from_char.md)
  : Map between PDFium's "all characters" and "extractable text" indices
- [`pdf_text_char_obj_index()`](https://humanpred.github.io/rpdfium/reference/pdf_text_char_obj_index.md)
  : Reverse-map a character index to its page-object index
- [`pdf_text_obj_rendered_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_text_obj_rendered_bitmap.md)
  : Rendered bitmap of a single text page-object
- [`pdf_glyph_path()`](https://humanpred.github.io/rpdfium/reference/pdf_glyph_path.md)
  : Glyph outline for a single glyph in a text page-object's font
- [`pdf_glyph_width()`](https://humanpred.github.io/rpdfium/reference/pdf_glyph_width.md)
  : Width of a glyph in a text page-object's font

## Rendering

- [`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md)
  : Render a PDF page to a bitmap

- [`pdf_render_page_with_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page_with_matrix.md)
  : Render a PDF page with an arbitrary affine transformation

- [`pdf_render_to_png()`](https://humanpred.github.io/rpdfium/reference/pdf_render_to_png.md)
  : Render a PDF page directly to a PNG file

- [`plot(`*`<pdfium_bitmap>`*`)`](https://humanpred.github.io/rpdfium/reference/plot.pdfium_bitmap.md)
  : Plot a pdfium_bitmap

- [`as.raster(`*`<pdfium_bitmap>`*`)`](https://humanpred.github.io/rpdfium/reference/as.raster.pdfium_bitmap.md)
  :

  Convert a pdfium_bitmap to base R's `"raster"` (character hex)

- [`as.array(`*`<pdfium_bitmap>`*`)`](https://humanpred.github.io/rpdfium/reference/as.array.pdfium_bitmap.md)
  : Convert a pdfium_bitmap to a 3D RGBA array of doubles in 0..1

- [`as.matrix(`*`<pdfium_bitmap>`*`)`](https://humanpred.github.io/rpdfium/reference/as.matrix.pdfium_bitmap.md)
  : Convert a pdfium_bitmap to a hex-color matrix

## Images

- [`pdf_image_info()`](https://humanpred.github.io/rpdfium/reference/pdf_image_info.md)
  : Inspect metadata for an embedded image
- [`pdf_image_size()`](https://humanpred.github.io/rpdfium/reference/pdf_image_size.md)
  : Pixel size of an embedded image
- [`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md)
  : Decoded image bitmap
- [`pdf_image_rendered()`](https://humanpred.github.io/rpdfium/reference/pdf_image_rendered.md)
  : Rendered image bitmap (page CTM applied)
- [`pdf_image_data()`](https://humanpred.github.io/rpdfium/reference/pdf_image_data.md)
  : Raw bytes of an embedded image stream
- [`pdf_image_filters()`](https://humanpred.github.io/rpdfium/reference/pdf_image_filters.md)
  : Filter chain for an embedded image stream
- [`pdf_image_icc_profile()`](https://humanpred.github.io/rpdfium/reference/pdf_image_icc_profile.md)
  : Decoded ICC color profile bytes for an embedded image

## Form XObjects

- [`pdf_form_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_form_objects.md)
  : List the page objects nested inside a Form XObject

## Clip paths

- [`pdf_obj_clip_path()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_clip_path.md)
  : Get the clip path attached to a page object
- [`pdf_clip_path_count()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_count.md)
  : Count sub-paths in a clip path
- [`pdf_clip_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_segments.md)
  : Read all segments of a clip path as a tibble

## Structure tree (tagged PDF / accessibility)

- [`pdf_structure_tree()`](https://humanpred.github.io/rpdfium/reference/pdf_structure_tree.md)
  : Read the tagged-PDF structure tree for a page

## One-call extraction

- [`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/reference/pdf_extract_paths.md)
  : Extract all path geometry on a page into a single tibble

## Document creation and serialisation

- [`pdf_doc_new()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_new.md)
  : Create a new, empty PDF document
- [`pdf_save()`](https://humanpred.github.io/rpdfium/reference/pdf_save.md)
  : Save a PDF document to disk
- [`pdf_save_to_raw()`](https://humanpred.github.io/rpdfium/reference/pdf_save_to_raw.md)
  : Save a PDF document to a raw vector

## Structural mutation

Open a document with `readwrite = TRUE` (or build one with
[`pdf_doc_new()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_new.md))
to enable these. See ADRs 011-018 for the writer-surface conventions.

- [`pdf_page_new()`](https://humanpred.github.io/rpdfium/reference/pdf_page_new.md)
  : Add a new blank page
- [`pdf_page_delete()`](https://humanpred.github.io/rpdfium/reference/pdf_page_delete.md)
  : Delete a page from the document
- [`pdf_pages_reorder()`](https://humanpred.github.io/rpdfium/reference/pdf_pages_reorder.md)
  : Reorder pages
- [`pdf_docs_merge()`](https://humanpred.github.io/rpdfium/reference/pdf_docs_merge.md)
  : Merge documents into a new PDF
- [`pdf_n_up()`](https://humanpred.github.io/rpdfium/reference/pdf_n_up.md)
  : Combine N pages of a document into one
- [`pdf_page_set_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_set_rotation.md)
  : Set a page's rotation
- [`pdf_page_set_box()`](https://humanpred.github.io/rpdfium/reference/pdf_page_set_box.md)
  : Set one of a page's named bounding boxes
- [`pdf_doc_set_language()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_set_language.md)
  : Set the document's declared language

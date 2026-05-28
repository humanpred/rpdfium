# Package index

## Documents

- [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md)
  : Open a PDF document

- [`pdf_doc_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_close.md)
  : Close a PDF document

- [`pdf_page_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_count.md)
  : Count pages in a PDF document

- [`pdf_doc_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_info.md)
  : Document-level metadata for a PDF

- [`pdf_doc_meta()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_meta.md)
  : Read one entry from a PDF's Info dictionary

- [`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md)
  : One-call summary of a PDF document

- [`summary(`*`<pdfium_doc>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_doc.md)
  : Document-level summary

- [`pdf_parse_date()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_parse_date.md)
  : Parse a PDF date string into POSIXct

- [`pdf_doc_text()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_text.md)
  : Read every page's text in one call

- [`pdf_doc_fonts()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_fonts.md)
  : Document-level rollup of every embedded / referenced font

- [`pdf_doc_file_id()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_file_id.md)
  : Read the document's file identifier from its trailer

- [`pdf_doc_page_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_page_mode.md)
  : Read the document's PageMode entry from its catalog

- [`pdf_doc_permissions()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_permissions.md)
  : Permission flags from a PDF's encryption dictionary

- [`pdf_doc_user_permissions()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_user_permissions.md)
  : User-level document permissions

- [`pdf_doc_security()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_security.md)
  : Document security handler revision

- [`pdf_doc_xref_valid()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_xref_valid.md)
  : Cross-reference table validity flag

- [`pdf_doc_trailer_ends()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_trailer_ends.md)
  :

  Byte offsets of every `%%EOF` trailer marker

- [`pdf_doc_is_tagged()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_is_tagged.md)
  : Is the document marked as tagged?

- [`pdf_doc_javascript()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_javascript.md)
  : Enumerate document-level JavaScript actions

- [`pdf_doc_focusable_subtypes()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_focusable_subtypes.md)
  : Annotation subtypes registered as keyboard-focusable

- [`pdf_doc_viewer_preferences()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_viewer_preferences.md)
  : Read the document's viewer preferences

- [`pdf_doc_viewer_preference_by_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_viewer_preference_by_name.md)
  :

  Look up a `/ViewerPreferences` name-typed entry by key

- [`pdf_doc_named_dests()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_named_dests.md)
  : Enumerate the document's named destinations

- [`pdf_doc_named_dest_by_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_named_dest_by_name.md)
  : Resolve a named destination by name

- [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmarks.md)
  : List the bookmark outline (table of contents) of a PDF

- [`pdf_doc_bookmark_find()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_bookmark_find.md)
  : Find a bookmark by its title

- [`pdf_page_label()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_label.md)
  : Read the logical page label of a PDF page

- [`pdf_page_labels()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_labels.md)
  : Read every page's logical label in one call

## Attachments

- [`pdf_attachments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachments.md)
  : List the files attached to a PDF document

- [`as_pdfium_attachment_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_pdfium_attachment_list.md)
  :

  Coerce input to a `pdfium_attachment_list`

- [`as_tibble(`*`<pdfium_attachment_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_attachment_list.md)
  :

  Tibble view of a `pdfium_attachment_list`

- [`summary(`*`<pdfium_attachment_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_attachment_list.md)
  : Tibble-shaped summary of an attachment list

- [`pdf_attachment_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_name.md)
  : Attachment file name

- [`pdf_attachment_mime_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_mime_type.md)
  : Attachment MIME / subtype

- [`pdf_attachment_size_bytes()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_size_bytes.md)
  : Attachment decompressed size in bytes

- [`pdf_attachment_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_data.md)
  : Read the raw bytes of an embedded file attachment

- [`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_dict_value.md)
  : Look up an attachment-dictionary entry by key

## Signatures

- [`pdf_signatures()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signatures.md)
  : List the digital signatures attached to a PDF document

- [`as_pdfium_signature_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_pdfium_signature_list.md)
  :

  Coerce input to a `pdfium_signature_list`

- [`as_tibble(`*`<pdfium_signature_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_signature_list.md)
  :

  Tibble view of a `pdfium_signature_list`

- [`summary(`*`<pdfium_signature_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_signature_list.md)
  : Tibble-shaped summary of a signature list

- [`pdf_signature_sub_filter()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_sub_filter.md)
  :

  Signature `/SubFilter` value

- [`pdf_signature_reason()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_reason.md)
  : Signature reason / comment text

- [`pdf_signature_time()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_time.md)
  : Signing time (raw PDF date string)

- [`pdf_signature_doc_mdp_permission()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_doc_mdp_permission.md)
  : Signature DocMDP permission level

- [`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_contents.md)
  : Read the raw bytes of a PDF signature's contents blob

- [`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_byte_range.md)
  : Read the signed byte ranges of a PDF signature

## Bookmarks

- [`as_pdfium_bookmark_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_pdfium_bookmark_list.md)
  :

  Coerce input to a `pdfium_bookmark_list`

- [`as_tibble(`*`<pdfium_bookmark_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_bookmark_list.md)
  :

  Tibble view of a `pdfium_bookmark_list`

- [`summary(`*`<pdfium_bookmark_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_bookmark_list.md)
  : Tibble-shaped summary of a bookmark list

- [`pdf_bookmark_title()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_title.md)
  : Bookmark display title

- [`pdf_bookmark_page_num()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_page_num.md)
  : Bookmark destination page number

- [`pdf_bookmark_action_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_action_type.md)
  : Bookmark action type

- [`pdf_bookmark_uri()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_uri.md)
  : Bookmark URI (for URI actions)

- [`pdf_bookmark_filepath()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_filepath.md)
  : Bookmark external file path

- [`pdf_bookmark_dest_view()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_view.md)
  : Bookmark destination view mode

- [`pdf_bookmark_dest_x()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_x.md)
  : Bookmark destination x coordinate

- [`pdf_bookmark_dest_y()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_y.md)
  : Bookmark destination y coordinate

- [`pdf_bookmark_dest_zoom()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_zoom.md)
  : Bookmark destination zoom factor

## Pages

- [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md)
  : Load a single page from an open PDF document
- [`pdf_page_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_close.md)
  : Close a page handle
- [`pdf_page_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_size.md)
  : Page dimensions in PDF points
- [`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_rotation.md)
  : Page rotation in degrees
- [`pdf_page_box()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_box.md)
  : Read a page's bounding box
- [`pdf_pages_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_pages_summary.md)
  : One-call summary of every page in a document
- [`summary(`*`<pdfium_page>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_page.md)
  : Page-level summary
- [`pdf_page_links()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_links.md)
  : List the clickable links on a page
- [`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_link_at_point.md)
  : Hit-test for the link annotation under a point
- [`pdf_link_annot_at_point()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_link_annot_at_point.md)
  : Hit-test for a link annotation, returning the annotation handle
- [`pdf_form_field_at_point()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_at_point.md)
  : Form-field hit-test for a point
- [`pdf_page_actions()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_actions.md)
  : Page additional actions (open / close handlers)
- [`pdf_page_thumbnail()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_thumbnail.md)
  : Page embedded thumbnail
- [`pdf_text_weblinks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_weblinks.md)
  : Auto-detected web links in a page's text

## Annotations and form fields

- [`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
  : List the annotations on a PDF page

- [`pdf_annot_at()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_at.md)
  :

  Construct a `pdfium_annot` handle for one annotation

- [`as_pdfium_annot_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_pdfium_annot_list.md)
  :

  Coerce input to a `pdfium_annot_list`

- [`as_tibble(`*`<pdfium_annot_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_annot_list.md)
  :

  Tibble view of a `pdfium_annot_list`

- [`summary(`*`<pdfium_annot_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_annot_list.md)
  : Tibble-shaped summary of an annotation list

- [`pdf_annot_subtype()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_subtype.md)
  : Annotation subtype (string)

- [`pdf_annot_subtype_code()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_subtype_code.md)
  : Annotation subtype code (integer enum)

- [`pdf_annot_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_flags.md)
  : Annotation flag bitmask

- [`pdf_annot_flags_decoded()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_flags_decoded.md)
  : Annotation flags decoded as named logicals

- [`pdf_annot_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_bounds.md)
  : Annotation bounding rectangle

- [`pdf_annot_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_contents.md)
  :

  Annotation `/Contents` text

- [`pdf_annot_title()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_title.md)
  :

  Annotation `/T` title (author) text

- [`pdf_annot_subject()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_subject.md)
  :

  Annotation `/Subj` subject text

- [`pdf_annot_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_color.md)
  :

  Annotation `/C` colour (RGBA, 0..1)

- [`pdf_annot_interior_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_interior_color.md)
  :

  Annotation `/IC` interior colour (RGBA, 0..1)

- [`pdf_annot_border_width()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_border_width.md)
  : Annotation border width

- [`pdf_annot_font_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_font_size.md)
  : Annotation font size (FreeText / Widget subtypes)

- [`pdf_annot_font_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_font_color.md)
  : Annotation font colour (RGB, 0..1)

- [`pdf_annot_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_dict_value.md)
  : Read an annotation-dict entry by key

- [`pdf_annot_appearance()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_appearance.md)
  : Appearance-stream string for an annotation

- [`pdf_annot_quad_points()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_quad_points.md)
  : Annotation quad points (attachment points)

- [`pdf_annot_vertices()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_vertices.md)
  : Annotation vertices (polygon / polyline)

- [`pdf_annot_ink_paths()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_ink_paths.md)
  : Annotation ink paths (ink strokes)

- [`pdf_annot_popup()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_popup.md)
  :

  Annotation popup (`/Popup` linked annot)

- [`pdf_annot_in_reply_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_in_reply_to.md)
  :

  Annotation reply-to (`/IRT` linked annot)

- [`pdf_annot_file_attachment_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_file_attachment_name.md)
  : Name of the file attached to a file-attachment annotation

- [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md)
  : Enumerate AcroForm fields across the whole document

- [`as_pdfium_form_field_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_pdfium_form_field_list.md)
  :

  Coerce input to a `pdfium_form_field_list`

- [`as_tibble(`*`<pdfium_form_field_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_form_field_list.md)
  :

  Tibble view of a `pdfium_form_field_list`

- [`summary(`*`<pdfium_form_field_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_form_field_list.md)
  : Tibble-shaped summary of a form-field list

- [`pdf_form_field_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_type.md)
  : Form-field type (string)

- [`pdf_form_field_type_code()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_type_code.md)
  : Form-field type code (integer enum)

- [`pdf_form_field_page_num()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_page_num.md)
  : Form-field page number

- [`pdf_form_field_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_name.md)
  :

  Form-field name (`/T`)

- [`pdf_form_field_alternate_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_alternate_name.md)
  :

  Form-field alternate (tooltip) name (`/TU`)

- [`pdf_form_field_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_value.md)
  :

  Form-field current value (`/V`)

- [`pdf_form_field_export_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_export_value.md)
  : Form-field export value

- [`pdf_form_field_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_flags.md)
  :

  Form-field flag bitmask (`/Ff`)

- [`pdf_form_field_flags_decoded()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_flags_decoded.md)
  : Form-field universal flag bits, decoded

- [`pdf_form_field_is_checked()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_is_checked.md)
  : Form-field checked state

- [`pdf_form_field_control_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_control_count.md)
  : Number of controls in this radio group (or NA)

- [`pdf_form_field_control_index()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_control_index.md)
  : 1-based index of this control within its radio group

- [`pdf_form_field_options()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_options.md)
  : Form-field option labels (combobox / listbox)

- [`pdf_form_field_is_option_selected()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_is_option_selected.md)
  : Form-field option selected-state (combobox / listbox)

- [`pdf_form_field_additional_actions_js()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_additional_actions_js.md)
  : Form-field JavaScript additional-action sources

## Page objects

- [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
  : Enumerate the objects on a page

- [`as_pdfium_obj_list()`](https://humanpred.github.io/rpdfium/dev/reference/as_pdfium_obj_list.md)
  :

  Coerce input to a `pdfium_obj_list`

- [`as_tibble(`*`<pdfium_obj_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/as_tibble.pdfium_obj_list.md)
  :

  Tibble view of a `pdfium_obj_list`

- [`summary(`*`<pdfium_obj_list>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/summary.pdfium_obj_list.md)
  : Tibble-shaped summary of a page-object list

- [`pdf_obj_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_type.md)
  : Report the type of a page object

- [`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_bounds.md)
  : Axis-aligned bounding box of a page object

- [`pdf_obj_rotated_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_rotated_bounds.md)
  : Rotated bounding quadpoints of a page object

- [`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_matrix.md)
  : Transformation matrix of a page object

- [`pdf_obj_has_transparency()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_has_transparency.md)
  : Does a page object use alpha blending?

- [`pdf_obj_is_active()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_is_active.md)
  : Active flag of a page object

- [`pdf_obj_marks()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marks.md)
  : Content marks attached to a page object

- [`pdf_obj_marked_content_id()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_marked_content_id.md)
  : Direct marked-content ID for a page object

## Paths

- [`pdf_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_segments.md)
  : Path segments of a path page-object
- [`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_stroke.md)
  : Stroke style of a path page-object
- [`pdf_path_fill()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_fill.md)
  : Fill color of a path page-object
- [`pdf_path_dash()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_dash.md)
  : Dash pattern of a path page-object
- [`pdf_path_line_cap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_cap.md)
  : Stroke line-cap style of a path page-object
- [`pdf_path_line_join()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_join.md)
  : Stroke line-join style of a path page-object
- [`pdf_path_draw_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_draw_mode.md)
  : Path draw mode (fill rule + stroke flag)

## Text

- [`pdf_text_font_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_font_size.md)
  : Font size of a text page-object
- [`pdf_text_content()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_content.md)
  : Text content of a text page-object
- [`pdf_text_runs()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_runs.md)
  : Extract every text run on a page
- [`pdf_text_font()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_font.md)
  : Font metadata of a text page-object
- [`pdf_text_font_metrics()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_font_metrics.md)
  : Font ascent and descent for a text page-object's font
- [`pdf_text_chars()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_chars.md)
  : Per-character text extraction
- [`pdf_text_colors()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_colors.md)
  : Per-character fill and stroke colors and text-index mapping
- [`pdf_text_render_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_render_mode.md)
  : Text-rendering mode of a text page-object
- [`pdf_text_search()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_search.md)
  : Find every occurrence of a query string in a PDF
- [`pdf_text_char_at_point()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_char_at_point.md)
  : Locate the character index nearest a (x, y) point on a page
- [`pdf_text_index_from_char()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_index_from_char.md)
  [`pdf_text_char_from_text_index()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_index_from_char.md)
  : Map between PDFium's "all characters" and "extractable text" indices
- [`pdf_text_char_obj_index()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_char_obj_index.md)
  : Reverse-map a character index to its page-object index
- [`pdf_text_obj_rendered_bitmap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_obj_rendered_bitmap.md)
  : Rendered bitmap of a single text page-object
- [`pdf_glyph_path()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_glyph_path.md)
  : Glyph outline for a single glyph in a text page-object's font
- [`pdf_glyph_width()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_glyph_width.md)
  : Width of a glyph in a text page-object's font

## Rendering

- [`pdf_render_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page.md)
  : Render a PDF page to a bitmap

- [`pdf_render_page_with_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page_with_matrix.md)
  : Render a PDF page with an arbitrary affine transformation

- [`pdf_render_to_png()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_to_png.md)
  : Render a PDF page directly to a PNG file

- [`plot(`*`<pdfium_bitmap>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/plot.pdfium_bitmap.md)
  : Plot a pdfium_bitmap

- [`as.raster(`*`<pdfium_bitmap>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/as.raster.pdfium_bitmap.md)
  :

  Convert a pdfium_bitmap to base R's `"raster"` (character hex)

- [`as.array(`*`<pdfium_bitmap>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/as.array.pdfium_bitmap.md)
  : Convert a pdfium_bitmap to a 3D RGBA array of doubles in 0..1

- [`as.matrix(`*`<pdfium_bitmap>`*`)`](https://humanpred.github.io/rpdfium/dev/reference/as.matrix.pdfium_bitmap.md)
  : Convert a pdfium_bitmap to a hex-color matrix

## Images

- [`pdf_image_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_info.md)
  : Inspect metadata for an embedded image
- [`pdf_image_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_size.md)
  : Pixel size of an embedded image
- [`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_bitmap.md)
  : Decoded image bitmap
- [`pdf_image_rendered()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_rendered.md)
  : Rendered image bitmap (page CTM applied)
- [`pdf_image_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_data.md)
  : Raw bytes of an embedded image stream
- [`pdf_image_filters()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_filters.md)
  : Filter chain for an embedded image stream
- [`pdf_image_icc_profile()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_icc_profile.md)
  : Decoded ICC color profile bytes for an embedded image

## Form XObjects

- [`pdf_form_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_objects.md)
  : List the page objects nested inside a Form XObject

## Clip paths

- [`pdf_obj_clip_path()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_clip_path.md)
  : Get the clip path attached to a page object
- [`pdf_clip_path_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_clip_path_count.md)
  : Count sub-paths in a clip path
- [`pdf_clip_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_clip_path_segments.md)
  : Read all segments of a clip path as a tibble

## Structure tree (tagged PDF / accessibility)

- [`pdf_structure_tree()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_structure_tree.md)
  : Read the tagged-PDF structure tree for a page

## One-call extraction

- [`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_extract_paths.md)
  : Extract all path geometry on a page into a single tibble

## Document creation and serialisation

- [`pdf_doc_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_new.md)
  : Create a new, empty PDF document
- [`pdf_save()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save.md)
  : Save a PDF document to disk
- [`pdf_save_to_raw()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save_to_raw.md)
  : Save a PDF document to a raw vector

## Structural mutation

Open a document with `readwrite = TRUE` (or build one with
[`pdf_doc_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_new.md))
to enable these. See ADRs 011-018 for the writer-surface conventions.

- [`pdf_page_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_new.md)
  : Add a new blank page
- [`pdf_page_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_delete.md)
  : Delete a page from the document
- [`pdf_pages_reorder()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_pages_reorder.md)
  : Reorder pages
- [`pdf_docs_merge()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_docs_merge.md)
  : Merge documents into a new PDF
- [`pdf_n_up()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_n_up.md)
  : Combine N pages of a document into one
- [`pdf_page_set_rotation()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_set_rotation.md)
  : Set a page's rotation
- [`pdf_page_set_box()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_set_box.md)
  : Set one of a page's named bounding boxes
- [`pdf_doc_set_language()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_set_language.md)
  : Set the document's declared language
- [`pdf_page_flush()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_flush.md)
  : Force-flush a page's pending content edits

## Page-object styling

Setters for page-object attributes. Each takes a `pdfium_obj` handle
from
[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
(parent doc must be readwrite) and marks the parent page dirty so
[`pdf_save()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save.md)
/ `pdf_render_*()` see the change.

- [`pdf_obj_set_matrix()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_matrix.md)
  : Set the affine transformation matrix of a page object
- [`pdf_obj_set_active()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_active.md)
  : Set whether a page object renders
- [`pdf_obj_set_blend_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_blend_mode.md)
  : Set the blend mode of a page object
- [`pdf_path_set_stroke()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_stroke.md)
  : Set the stroke style of a path page object
- [`pdf_path_set_fill()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_fill.md)
  : Set the fill color of a path page object
- [`pdf_path_set_line_cap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_line_cap.md)
  : Set the line cap style of a path stroke
- [`pdf_path_set_line_join()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_line_join.md)
  : Set the line join style of a path stroke
- [`pdf_path_set_dash()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_dash.md)
  : Set the dash array + phase of a path stroke
- [`pdf_path_set_draw_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_draw_mode.md)
  : Set the draw mode of a path page object
- [`pdf_text_set_content()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_set_content.md)
  : Replace the text content of a text page object
- [`pdf_text_set_render_mode()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_set_render_mode.md)
  : Set the render mode of a text page object
- [`pdf_obj_add_mark()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_add_mark.md)
  : Add a content mark to a page object
- [`pdf_obj_remove_mark()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_remove_mark.md)
  : Remove a content mark from a page object

## Path geometry

Appenders for path page-objects. PDFium’s public API is append-only —
there is no segment-removal or -replacement symbol. Compose with
[`pdf_path_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_new.md)
and
[`pdf_obj_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_delete.md)
below for the full read → edit → write workflow.

- [`pdf_path_move_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_move_to.md)
  : Append a MoveTo command to a path object
- [`pdf_path_line_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_to.md)
  : Append a LineTo command to a path object
- [`pdf_path_bezier_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_bezier_to.md)
  : Append a cubic Bezier curve to a path object
- [`pdf_path_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_close.md)
  : Close the current subpath of a path object
- [`pdf_path_append()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_append.md)
  : Append a sequence of path segments in one call

## Page-object creation

Create fresh page-objects (paths, rectangles, text, JPEG images) on a
page that’s been opened with `readwrite = TRUE` or built via
[`pdf_doc_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_new.md).
Use
[`pdf_obj_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_delete.md)
for the inverse — remove + destroy a page-object. PNG / TIFF / raw-
bitmap embedding stays deferred to a later release pending `FPDF_BITMAP`
plumbing.

- [`pdf_path_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_new.md)
  : Create a new path page-object on a page
- [`pdf_rect_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_rect_new.md)
  : Create a closed rectangle path on a page
- [`pdf_text_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_new.md)
  : Create a new text page-object on a page
- [`pdf_image_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_new.md)
  : Create a new image page-object from JPEG bytes
- [`pdf_obj_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_delete.md)
  : Remove a page object and destroy it

## Font loading

Load a font for use in
[`pdf_text_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_new.md).
The 14 PDF standard fonts need no embedding; arbitrary TrueType / Type1
fonts get their bytes copied into the document via `FPDFText_LoadFont`.
[`pdf_font_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_close.md)
is idempotent and matches the explicit- release pattern of the other
handle classes.

- [`pdf_font_load_standard()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load_standard.md)
  : Load one of the 14 PDF standard fonts
- [`pdf_font_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load.md)
  : Load a TrueType or Type1 font from bytes
- [`pdf_font_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_close.md)
  : Close a font handle

## Annotation authoring

Create / delete annotations and mutate their properties. Mirrors the
`pdf_annot_*` readers; each setter takes a `pdfium_annot` whose parent
doc is readwrite. PDFium supports creating these subtypes: circle,
fileattachment, freetext, highlight, ink, link, popup, square, squiggly,
stamp, strikeout, text, underline.

- [`pdf_annot_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_new.md)
  : Create a new annotation on a page

- [`pdf_annot_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_delete.md)
  : Remove an annotation and invalidate the handle

- [`pdf_annot_set_bounds()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_bounds.md)
  : Set the bounding rectangle of an annotation

- [`pdf_annot_set_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_color.md)
  : Set the stroke / line color of an annotation

- [`pdf_annot_set_interior_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_interior_color.md)
  : Set the interior / fill color of an annotation

- [`pdf_annot_set_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_flags.md)
  : Set the flags bitmask of an annotation

- [`pdf_annot_set_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_contents.md)
  :

  Set the `/Contents` text of an annotation

- [`pdf_annot_set_title()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_title.md)
  :

  Set the `/T` (title / author) of an annotation

- [`pdf_annot_set_subject()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_subject.md)
  :

  Set the `/Subj` (subject) of an annotation

- [`pdf_annot_set_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_dict_value.md)
  : Set an arbitrary string-valued entry on an annotation dict

- [`pdf_annot_append_quad()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_append_quad.md)
  :

  Append a quad to an annotation's `/QuadPoints` array

## Form filling

Write `/V` (the field value) on AcroForm widget annotations and flatten
the page when the form-fill workflow finishes.
[`pdf_form_field_set_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_set_value.md)
dispatches by the field’s type: character for text / choice fields,
logical-or-character for checkable fields.
[`pdf_page_flatten()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_flatten.md)
bakes both form widgets and annotations into the page’s content stream —
irreversible and intended as the final step before saving a non-editable
copy.

- [`pdf_form_field_set_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_set_value.md)
  : Set the value of a form field
- [`pdf_form_field_clear()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_clear.md)
  : Clear a form field to its default value
- [`pdf_form_reset()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_reset.md)
  : Reset every form field in the document to its default value
- [`pdf_page_flatten()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_flatten.md)
  : Flatten form fields and annotations into the page content stream

## Attachment authoring

Add, delete, and mutate the document’s embedded-file attachments. The
natural sequence for a fresh attachment is
[`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_new.md)
→
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_data.md)
(to populate the file bytes and materialise the `/Params` subdict) →
[`pdf_attachment_set_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_dict_value.md)
(for any extra dictionary metadata).

- [`pdf_attachment_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_new.md)
  : Add a new embedded file attachment to a document

- [`pdf_attachment_delete()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_delete.md)
  : Delete an embedded file attachment from a document

- [`pdf_attachment_set_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_dict_value.md)
  :

  Set an entry in an attachment's `/Params` dictionary

- [`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_data.md)
  : Set the raw bytes of an embedded file attachment

## API-completion additions

The v0.1.0 “complete the relevant PDFium surface” pass picks up the last
batch of single-call wrappers that pair with the existing readers +
setters. Grouped by topic below; all live in `R/api_completion.R`.

- [`pdf_doc_form_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_form_type.md)
  : Form-type flavour of the document

- [`pdf_bookmark_child_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_child_count.md)
  : Number of children for a bookmark

- [`pdf_page_has_transparency()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_has_transparency.md)
  : Does the page contain transparency?

- [`pdf_page_bounding_box()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_bounding_box.md)
  : Page bounding box (cropbox ∩ mediabox)

- [`pdf_page_transform_annots()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_transform_annots.md)
  : Transform every annotation on a page in one shot

- [`pdf_annot_index()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_index.md)
  : Find an annotation's page-relative index by handle

- [`pdf_device_to_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_device_to_page.md)
  : Convert device (screen) coordinates to PDF page coordinates

- [`pdf_page_to_device()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_to_device.md)
  : Convert PDF page coordinates to device (screen) coordinates

- [`pdf_text_rects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_rects.md)
  : Rectangles occupied by a character range

- [`pdf_text_bounded()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_bounded.md)
  : Extract text inside a bounding rectangle

- [`pdf_text_char_geometry()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_char_geometry.md)
  : Per-character geometry: transformation matrix, rotation angle, font
  weight

- [`pdf_path_set_dash_phase()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_set_dash_phase.md)
  : Set just the dash phase of a path object

- [`pdf_obj_mark_set_blob()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_mark_set_blob.md)
  : Set a binary-blob content-mark parameter

- [`pdf_obj_mark_remove_param()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_mark_remove_param.md)
  : Remove a content-mark parameter

- [`pdf_font_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_data.md)
  : Extract the bytes of an embedded font

- [`pdf_font_load_cidtype2()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_font_load_cidtype2.md)
  : Load a CID Type 2 (composite TrueType) font with explicit mappings

- [`pdf_text_set_charcodes()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_set_charcodes.md)
  : Populate a text object with explicit glyph charcodes

- [`pdf_annot_add_ink_stroke()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_add_ink_stroke.md)
  : Append an ink stroke to an ink annotation

- [`pdf_annot_remove_ink_list()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_remove_ink_list.md)
  : Remove all ink strokes from an ink annotation

- [`pdf_annot_object_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_object_count.md)
  : Number of embedded page-objects inside an annotation

- [`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_objects.md)
  : Page-objects embedded inside an annotation

- [`pdf_annot_append_object()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_append_object.md)
  : Append a page-object to an annotation

- [`pdf_annot_remove_object()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_remove_object.md)
  : Remove a page-object from an annotation

- [`pdf_annot_update_object()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_update_object.md)
  : Update an embedded page-object after mutating it

- [`pdf_annot_set_uri()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_uri.md)
  : Set the URI of a link annotation

- [`pdf_annot_set_appearance()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_appearance.md)
  : Set the appearance stream content for an annotation

- [`pdf_annot_add_file_attachment()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_add_file_attachment.md)
  : Attach a file to a file-attachment annotation

- [`pdf_annot_line()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_line.md)
  : Line endpoints of a line annotation

- [`pdf_annot_link()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_link.md)
  : Link metadata for a link annotation

- [`pdf_annot_set_border()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_border.md)
  : Set the border of an annotation

- [`pdf_clip_path_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_clip_path_new.md)
  : Create a clip path covering a rectangle

- [`pdf_clip_path_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_clip_path_close.md)
  : Release a clip-path handle

- [`pdf_page_insert_clip_path()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_insert_clip_path.md)
  : Insert a clip path into a page

- [`pdf_obj_transform_clip_path()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_transform_clip_path.md)
  : Transform the clip path of a page object

- [`pdf_page_transform_with_clip()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_transform_with_clip.md)
  : Apply a transform to a page's content stream with an optional clip

- [`pdf_xobject_from_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_xobject_from_page.md)
  : Create an XObject (reusable form) from a source-doc page

- [`pdf_xobject_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_xobject_close.md)
  : Close an XObject handle

- [`pdf_obj_form_from_xobject()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_form_from_xobject.md)
  : Instantiate an XObject as a form page-object on a page

- [`pdf_form_obj_remove_object()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_obj_remove_object.md)
  : Remove a child page-object from a form-xobject

- [`pdf_docs_import_pages()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_docs_import_pages.md)
  : Import page ranges from a source doc into a destination doc

- [`pdf_docs_copy_viewer_preferences()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_docs_copy_viewer_preferences.md)
  :

  Copy `/ViewerPreferences` from one document to another

- [`pdf_bitmap_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bitmap_new.md)
  : Create a fresh in-memory bitmap

- [`pdf_bitmap_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bitmap_close.md)
  : Release a bitmap handle

- [`pdf_bitmap_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bitmap_info.md)
  : Bitmap dimensions and format

- [`pdf_bitmap_fill_rect()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bitmap_fill_rect.md)
  : Fill a rectangle of the bitmap with a solid color

- [`pdf_bitmap_buffer()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bitmap_buffer.md)
  [`pdf_bitmap_set_buffer()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bitmap_buffer.md)
  : Read or write the bitmap's raw pixel bytes

- [`pdf_image_set_bitmap()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_image_set_bitmap.md)
  : Set a bitmap on an image page-object

- [`pdf_system_fonts_default_ttf_map()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_system_fonts_default_ttf_map.md)
  : PDFium's default charset → TTF substitution map

- [`pdf_system_fonts_install_default()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_system_fonts_install_default.md)
  : Install PDFium's default system-font-info provider

- [`pdf_annot_set_font_color()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_set_font_color.md)
  : Set the font color of an annotation

- [`pdf_form_field_set_flags()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_set_flags.md)
  : Set the form-field flag bitmask on a form-field widget

- [`pdf_doc_set_focusable_subtypes()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_set_focusable_subtypes.md)
  : Set the doc-wide list of annotation subtypes that participate in tab
  focus

## Enum code \<-\> name helpers

Bidirectional converters between PDFium’s integer enum codes and their
short string names. Paired `_name()` and `_code()` functions for each
enum: annotation subtype, page-object type, path-segment type,
form-field type, page / link action type, and named-destination view
mode. Useful when filtering a tibble by code, passing programmatic input
into a setter, or round-tripping codes through a CSV that’s lost the
names.

- [`pdfium_annot_subtype_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_annot_subtype_name.md)
  [`pdfium_annot_subtype_code()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_annot_subtype_name.md)
  : PDF annotation subtype codes \<-\> names
- [`pdfium_obj_type_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_obj_type_name.md)
  [`pdfium_obj_type_code()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_obj_type_name.md)
  : PDF page-object type codes \<-\> names
- [`pdfium_segment_type_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_segment_type_name.md)
  [`pdfium_segment_type_code()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_segment_type_name.md)
  : Path-segment type codes \<-\> names
- [`pdfium_form_field_type_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_form_field_type_name.md)
  [`pdfium_form_field_type_code()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_form_field_type_name.md)
  : Form-field type codes \<-\> names
- [`pdfium_action_type_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_action_type_name.md)
  [`pdfium_action_type_code()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_action_type_name.md)
  : Link / page action type codes \<-\> names
- [`pdfium_dest_view_name()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_dest_view_name.md)
  [`pdfium_dest_view_code()`](https://humanpred.github.io/rpdfium/dev/reference/pdfium_dest_view_name.md)
  : Named-destination view-mode codes \<-\> names

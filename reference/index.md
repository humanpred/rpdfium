# Package index

## Documents

- [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md)
  : Open a PDF document
- [`pdf_close()`](https://humanpred.github.io/rpdfium/reference/pdf_close.md)
  : Close a PDF document
- [`pdf_page_count()`](https://humanpred.github.io/rpdfium/reference/pdf_page_count.md)
  : Count pages in a PDF document
- [`pdf_doc_info()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_info.md)
  : Document-level metadata for a PDF
- [`pdf_doc_meta()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_meta.md)
  : Read one entry from a PDF's Info dictionary
- [`pdf_parse_date()`](https://humanpred.github.io/rpdfium/reference/pdf_parse_date.md)
  : Parse a PDF date string into POSIXct
- [`pdf_text()`](https://humanpred.github.io/rpdfium/reference/pdf_text.md)
  : Read every page's text in one call
- [`pdf_fonts()`](https://humanpred.github.io/rpdfium/reference/pdf_fonts.md)
  : Document-level rollup of every embedded / referenced font
- [`pdf_file_id()`](https://humanpred.github.io/rpdfium/reference/pdf_file_id.md)
  : Read the document's file identifier from its trailer
- [`pdf_doc_page_mode()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_page_mode.md)
  : Read the document's PageMode entry from its catalog
- [`pdf_doc_permissions()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_permissions.md)
  : Permission flags from a PDF's encryption dictionary
- [`pdf_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmarks.md)
  : Read the bookmark outline (table of contents) of a PDF
- [`pdf_page_label()`](https://humanpred.github.io/rpdfium/reference/pdf_page_label.md)
  : Read the logical page label of a PDF page
- [`pdf_page_labels()`](https://humanpred.github.io/rpdfium/reference/pdf_page_labels.md)
  : Read every page's logical label in one call

## Attachments

- [`pdf_attachments()`](https://humanpred.github.io/rpdfium/reference/pdf_attachments.md)
  : List the files attached to a PDF document
- [`pdf_attachment_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_data.md)
  : Read the raw bytes of an embedded file attachment

## Signatures

- [`pdf_signatures()`](https://humanpred.github.io/rpdfium/reference/pdf_signatures.md)
  : List the digital signatures attached to a PDF document
- [`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_contents.md)
  : Read the raw bytes of a PDF signature's contents blob
- [`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_byte_range.md)
  : Read the signed byte ranges of a PDF signature

## Pages

- [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md)
  : Load a single page from an open PDF document
- [`pdf_close_page()`](https://humanpred.github.io/rpdfium/reference/pdf_close_page.md)
  : Close a page handle
- [`pdf_page_size()`](https://humanpred.github.io/rpdfium/reference/pdf_page_size.md)
  : Page dimensions in PDF points
- [`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_rotation.md)
  : Page rotation in degrees
- [`pdf_page_box()`](https://humanpred.github.io/rpdfium/reference/pdf_page_box.md)
  : Read a page's bounding box
- [`pdf_page_links()`](https://humanpred.github.io/rpdfium/reference/pdf_page_links.md)
  : List the clickable links on a page

## Annotations and form fields

- [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
  : List the annotations on a PDF page
- [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md)
  : Enumerate AcroForm fields across the whole document

## Page objects

- [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
  : Enumerate the objects on a page
- [`pdf_obj_type()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_type.md)
  : Report the type of a page object
- [`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md)
  : Axis-aligned bounding box of a page object
- [`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_matrix.md)
  : Transformation matrix of a page object

## Paths

- [`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
  : Path segments of a path page-object
- [`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/reference/pdf_path_stroke.md)
  : Stroke style of a path page-object
- [`pdf_path_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_fill.md)
  : Fill color of a path page-object
- [`pdf_path_dash()`](https://humanpred.github.io/rpdfium/reference/pdf_path_dash.md)
  : Dash pattern of a path page-object

## Text

- [`pdf_text_font_size()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_size.md)
  : Font size of a text page-object
- [`pdf_text_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_content.md)
  : Text content of a text page-object
- [`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
  : Extract every text run on a page
- [`pdf_text_font()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font.md)
  : Font metadata of a text page-object
- [`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)
  : Per-character text extraction

## Rendering

- [`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md)
  : Render a PDF page to a bitmap

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

## One-call extraction

- [`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/reference/pdf_extract_paths.md)
  : Extract all path geometry on a page into a single tibble

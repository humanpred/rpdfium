# pdfium (development version)

## PDFium update

* The bundled PDFium moves from `chromium/7857` to `chromium/8066`
  (Chromium 156). No PDFium function the package uses was removed or
  changed signature.

## New features

* `pdf_path_segments()` and `pdf_extract_paths()` gain `cx1`, `cy1`,
  `cx2`, `cy2` columns: the two control points of each cubic Bezier
  curve, on the curve's endpoint row (`NA` elsewhere). A curve still
  spans three `"bezierto"` rows — the two control points, then the
  endpoint — as it always did; the documentation wrongly said the
  control points were not available.
* `pdf_text_set_font_size()` sets a text object's font size, the writer
  for `pdf_text_font_size()`.
* `pdf_obj_add_existing_mark()` shares an existing content mark with
  another page object, so consecutive objects can be tagged as one
  marked-content span.
* `pdf_obj_rendered_fill_pattern()` and
  `pdf_obj_rendered_stroke_pattern()` return one rendered tile of the
  tiling pattern a page object is painted with.
* `pdf_bookmark_color()` and `pdf_bookmark_style()` read an outline
  item's title colour and italic / bold flags; the bookmark tibble
  gains `color_red`, `color_green`, `color_blue`, `italic` and `bold`
  columns.
* `pdf_attachment_description()`, `pdf_attachment_set_description()`
  and `pdf_attachment_af_relationship()` read and write an embedded
  file's description and read its PDF 2.0 associated-file relationship;
  the attachment tibble gains `description` and `af_relationship`
  columns.

## Behaviour changes from the PDFium update

* `pdf_attachment_set_dict_value()` now round-trips non-ASCII text;
  PDFium used to store the raw UTF-8 bytes, which read back garbled.
* `pdf_page_flatten()` also removes the flattened fields from the
  document's interactive form; flattening the last field removes the
  form, so `pdf_doc_form_type()` then reports `"none"`.
* `pdf_annot_set_bounds()` no longer enlarges an existing appearance
  stream's bounding box, so the appearance is scaled to the new
  rectangle.
* `pdf_doc_new()` documents get a `/CreationDate` with a `+00'00'`
  offset. PDFium applies it to the local wall-clock time, so the
  parsed value is unchanged from before (see `?pdf_doc_new`).

## Bug fixes

* `pdf_annot_objects()` reports each embedded object's own type
  (`"path"`, `"text"`, `"image"`, `"shading"` or `"form"`) instead of
  `"unknown"`, so the type-specific readers and setters such as
  `pdf_path_fill()`, `pdf_path_set_fill()` and `pdf_text_set_content()`
  accept objects inside an annotation; `pdf_annot_update_object()`
  then writes a change into the appearance stream. `pdf_text_content()`
  refuses these objects with an error, because PDFium only reads the
  text of objects in the page's own content.
* `pdf_render_page()`, `pdf_image_bitmap()`, `pdf_image_rendered()` and
  `pdf_text_obj_rendered_bitmap()` now return a **conformant**
  `nativeRaster`: the backing integer buffer is laid out row-major, so
  the bitmap can be passed straight to `png::writePNG()`,
  `grid::grid.raster()` and R's graphics engine with no reshape. Prior
  versions stored the buffer column-major, which sheared every row
  sideways when a consumer trusted the `nativeRaster` class ("stride
  streak" garble). `as.array()` / `as.raster()` are updated to match
  and remain correct. Output now matches `png::readPNG()` /
  `magick::image_read()` in dims, RGBA channel order and 0..1 range.
* `pdf_render_page()` and `pdf_render_page_with_matrix()` no longer
  modify the document. Every render used to rewrite the bounding box of
  annotation appearance streams, which drew some annotations at the
  wrong size and carried into later `pdf_save()` output.
* `pdf_form_field_set_value()`'s documentation no longer claims that
  the field's appearance is regenerated; PDFium's API has no way to do
  that outside its interactive form-fill layer.

# pdfium 0.1.0

* Initial CRAN release.

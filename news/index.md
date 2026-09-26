# Changelog

## pdfium (development version)

### PDFium update

- The bundled PDFium moves from `chromium/7857` to `chromium/8066`
  (Chromium 156). No PDFium function the package uses was removed or
  changed signature.

### New features

- [`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
  and
  [`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/reference/pdf_extract_paths.md)
  gain `cx1`, `cy1`, `cx2`, `cy2` columns: the two control points of
  each cubic Bezier curve, on the curve’s endpoint row (`NA` elsewhere).
  A curve still spans three `"bezierto"` rows — the two control points,
  then the endpoint — as it always did; the documentation wrongly said
  the control points were not available.
- [`pdf_text_set_font_size()`](https://humanpred.github.io/rpdfium/reference/pdf_text_set_font_size.md)
  sets a text object’s font size, the writer for
  [`pdf_text_font_size()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_size.md).
- [`pdf_obj_add_existing_mark()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_add_existing_mark.md)
  shares an existing content mark with another page object, so
  consecutive objects can be tagged as one marked-content span.
- [`pdf_obj_rendered_fill_pattern()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_rendered_fill_pattern.md)
  and
  [`pdf_obj_rendered_stroke_pattern()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_rendered_fill_pattern.md)
  return one rendered tile of the tiling pattern a page object is
  painted with.
- [`pdf_bookmark_color()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_color.md)
  and
  [`pdf_bookmark_style()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_style.md)
  read an outline item’s title colour and italic / bold flags; the
  bookmark tibble gains `color_red`, `color_green`, `color_blue`,
  `italic` and `bold` columns.
- [`pdf_attachment_description()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_description.md),
  [`pdf_attachment_set_description()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_description.md)
  and
  [`pdf_attachment_af_relationship()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_af_relationship.md)
  read and write an embedded file’s description and read its PDF 2.0
  associated-file relationship; the attachment tibble gains
  `description` and `af_relationship` columns.

### Behaviour changes from the PDFium update

- [`pdf_attachment_set_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_set_dict_value.md)
  now round-trips non-ASCII text; PDFium used to store the raw UTF-8
  bytes, which read back garbled.
- [`pdf_page_flatten()`](https://humanpred.github.io/rpdfium/reference/pdf_page_flatten.md)
  also removes the flattened fields from the document’s interactive
  form; flattening the last field removes the form, so
  [`pdf_doc_form_type()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_form_type.md)
  then reports `"none"`.
- [`pdf_annot_set_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_bounds.md)
  no longer enlarges an existing appearance stream’s bounding box, so
  the appearance is scaled to the new rectangle.
- [`pdf_doc_new()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_new.md)
  documents get a `/CreationDate` with a `+00'00'` offset. PDFium
  applies it to the local wall-clock time, so the parsed value is
  unchanged from before (see
  [`?pdf_doc_new`](https://humanpred.github.io/rpdfium/reference/pdf_doc_new.md)).

### Bug fixes

- [`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md),
  [`pdf_image_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_image_bitmap.md),
  [`pdf_image_rendered()`](https://humanpred.github.io/rpdfium/reference/pdf_image_rendered.md)
  and
  [`pdf_text_obj_rendered_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_text_obj_rendered_bitmap.md)
  now return a **conformant** `nativeRaster`: the backing integer buffer
  is laid out row-major, so the bitmap can be passed straight to
  [`png::writePNG()`](https://rdrr.io/pkg/png/man/writePNG.html),
  [`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html) and
  R’s graphics engine with no reshape. Prior versions stored the buffer
  column-major, which sheared every row sideways when a consumer trusted
  the `nativeRaster` class (“stride streak” garble).
  [`as.array()`](https://rdrr.io/r/base/array.html) /
  [`as.raster()`](https://rdrr.io/r/grDevices/as.raster.html) are
  updated to match and remain correct. Output now matches
  [`png::readPNG()`](https://rdrr.io/pkg/png/man/readPNG.html) /
  `magick::image_read()` in dims, RGBA channel order and 0..1 range.
- [`pdf_render_page()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page.md)
  and
  [`pdf_render_page_with_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_render_page_with_matrix.md)
  no longer modify the document. Every render used to rewrite the
  bounding box of annotation appearance streams, which drew some
  annotations at the wrong size and carried into later
  [`pdf_save()`](https://humanpred.github.io/rpdfium/reference/pdf_save.md)
  output.
- [`pdf_form_field_set_value()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_set_value.md)’s
  documentation no longer claims that the field’s appearance is
  regenerated; PDFium’s API has no way to do that outside its
  interactive form-fill layer.

## pdfium 0.1.0

- Initial CRAN release.

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

- Installed and binary packages now carry PDFium’s licence notices in
  `pdfium-licenses/`
  (`system.file("pdfium-licenses", package = "pdfium")`): PDFium’s
  BSD-3-Clause licence, the licences of the third-party code compiled
  into `libpdfium`, and bblanchon/pdfium-binaries’ MIT licence. They
  were dropped when the PDFium archive was unpacked, and `LICENSE.md`
  pointed at a file that was never installed; it also misnamed
  bblanchon/pdfium-binaries’ licence as Apache-2.0. Installation now
  stops if a PDFium archive lacks PDFium’s own notice.
- [`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md)
  reports each embedded object’s own type (`"path"`, `"text"`,
  `"image"`, `"shading"` or `"form"`) instead of `"unknown"`, so the
  type-specific readers and setters such as
  [`pdf_path_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_fill.md),
  [`pdf_path_set_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_set_fill.md)
  and
  [`pdf_text_set_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_set_content.md)
  accept objects inside an annotation;
  [`pdf_annot_update_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_update_object.md)
  then writes a change into the appearance stream.
  [`pdf_text_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_content.md)
  refuses these objects with an error, because PDFium only reads the
  text of objects in the page’s own content.
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
- [`pdf_annot_append_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_append_object.md)
  no longer frees its object twice. PDFium’s `FPDFAnnot_AppendObject`
  takes ownership of the object, but the object was still on its page as
  well, so closing the page or collecting the annotation handle could
  crash R. The object is now *moved*: it leaves the annotation’s page,
  its handle is closed, and
  [`pdf_annot_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_objects.md)
  reaches it inside the annotation. Annotations other than `"ink"` and
  `"stamp"`, and objects that are not top-level objects of the
  annotation’s page, are refused with an error that leaves everything in
  place (ADR-023). The documentation of
  [`pdf_annot_append_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_append_object.md),
  [`pdf_annot_remove_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_remove_object.md)
  and
  [`pdf_annot_update_object()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_update_object.md)
  named `"stamp"` or `"freetext"`; PDFium supports `"ink"` and
  `"stamp"`.
- [`pdf_form_obj_remove_object()`](https://humanpred.github.io/rpdfium/reference/pdf_form_obj_remove_object.md)
  frees the removed child (it used to leak) and closes the child’s
  handle. Its documentation now says that PDFium does not save the
  removal: the saved file still draws the removed child.
- Annotation handles collected after their page was closed now release
  PDFium’s annotation context while the document is still open; before,
  the context leaked.
- [`pdf_annot_delete()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_delete.md)
  removes the handle’s own annotation. It used the position recorded
  when the handle was made, so after an earlier delete on the same page
  it removed the next annotation or failed, and for a form field it
  removed an unrelated annotation. Deleting an annotation that is no
  longer on its page, for example through a second handle to it, is now
  an error that changes nothing.
- [`pdf_annot_delete()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_delete.md)
  no longer leaks PDFium’s annotation context, and with it any
  page-objects of the annotation’s appearance stream.
- [`pdf_doc_close()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_close.md),
  and the finalizer of a collected document, first close the annotation
  handles still open on the document, including form-field handles from
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md).
  Those handles print as closed afterwards, and `pdf_annot_*()` calls on
  them raise an error. An annotation handle collected after both its
  page and its document had been closed used to leak PDFium’s annotation
  context, together with the page-objects of its appearance stream
  (ADR-024).
- [`pdf_page_insert_clip_path()`](https://humanpred.github.io/rpdfium/reference/pdf_page_insert_clip_path.md)
  no longer closes `clip_path`. PDFium never takes ownership of an
  inserted clip path, so the path was never freed. The handle now stays
  open, can be inserted into other pages, and is released by
  [`pdf_clip_path_close()`](https://humanpred.github.io/rpdfium/reference/pdf_clip_path_close.md)
  or garbage collection.
- [`pdf_system_fonts_install_default()`](https://humanpred.github.io/rpdfium/reference/pdf_system_fonts_install_default.md)
  installs PDFium’s default system-font provider once per library
  lifetime, and the package frees it when it shuts the library down.
  Each call used to allocate a new provider that was never completely
  freed.

## pdfium 0.1.0

- Initial CRAN release.

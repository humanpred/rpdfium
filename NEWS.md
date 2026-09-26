# pdfium (development version)

* `pdf_annot_append_object()` no longer frees its object twice. PDFium's
  `FPDFAnnot_AppendObject` takes ownership of the object, but the object
  was still on its page as well, so closing the page or collecting the
  annotation handle could crash R. The object is now *moved*: it leaves
  the annotation's page, its handle is closed, and
  `pdf_annot_objects()` reaches it inside the annotation. Annotations
  other than `"ink"` and `"stamp"`, and objects that are not top-level
  objects of the annotation's page, are refused with an error that
  leaves everything in place (ADR-023). The documentation of
  `pdf_annot_append_object()`, `pdf_annot_remove_object()` and
  `pdf_annot_update_object()` named `"stamp"` or `"freetext"`; PDFium
  supports `"ink"` and `"stamp"`.
* `pdf_form_obj_remove_object()` frees the removed child (it used to
  leak) and closes the child's handle. Its documentation now says that
  PDFium does not save the removal: the saved file still draws the
  removed child.
* Annotation handles collected after their page was closed now release
  PDFium's annotation context while the document is still open; before,
  the context leaked.

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

# pdfium 0.1.0

* Initial CRAN release.

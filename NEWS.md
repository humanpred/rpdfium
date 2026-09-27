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
* `pdf_annot_delete()` removes the handle's own annotation. It used the
  position recorded when the handle was made, so after an earlier
  delete on the same page it removed the next annotation or failed,
  and for a form field it removed an unrelated annotation. Deleting an
  annotation that is no longer on its page, for example through a
  second handle to it, is now an error that changes nothing.
* `pdf_annot_delete()` no longer leaks PDFium's annotation context, and
  with it any page-objects of the annotation's appearance stream.
* `pdf_doc_close()`, and the finalizer of a collected document, first
  close the annotation handles still open on the document, including
  form-field handles from `pdf_form_fields()`. Those handles print as
  closed afterwards, and `pdf_annot_*()` calls on them raise an error.
  An annotation handle collected after both its page and its document
  had been closed used to leak PDFium's annotation context, together
  with the page-objects of its appearance stream (ADR-024).
* `pdf_doc_close()`, and the finalizer of a collected document, now also
  close the document's pages, including the pages of `pdf_form_fields()`.
  Page and page-object calls on them raise an error ("Page has been
  closed: its document was closed.") instead of reading freed memory.
  Rendering or extracting text from a page whose document had been
  closed read, and for text also wrote, the freed document; the results
  looked right, so nothing noticed. A page collected after its document
  had been closed also closed itself after the document, which PDFium
  does not allow (ADR-025).
* `pdf_doc_close()` also closes the document's font and XObject handles.
  `pdf_obj_form_from_xobject()` with an XObject whose document had been
  closed built the form object from the freed document; it now raises an
  error.
* `pdf_text_new()` and `pdf_obj_form_from_xobject()` refuse a font or
  XObject that belongs to a document other than the page's. With a font
  from `pdf_font_load()` or an XObject, the new object pointed into the
  other document: `pdf_save()` wrote it out wrongly, and once the other
  document was closed, reading the page read freed memory.
* The form object from `pdf_obj_form_from_xobject()` stays usable after
  `pdf_xobject_close()`, as documented; it used to raise an error.
* `pdf_page_insert_clip_path()` no longer closes `clip_path`. PDFium
  never takes ownership of an inserted clip path, so the path was never
  freed. The handle now stays open, can be inserted into other pages,
  and is released by `pdf_clip_path_close()` or garbage collection.
* `pdf_system_fonts_install_default()` installs PDFium's default
  system-font provider once per library lifetime, and the package frees
  it when it shuts the library down. Each call used to allocate a new
  provider that was never completely freed.

# pdfium 0.1.0

* Initial CRAN release.

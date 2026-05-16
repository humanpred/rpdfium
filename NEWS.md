# pdfium 0.1.0

First CRAN release. Ships 53 exported `pdf_*` functions, grouped by
capability below.

## Documents

* `pdf_open()` / `pdf_close()` open and close a PDF file by path or
  in-memory raw vector, with optional password.
* `pdf_page_count()` reports the page count.
* `pdf_doc_info()`, `pdf_doc_meta()` read Info-dict metadata
  (title, author, subject, creator, producer, dates).
* `pdf_parse_date()` parses PDF date strings (`D:YYYYMMDD...`) to
  `POSIXct`.
* `pdf_doc_permissions()`, `pdf_doc_page_mode()` surface the
  permission bits and the PageMode hint from the document catalog.
* `pdf_bookmarks()` reads the outline / table of contents.
* `pdf_page_label()`, `pdf_page_labels()` resolve the human-facing
  page labels (e.g. roman-numeral prefaces, alphabetic appendices).
* `pdf_file_id()` returns the trailer `/ID` bytes.

## Pages

* `pdf_load_page()` / `pdf_close_page()` open and close individual
  pages.
* `pdf_page_size()`, `pdf_page_rotation()`, `pdf_page_box()` report
  page geometry, including the MediaBox / CropBox / BleedBox /
  TrimBox / ArtBox.
* `pdf_page_links()` enumerates link annotations on a page.

## Page objects, paths, and styling

* `pdf_page_objects()` enumerates the path / text / image / form
  objects on a page; child objects link back to their parent via R
  references so GC ordering can't invalidate a live child.
* `pdf_obj_type()`, `pdf_obj_bounds()`, `pdf_obj_matrix()` report
  each object's kind, bounding box, and 3x3 transformation matrix.
* `pdf_path_segments()` returns each path's segments as a tibble:
  segment type (`moveto`, `lineto`, `bezier`), point coordinates,
  and close flag.
* `pdf_path_stroke()`, `pdf_path_fill()`, `pdf_path_dash()` surface
  stroke / fill colour and opacity, stroke width, and dash array /
  phase.

## Text

* `pdf_text()` returns a character vector with one element per page
  (matches the shape of `pdftools::pdf_text()`).
* `pdf_text_runs()` returns the page's text as a tibble of runs
  with bounding box, font metadata, and font size.
* `pdf_text_chars()` returns per-character positions and Unicode
  codepoints for fine-grained text layout work.
* `pdf_text_content()`, `pdf_text_font()`, `pdf_text_font_size()`
  read text from an individual text object.
* `pdf_fonts()` summarises the distinct fonts used anywhere in the
  document.

## Images

* `pdf_image_info()`, `pdf_image_size()` report image-object
  metadata (filter, BPC, colorspace) and pixel size.
* `pdf_image_bitmap()`, `pdf_image_rendered()` return the embedded
  bitmap (decoded) or the rendered bitmap with the page's CTM
  applied.
* `pdf_image_data()`, `pdf_image_filters()` return the raw image
  byte stream and its filter chain.

## Form XObjects and clipping

* `pdf_form_objects()` enumerates the nested objects inside a Form
  XObject; nested objects record their `parent_form` so render
  chains are walkable.
* `pdf_obj_clip_path()`, `pdf_clip_path_count()`,
  `pdf_clip_path_segments()` expose the clip path attached to a
  page object as a `pdfium_clip_path` with one sub-path per `W`
  operator.

## Rendering

* `pdf_render_page()` renders a page to a `pdfium_bitmap` with
  configurable size, rotation, background, and render flags;
  `as.raster()`, `as.array()`, `as.matrix()`, `plot()`, and
  `print()` methods are provided.
* `pdf_render_to_png()` saves a page render straight to a PNG file.

## Annotations, form fields, attachments, signatures

* `pdf_annotations()` enumerates annotations on a page (text,
  highlight, link, widget, ...).
* `pdf_form_fields()` lists AcroForm fields with name, alternate
  name, value, and type.
* `pdf_attachments()`, `pdf_attachment_data()` enumerate the
  document's embedded files and read each one's bytes.
* `pdf_signatures()`, `pdf_signature_contents()`,
  `pdf_signature_byte_range()` surface signature widgets and their
  PKCS#7 payloads.

## One-call extraction

* `pdf_extract_paths()` is a one-call helper that returns a tibble
  of every path on every page with style and geometry attached, and
  page-level metadata as attributes -- the entry point used by
  `kmextract`.

## Architecture

* Four-layer model (R API -> Rcpp glue -> PDFium C ABI ->
  `libpdfium`).
* S3 classes `pdfium_doc`, `pdfium_page`, `pdfium_obj`,
  `pdfium_bitmap`, and `pdfium_clip_path`, each backed by an R
  `externalptr` with a C finalizer registered via
  `R_RegisterCFinalizerEx(..., onexit = TRUE)`.
* Idempotent `pdf_close()` / `pdf_close_page()`. Children hold an
  R-level reference to their parent so GC can't reclaim the parent
  before the child.
* `libpdfium` is downloaded at install time from
  [`bblanchon/pdfium-binaries`](https://github.com/bblanchon/pdfium-binaries)
  per `tools/pdfium-version.txt`; the source tarball stays well
  under CRAN's 5 MB limit. `CRAN_PDFIUM_OFFLINE=1` opts out of the
  network fetch for offline builds.

## Vignettes

* `vignette("getting-started", package = "pdfium")` -- first
  five-minute tour of the API.
* `vignette("extracting-paths", package = "pdfium")` -- the
  vector-geometry workflow that motivated the package.
* `vignette("text-extraction", package = "pdfium")` -- text runs,
  per-character positions, and font metadata.
* `vignette("rendering", package = "pdfium")` -- `pdf_render_page()`
  and the bitmap class.
* `vignette("architecture", package = "pdfium")` -- the four-layer
  model and the memory contract.

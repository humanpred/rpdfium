# pdfium 0.1.0

First public release. Idiomatic R bindings to Google's
[PDFium](https://pdfium.googlesource.com/pdfium/) engine. Where
`pdftools` (Poppler-based) covers text and rasterised pages,
`pdfium` adds vector-level structure: every path object's segments
and style, every text run's font and bounding box, every embedded
image's source bytes and metadata, every form XObject's nested
children, and every clip region's geometry.

## Documents

* `pdf_open(path, password = NULL)` / `pdf_close(doc)` — load and
  release a `pdfium_doc`. Idempotent close; a GC-triggered finalizer
  also runs `FPDF_CloseDocument` automatically when handles become
  unreachable.
* `pdf_page_count(doc_or_path)` — total page count. Accepts a path
  for one-shot inspection.
* `pdf_doc_info(doc_or_path)` — page count, file version, every
  standard Info-dictionary entry, plus POSIXct parses of the two
  date fields. Shape mirrors `pdftools::pdf_info()` for porting.
* `pdf_doc_meta(doc, tag)` — read one Info-dictionary tag by name.
* `pdf_parse_date(s)` — vectorised parser for PDF's
  `"D:YYYYMMDDHHmmSS+HH'mm'"` date format into UTC `POSIXct`.

## Pages

* `pdf_load_page(doc, page)` / `pdf_close_page(page)` — page-level
  handle.
* `pdf_page_size(doc, page)` — width and height in PDF points.
* `pdf_page_rotation(doc, page)` — 0/90/180/270 from the page's own
  `/Rotate` attribute.

## Page objects

* `pdf_page_objects(page)` — list of typed `pdfium_obj` handles for
  every drawable element on a page.
* `pdf_obj_type(obj)` — one of `"path"`, `"text"`, `"image"`,
  `"form"`, `"shading"`, `"unknown"`.
* `pdf_obj_bounds(obj)` — bounding box in PDF user space.
* `pdf_obj_matrix(obj)` — 2D affine matrix `(a, b, c, d, e, f)`.

## Paths

* `pdf_path_segments(obj)` — tibble with columns `segment_index`,
  `segment_type`, `x`, `y`, `close_figure`.
* `pdf_path_stroke(obj)` — flat named numeric vector with elements
  `red`, `green`, `blue`, `alpha`, `width`.
* `pdf_path_fill(obj)` — flat named numeric vector with elements
  `red`, `green`, `blue`, `alpha`.
* `pdf_path_dash(obj)` — dash pattern + phase.

## Text

* `pdf_text_content(obj)` — Unicode content of a text object,
  UTF-8 encoded.
* `pdf_text_font_size(obj)` — font size in user-space points.
* `pdf_text_font(obj)` — named list with `font_base_name`,
  `font_family`, `font_weight`, `font_italic_angle`,
  `font_is_embedded`, `font_flags`. Field names match the
  `font_*` columns of `pdf_text_runs()` so the two shapes
  interoperate.
* `pdf_text_runs(page)` — page-level tibble of every text run with
  bounding box, content, and font metadata.

## One-call extraction

* `pdf_extract_paths(doc, page_num)` — one tibble row per path
  segment with stroke / fill / bounds folded in. Columns are
  `path_index`, `segment_index`, `segment_type`, `x`, `y`,
  `close_figure`, then the per-path style and bounds. Carries
  `page_size`, `page_rotation`, and `text_runs` attributes for
  context.

## Rendering

* `pdf_render_page(page_or_doc, dpi, background, annotations,
  rotation)` returns a `pdfium_bitmap` S3 object inheriting from
  base R's `nativeRaster`.
* `plot.pdfium_bitmap()` draws the bitmap into the active device
  via [graphics::rasterImage()] with `asp = 1`; pass
  `interpolate = FALSE` for pixel-exact display of small bitmaps.
* Same bitmap shape can be drawn directly by
  `graphics::rasterImage()` or `grid::rasterGrob()` without
  conversion.
* Converters: `as.array.pdfium_bitmap()` → 3D `[H, W, 4]` doubles
  0..1 (matches `png::writePNG()`); `as.raster.pdfium_bitmap()`
  → `"#RRGGBBAA"` character matrix in base R's `"raster"` class;
  `as.matrix.pdfium_bitmap()` → plain character matrix.
* `pdf_render_to_png(file, ...)` saves directly via `png` (a
  Suggests dependency).

## Embedded images

* `pdf_image_info(obj)` — width, height, DPI, bits-per-pixel,
  colorspace, marked-content id.
* `pdf_image_size(obj)` — fast width/height-only variant.
* `pdf_image_bitmap(obj)` — decoded source-pixel raster (no CTM
  applied), as a `pdfium_bitmap`.
* `pdf_image_rendered(obj)` — page-CTM-applied rendering, as a
  `pdfium_bitmap`.
* `pdf_image_data(obj, decoded = TRUE)` — raw byte buffer; with
  `decoded = FALSE` returns the original embedded stream
  (JPEG / JBIG2 / JPEG 2000 / Flate-compressed bytes) for
  save-as-original workflows.
* `pdf_image_filters(obj)` — the stream's decoder chain.

## Form XObjects

* `pdf_form_objects(form)` — list the page objects nested inside a
  Form XObject. Returns fully-typed `pdfium_obj`s that participate
  in every existing accessor. Recursive: nested forms can be passed
  back in.
* `pdfium_obj` gains an optional `parent_form` field; the
  `format()` method renders the containment chain
  (`"obj 2 of form 1 on page 1"`).

## Clip paths

* `pdf_obj_clip_path(obj)` — returns a `pdfium_clip_path` S3 object
  attached to a page object, or `NULL` when no clip is set.
* `pdf_clip_path_count(clip_path)` — number of sub-paths in the
  clip.
* `pdf_clip_path_segments(clip_path)` — tibble shaped like
  `pdf_path_segments()` with a leading `path_index` column for the
  outer sub-path level.

## Documentation

Four vignettes ship with the package: getting-started, extracting
paths, extracting text and fonts, and rendering pages to bitmaps.
A fifth vignette documents the four-layer architecture and memory
model.

## Distribution and licensing

The bundled `libpdfium` shared library is downloaded from
[bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
at install time. The pinned release lives in
`tools/pdfium-version.txt`. Package code is MIT; the bundled
binary is BSD-3-Clause. See `LICENSE.md` for the combined
provenance.

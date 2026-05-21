# Choosing pdfium vs other PDF packages

CRAN already has several PDF packages. This vignette helps you pick the
right one for the task — and explains where `pdfium` adds new capability
rather than duplicating existing work. A more detailed
contributor-facing inventory lives in `dev/r-pdf-ecosystem-survey.md`.

## TL;DR — which package for which job?

| Task | First-line package |
|----|----|
| Read text only (whole-page strings) | `pdftools` |
| Read text with per-token bounding boxes | `pdftools::pdf_data()` (Poppler-precision) **or** [`pdfium::pdf_text_runs()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_runs.md) (PDFium-precision, plus font flags) |
| Render a page to a bitmap | `pdftools::pdf_render_page()` **or** [`pdfium::pdf_render_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page.md) |
| Split / merge / compress lossless | `qpdf` (or `cpp11qpdf`) |
| OCR or general image-processing pipeline | `magick` |
| Extract a *table* from a PDF | `tabulapdf` |
| **Inspect path geometry** (segments, Bezier control points, stroke/fill, transform matrices) | **`pdfium`** — no other CRAN package surfaces this |
| **Fill AcroForm fields without a JRE** | **`pdfium`** (`staplr` requires Java + pdftk) |
| **Edit annotations** (read + write) | **`pdfium`** |
| **Programmatically build small PDFs** with paths, text, images, annotations | **`pdfium`** (also `minipdf` for a pure-R writer with no native dependency) |
| Edit XMP metadata or bookmarks | `xmpdf` (orchestrates `exiftool` / `ghostscript` / `pdftk`) |

## What `pdfium` adds

Three capabilities no other CRAN package surfaces today:

### 1. Vector path geometry

``` r

library(pdfium)
doc <- pdf_doc_open("figure.pdf")
objs <- pdf_page_objects(pdf_page_load(doc, 1))
# Pick the first path object and read its segments.
i <- match(TRUE, vapply(objs, pdf_obj_type, "") == "path")
pdf_path_segments(objs[[i]])
#> # A tibble: 8 x 5
#>   segment_type     x     y close_figure cp1_x …
#>   <chr>        <dbl> <dbl> <lgl>        <dbl>
#> 1 moveto         100   100 FALSE           NA
#> 2 lineto         200   100 FALSE           NA
#> 3 bezierto       300   100 FALSE          150  …
#> ...
```

Stroke / fill colors, dash patterns, transformation matrices, draw
modes, and clip paths are all surfaced via `pdf_path_*()` and
`pdf_obj_*()`. No equivalent exists in `pdftools` (Poppler exposes text
only), `qpdf` (lossless structural ops, no content access), or `magick`
(rasterises through Ghostscript).

### 2. AcroForm filling without Java

``` r

doc <- pdf_doc_open("application.pdf", readwrite = TRUE)
fields <- pdf_form_fields(doc)
by_name <- setNames(fields, vapply(fields, pdf_form_field_name, ""))
pdf_form_field_set_value(by_name[["full_name"]], "Ada Lovelace")
pdf_form_field_set_value(by_name[["subscribe"]], TRUE)
pdf_save(doc, "filled.pdf")
```

`staplr` is the only other CRAN package that can fill PDF forms, but it
shells out to `pdftk-java`, which means installing a JRE + pdftk-java
jar. `pdfium`’s form-fill API ships entirely as native code — no Java
dependency.

### 3. Annotation authoring (full read + write)

``` r

hl <- pdf_annot_new(page, subtype = "highlight",
                    bounds = c(100, 700, 400, 720))
pdf_annot_set_color(hl, color = c(255, 240, 0))
pdf_annot_set_contents(hl, "Important")
pdf_annot_append_quad(hl, quad = c(100, 700, 400, 700,
                                    100, 720, 400, 720))
pdf_save(doc, "annotated.pdf")
```

No other CRAN package surfaces annotations at all. The full list of
supported subtypes lives in
[`?pdf_annot_new`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_new.md).

## Where `pdfium` deliberately doesn’t compete

- **Structural split / merge / compress** — `qpdf` is the right answer.
  It’s content-preserving, doesn’t re-encode streams, and has been the
  de facto choice for years. We expose
  [`pdf_pages_reorder()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_pages_reorder.md)
  and
  [`pdf_docs_merge()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_docs_merge.md)
  because they fall out of the mutation surface for free, but if your
  only job is “split this PDF in half”, reach for `qpdf::pdf_split()`
  first.
- **Table extraction** — `tabulapdf` (formerly `tabulizer`) has a decade
  of Tabula’s heuristics behind it. `pdfium` gives you text-with-bounds
  and path geometry — the primitives a future pure-R `tabulapdf`-style
  package could be built on — but doesn’t ship a table detector itself.
- **OCR and general image processing** — `magick` is the right tool for
  the broader image-processing pipeline.
  [`pdfium::pdf_render_page()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_render_page.md)
  returns a `pdfium_bitmap` you can pass to `magick::image_read()` if
  you want to render with PDFium and then process with ImageMagick.
- **XMP metadata** — `xmpdf` orchestrates `exiftool` / `ghostscript` /
  `pdftk` correctly and writes both XMP and the Info dictionary.
  `pdfium` only reads the Info dict in v0.1.0; XMP and Info-write remain
  `xmpdf`’s territory.

## Feature matrix at a glance

| Feature | pdfium | pdftools | qpdf | magick | tabulapdf | staplr | xmpdf |
|----|----|----|----|----|----|----|----|
| Text content | yes | yes | no | no | partial | no | no |
| Text positioning | yes (float precision) | partial (int per token) | no | no | partial (table region only) | no | no |
| Font metadata | yes (per char) | partial (per token) | no | no | no | no | no |
| Render to bitmap | yes (PDFium) | yes (Poppler) | no | yes (Ghostscript) | no | no | no |
| Document metadata (read) | yes | yes | no | partial | no | no | yes |
| Document metadata (write) | partial (lang only) | no | no | no | no | no | yes |
| Page count / size | yes | yes | yes | yes | yes | yes | partial |
| Page rotation (read) | yes | no | no | no | no | yes | no |
| Page rotation (write) | yes | no | no | no | no | yes | no |
| Page reorder / merge / split | yes | no | yes | no | no | yes | no |
| **Path segments** | **yes** | no | no | no | no (internal only) | no | no |
| **Path style** (stroke / fill / dash / matrix) | **yes** | no | no | no | no | no | no |
| **Bezier control points** | **yes** | no | no | no | no | no | no |
| **Image XObject extraction** | **yes** | no | no | no | no | no | no |
| **Form XObjects** | **yes** | no | no | no | no | no | no |
| **Clip paths** | **yes** | no | no | no | no | no | no |
| **Structure tree (tagged PDF)** | **yes** | no | no | no | no | no | no |
| **Annotations (read)** | **yes** | no | no | no | no | no | no |
| **Annotations (write)** | **yes** | no | no | no | no | no | no |
| Form fields (read) | yes | no | no | no | no | yes (Java) | no |
| Form fields (fill) | yes | no | no | no | no | yes (Java) | no |
| Page flatten | yes | no | no | no | no | no | no |
| Attachments (read) | yes | yes | no | no | no | no | no |
| Attachments (author) | yes | no | no | no | no | no | no |
| Signatures (read) | yes | no | no | no | no | no | no |
| Bookmarks (read) | yes | partial (toc) | no | no | no | no | yes |
| Bookmarks (write) | no | no | no | no | no | no | yes |
| Encryption / password | partial (open only) | yes | yes | no | partial | partial | no |

Bold rows are capabilities `pdfium` adds to the R ecosystem.

## Switching from `pdftools`

The two packages overlap on text + render + metadata. The signatures are
close enough that switching is mostly a find-and-replace:

| `pdftools` | `pdfium` |
|----|----|
| `pdf_text(path)` | `pdf_doc_text(path)` |
| `pdf_info(path)` | `pdf_doc_info(path)` — or `pdf_doc_summary(path)` for a richer one-row tibble |
| `pdf_pagesize(path)` | `pdf_pages_summary(path)` (one row per page; also includes rotation + label) |
| `pdf_render_page(path, ...)` | `pdf_render_page(doc_or_path, ...)` |
| `pdf_data(path)` | `pdf_text_runs(page)` |
| `pdf_doc_fonts(path)` | `pdf_doc_fonts(doc)` |
| `pdf_attachments(path)` | `pdf_attachments(doc)` |

The biggest behavioural difference: `pdftools` opens a fresh document on
every call, while `pdfium` expects you to open once
([`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md))
and pass the resulting handle to subsequent functions. The
path-accepting convenience wrappers (`pdf_doc_text(path)`,
`pdf_attachments(path)`, etc.) work the same way `pdftools` does, but
they’re shortcuts — for any non-trivial workflow, hold onto the
`pdfium_doc` handle.

# Text content of a text page-object

Returns the Unicode text of `obj` as a single character string. PDFium
produces UTF-16LE internally; the wrapper converts to UTF-8 with the
encoding flag set so R prints non-ASCII glyphs correctly.

## Usage

``` r
pdf_text_content(obj)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"` (from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)).

## Value

A character scalar (UTF-8 encoded). An empty text object returns `""`.

## Details

Loading text from a PDF requires the per-page text-extraction context
(`FPDFText_LoadPage` / `FPDFText_ClosePage`). The wrapper opens and
closes that context internally on every call. When you need many text
objects from one page, the upcoming
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_runs.md)
(Phase 3 slice 2) will share a single text-page across the entire page
to avoid the per-call overhead.

## See also

[`pdf_text_font_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_font_size.md),
[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  p <- pdf_page_load(doc, 1)
  text_obj <- Filter(\(o) o$type == "text", pdf_page_objects(p))[[1]]
  pdf_text_content(text_obj)
  pdf_page_close(p)
  pdf_doc_close(doc)
}
```

# Extract every text run on a page

Returns one row per text page-object on `page`, with the text content,
bounding box, font size, and 1-based page-object index. Loads PDFium's
per-page text-extraction context (`FPDFText_LoadPage`) once and reuses
it across every text object on the page; this is materially faster than
calling
[`pdf_text_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_content.md)
in a loop, which opens and closes a text page per object.

## Usage

``` r
pdf_text_runs(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md),
  or a `pdfium_doc` (in which case the first page is loaded and closed
  automatically).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A tibble with columns:

- `obj_index` - 1-based page-object index (so this row is the
  `obj_index`-th object returned by
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)).
  Renamed from `text_index` in the v0.1.0 reader/writer audit to avoid
  colliding with `pdf_text_chars()$text_index`, which is the
  *extractable-text* offset.

- `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top`

  - the object's bounding box in PDF points

- `font_size` - typographic em size; multiply by the text object's
  matrix scale (when available) for rendered size

- `text` - UTF-8 string

## Details

The returned tibble's schema matches the `text_runs` attribute produced
by
[`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/reference/pdf_extract_paths.md).

## See also

[`pdf_text_content()`](https://humanpred.github.io/rpdfium/reference/pdf_text_content.md),
[`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/reference/pdf_extract_paths.md)

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "unicode.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_open(fixture)
  pdf_text_runs(doc, 1)
  pdf_close(doc)
}
```

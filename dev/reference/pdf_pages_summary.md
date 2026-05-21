# One-call summary of every page in a document

Returns a tibble with one row per page covering the cheap per-page
facts: width, height (both in PDF user-space points, pre-rotation),
rotation in degrees, and the page label (if any). The per-page values
come from the existing single-page readers
[`pdf_page_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_size.md)
(fast `FPDF_GetPageSizeByIndexF` path),
[`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_rotation.md),
and
[`pdf_page_labels()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_labels.md);
no per-page
[`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md)
is required for any of them, so the function is efficient on long
documents.

## Usage

``` r
pdf_pages_summary(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is an open `pdfium_doc`.

## Value

A tibble with columns:

- `page_num` — integer, 1-based.

- `width`, `height` — numeric, PDF user-space points.

- `rotation` — integer, `0` / `90` / `180` / `270`.

- `label` — character; the page's `/PageLabels` entry, or `NA` when the
  document has no labels.

## Details

For deeper per-page facts (annotation count, object count, text content,
…) load each page individually with
[`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md)
and call the per-page readers.

## See also

[`pdf_doc_summary()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_summary.md)
for the doc-level companion;
[`pdf_page_size()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_size.md),
[`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_rotation.md),
[`pdf_page_labels()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_labels.md)
for the per-row readers.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) pdf_pages_summary(fixture)
#> # A tibble: 1 × 5
#>   page_num width height rotation label
#>      <int> <dbl>  <dbl>    <int> <chr>
#> 1        1   288    216        0 NA   
```

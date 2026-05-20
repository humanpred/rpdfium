# Document-level rollup of every embedded / referenced font

Returns one tibble row per distinct font used anywhere in the document,
with the same metadata columns
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)/[`pdf_text_font()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font.md)
report at the run/object level. Useful for porting from
`pdftools::pdf_doc_fonts()`.

## Usage

``` r
pdf_doc_fonts(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

A tibble with columns: `font_base_name`, `font_family`, `font_weight`,
`font_italic_angle`, `font_is_embedded`, `font_flags`, `first_seen_page`
(1-based).

## Details

Two fonts are treated as distinct when any of `font_base_name`,
`font_family`, `font_weight`, `font_italic_angle`, `font_is_embedded`,
or `font_flags` differ. The first page on which each font appears is
recorded in `first_seen_page`.

## See also

[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md),
[`pdf_text_font()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font.md).

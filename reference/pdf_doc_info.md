# Document-level metadata for a PDF

Returns the page count, the PDF file version, every standard
Info-dictionary entry, and POSIXct parses of the two date fields. The
shape mirrors `pdftools::pdf_info()` to ease porting.

## Usage

``` r
pdf_doc_info(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

A list with elements:

- `page_count` - integer

- `file_version` - integer; PDFium reports `10 * major + minor` (e.g.
  `17` for PDF 1.7)

- `title`, `author`, `subject`, `keywords`, `creator`, `producer`,
  `creation_date`, `mod_date`, `trapped` - character

- `creation_date_parsed`, `mod_date_parsed` - POSIXct (UTC), `NA` when
  the source date is empty or unparseable

## Details

Standard Info-dictionary entries are UTF-8 strings; missing entries
appear as `""`. Date strings come back in the PDF format
`"D:YYYYMMDDHHmmSS+HH'mm'"` and are also parsed into POSIXct (UTC) in
the `creation_date_parsed` and `mod_date_parsed` slots; parses that fail
return `NA`.

## See also

[`pdf_doc_meta()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_meta.md)
for arbitrary tag access,
[`pdf_parse_date()`](https://humanpred.github.io/rpdfium/reference/pdf_parse_date.md)
for the date-parser used internally.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  info <- pdf_doc_info(fixture)
  info$page_count
  info$producer
  info$creation_date_parsed
}
#> [1] "2026-05-15 19:12:28 UTC"
```

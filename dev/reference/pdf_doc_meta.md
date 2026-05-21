# Read one entry from a PDF's Info dictionary

Wraps `FPDF_GetMetaText`. Returns the requested standard or custom
Info-dictionary tag value as a UTF-8 string, or `""` when the tag is
absent. Standard tags are `"Title"`, `"Author"`, `"Subject"`,
`"Keywords"`, `"Creator"`, `"Producer"`, `"CreationDate"`, `"ModDate"`,
`"Trapped"`. Custom tags from a particular producer's Info dictionary
are also accepted.

## Usage

``` r
pdf_doc_meta(doc, tag)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md).

- tag:

  Character scalar - the Info-dictionary key.

## Value

Character scalar, UTF-8 encoded. `""` if the tag is not present.

## See also

[`pdf_doc_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_info.md)
for a single call that returns every standard tag plus the page count
and file version.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  pdf_doc_meta(doc, "Producer")
  pdf_doc_close(doc)
}
```

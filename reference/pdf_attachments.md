# List the files attached to a PDF document

Returns a `pdfium_attachment_list` — a list of `pdfium_attachment`
handles, one per `/EmbeddedFile` in the document. Each handle is a thin
wrapper around an `FPDF_ATTACHMENT` owned by the parent doc; the
per-attribute getters
([`pdf_attachment_name()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_name.md),
[`pdf_attachment_mime_type()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_mime_type.md),
[`pdf_attachment_size_bytes()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_size_bytes.md),
[`pdf_attachment_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_data.md),
[`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_dict_value.md))
operate on a single handle.

## Usage

``` r
pdf_attachments(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

## Value

A `pdfium_attachment_list` (empty if the document has no attachments).

## Details

Use `tibble::as_tibble(pdf_attachments(doc))` for the tibble view; the
resulting tibble carries `handle` and `source` list-columns that survive
round-trip through
[`as_pdfium_attachment_list()`](https://humanpred.github.io/rpdfium/reference/as_pdfium_attachment_list.md).

## See also

[`pdf_attachment_data()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_data.md),
[`pdf_attachment_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_attachment_dict_value.md).

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "shapes.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) pdf_attachments(fixture)
#> <pdfium_attachment_list: 0 attachment(s)>
```

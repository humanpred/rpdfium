# List the digital signatures attached to a PDF document

Returns a `pdfium_signature_list` — a list of `pdfium_signature`
handles, one per signature object in the document. Per-attribute getters
([`pdf_signature_sub_filter()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_sub_filter.md),
[`pdf_signature_reason()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_reason.md),
[`pdf_signature_time()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_time.md),
[`pdf_signature_doc_mdp_permission()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_doc_mdp_permission.md),
[`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_contents.md),
[`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_byte_range.md))
operate on a single handle.

## Usage

``` r
pdf_signatures(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md),
  or a character path.

## Value

A `pdfium_signature_list` (empty if no signatures).

## Details

Use `tibble::as_tibble(pdf_signatures(doc))` for the tibble view.

Wraps `FPDF_GetSignatureCount`, `FPDF_GetSignatureObject`, and the
`FPDFSignatureObj_*` family.

## See also

[`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_contents.md),
[`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_byte_range.md),
[`pdf_parse_date()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_parse_date.md)
for parsing the time string.

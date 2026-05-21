# Document security handler revision

Returns the PDF security handler revision used by the document:

## Usage

``` r
pdf_doc_security(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_open.md),
  or a character path.

## Value

Integer scalar. `NA` for unencrypted PDFs; one of `2`, `3`, `4`, `5`,
`6` otherwise.

## Details

- `NA` — unencrypted (PDFium reports `-1`, mapped to `NA` here).

- `2` — original 40-bit RC4 (PDF 1.1).

- `3` — 128-bit RC4 (PDF 1.4).

- `4` — AES (PDF 1.6).

- `5` — AES-256, Adobe Extension Level 3 (PDF 1.7).

- `6` — AES-256 (PDF 2.0).

Wraps `FPDF_GetSecurityHandlerRevision`. Useful when classifying PDFs as
"encrypted vs not" and when reporting the encryption strength to
downstream tools — combine with
[`pdf_doc_permissions()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_permissions.md)
to know whether a viewer would let a user print/copy/edit.

## See also

[`pdf_doc_permissions()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_permissions.md),
[`pdf_doc_user_permissions()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_user_permissions.md).

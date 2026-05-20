# User-level document permissions

Returns the *user* subset of the document's permission bitmask (the bits
that apply to a user who opened the PDF without the owner password).
Same shape as
[`pdf_doc_permissions()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_permissions.md)
— a named logical vector with one entry per permission flag — but with
owner-only operations cleared. Wraps `FPDF_GetDocUserPermissions`.

## Usage

``` r
pdf_doc_user_permissions(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

## Value

Named logical vector. Same names as
[`pdf_doc_permissions()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_permissions.md).

## Details

For unencrypted PDFs, every flag is `TRUE`.

## See also

[`pdf_doc_permissions()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_permissions.md),
[`pdf_doc_security()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_security.md).

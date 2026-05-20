# Signature DocMDP permission level

Returns the PDF DocMDP permission level (`1`, `2`, or `3`) or `NA` when
no DocMDP entry is present. Wraps
`FPDFSignatureObj_GetDocMDPPermission`.

## Usage

``` r
pdf_signature_doc_mdp_permission(sig)
```

## Arguments

- sig:

  A `pdfium_signature` handle from
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/reference/pdf_signatures.md).

## Value

Integer scalar (1/2/3) or `NA`.

## Details

Level 1 = no changes; 2 = form-fill only; 3 = form-fill + annotations +
signing fields.

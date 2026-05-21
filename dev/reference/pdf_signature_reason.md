# Signature reason / comment text

Returns the UTF-8 reason string attached when the signer wrote one.
Empty if absent. Wraps `FPDFSignatureObj_GetReason`.

## Usage

``` r
pdf_signature_reason(sig)
```

## Arguments

- sig:

  A `pdfium_signature` handle from
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signatures.md).

## Value

Character scalar.

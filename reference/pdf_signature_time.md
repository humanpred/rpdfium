# Signing time (raw PDF date string)

Returns the signing time as the raw PDF date string
(`"D:YYYYMMDDHHmmSS+HH'mm'"`). Empty if the signature defers to the
PKCS#7 timestamp. Pass to
[`pdf_parse_date()`](https://humanpred.github.io/rpdfium/reference/pdf_parse_date.md)
for POSIXct. Wraps `FPDFSignatureObj_GetTime`.

## Usage

``` r
pdf_signature_time(sig)
```

## Arguments

- sig:

  A `pdfium_signature` handle from
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/reference/pdf_signatures.md).

## Value

Character scalar.

# Read the signed byte ranges of a PDF signature

Returns the (offset, length) pairs that describe which contiguous spans
of the original PDF byte stream were covered by the signing digest. A
signature typically covers everything except the signature's own
`/Contents` entry, so a normal signed PDF returns two pairs: bytes 0 to
just-before-Contents, and bytes just-after-Contents to end-of-file.

## Usage

``` r
pdf_signature_byte_range(sig)
```

## Arguments

- sig:

  A `pdfium_signature` handle from
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signatures.md).

## Value

An integer matrix with `byte_range_pairs` rows and two columns named
`offset` and `length` (both in bytes).

## Details

Wraps `FPDFSignatureObj_GetByteRange`.

## See also

[`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signature_contents.md).

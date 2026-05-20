# Read the signed byte ranges of a PDF signature

Returns the (offset, length) pairs that describe which contiguous spans
of the original PDF byte stream were covered by the signing digest. A
signature typically covers everything except the signature's own
`/Contents` entry, so a normal signed PDF returns two pairs: bytes 0 to
just-before-Contents, and bytes just-after-Contents to end-of-file.

## Usage

``` r
pdf_signature_byte_range(doc, signature_index = 1L)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

- signature_index:

  One-based signature index (default `1`), as listed by
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/reference/pdf_signatures.md).

## Value

An integer matrix with `byte_range_pairs` rows and two columns named
`offset` and `length` (both in bytes).

## Details

Wraps `FPDFSignatureObj_GetByteRange`.

## See also

[`pdf_signatures()`](https://humanpred.github.io/rpdfium/reference/pdf_signatures.md),
[`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_contents.md).

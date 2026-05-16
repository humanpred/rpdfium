# Read the raw bytes of a PDF signature's contents blob

Returns the DER-encoded PKCS#7 (for `adbe.pkcs7.*` /
`ETSI.CAdES.detached` sub-filters) or PKCS#1 (for `adbe.x509.rsa_sha1`)
signature blob. Feed this into a PKI library to actually verify the
signature (e.g. `openssl::pkcs7_verify(bytes, data = signed_bytes)`).

## Usage

``` r
pdf_signature_contents(doc, signature_index = 1L)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- signature_index:

  One-based signature index (default `1`), as listed by
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/reference/pdf_signatures.md).

## Value

A raw vector of the signature blob.

## Details

Wraps `FPDFSignatureObj_GetContents`.

## See also

[`pdf_signatures()`](https://humanpred.github.io/rpdfium/reference/pdf_signatures.md),
[`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_byte_range.md).

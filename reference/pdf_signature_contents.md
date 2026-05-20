# Read the raw bytes of a PDF signature's contents blob

Returns the DER-encoded PKCS#7 (for `adbe.pkcs7.*` /
`ETSI.CAdES.detached` sub-filters) or PKCS#1 (for `adbe.x509.rsa_sha1`)
signature blob. Feed this into a PKI library to actually verify the
signature (e.g. `openssl::pkcs7_verify(bytes, data = signed_bytes)`).

## Usage

``` r
pdf_signature_contents(sig)
```

## Arguments

- sig:

  A `pdfium_signature` handle from
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/reference/pdf_signatures.md).

## Value

A raw vector of the signature blob.

## Details

Wraps `FPDFSignatureObj_GetContents`.

## See also

[`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_byte_range.md).

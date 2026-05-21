# Signature `/SubFilter` value

Returns the signature's `/SubFilter` field (e.g.
`"adbe.pkcs7.detached"`, `"ETSI.CAdES.detached"`,
`"adbe.x509.rsa_sha1"`). ASCII. Wraps `FPDFSignatureObj_GetSubFilter`.

## Usage

``` r
pdf_signature_sub_filter(sig)
```

## Arguments

- sig:

  A `pdfium_signature` handle from
  [`pdf_signatures()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_signatures.md).

## Value

Character scalar.

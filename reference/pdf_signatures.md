# List the digital signatures attached to a PDF document

Returns a tibble row per signature object in the document. Wraps
`FPDF_GetSignatureCount`, `FPDF_GetSignatureObject`, and the
`FPDFSignatureObj_*` scalar accessors.

## Usage

``` r
pdf_signatures(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

## Value

A tibble with columns:

- `signature_index` integer - 1-based; pass to
  [`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_contents.md)
  /
  [`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_byte_range.md).

- `sub_filter` character - the signature's `/SubFilter` value, e.g.
  `"adbe.pkcs7.detached"`, `"ETSI.CAdES.detached"`,
  `"adbe.x509.rsa_sha1"`. ASCII.

- `reason` character - UTF-8 reason / comment string, attached when the
  signer wrote one. Empty if absent.

- `time` character - signing time in PDF date format
  (`"D:YYYYMMDDHHmmSS+HH'mm'"`). Empty if the signature defers to the
  timestamp inside the PKCS#7 blob. Pass to
  [`pdf_parse_date()`](https://humanpred.github.io/rpdfium/reference/pdf_parse_date.md)
  for a POSIXct.

- `doc_mdp_permission` integer - 1, 2, or 3 (PDF DocMDP permission
  level: no changes / form-fill only / form-fill

  - annotations + signing fields). `NA` when no DocMDP entry is present.

- `contents_size` integer - byte length of the signature blob
  (DER-encoded PKCS#1 or PKCS#7).

- `byte_range_pairs` integer - number of (offset, length) pairs covered
  by the signed digest. Pass `signature_index` to
  [`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_byte_range.md)
  for the actual pairs.

Returns a 0-row tibble of the same schema when the document has no
signatures.

## See also

[`pdf_signature_contents()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_contents.md)
for the raw PKCS#7 / PKCS#1 bytes,
[`pdf_signature_byte_range()`](https://humanpred.github.io/rpdfium/reference/pdf_signature_byte_range.md)
for the signed byte ranges,
[`pdf_parse_date()`](https://humanpred.github.io/rpdfium/reference/pdf_parse_date.md)
for parsing the `time` column.

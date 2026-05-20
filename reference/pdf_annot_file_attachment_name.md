# Name of the file attached to a file-attachment annotation

For annotations of subtype `"fileattachment"`, returns the attached
file's name (UTF-8) — the same value that surfaces in the
`file_attachment_name` column of `as_tibble(pdf_annotations())`. Empty
string for any other annotation subtype. Wraps
`FPDFAnnot_GetFileAttachment` + `FPDFAttachment_GetName`.

## Usage

``` r
pdf_annot_file_attachment_name(annot)
```

## Arguments

- annot:

  A `pdfium_annot` handle from
  [`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
  or
  [`pdf_annot_at()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_at.md).

## Value

Character scalar.

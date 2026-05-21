# Set the `/T` (title / author) of an annotation

Wraps `FPDFAnnot_SetStringValue(annot, "T", text)`. By convention the
`/T` entry holds the annotation author's name (Acrobat shows it as
"Author").

## Usage

``` r
pdf_annot_set_title(annot, text)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

- text:

  Character scalar (UTF-8).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_title()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_title.md).

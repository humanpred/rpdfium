# Set the `/Subj` (subject) of an annotation

Wraps `FPDFAnnot_SetStringValue(annot, "Subj", text)`. The subject is a
brief descriptor (e.g. "Highlight") that some PDF readers surface
separately from `/Contents`.

## Usage

``` r
pdf_annot_set_subject(annot, text)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

- text:

  Character scalar (UTF-8).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_subject()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_subject.md).

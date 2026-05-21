# Set the `/Contents` text of an annotation

Wraps `FPDFAnnot_SetStringValue(annot, "Contents", text)`. The Contents
entry is the visible body / popup-message text on most annotation
subtypes.

## Usage

``` r
pdf_annot_set_contents(annot, text)
```

## Arguments

- annot:

  A `pdfium_annot` handle. Parent doc must be readwrite.

- text:

  Character scalar (UTF-8).

## Value

Invisibly returns the parent `pdfium_doc`.

## See also

[`pdf_annot_contents()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_contents.md),
[`pdf_annot_set_title()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_title.md),
[`pdf_annot_set_subject()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_subject.md),
[`pdf_annot_set_dict_value()`](https://humanpred.github.io/rpdfium/reference/pdf_annot_set_dict_value.md).

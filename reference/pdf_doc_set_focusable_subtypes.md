# Set the doc-wide list of annotation subtypes that participate in tab focus

Wraps `FPDFAnnot_SetFocusableSubtypes`. Pair with the existing
[`pdf_doc_focusable_subtypes()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_focusable_subtypes.md)
reader.

## Usage

``` r
pdf_doc_set_focusable_subtypes(doc, subtypes)
```

## Arguments

- doc:

  A `pdfium_doc` opened with `readwrite = TRUE`.

- subtypes:

  Character vector of subtype names (e.g. `c("widget", "link")`). Must
  match the subtype-code table used by
  [`pdfium_annot_subtype_code()`](https://humanpred.github.io/rpdfium/reference/pdfium_annot_subtype_name.md).

## Value

Invisibly returns `doc`.

## See also

[`pdf_doc_focusable_subtypes()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_focusable_subtypes.md).

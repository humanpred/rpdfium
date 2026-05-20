# Annotation subtypes registered as keyboard-focusable

Returns the set of `FPDF_ANNOT_*` subtype codes the document's form-fill
module accepts for tab-focus, as names. Widget annotations are always
focusable by default; other subtypes can be registered via
`FPDFAnnot_SetFocusableSubtypes` (writer side, not yet exposed). Wraps
`FPDFAnnot_GetFocusableSubtypesCount` and
`FPDFAnnot_GetFocusableSubtypes`.

## Usage

``` r
pdf_doc_focusable_subtypes(doc, password = NULL)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md),
  or a character path.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

Character vector of annotation-subtype names. Empty when the document
has no form-fill module or no focusable subtypes.

## Details

Mostly a viewer-UI concern; exposed here for round-trip completeness
against the v0.2.0 setter.

## See also

[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
(`subtype` column maps to the same names).

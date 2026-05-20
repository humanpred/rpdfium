# Content marks attached to a page object

Returns one tibble row per *content mark* on the page object — the
tagged-PDF mechanism that links a piece of page content (a path, a text
run, an image, ...) to a structure element in
[`pdf_structure_tree()`](https://humanpred.github.io/rpdfium/reference/pdf_structure_tree.md).
Wraps `FPDFPageObj_CountMarks`, `FPDFPageObj_GetMark`,
`FPDFPageObjMark_GetName`, `_CountParams`, `_GetParamKey`,
`_GetParamValueType`, and the `_GetParamIntValue` /
`_GetParamStringValue` / `_GetParamBlobValue` accessors.

## Usage

``` r
pdf_obj_marks(obj)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md).

## Value

A tibble with columns:

- `mark_index` integer - 1-based position in the object's mark stack.

- `name` character - the mark name (BDC tag).

- `params` list-column - a named list of the mark's parameter values.
  Values are typed in R: numeric for `FPDF_OBJECT_NUMBER`, character for
  `_STRING` / `_NAME`, raw vectors for blobs.

Returns a 0-row tibble of the same schema when the object has no marks
(typical for content from untagged PDFs).

## Details

Each mark carries a *name* (typically the structural type or BDC tag —
e.g. `"P"`, `"Span"`, `"Artifact"`) and zero or more parameters as
key/value pairs. The most common parameter is `MCID` (an integer linking
the object to a structure tree element's marked-content reference).

## See also

[`pdf_structure_tree()`](https://humanpred.github.io/rpdfium/reference/pdf_structure_tree.md)
for the structure-tree side of the same linkage;
[`pdf_obj_type()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_type.md).

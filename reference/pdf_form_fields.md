# Enumerate AcroForm fields across the whole document

Returns a handle for every form widget across every page of the
document. Walks each page's annotations, filters to those of subtype
`widget`, and reads PDFium's form-field metadata through a transient
`FPDF_FORMHANDLE` (init / enumerate / teardown happens inside one call -
the handle is not exposed to R).

## Usage

``` r
pdf_form_fields(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

## Value

A `pdfium_form_field_list`: a list of `pdfium_form_field` handles, one
per widget, in document order (page-major, then in-page annotation
order). A `pdfium_form_field` is also a `pdfium_annot`, so the
`pdf_form_field_*` readers and setters and the `pdf_annot_*` readers
take it.
[`tibble::as_tibble()`](https://tibble.tidyverse.org/reference/as_tibble.html)
(or [`summary()`](https://rdrr.io/r/base/summary.html)) turns the list
into a tibble with one row per field; see
[`as_tibble.pdfium_form_field_list()`](https://humanpred.github.io/rpdfium/reference/as_tibble.pdfium_form_field_list.md)
for its columns. The list is empty when the document has no AcroForm
dictionary.

## Details

Wraps `FPDFDOC_InitFormFillEnvironment`,
`FPDFDOC_ExitFormFillEnvironment`, the `FPDFAnnot_GetFormField*` family,
`FPDFAnnot_IsChecked` for the check/radio state, and
`FPDFAnnot_GetOption*` for choice-list options.

## See also

[`pdf_annotations()`](https://humanpred.github.io/rpdfium/reference/pdf_annotations.md)
for the page-level annotation surface that includes widget annotations
alongside text, highlights, ink, etc.

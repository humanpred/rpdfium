# Form-type flavour of the document

Wraps `FPDF_GetFormType` to report whether the document carries an
AcroForm (`"acro_form"`), a full XFA form (`"xfa_full"`), an XFA
foreground overlay on top of an AcroForm (`"xfa_foreground"`), or no
form at all (`"none"`).

## Usage

``` r
pdf_doc_form_type(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md).

## Value

Character scalar — one of `"none"`, `"acro_form"`, `"xfa_full"`,
`"xfa_foreground"`.

## Details

AcroForm is what
[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md)
enumerates; XFA forms are an Adobe-specific dialect that PDFium does not
interpret (you can detect them with this function and warn the user to
use Adobe Reader).

## See also

[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md).

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "minimal.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  pdf_doc_form_type(doc)
  pdf_doc_close(doc)
}
```

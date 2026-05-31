# Create an XObject (reusable form) from a source-doc page

Wraps `FPDF_NewXObjectFromPage`. Copies the visual content of
`src_doc`'s page `src_page_num` into `dest_doc` as an `FPDF_XOBJECT`.
The XObject can then be instantiated multiple times in `dest_doc` via
[`pdf_obj_form_from_xobject()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_form_from_xobject.md)
— useful for "n-up" layouts where the same page content needs to be
tiled.

## Usage

``` r
pdf_xobject_from_page(dest_doc, src_doc, src_page_num = 1L)
```

## Arguments

- dest_doc:

  A `pdfium_doc` opened with `readwrite = TRUE`.

- src_doc:

  Source `pdfium_doc`. Read-only is fine.

- src_page_num:

  One-based page index in `src_doc`.

## Value

A `pdfium_xobject` handle.

## See also

[`pdf_obj_form_from_xobject()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_form_from_xobject.md)
to instantiate as a page object;
[`pdf_xobject_close()`](https://humanpred.github.io/rpdfium/reference/pdf_xobject_close.md)
for deterministic release.

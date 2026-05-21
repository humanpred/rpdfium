# Reset every form field in the document to its default value

Convenience wrapper that calls
[`pdf_form_field_clear()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_clear.md)
on every form field in `doc`. PDFium has no public `FORM_Reset` symbol,
so this is implemented as a loop over the field list.

## Usage

``` r
pdf_form_reset(doc)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md).
  Must be readwrite.

## Value

Invisibly returns `doc`.

## See also

[`pdf_form_field_clear()`](https://humanpred.github.io/rpdfium/reference/pdf_form_field_clear.md).

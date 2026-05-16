# List the annotations on a PDF page

Returns one tibble row per annotation on the given page, carrying the
structural metadata PDFium surfaces: subtype, bounding box, the 32-bit
flags bitmask, and the two text string entries (`/Contents` and `/T`)
every annotation kind may carry. For form-widget-specific fields (field
type, field value, choice options) use
[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md)
instead.

## Usage

``` r
pdf_annotations(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md),
  or a `pdfium_doc` (in which case `page_num` selects the page).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A tibble with columns:

- `annotation_index` integer - 1-based index within the page's
  annotation table.

- `subtype` character - one of `"text"`, `"link"`, `"freetext"`,
  `"line"`, `"square"`, `"circle"`, `"polygon"`, `"polyline"`,
  `"highlight"`, `"underline"`, `"squiggly"`, `"strikeout"`, `"stamp"`,
  `"caret"`, `"ink"`, `"popup"`, `"fileattachment"`, `"sound"`,
  `"movie"`, `"widget"`, `"screen"`, `"printermark"`, `"trapnet"`,
  `"watermark"`, `"threed"`, `"richmedia"`, `"xfawidget"`, `"redact"`,
  or `"unknown"`. `"widget"` annotations are AcroForm fields; pass the
  document to
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md)
  for their field-level metadata.

- `flags` integer - the annotation's 32-bit flag bitmask. Useful bits:
  `0x01` invisible, `0x02` hidden, `0x04` printable, `0x40` read-only,
  `0x80` locked.

- `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top` -
  rectangle in PDF user space.

- `contents` character - the annotation's `/Contents` text, UTF-8
  encoded. Empty when absent.

- `title` character - the annotation's `/T` (title / author) text, UTF-8
  encoded. Empty when absent.

Returns a 0-row tibble of the same schema when the page has no
annotations.

## Details

Wraps `FPDFPage_GetAnnotCount`, `FPDFPage_GetAnnot`,
`FPDFAnnot_GetSubtype`, `FPDFAnnot_GetFlags`, `FPDFAnnot_GetRect`,
`FPDFAnnot_GetStringValue`.

## See also

[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/reference/pdf_form_fields.md)
for AcroForm-specific accessors.

# List the annotations on a PDF page

Returns one tibble row per annotation on the given page, carrying the
structural metadata PDFium surfaces: subtype, bounding box, raw +
decoded flags, the three free-text string entries (`/Contents`, `/T`,
`/Subj`), color (`/C`) and interior color (`/IC`), and the annotation's
stroke border width. For form-widget-specific fields (field type, field
value, choice options) use
[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md)
instead.

## Usage

``` r
pdf_annotations(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_load.md),
  or a `pdfium_doc` (in which case `page_num` selects the page).

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A tibble with columns:

- `annotation_index` integer - 1-based index within the page's
  annotation table.

- `subtype_code` integer - the raw `FPDF_ANNOT_*` enum value (`0..28`).
  Useful when round-tripping into v0.2.0 writers that take the enum
  directly.

- `subtype` character - one of `"text"`, `"link"`, `"freetext"`,
  `"line"`, `"square"`, `"circle"`, `"polygon"`, `"polyline"`,
  `"highlight"`, `"underline"`, `"squiggly"`, `"strikeout"`, `"stamp"`,
  `"caret"`, `"ink"`, `"popup"`, `"fileattachment"`, `"sound"`,
  `"movie"`, `"widget"`, `"screen"`, `"printermark"`, `"trapnet"`,
  `"watermark"`, `"threed"`, `"richmedia"`, `"xfawidget"`, `"redact"`,
  or `"unknown"`. `"widget"` annotations are AcroForm fields; pass the
  document to
  [`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md)
  for their field-level metadata.

- `flags` integer - the raw 32-bit `/F` flag bitmask.

- `is_invisible`, `is_hidden`, `is_print`, `is_no_view`, `is_read_only`,
  `is_locked` logical - decoded flag bits (bits 1, 2, 3, 6, 7, 8 from
  PDF spec Table 165).

- `bounds_left`, `bounds_bottom`, `bounds_right`, `bounds_top` -
  rectangle in PDF user space.

- `contents` character - the annotation's `/Contents` body text, UTF-8
  encoded. Empty when absent.

- `title` character - the annotation's `/T` (title / author) text. Empty
  when absent.

- `subject` character - the annotation's `/Subj` subject line. Empty
  when absent.

- `color_red`, `color_green`, `color_blue`, `color_alpha` numeric - the
  annotation's `/C` color components in 0..1. `NA` when the annotation
  has no `/C`.

- `interior_red`, `interior_green`, `interior_blue`, `interior_alpha`
  numeric - the annotation's `/IC` interior color components in 0..1
  (used by line/square/ circle / polygon subtypes). `NA` otherwise.

- `border_width` numeric - the stroke border width PDFium reports for
  `/Border` / `/BS`. `NA` for subtypes that don't carry a border.

- `quad_points` list-column - for highlights, underlines, strikeouts,
  squigglies (and any other quad-bearing subtype), a numeric matrix with
  one row per quad set and eight columns
  `x1, y1, x2, y2, x3, y3, x4, y4` in PDF user space. `NULL` for
  annotations without `/QuadPoints`. Multi-line highlights produce one
  row per line.

- `vertices` list-column - for line / polygon / polyline annotations, an
  N-by-2 numeric matrix with columns `x, y`. `NULL` for other subtypes.

- `ink_paths` list-column - for ink annotations, a list of stroke paths,
  each an N-by-2 numeric matrix `x, y`. `NULL` for non-ink annotations.
  One element per ink stroke; a single-stroke ink annotation produces a
  length-1 list.

- `font_color_red`, `font_color_green`, `font_color_blue` numeric - the
  annotation's text-fill color (`/DA` "g"/"rg"/ "k" operands) in 0..1.
  Meaningful for FreeText / Widget subtypes that carry inline text; `NA`
  for others.

- `font_size` numeric - the text-fill font size from `/DA`; `NA` when
  the annotation doesn't carry variable text.

- `popup_index` integer - 1-based `annotation_index` of the linked
  `/Popup` annotation on the same page (for sticky-note + popup pairs);
  `NA` when none.

- `irt_index` integer - 1-based `annotation_index` of the `/IRT`
  (in-reply-to) annotation for comment threads; `NA` when none.

- `file_attachment_name` character - the attachment name for
  `fileattachment`-subtype annotations; `NA` for other subtypes.

Returns a 0-row tibble of the same schema when the page has no
annotations.

## Details

Wraps `FPDFPage_GetAnnotCount`, `FPDFPage_GetAnnot`,
`FPDFAnnot_GetSubtype`, `FPDFAnnot_GetFlags`, `FPDFAnnot_GetRect`,
`FPDFAnnot_GetStringValue`, `FPDFAnnot_GetColor`, `FPDFAnnot_GetBorder`,
`FPDFAnnot_GetAttachmentPoints` / `_HasAttachmentPoints` /
`_CountAttachmentPoints`, `FPDFAnnot_GetVertices`, and
`FPDFAnnot_GetInkListCount` / `_GetInkListPath`.

## See also

[`pdf_form_fields()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_fields.md)
for AcroForm-specific accessors.

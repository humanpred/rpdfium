# Load a TrueType or Type1 font from bytes

Wraps `FPDFText_LoadFont`. The font bytes are embedded into the PDF up
front (PDFium copies them; the input is free to be garbage-collected
after the call returns). Use
[`pdf_font_load_standard()`](https://humanpred.github.io/rpdfium/reference/pdf_font_load_standard.md)
for the 14 PDF standard fonts where no embedding is needed.

## Usage

``` r
pdf_font_load(doc, font_data, type = c("truetype", "type1"), cid = TRUE)
```

## Arguments

- doc:

  A `pdfium_doc` opened with `readwrite = TRUE`.

- font_data:

  Either a raw vector containing the font bytes or a character path to a
  font file on disk.

- type:

  Character — `"truetype"` (default) for TrueType / OTF fonts, or
  `"type1"` for Type1 fonts.

- cid:

  Logical. If `TRUE` (the default), the font is loaded as a CID
  (composite) font. CID encoding is required for fonts with more than
  255 glyphs — i.e. anything that needs to render non-Latin-1 text. The
  non-CID path (`cid = FALSE`) is smaller on disk but limited to the
  standard PDF encodings. When in doubt, leave this as `TRUE`.

## Value

A `pdfium_font` handle. Pass it as the `font` argument of
[`pdf_text_new()`](https://humanpred.github.io/rpdfium/reference/pdf_text_new.md).

## See also

[`pdf_font_load_standard()`](https://humanpred.github.io/rpdfium/reference/pdf_font_load_standard.md),
[`pdf_text_new()`](https://humanpred.github.io/rpdfium/reference/pdf_text_new.md),
[`pdf_font_close()`](https://humanpred.github.io/rpdfium/reference/pdf_font_close.md).

## Examples

``` r
if (FALSE) { # \dontrun{
doc <- pdf_doc_new()
page <- pdf_page_new(doc, width = 612, height = 792)
ttf <- "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
if (file.exists(ttf)) {
  font <- pdf_font_load(doc, ttf)
  pdf_text_new(page, "hello", font = font, font_size = 24,
               x = 72, y = 720)
}
pdf_save(doc, tempfile(fileext = ".pdf"))
} # }
```

# Glyph outline for a single glyph in a text page-object's font

Returns the path segments of the glyph rendered at `font_size` in PDF
user-space points. Useful for:

## Usage

``` r
pdf_glyph_path(obj, glyph_code, font_size = NA_real_)
```

## Arguments

- obj:

  A `pdfium_obj` of type `"text"`.

- glyph_code:

  Single non-negative integer; see the section above.

- font_size:

  Numeric font size in PDF points. When `NA` (default), uses the text
  object's own font size — the most common choice when matching what is
  drawn on the page.

## Value

A tibble with one row per glyph-path segment:

- `segment_index` integer - 1-based.

- `segment_type` character - `"moveto"`, `"lineto"`, `"bezierto"`, or
  `"unknown"`.

- `x`, `y` numeric - point coordinates in PDF user-space points (the
  glyph's local coordinate system, scaled to the requested `font_size`).

- `close_figure` logical - `TRUE` if this segment closes the current
  sub-path. Returns an empty tibble when PDFium reports no glyph
  outline.

## Details

- Reconstructing challenging character mappings — render the glyph at
  the character's reported unicode code point and compare to a reference
  rendering of that code point to see whether the font actually draws
  what its ToUnicode CMap claims.

- Visualising the glyphs PDFium picked when extracting text.

- Computing exact glyph silhouettes for layout / collision detection
  beyond what bounding boxes give you.

Wraps `FPDFTextObj_GetFont` -\> `FPDFFont_GetGlyphPath` -\>
`FPDFGlyphPath_CountGlyphSegments` /
`FPDFGlyphPath_GetGlyphPathSegment`.

## Glyph code interpretation

`glyph_code` is the *font's* glyph identifier, not the unicode code
point — though for many fonts they coincide:

- **TrueType fonts with `/Identity-H` encoding** (most modern embedded
  CID-keyed fonts): glyph code equals unicode code point. Pass
  `chars$codepoint` from
  [`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md).

- **TrueType fonts with a `cmap` (e.g. WinAnsi or MacRoman encoding)**:
  glyph code is the encoded character code in the PDF stream, not the
  unicode value. The unicode \<-\> glyph map is opaque through the
  public PDFium API.

- **Type 1 fonts**: glyph code is the encoding-specific character code
  (1-byte for almost all PDF Type 1 fonts).

If the path comes back empty, the glyph code likely doesn't map to a
glyph in this font's encoding — try the character code from the source
content stream (visible in tools like `pdfinfo -text`) instead.

## See also

[`pdf_glyph_width()`](https://humanpred.github.io/rpdfium/reference/pdf_glyph_width.md),
[`pdf_text_font_metrics()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_metrics.md),
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)
for the per-character readout that drives most "investigate this glyph"
workflows,
[`pdf_text_obj_rendered_bitmap()`](https://humanpred.github.io/rpdfium/reference/pdf_text_obj_rendered_bitmap.md)
when you want the rendered pixels instead of the outline.

## Examples

``` r
if (FALSE) { # \dontrun{
doc <- pdf_doc_open("weird-font.pdf")
page <- pdf_page_load(doc, 1)
text_obj <- Filter(\(o) o$type == "text", pdf_page_objects(page))[[1]]
# First visible character on the page:
chars <- pdf_text_chars(page)
first <- chars[!chars$is_generated, ][1, ]
pdf_glyph_path(text_obj, first$codepoint)
} # }
```

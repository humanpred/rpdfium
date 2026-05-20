# Find every occurrence of a query string in a PDF

Searches each page of the document for `query` and returns a row per
match with the page number, character offset, matched text, and bounding
box in PDF user-space points. Wraps PDFium's `FPDFText_FindStart` /
`FPDFText_FindNext` family.

## Usage

``` r
pdf_text_search(
  doc,
  query,
  case_sensitive = FALSE,
  whole_word = FALSE,
  consecutive = FALSE,
  password = NULL
)
```

## Arguments

- doc:

  A `pdfium_doc` from
  [`pdf_doc_open()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_open.md),
  or a character path.

- query:

  Single non-empty character string to find. Encoded to UTF-16LE before
  being handed to PDFium; any character representable in UTF-8 works
  (including supplementary-plane code points via surrogate pairs).

- case_sensitive:

  If `TRUE`, only exact-case matches are returned. Default `FALSE`
  (case-insensitive ASCII letters; PDFium does not promise case folding
  for non-ASCII letters).

- whole_word:

  If `TRUE`, the match must be bounded by word-break characters
  (whitespace / punctuation) on both sides. Default `FALSE`.

- consecutive:

  If `TRUE`, after a match the next search resumes *immediately* after
  the match end; if `FALSE` (default), PDFium skips ahead by one
  character before searching again, so overlapping matches are not
  reported.

- password:

  Optional password for encrypted PDFs when `doc` is a path. Ignored
  when `doc` is already an open `pdfium_doc`.

## Value

A tibble with one row per match and columns:

- `page` (integer, 1-based)

- `match_index` (integer, 1-based within `page`)

- `start_char` (integer, 0-based character offset on the page)

- `char_count` (integer, number of characters in the match)

- `text` (character, the matched substring, UTF-8)

- `left`, `bottom`, `right`, `top` (numeric, axis-aligned union of the
  matched characters' bounding boxes in PDF user-space points; `NA` when
  PDFium reports no bounds, which can happen for glyphs without a
  positioned origin)

The tibble has zero rows when no matches are found. Column types are
stable across the zero-row and non-zero-row cases.

## Details

Match indexing is character-based: PDFium's text page is an indexable
sequence of glyph-derived characters in reading order, and `start_char`
is the 0-based offset of the first matched character on that page. The
same offset can be cross-referenced against
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)
output if you need per-character bounds rather than per-match bounds.

Multi-line matches (where the matched text wraps across lines) are
reported as a single row whose bounding box is the axis-aligned union of
every contributing character's bounding box. If you need one rectangle
per line for highlighting, expand each row by iterating
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)
over `start_char:(start_char + char_count - 1)`.

## See also

[`pdf_doc_text()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_text.md)
for whole-page text,
[`pdf_text_runs()`](https://humanpred.github.io/rpdfium/reference/pdf_text_runs.md)
for per-text-object structure,
[`pdf_text_chars()`](https://humanpred.github.io/rpdfium/reference/pdf_text_chars.md)
for per-character positions.

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "unicode.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  pdf_text_search(fixture, "Hello")
  pdf_text_search(fixture, "WORLD", case_sensitive = FALSE)
}
#> # A tibble: 1 × 9
#>    page match_index start_char char_count text   left bottom right   top
#>   <int>       <int>      <int>      <int> <chr> <dbl>  <dbl> <dbl> <dbl>
#> 1     1           1          7          5 world  129.   137.  158.  146.
```

# Read the tagged-PDF structure tree for a page

Returns one tibble row per accessibility structure element associated
with the given page, walking PDFium's view of the document's
`/StructTreeRoot` depth-first. Each row carries the element's structural
type (e.g. `"P"`, `"H1"`, `"Span"`, `"Figure"`), its title / language /
alternative text, the marked-content ID linking it to a page-content
tag, and the tree shape (parent_index + level).

## Usage

``` r
pdf_structure_tree(page, page_num = 1L)
```

## Arguments

- page:

  A `pdfium_page` from
  [`pdf_page_load()`](https://humanpred.github.io/rpdfium/reference/pdf_page_load.md),
  or a `pdfium_doc`.

- page_num:

  One-based page index. Only used when `page` is a `pdfium_doc`. Ignored
  otherwise.

## Value

A tibble with columns:

- `element_index` integer - 1-based pre-order position in the page's
  tree walk.

- `parent_index` integer - the `element_index` of the parent element;
  `0` for top-level entries (children of the page's structure-tree
  root).

- `level` integer - 1-based nesting depth.

- `type` character - the structural element type (`/S`), UTF-8. Common
  values follow the PDF spec's standard structure types (e.g.
  `"Document"`, `"Sect"`, `"P"`, `"H1"`, `"Span"`, `"Figure"`,
  `"Table"`).

- `title` character - the element's `/T` title (often empty).

- `lang` character - the element's `/Lang` IETF BCP 47 code (e.g.
  `"en"`, `"fr"`); empty when none is set.

- `alt_text` character - the element's `/Alt` alternative text for
  assistive technology; empty when none is set.

- `actual_text` character - the element's `/ActualText` replacement
  text; empty when none is set.

- `id` character - the element's `/ID` string (often empty).

- `mcid` integer - the first marked-content ID associated with the
  element (whether direct `/K N` or via the first `/MCR` child); `NA`
  when the element has no marked content of its own (typical for
  container elements like `Document` / `Sect`).

- `mcid_count` integer - how many marked-content IDs the element
  references; `0` for elements without content, `1` for the simple
  `/K N` case, `>1` for elements that span several content tags.

- `obj_type` character - the element's `/Type` entry (typically
  `"StructElem"`; empty when not set).

- `attributes` list-column - a named list of the element's structural
  attributes (PDF spec table 354+), with R-typed values: logical for
  `/O /Layout /BBox`-like booleans, numeric for `/RowSpan` / `/ColSpan`
  / `/StartIndent`, character for `/Placement` / `/TextAlign` /
  `/Lang`-style names. Empty list when the element has no `/A` attribute
  objects. Aggregated across all attribute dictionaries on the element
  (PDF's nested attribute-class layout is flattened to a single
  namespace).

Returns a 0-row tibble of the same schema when the page has no
associated structure tree (typical for untagged PDFs).

## Details

Most PDFs are not tagged; for those, this function returns a 0-row
tibble. Tagging is required for `print_high_res`-quality accessibility,
screen-reader support, and PDF/UA conformance.

Wraps `FPDF_StructTree_GetForPage`, `FPDF_StructTree_*Children`,
`FPDF_StructElement_GetType` / `GetTitle` / `GetLang` / `GetAltText` /
`GetActualText` / `GetID` / `GetMarkedContentID`.

## See also

[`pdf_doc_is_tagged()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_is_tagged.md)
for a fast yes/no check at the document level.

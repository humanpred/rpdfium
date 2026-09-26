# Tibble view of a `pdfium_bookmark_list`

Walks every bookmark in the list and reads its metadata into a tibble.
Adds `handle` and `source` list-columns (ADR-017).

## Usage

``` r
# S3 method for class 'pdfium_bookmark_list'
as_tibble(x, ...)
```

## Arguments

- x:

  A `pdfium_bookmark_list` from
  [`pdf_doc_bookmarks()`](https://humanpred.github.io/rpdfium/reference/pdf_doc_bookmarks.md).

- ...:

  Unused (S3 generic compatibility).

## Value

A tibble with one row per bookmark: `bookmark_index`, `parent_index`,
`level`, `title`, `page_num`, `action_type`, `uri`, `filepath`,
`dest_view`, `dest_x`, `dest_y`, `dest_zoom` (see the per-handle
getters), `color_red` / `color_green` / `color_blue` (title color in
`[0, 1]`, `NA` when unset; see
[`pdf_bookmark_color()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_color.md))
and `italic` / `bold` (see
[`pdf_bookmark_style()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_style.md)),
plus the `handle` and `source` list-columns.

# Link / page action type codes \<-\> names

PDFium reports action types as `FPDFACTION_*` codes (0 = unsupported, 1
= goto, 2 = remote_goto, 3 = uri, 4 = launch, 5 = embedded_goto).
[`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md)
and the page-additional-actions API return the name as `action_type`;
these helpers expose the symmetric direction.

## Usage

``` r
pdfium_action_type_name(codes)

pdfium_action_type_code(names)
```

## Arguments

- codes:

  Integer vector of PDFium subtype codes.

- names:

  Character vector of subtype names (case-insensitive).

## Value

A character vector (`_name()`) or integer vector (`_code()`), same
length as the input.

## Details

Note: the `FPDFACTION_*` enum is 1-based (with 0 reserved for
"unsupported"), so the conversion respects that base.

## See also

[`pdf_link_at_point()`](https://humanpred.github.io/rpdfium/reference/pdf_link_at_point.md),
[`pdf_page_actions()`](https://humanpred.github.io/rpdfium/reference/pdf_page_actions.md),
[`pdf_bookmark_action_type()`](https://humanpred.github.io/rpdfium/reference/pdf_bookmark_action_type.md).

## Examples

``` r
pdfium_action_type_name(c(1L, 3L, 5L))
#> [1] "goto"          "uri"           "embedded_goto"
#> [1] "goto" "uri" "embedded_goto"
pdfium_action_type_code(c("goto", "URI", "launch"))
#> [1] 1 3 4
#> [1] 1 3 4
```

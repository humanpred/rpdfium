# Named-destination view-mode codes \<-\> names

Named-destination view modes are reported as `PDFDEST_VIEW_*` codes (0 =
unknown, 1 = xyz, 2 = fit, 3 = fith, 4 = fitv, 5 = fitr, 6 = fitb, 7 =
fitbh, 8 = fitbv).
[`pdf_bookmark_dest_view()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_view.md)
returns the name; these helpers expose the mapping.

## Usage

``` r
pdfium_dest_view_name(codes)

pdfium_dest_view_code(names)
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

Note: like the action-type enum, this enum is 1-based (with 0 reserved
for the unknown sentinel).

## See also

[`pdf_bookmark_dest_view()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_bookmark_dest_view.md),
[`pdf_doc_named_dests()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_named_dests.md).

## Examples

``` r
pdfium_dest_view_name(c(1L, 2L, 5L))
#> [1] "xyz"  "fit"  "fitr"
#> [1] "xyz" "fit" "fitr"
pdfium_dest_view_code(c("xyz", "Fit", "fitr"))
#> [1] 1 2 5
#> [1] 1 2 5
```

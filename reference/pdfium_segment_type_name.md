# Path-segment type codes \<-\> names

PDFium's `FPDFPathSegment_GetType` returns one of `0` (lineto), `1`
(bezierto), or `2` (moveto).
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
surfaces the name as `segment_type`. These helpers expose the mapping
for programmatic filters / round-trips.

## Usage

``` r
pdfium_segment_type_name(codes)

pdfium_segment_type_code(names)
```

## Arguments

- codes:

  Integer vector of PDFium subtype codes.

- names:

  Character vector of subtype names (case-insensitive).

## Value

A character vector (`_name()`) or integer vector (`_code()`), same
length as the input.

## See also

[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md).

## Examples

``` r
pdfium_segment_type_name(c(0L, 1L, 2L))
#> [1] "lineto"   "bezierto" "moveto"  
#> [1] "lineto"  "bezierto" "moveto"
pdfium_segment_type_code(c("moveto", "lineto", "bezierto"))
#> [1] 2 0 1
#> [1] 2 0 1
```

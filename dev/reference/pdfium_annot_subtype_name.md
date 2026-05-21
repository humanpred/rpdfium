# PDF annotation subtype codes \<-\> names

PDFium reports the annotation subtype as an integer code in the
`FPDF_ANNOT_*` enum (0 = unknown, 1 = text, 2 = link, ..., 28 = redact).
[`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md)
already surfaces both `subtype` (name) and `subtype_code` (integer).
These helpers expose the name\<-\>code mapping as a standalone
vectorized conversion.

## Usage

``` r
pdfium_annot_subtype_name(codes)

pdfium_annot_subtype_code(names)
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

Names are case-insensitive on input; unknown names map to 0 (`unknown`).
Out-of-range codes map to `"unknown"`.

## See also

[`pdf_annotations()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annotations.md),
[`pdf_annot_subtype()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_subtype.md),
[`pdf_annot_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_new.md).

## Examples

``` r
pdfium_annot_subtype_name(c(1L, 2L, 9L))
#> [1] "text"      "link"      "highlight"
#> [1] "text" "link" "highlight"
pdfium_annot_subtype_code(c("text", "Link", "fileattachment"))
#> [1]  1  2 17
#> [1]  1  2 17
```

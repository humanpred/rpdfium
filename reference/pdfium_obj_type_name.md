# PDF page-object type codes \<-\> names

PDFium reports the type of each page object as an integer code (0 =
unknown, 1 = text, 2 = path, 3 = image, 4 = shading, 5 = form XObject).
[`pdf_obj_type()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_type.md)
returns the name; this helper exposes the symmetric direction.

## Usage

``` r
pdfium_obj_type_name(codes)

pdfium_obj_type_code(names)
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

[`pdf_obj_type()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_type.md),
[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md).

## Examples

``` r
pdfium_obj_type_name(c(1L, 2L, 3L))
#> [1] "text"  "path"  "image"
#> [1] "text" "path" "image"
pdfium_obj_type_code(c("text", "Image", "form"))
#> [1] 1 3 5
#> [1] 1 3 5
```

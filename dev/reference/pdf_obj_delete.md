# Remove a page object and destroy it

Wraps `FPDFPage_RemoveObject` + `FPDFPageObj_Destroy`. After the call:

## Usage

``` r
pdf_obj_delete(obj)
```

## Arguments

- obj:

  A `pdfium_obj` from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
  or one of the creators
  ([`pdf_path_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_new.md)
  /
  [`pdf_rect_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_rect_new.md)
  /
  [`pdf_text_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_new.md)).
  Parent doc must be readwrite.

## Value

Invisibly returns the parent `pdfium_doc`.

## Details

- The object is gone from the page's content stream.

- The C++ object is destroyed.

- The R `pdfium_obj` handle's externalptr is cleared so calling any
  other `pdf_obj_*` / `pdf_path_*` / `pdf_text_*` function on it errors
  cleanly via the existing closed-handle path.

Re-fetch via
[`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
if you need an updated obj list after deletions (the page-scoped indices
shift).

## See also

[`pdf_path_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_new.md),
[`pdf_rect_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_rect_new.md),
[`pdf_text_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_text_new.md).

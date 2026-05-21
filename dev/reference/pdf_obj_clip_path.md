# Get the clip path attached to a page object

A PDF clip path defines the geometric region inside which a page object
is allowed to draw. Wraps `FPDFPageObj_GetClipPath`. Most page objects
have no clip path; this function returns `NULL` for those.

## Usage

``` r
pdf_obj_clip_path(obj)
```

## Arguments

- obj:

  A `pdfium_obj` (from
  [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_objects.md)
  or
  [`pdf_form_objects()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_objects.md)).

## Value

A `pdfium_clip_path` object, or `NULL` when `obj` has no clip path or
only an empty one.

## Details

PDFium returns a non-NULL clip handle even for objects whose clip is
"empty" (the underlying `CPDF_ClipPath` exists but has no sub-paths
attached). This wrapper normalizes that case to `NULL` so callers only
see clip-path objects with at least one real sub-path.

## See also

[`pdf_clip_path_count()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_clip_path_count.md),
[`pdf_clip_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_clip_path_segments.md).

## Examples

``` r
fixture <- system.file("extdata", "fixtures", "clip.pdf",
  package = "pdfium"
)
if (nzchar(fixture)) {
  doc <- pdf_doc_open(fixture)
  page <- pdf_page_load(doc, 1L)
  objs <- pdf_page_objects(page)
  clipped <- Filter(function(o) !is.null(pdf_obj_clip_path(o)), objs)
  length(clipped)
  pdf_page_close(page)
  pdf_doc_close(doc)
}
```

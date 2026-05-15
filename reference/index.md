# Package index

## Documents

- [`pdf_open()`](https://humanpred.github.io/rpdfium/reference/pdf_open.md)
  : Open a PDF document
- [`pdf_close()`](https://humanpred.github.io/rpdfium/reference/pdf_close.md)
  : Close a PDF document
- [`pdf_page_count()`](https://humanpred.github.io/rpdfium/reference/pdf_page_count.md)
  : Count pages in a PDF document

## Pages

- [`pdf_load_page()`](https://humanpred.github.io/rpdfium/reference/pdf_load_page.md)
  : Load a single page from an open PDF document
- [`pdf_close_page()`](https://humanpred.github.io/rpdfium/reference/pdf_close_page.md)
  : Close a page handle
- [`pdf_page_size()`](https://humanpred.github.io/rpdfium/reference/pdf_page_size.md)
  : Page dimensions in PDF points
- [`pdf_page_rotation()`](https://humanpred.github.io/rpdfium/reference/pdf_page_rotation.md)
  : Page rotation in degrees

## Page objects

- [`pdf_page_objects()`](https://humanpred.github.io/rpdfium/reference/pdf_page_objects.md)
  : Enumerate the objects on a page
- [`pdf_obj_type()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_type.md)
  : Report the type of a page object
- [`pdf_obj_bounds()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_bounds.md)
  : Axis-aligned bounding box of a page object
- [`pdf_obj_matrix()`](https://humanpred.github.io/rpdfium/reference/pdf_obj_matrix.md)
  : Transformation matrix of a page object

## Paths

- [`pdf_path_segments()`](https://humanpred.github.io/rpdfium/reference/pdf_path_segments.md)
  : Path segments of a path page-object
- [`pdf_path_stroke()`](https://humanpred.github.io/rpdfium/reference/pdf_path_stroke.md)
  : Stroke style of a path page-object
- [`pdf_path_fill()`](https://humanpred.github.io/rpdfium/reference/pdf_path_fill.md)
  : Fill color of a path page-object
- [`pdf_path_dash()`](https://humanpred.github.io/rpdfium/reference/pdf_path_dash.md)
  : Dash pattern of a path page-object

## Text

- [`pdf_text_font_size()`](https://humanpred.github.io/rpdfium/reference/pdf_text_font_size.md)
  : Font size of a text page-object

## One-call extraction

- [`pdf_extract_paths()`](https://humanpred.github.io/rpdfium/reference/pdf_extract_paths.md)
  : Extract all path geometry on a page into a single tibble

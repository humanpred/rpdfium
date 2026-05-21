# Mutating PDFs

This vignette walks through the v0.1.0 mutation surface. Everything here
is opt-in: you have to either open a document with `readwrite = TRUE`,
or build one with
[`pdf_doc_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_new.md).
Setters check the readwrite flag and raise a clean error otherwise, so
accidental mutations on an inspection-only doc fail loudly.

``` r

library(pdfium)
```

## The common pattern

``` r

doc <- pdf_doc_open("report.pdf", readwrite = TRUE)
on.exit(pdf_doc_close(doc), add = TRUE)

# ... mutate ...

pdf_save(doc, "report-modified.pdf")
```

[`pdf_save()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_save.md)
triggers `FPDFPage_GenerateContent()` on every page that’s been touched
by a setter, so the content stream you serialise reflects the changes.
`pdf_save_to_raw(doc)` writes to a `raw` vector instead of a file.

## Structural mutation

Move, rotate, resize, add, remove, and merge pages.

``` r

# Rotate the first page 90 degrees clockwise.
pdf_page_set_rotation(doc, page_num = 1, rotation = 90)

# Set the crop box on page 2.
pdf_page_set_box(doc, page_num = 2,
                 box = "crop", bounds = c(36, 36, 576, 756))

# Reorder pages: move page 3 to position 1.
pdf_pages_reorder(doc, new_order = c(3, 1, 2, 4:pdf_page_count(doc)))

# Append a blank letter-size page.
pdf_page_new(doc, width = 612, height = 792)

# Merge another document's pages 1-5 onto the end.
other <- pdf_doc_open("appendix.pdf")
pdf_docs_merge(doc, other, source_pages = 1:5)
pdf_doc_close(other)

# 2-up imposition: print 4 logical pages onto each physical sheet.
pdf_n_up(doc, n_up = c(2, 2), output_size = c(612, 792))

# Tag the document's language for accessibility tooling.
pdf_doc_set_language(doc, "en-US")
```

## Building a page from scratch

[`pdf_doc_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_new.md)
returns an empty writable document. Combine it with
[`pdf_page_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_new.md)
and the page-object creators to draw programmatic PDFs.

``` r

doc <- pdf_doc_new()
page <- pdf_page_new(doc, width = 612, height = 792)

# A red filled rectangle.
rect <- pdf_rect_new(page, bounds = c(50, 600, 250, 700))
pdf_path_set_fill(rect, color = c(220, 50, 47))
pdf_path_set_draw_mode(rect, draw_mode = "fill")

# A text object on top.
txt <- pdf_text_new(page, font = "Helvetica-Bold", size = 18)
pdf_text_set_content(txt, "Hello pdfium!")
pdf_obj_set_matrix(txt, matrix(c(1, 0, 0, 0, 1, 0, 80, 640, 1),
                               nrow = 3, byrow = TRUE))

pdf_save(doc, "hello.pdf")
```

[`pdf_path_new()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_new.md)
makes an empty path you grow with
[`pdf_path_move_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_move_to.md)
/
[`pdf_path_line_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_line_to.md)
/
[`pdf_path_bezier_to()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_bezier_to.md)
/
[`pdf_path_close()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_close.md).
[`pdf_path_append()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_append.md)
lets you pour a whole data-frame of segments (matching the schema of
[`pdf_path_segments()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_path_segments.md))
into a path in one call — useful for echoing geometry from one document
into another.

## Styling an existing object

The setters mirror the readers one-for-one:

``` r

page <- pdf_page_load(doc, 1)
objs <- pdf_page_objects(page)

# Find the first path object.
i <- match(TRUE, vapply(objs, pdf_obj_type, "") == "path")
path <- objs[[i]]

# Make it dashed and turquoise.
pdf_path_set_dash(path, dash_array = c(4, 2), dash_phase = 0)
pdf_path_set_stroke(path, color = c(0, 200, 200))
```

Most styling setters are **composite**: they accept either a full
replacement (`color = c(r, g, b)` or `c(r, g, b, a)`) or a partial
overlay (individual `red` / `green` / `blue` / `alpha` arguments).
Integer 0-255 and double 0-1 colors are auto-detected. See
[`?pdf_obj_set_blend_mode`](https://humanpred.github.io/rpdfium/dev/reference/pdf_obj_set_blend_mode.md)
for the full list of styling setters.

## Annotation authoring

``` r

# Add a yellow highlight to page 1 covering a quad.
hl <- pdf_annot_new(page, subtype = "highlight",
                    bounds = c(100, 700, 400, 720))
pdf_annot_set_color(hl, color = c(255, 240, 0))
pdf_annot_set_contents(hl, "Important")
pdf_annot_append_quad(hl, quad = c(100, 700, 400, 700,
                                    100, 720, 400, 720))
```

The supported subtypes are listed in
[`?pdf_annot_new`](https://humanpred.github.io/rpdfium/dev/reference/pdf_annot_new.md).
Delete an annotation with `pdf_annot_delete(annot)`; the handle is
invalidated on the spot, so subsequent reads through it raise a clean
error.

## Form filling

[`pdf_form_field_set_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_set_value.md)
is polymorphic — it dispatches by the field’s type.

``` r

fields <- pdf_form_fields(doc)
by_name <- setNames(fields,
                    vapply(fields, pdf_form_field_name, ""))

# Text field: character scalar.
pdf_form_field_set_value(by_name[["full_name"]], "Ada Lovelace")

# Checkbox: logical, or the literal export-value string.
pdf_form_field_set_value(by_name[["subscribe"]], TRUE)
pdf_form_field_set_value(by_name[["over_18"]], "Yes")

# Combobox / listbox: must match one of the field's options.
pdf_form_field_set_value(by_name[["country"]], "United Kingdom")
```

To wipe a single field back to its default value, use
[`pdf_form_field_clear()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_clear.md).
To reset every field in the document, `pdf_form_reset(doc)`.

When you’re ready to ship a non-editable PDF,
[`pdf_page_flatten()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_page_flatten.md)
bakes the widget appearances and any other annotations into the page’s
content stream. **It’s irreversible** — there is no
`pdf_page_unflatten()`. Run it as the last step before saving the
final-state PDF.

## Embedded file attachments

``` r

# Add a CSV attachment to the document.
att <- pdf_attachment_new(doc, name = "data.csv")
csv_bytes <- charToRaw("a,b,c\n1,2,3\n")
pdf_attachment_set_data(att, csv_bytes)
pdf_attachment_set_dict_value(att, "Desc",
                              "Source data for the figures above")
```

Note the ordering:
[`pdf_attachment_set_data()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_data.md)
first (it creates `/Params` on the embedded file stream as a side
effect), then any
[`pdf_attachment_set_dict_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_set_dict_value.md)
calls.

## What’s *not* in v0.1.0

A few writable surfaces are documented as upstream gaps awaiting a
PDFium patch:

- **Choice-field `/Opt` arrays.**
  [`pdf_form_field_set_value()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_form_field_set_value.md)
  validates against the existing options, but PDFium has no public API
  to grow the option list. See
  `dev/upstream-patches/pdfium-FPDFAnnot_AppendOption.patch`.
- **The file-stream `/Subtype` on attachments.** The MIME type surfaced
  by
  [`pdf_attachment_mime_type()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_attachment_mime_type.md)
  lives on the embedded file stream itself, not on `/Params`; PDFium has
  no setter for it.
- **Document-info dict (`/Info`) writes** — title, author, subject. The
  reader
  ([`pdf_doc_info()`](https://humanpred.github.io/rpdfium/dev/reference/pdf_doc_info.md))
  exists but the writer requires an upstream `FPDF_SetMetaText` that
  doesn’t ship yet.

See `dev/upstream-patches/` in the source tree for the full set of
upstream patches we maintain.

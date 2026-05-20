# ADR-016 — Page-object creation scope

- Status: Accepted
- Date: 2026-05-19
- Deciders: Bill Denney

## Context

The original v0.2.0 plan explicitly marked page-object authoring
(`FPDFPageObj_CreateNewPath`, `_NewTextObj`, `_NewImageObj`) as a
non-goal, deferring to `grDevices::cairo_pdf` or
`ggplot2 + ggsave` for users who want to author whole PDFs. With
the full v0.2.0 surface folding into v0.1.0, the question is
whether to include page-object creation too.

The case for including it:

- Every reader of page objects (`pdf_page_objects`,
  `pdf_path_segments`, `pdf_text_runs`, `pdf_image_info`,
  `pdf_obj_matrix`, etc.) has a natural writer mirror.
- Without creation, the package can modify but cannot
  *construct*. That asymmetry is awkward for users who want to add
  one box to an existing page; the workaround (export to PNG,
  paste back via image-obj-set-bitmap) is worse.
- The C ABI for creation is a small, well-defined set: ~10
  functions across paths / text / images / rects.

The case against:

- Drawing PDFs programmatically is genuinely better served by
  `cairo_pdf`'s graphics API. We are not competing with that.
- Font management is its own subsystem (`FPDFText_LoadFont`,
  `FPDFText_LoadStandardFont`, CID fonts, ToUnicode CMaps) and
  carries non-trivial implementation cost.

## Decision

Include page-object creation in v0.1.0:

| R function | PDFium symbol |
|---|---|
| `pdf_obj_new_path(x, y)` | `FPDFPageObj_CreateNewPath` |
| `pdf_obj_new_rect(x, y, w, h)` | `FPDFPageObj_CreateNewRect` |
| `pdf_obj_new_text(doc, font, font_size)` | `FPDFPageObj_NewTextObj` |
| `pdf_obj_new_image(doc)` | `FPDFPageObj_NewImageObj` |
| `pdf_page_insert_object(page, obj, index = NULL)` | `FPDFPage_InsertObject` / `_AtIndex` |
| `pdf_page_remove_object(page, obj)` | `FPDFPage_RemoveObject` |
| `pdf_font_load_standard(doc, name)` | `FPDFText_LoadStandardFont` |
| `pdf_font_load(doc, bytes, type, cid)` | `FPDFText_LoadFont` |
| `pdf_font_close(font)` | `FPDFFont_Close` (typically via finalizer) |
| `pdf_image_set_bitmap(obj, bitmap, page = NULL)` | `FPDFImageObj_SetBitmap` |
| `pdf_image_set_jpeg(obj, path_or_raw, page = NULL, inline = TRUE)` | `FPDFImageObj_LoadJpegFile{Inline}` |

A new S3 class `pdfium_font` wraps `FPDF_FONT` handles. It carries
its own finalizer (`FPDFFont_Close`) and an R-level reference to
the document (so GC ordering keeps the doc alive while any font
handle is reachable).

`pdf_obj_new_text` accepts either a `pdfium_font` (loaded via
`pdf_font_load{_standard}`) or a single string naming one of the
14 standard PDF fonts (in which case we call
`FPDFText_LoadStandardFont` internally and stash the resulting
font on `doc$standard_fonts` as a cache).

## Consequences

- The writer surface is symmetric to the reader: every
  `pdf_*_obj*` reader has a `pdf_*_new_*` creator + a `pdf_*_set_*`
  setter.
- `pdfium_font` becomes a fourth top-level S3 class alongside
  `pdfium_doc`, `pdfium_page`, `pdfium_obj`.
- Standard-font caching on the doc reduces repeat loads but
  requires careful cleanup at `pdf_doc_close()`.
- We still recommend `cairo_pdf` for users authoring whole
  documents from scratch; document this in the vignette. The
  pdfium creation API is the right choice for *incremental*
  additions to existing PDFs.

## Alternatives considered

- **Exclude page-object creation entirely** (original v0.2.0
  position): rejected — leaves the writer surface asymmetric and
  the "add one box to this page" use case unaddressed.
- **Include path + image creation but defer text creation**:
  rejected — font management is the hard part; once we ship paths
  + images we may as well ship text, which uses the same shape.
- **Wrap the cairo R API for "drawing on a PDFium page"**:
  rejected — would tie us to grDevices' graphics state model,
  which doesn't map cleanly to PDFium page objects.

## References

- `dev/mutation-design.md` §2 Phase 5.
- PDFium `fpdf_edit.h` page-object creation symbols.

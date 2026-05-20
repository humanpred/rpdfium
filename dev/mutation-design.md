# pdfium 0.1.0 — Mutation, authoring, and form-filling design

Status: **active**. Supersedes the post-0.1.0 framing in
[`v0.2.0-plan.md`](v0.2.0-plan.md). After review, the decision was made
to fold the entire writer surface into the v0.1.0 CRAN release rather
than deferring it. The architectural and feature content of
`v0.2.0-plan.md` is mostly unchanged; this document captures the
sequencing, ADRs accepted, and integration points with the existing
0.1.0 reader surface.

This file is the single source of truth for *what shipping 0.1.0 with
writers means*. The `v0.2.0-plan.md` file remains in the tree as the
predecessor record; do not edit it.

## 0. Reader / writer correspondence

The 0.1.0 read surface was deliberately designed for write-symmetry:
every tibble that a reader returns is editable as an ordinary R data
frame and handed back to a writer with minimal reshaping. The
companion document [`reader-writer-audit.md`](reader-writer-audit.md)
walks every reader against the writer surface below. The headline:

* **Identity columns.** Every reader emits an `xxx_index` 1-based
  identity column (`annotation_index`, `field_index`, `link_index`,
  `bookmark_index`, `mark_index`, `element_index`,
  `attachment_index`, `obj_index`). The writer counterpart accepts
  the same index plus the implicit doc/page handle to locate the
  object.
* **Native PDF coordinate space.** All geometry is in PDF
  user-space points (`bounds_left`, `bounds_bottom`, `bounds_right`,
  `bounds_top` ordering). Writers consume the same convention; the
  C shim translates to PDFium's `FS_RECTF`.
* **List-columns for variable geometry.** Quad points, vertices,
  ink paths, dash arrays, option labels, marked-content params,
  structure attributes — every variable-length payload is a
  list-column of matrices / vectors / named lists. Writers accept
  the same shape.
* **Codes and names coexist.** Annotation subtype, action type,
  fill mode, line cap / join, render mode, dest view all come back
  as readable strings *and* (where it matters) integer enum codes.
  Writers take either; the bidirectional helpers ship in
  Phase 9 below.
* **Normalized numeric ranges.** Colors are 0..1 doubles, matrices
  are 3x2, opacities are 0..1. PDFium's 0..255 / float32 / `FS_*`
  encodings stay inside the C layer.

For every reader-writer pair the round-trip contract is:

> Read it. Modify a single cell (or list-column element). Hand the
> changed row (or its index + the new value) to the writer.
> `pdf_save()`. Re-open. The modification persists.

The exhaustive mapping table from `v0.2.0-plan.md` §0.1 still
applies; see that document for the row-by-row catalog.

## 1. Architectural decisions (now accepted)

Six ADRs were drafted as "proposed" in the v0.2.0 plan. With the
scope merged into v0.1.0 they become accepted as:

| # | Topic | Outcome |
|---|---|---|
| [ADR-011](decisions/ADR-011-mutation-lifecycle.md) | Mutation lifecycle: explicit `pdf_save()` | open → modify → `pdf_save(doc, file)`; no in-place edit, no side-effect path-string overloads |
| [ADR-012](decisions/ADR-012-readwrite-flag.md) | Read-write flag on `pdfium_doc` | `pdf_doc_open(..., readwrite = FALSE)`; mutators error early on read-only handles |
| [ADR-013](decisions/ADR-013-form-fill-env.md) | Form-fill environment lifetime | Lazy + cached; FFL env spins up on first form mutation, frees at `pdf_doc_close()` |
| [ADR-014](decisions/ADR-014-structural-mutation-set.md) | Structural mutation set | Rotate, delete, reorder, merge, set-box, set-language; defer compress/linearise/encrypt to qpdf |
| [ADR-015](decisions/ADR-015-annotation-authoring.md) | Annotation authoring scope | All FPDF_ANNOT_* subtypes PDFium supports via `FPDFAnnot_IsSupportedSubtype`; `_set_uri`, `_set_*` properties; `_add_ink_stroke` |
| [ADR-016](decisions/ADR-016-page-object-creation.md) | Page-object creation scope | New paths, rects, text, images; insert into pages with `FPDFPage_InsertObject`; the writer pairs every reader |

Atomic save semantics (write to tempfile in destination dir, rename
on success) live inside `pdf_save()` itself rather than a separate
ADR; documented in the function reference.

## 2. Layering (10 phases)

The writer surface is built up in ten phases. Each phase is one or
more commits on the working branch and lands its own tests.

| Phase | Scope | Key R functions | Key PDFium symbols |
|---|---|---|---|
| 1 | **Foundation** | `pdf_doc_open(..., readwrite=)`, `pdf_save()`, `pdf_save_to_raw()`, `pdf_new_doc()`, `assert_readwrite()` (internal) | `FPDF_SaveAsCopy`, `FPDF_FILEWRITE`, `FPDF_CreateNewDocument` |
| 2 | **Structural mutation** | `pdf_set_page_rotation`, `pdf_delete_page`, `pdf_reorder_pages`, `pdf_docs_merge`, `pdf_set_page_box`, `pdf_set_doc_language`, `pdf_new_page` | `FPDFPage_SetRotation`, `_Delete`, `FPDF_MovePages`, `FPDF_ImportPagesByIndex`, `FPDFPage_Set*Box`, `FPDFCatalog_SetLanguage`, `FPDFPage_New` |
| 3 | **Page-obj styling setters** | `pdf_obj_set_matrix/_active/_blend_mode/_transform`; `pdf_path_set_stroke_*/_fill_*/_line_*/_dash/_draw_mode`; `pdf_text_set/_set_font_size/_set_render_mode`; `pdf_obj_add_mark/_remove_mark/_set_mark_param_*` | `FPDFPageObj_Set*`, `FPDFPath_SetDrawMode`, `FPDFText_SetText`, `FPDFTextObj_Set*`, `FPDFPageObj_AddMark`, `FPDFPageObjMark_Set*Param` |
| 4 | **Path geometry rebuild** | `pdf_path_new`, `pdf_path_replace`, `pdf_path_close_subpath` | `FPDFPath_MoveTo/_LineTo/_BezierTo/_Close` |
| 5 | **Page-obj creation** | `pdf_obj_new_path/_new_rect/_new_text/_new_image`; `pdf_page_insert_object/_remove_object`; `pdf_font_load_standard/_load`; `pdf_image_set_bitmap/_set_jpeg` | `FPDFPageObj_CreateNewPath`, `_CreateNewRect`, `_NewTextObj`, `_NewImageObj`, `FPDFPage_InsertObject`, `FPDFText_LoadStandardFont`, `FPDFText_LoadFont`, `FPDFImageObj_SetBitmap`, `FPDFImageObj_LoadJpegFile` |
| 6 | **Annotation authoring** | `pdf_annot_new/_remove/_update_object`; setters for rect, contents, title, subject, color, interior_color, flags, border, font_color, font_size, quad_points, vertices, ink_paths, uri, AP; `pdf_annot_set_string_value` generic; `pdf_annot_add_ink_stroke/_remove_ink_list`; `pdf_annot_append_object` | `FPDFPage_CreateAnnot`, `FPDFPage_RemoveAnnot`, `FPDFAnnot_Set*`, `_AddInkStroke`, `_RemoveInkList`, `_SetURI`, `_SetAP`, `_AppendObject` |
| 7 | **Form filling** | `pdf_form_set_value`, `_set_checked`, `_clear`, `_flatten`, `_set_options_selected`, `_set_flags` | `FPDFDOC_InitFormFillEnvironment`, `_ExitFormFillEnvironment`, `FPDFAnnot_SetStringValue`, `_SetFormFieldFlags`, `FORM_SetIndexSelected`, `FORM_Reset`, `FPDFPage_Flatten` |
| 8 | **Attachment authoring** | `pdf_attachment_new`, `_delete`, `_set_file`, `_set_string_value` | `FPDFDoc_AddAttachment`, `_DeleteAttachment`, `FPDFAttachment_SetFile`, `_SetStringValue` |
| 9 | **Bidirectional enum helpers** | `pdfium_annot_subtype_code`, `pdfium_action_type_code`, `pdfium_dest_view_code`, `pdfium_line_cap_code`, `pdfium_line_join_code`, `pdfium_fill_mode_code`, `pdfium_render_mode_code`, `pdfium_field_flag_encode`, `pdfium_annot_flag_encode`, `pdf_format_date` | Pure-R inverse lookups of the existing reader-side `_name()` helpers |
| 10 | **Polish** | `vignettes/mutating-pdfs.Rmd`, NEWS.md, round-trip integration tests, coverage to 100%, lint clean, pkgdown reference index | n/a |

Each phase has its own tests under `tests/testthat/test-mut-<phase>-*.R`.

## 3. Save semantics

`pdf_save(doc, file, ...)` writes via `FPDF_SaveAsCopy` with these
flags exposed:

* `incremental = FALSE` (default) — pass `FPDF_NO_INCREMENTAL`. Most
  useful for users who want a clean re-serialised PDF.
* `incremental = TRUE` — pass `FPDF_INCREMENTAL`. Appends an
  incremental update; preserves original byte layout. Required for
  signing workflows.
* `remove_security = FALSE` (default) — never strips an encryption
  dictionary unless the caller explicitly asks for it.
* `subset_new_fonts = TRUE` (default) — passes
  `FPDF_SUBSET_NEW_FONTS`. Subsets newly-embedded fonts; matches the
  default Acrobat does.

Atomic write:

1. Resolve `file` to its absolute path; its directory is `dest_dir`.
2. Create a tempfile in `dest_dir` (so `file.rename` is atomic on
   the same filesystem).
3. Write PDFium's bytes via the `FPDF_FILEWRITE` callback into a
   `std::ofstream` opened against the tempfile.
4. On success, `file.rename(temp, file)`. On any failure
   (PDFium returns 0, the stream raises, etc.), `file.remove(temp)`
   and raise. The destination file is never partially overwritten.

`pdf_save_to_raw(doc, ...)` is the same path with the callback
appending to a `std::vector<uint8_t>` instead of a file. Returns a
`raw` vector. No atomic-write concern; useful for piping into
`httr2::req_body_raw()` etc.

`FPDF_SaveWithVersion(doc, ..., file_version)` is exposed via a
`version = NULL` (default = preserve input version) argument to
`pdf_save()`.

## 4. readwrite flag

`pdf_doc_open(path, source = NULL, password = NULL, readwrite = FALSE)`.

The flag lives on the `pdfium_doc` S3 object as `doc$readwrite`
(logical scalar). Every mutator calls `assert_readwrite(doc)` —
an internal helper in `R/utils.R`:

```r
assert_readwrite <- function(doc) {
  if (!isTRUE(doc$readwrite)) {
    stop(
      "Document opened read-only; reopen with `pdf_doc_open(..., readwrite = TRUE)`.",
      call. = FALSE
    )
  }
  invisible(doc)
}
```

PDFium itself has no read/write flag — every loaded `FPDF_DOCUMENT`
is mutable. The R-side flag is the package's hedge against
accidental edits.

`pdf_new_doc()` returns a `pdfium_doc` with `readwrite = TRUE`
unconditionally (you can't usefully create a doc you can't write).

## 5. Form-fill environment lifetime

`FPDFDOC_InitFormFillEnvironment(doc, &form_fill_info)` returns an
`FPDF_FORMHANDLE` that must be released via
`FPDFDOC_ExitFormFillEnvironment` before document close. The R
wrapper stores the handle in `doc$ffl_env` (an externalptr), spun
up lazily on first form mutation:

```r
ensure_ffl_env <- function(doc) {
  if (is.null(doc$ffl_env)) {
    doc$ffl_env <- cpp_form_fill_env_init(doc$ptr)
  }
  doc$ffl_env
}
```

The form-fill env has its own R-level finalizer that calls
`FPDFDOC_ExitFormFillEnvironment` on GC. `pdf_doc_close()` runs the
finalizer eagerly so the lifecycle order is correct (form-fill env
must die before the doc).

## 6. Test fixtures

Existing fixtures + four new ones (built by `tools/build-fixtures.R`):

* `mut_blank.pdf` — single empty page, suitable as a creation
  target for `pdf_new_page()`, `pdf_obj_new_*()` round-trips.
* `mut_form.pdf` — three-field AcroForm (text, checkbox, choice)
  for form-fill round-trips.
* `mut_merge_a.pdf` / `mut_merge_b.pdf` — two-page visually-distinct
  inputs for `pdf_docs_merge()` and `pdf_reorder_pages()`.
* `mut_annot.pdf` — page with one each of FreeText, Highlight, and
  Ink annotations, for `pdf_annot_set_*()` round-trips.

## 7. Sequencing & PR plan

Phases 1–10 above. Each phase is its own commit (or small batch of
commits) on the current branch `claude/0.1.0-read-completion`. The
branch lands after Phase 10 polish.

Phase 1 (foundation) blocks every other phase. Phases 2–8 are
parallelisable in principle but each shares `R/RcppExports.R` and
`src/RcppExports.cpp`, so we serialise them to avoid merge conflicts
(see "Stack PRs or serialize them" guidance in CLAUDE.md memory).

## 8. Risks

These are the same risks called out in `v0.2.0-plan.md` §7,
unchanged by the merge:

1. **`FPDF_ImportPagesByIndex` lifetime**: closing the source before
   the destination may leave dangling pointers. Test for it
   explicitly in `pdf_docs_merge()`'s round-trip.
2. **Annotation appearance-stream regeneration**: `FPDFAnnot_SetAP`
   semantics. Investigate per-subtype.
3. **`/Vertices` and `/InkList` setters**: PDFium has
   `FPDFAnnot_AddInkStroke` and `_RemoveInkList` but no public
   vertex-setter. Document the gap; `pdf_annot_set_vertices()` may
   require dict-level access.
4. **Atomic save on Windows**: `file.rename()` is atomic on the
   same volume only. The tempfile-in-dest-dir convention guarantees
   that.
5. **`FPDFPage_GenerateContent`**: must be called before save to
   persist most edits. `pdf_save()` calls it on every modified
   page (tracked via an R-side "dirty pages" set on `pdfium_doc`).
6. **XFA forms**: out of scope. PDFium's XFA support is build-time
   conditional; we don't expose it.

## 9. Out-of-scope (kept deferred even with full v0.2.0 surface in 0.1.0)

* Digital-signature creation (PKCS#7 signing). Better as a
  companion package `pdfium.signatures` that links OpenSSL.
* JavaScript / form-action mutation. Niche, deep, and a research
  problem.
* Tagged-PDF authoring (`/StructTreeRoot` mutation). Read in 0.1.0,
  write requires raw dict access PDFium doesn't expose.
* Bookmark mutation. PDFium has no public outline mutators;
  `pdf_bookmarks_replace(doc, df)` deferred to v0.2.0.
* Streaming open (`FPDFAvail_*`). Local-file workflow only.

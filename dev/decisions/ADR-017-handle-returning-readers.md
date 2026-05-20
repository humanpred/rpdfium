# ADR-017 — Handle-returning readers + tibble round-trip

- Status: Accepted
- Date: 2026-05-20
- Deciders: Bill Denney

## Context

The v0.1.0 reader surface is split across two return shapes:

- `pdf_page_objects(page)` returns a **list of `pdfium_obj`** handles.
  Per-attribute readers (`pdf_obj_type`, `pdf_obj_bounds`,
  `pdf_path_segments`, …) take the handle and read one fact about it.
- Everything else (`pdf_annotations`, `pdf_form_fields`,
  `pdf_attachments`, `pdf_signatures`, `pdf_bookmarks`,
  `pdf_text_runs`, `pdf_text_chars`, `pdf_page_links`, …) returns a
  **tibble** with one row per item.

The asymmetry is inherited from how the readers landed. With the
writer surface entering scope in 0.1.0, the asymmetry becomes a
visible irritant: page-object writers take handles (mirroring the
reader); annotation writers would either take indices (mirroring
the reader) or invent a new handle type.

We have no users yet — the API can still be reshaped without a
back-compat break — so this is the moment to harmonize.

## Decision

Every PDFium-handle-backed reader returns a **list of S3 handles**.
Tibble shape is available via `as_tibble()` and the round-trip back
to handles is `as_pdfium_<class>()`:

| Reader (after refactor) | Returns | New S3 class | Lifetime |
|---|---|---|---|
| `pdf_page_objects(page)` | `list` of `pdfium_obj` (unchanged) | `pdfium_obj` | Borrows page |
| `pdf_annotations(page)` | `list` of `pdfium_annot` | `pdfium_annot` | Per-handle finalizer (`FPDFPage_CloseAnnot`); page pinned via prot slot |
| `pdf_form_fields(doc)` | `list` of `pdfium_form_field` | `pdfium_form_field` (IS-A `pdfium_annot` of subtype widget) | Per-handle finalizer |
| `pdf_attachments(doc)` | `list` of `pdfium_attachment` | `pdfium_attachment` | Borrows doc |
| `pdf_signatures(doc)` | `list` of `pdfium_signature` | `pdfium_signature` | Borrows doc |
| `pdf_bookmarks(doc)` | `list` of `pdfium_bookmark` | `pdfium_bookmark` | Borrows doc |

Each list of handles can be flattened via
`tibble::as_tibble(x)` (an S3 method on the list type). The
resulting tibble carries **both** of these list-columns:

- `handle` — the original `pdfium_<class>` handle for each row.
  Preserves R-object identity across round-trip.
- `source` — the parent (`pdfium_page` or `pdfium_doc`) for each
  row. Useful for `group_by(source)` and as a sanity check on
  `as_pdfium_<class>(tbl)`.

`as_pdfium_<class>(x)` is the reverse:

- If `x` is already a list of `pdfium_<class>`, it is a no-op (with
  validation).
- If `x` is a tibble with a `handle` column, return `x$handle`.
- Otherwise error with a clear message.

The page-object readers (`pdf_text_runs`, `pdf_text_chars`,
`pdf_page_links`) and document-property readers (`pdf_doc_info`,
`pdf_doc_meta`, `pdf_signatures_byte_range`) remain tibble / list
returning — they don't wrap PDFium *handles*, they project
PDFium properties.

## Consequences

- Five readers change their default return shape. Existing test
  suites that asserted `tibble::is_tibble(pdf_annotations(...))` need
  updating to call `as_tibble()` first or to inspect the new handle
  list instead. We have no users yet, so this is acceptable.
- Five new S3 classes ship with this commit. Each has:
  - A constructor `new_pdfium_<class>(ptr, parent, [index])`.
  - A `format` / `print` method.
  - Per-attribute getters mirroring the previous tibble columns.
  - An `as_tibble.<class>_list` method (we wrap the returned list
    in a thin `pdfium_<class>_list` class so the S3 dispatch
    target is clean).
- The reader refactor lands **before** any new writer code so the
  setters in Phases 3–9 can assume the new shape.
- Existing exports `pdf_annotations()`, `pdf_form_fields()`, etc.,
  retain their names but change return type.
- Defensive validation: every C++ shim that takes a handle's
  `externalptr` checks for NULL and raises a clean R-level error.
  `tests/testthat/test-defensive.R` exercises malformed inputs.

## Alternatives considered

- **Keep readers tibble-shape; introduce handle constructors as
  separate helpers**: rejected — leaves the inconsistency between
  `pdf_page_objects` (list of handles) and `pdf_annotations` (tibble)
  in place. The whole point of this ADR is to remove that
  inconsistency.
- **Staged refactor (one reader per writer phase)**: rejected — adds
  temporary inconsistency that's worse than the existing kind.
- **Refactor to handles only; no tibble companion**: rejected —
  data-frame inspection is the most common use case; forcing
  `purrr::map` on every interactive read would be a regression.

## References

- `dev/mutation-design.md` §2.5 (the inserted refactor phase).
- ADR-005 (memory model).
- ADR-015 (annotation authoring scope) — depends on the
  `pdfium_annot` class.

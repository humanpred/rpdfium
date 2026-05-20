# ADR-020 — Handle-design follow-ups

- Status: Accepted
- Date: 2026-05-21
- Deciders: Bill Denney

## Context

After landing ADR-017 (handle-returning readers) and the first two
slices (annotations, form fields), a Q&A pass formalised the
remaining design decisions that affect every subsequent reader
refactor and every writer phase. This ADR captures those
decisions so future contributors don't relitigate them.

## Decisions

### 1. Bookmark shape: flat list of handles

`pdf_doc_bookmarks(doc)` returns `pdfium_bookmark_list` in
pre-order traversal. The tree is recoverable from each handle's
`parent_index` slot (and the `parent_index` column on
`as_tibble`). No nested-tree return type. Symmetric with annot /
form_field / attachment / signature.

### 2. Per-handle getter coverage: every column

Every tibble column in `as_tibble(<list>)` has a matching
per-handle getter (`pdf_<class>_<attr>(handle)`). This pairs
naturally with the writer surface (every reader has a setter
twin) and means callers who hold a single handle never have to
fall back to building a tibble.

Concretely, the surface grows by ~50 small functions across the
five handle classes (annot already has 13; form_field needs ~17,
attachment ~4, signature ~6, bookmark ~10).

### 3. Lookup functions return handles, not indices

`pdf_doc_bookmark_find(doc, title)` returns a `pdfium_bookmark`
(or NULL on miss). `pdf_link_annot_at_point(doc, x, y)` returns a
`pdfium_annot` (or NULL). `pdf_form_field_at_point(doc, x, y)`
returns a `pdfium_form_field` (or NULL).

The previous integer-index returns are dropped; pre-0.1.0 there
are no users to break.

### 4. Defensive C-side validation at every shim entry

Task #38: every `cpp_*` Rcpp shim's first line validates the
incoming externalptr (typeof == EXTPTRSXP, address != NULL). On
miss, clean R-level error. No crashes ever, even with malformed
or post-close input. Lands as a dedicated commit + test pass
(`tests/testthat/test-defensive.R`) before Phase 6 (where
mutators add new shim surface).

### 5. `pdf_page_objects()` symmetry with the new wrapper class

Retrofit `pdf_page_objects(page)` to return `pdfium_obj_list`
(was: plain list). Adds `as_tibble.pdfium_obj_list` and
`as_pdfium_obj_list`. The 2-3 existing tests that check
`is.list(pdf_page_objects(...))` still pass (list-of-handles IS a
list).

### 6. No tibble caching on `*_list` objects

Each `as_tibble(list)` re-runs the underlying bulk reader. Always
fresh; no invalidation surface to maintain. Acceptable for the
typical read workflow; mutation-heavy workflows pay the re-read
cost.

### 7. AP regeneration on every render

`pdf_render_*()` walks **every annotation** on the page after the
page-content flush and forces each AP stream to regenerate
(`FPDFAnnot_SetRect` to the annotation's current rect — a no-op
for the rect value itself but flips PDFium's AP-dirty flag so the
next render rebuilds the stream from the live dict).

The original draft proposed walking a dirty-set instead of every
annot; reviewer pushback flagged the dirty-tracking layer as a
correctness hazard (any new mutator path has to remember to mark
its annot, and missed marks degrade silently — the render still
succeeds but with stale AP). Walking every annot is structurally
correct: no missed-mutator class of bug, no extra state.

Cost: one `FPDFPage_GetAnnot` + `GetRect` + `SetRect` +
`CloseAnnot` per annotation per render. Typical docs (< 100
annots/page) see sub-millisecond overhead, dwarfed by
rasterization. Pages with zero annotations short-circuit at the
count check.

Guarantee: any render reflects every mutator that ran before it,
even when consumed by downstream tools (Acrobat, MuPDF) that
cache /AP and don't reconcile.

### 8. CRAN release timing: after all phases

Cut 0.1.0 only after every phase (2.5c, 2.5d, 2.5e, 3, 4, 5, 6,
7, 8, 9, 10) lands AND the full-API gap audit (task #47)
confirms no non-deprecated PDFium symbol is missed without an
explicit out-of-scope reason. Estimated 4-6 more sessions.

### 9. Vignette scope: one umbrella + one comparison

`vignettes/mutating-pdfs.Rmd` covers save / structural / annot
authoring / form filling / page-obj creation in one document.
`vignettes/comparison.Rmd` shows pdftools / qpdf / magick /
tabulizer / staplr use cases reimplemented in `pdfium`; code
chunks use `eval = FALSE` so no new Suggests entries.

### 10. Branch / PR strategy: one branch per phase, stacked

Each phase gets its own branch (`claude/0.1.0-phase-N`) stacked
on the previous one. Wall-clock minimized (parallel branch
preparation); review remains per-phase. Rework cost when an
earlier branch needs amendments is accepted.

### 11. API breakage policy

Pre-0.1.0: zero back-compat constraint; rename freely.

Post-0.1.0 (after CRAN): every removal or rename ships a deprecated
shim that calls the new function and warns once per session.
Removal of the shim itself happens at the next major version
(0.2.0, 1.0, etc.) per standard CRAN deprecation cadence.

Post-1.0: any API break requires its own ADR documenting the
migration path and a deprecation cycle of at least 2 minor
versions.

### 12. Inverse-helper batch (Phase 9)

The ten name->code inverse-lookup helpers
(`pdfium_annot_subtype_code`, `pdfium_action_type_code`,
`pdfium_dest_view_code`, `pdfium_line_cap_code`,
`pdfium_line_join_code`, `pdfium_fill_mode_code`,
`pdfium_render_mode_code`, `pdfium_field_flag_encode`,
`pdfium_annot_flag_encode`, `pdf_format_date`) land in one
dedicated commit at the end of Phase 2.5, before Phase 3
(writers) starts. Phase 3+ can assume them.

### 13. Continuous API gap audit

Task #47 runs at the end of each writer phase (Phase 3
onwards). Produces `dev/coverage-gap.md` listing every PDFium
symbol with status (`surfaced`, `deferred`, `deprecated`,
`out-of-scope`). Gaps are surfaced as user questions before the
next phase begins so the user can decide surface-or-defer
explicitly.

## Consequences

- The five handle-returning readers (annot done, form_field done,
  attachment, signature, bookmark pending) share one consistent
  design: list-wrapper, `as_tibble` with handle+source columns,
  reverse converter, per-attribute getters for every column.
- Lookups all return handles uniformly; downstream pipelines
  expect `is.null(result)` or `inherits(result, "pdfium_*")`
  checks, not integer indexes.
- Render paths are slightly slower per call (annot AP refresh
  walk) in exchange for a much stronger consistency guarantee.
- The vignette tally grows from 5 to 7. CRAN reviewers see one
  new feature umbrella + one positioning document.
- The release scope is significantly larger than v0.1.0 was when
  the project started; CRAN gets a 'big initial' release rather
  than incremental 0.1.0 / 0.2.0 / 0.3.0 cycles.

## References

- ADR-017 (handle-returning readers — the base decision).
- ADR-018 (setter conventions).
- ADR-019 (naming conventions).
- `dev/mutation-design.md` (phase roadmap).

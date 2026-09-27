# Architecture Decision Records

This directory records every material design decision in `pdfium` as a
Markdown ADR following the
[MADR template](https://adr.github.io/madr/).

## Index

| # | Status   | Title |
|---|----------|---|
| [001](ADR-001-language-stack.md) | Accepted | Language and framework: R ≥ 4.2 + Rcpp + C++17 + S3 |
| [002](ADR-002-license.md)        | Accepted | License: MIT for the R package, BSD-3-Clause for the bundled PDFium |
| [003](ADR-003-binary-distribution.md) | Accepted (CRAN-submission wording superseded by ADR-026; download-integrity consequence superseded by ADR-027) | Binary distribution: bblanchon pdfium-binaries downloaded at install |
| [004](ADR-004-api-style.md)      | Accepted | API style: snake_case `pdf_*`, S3 classes, tibble outputs |
| [005](ADR-005-memory-model.md)   | Accepted | Memory model: `externalptr` + finalizers + idempotent explicit close |
| [006](ADR-006-pdfium-pin.md)     | Accepted (hash-pinning alternative superseded by ADR-027) | PDFium version pinning policy |
| [007](ADR-007-ci-and-coverage.md) | Accepted | CI: GitHub Actions matrix, 100% R coverage gate, valgrind, ASan |
| [008](ADR-008-cran-targeting.md) | Accepted (release targeting superseded by ADR-026; quality constraints in force) | CRAN-from-v0.1.0 hardening |
| [009](ADR-009-defer-bezier-controls.md) | Superseded by ADR-021 | Defer Bezier control points to a post-0.1.0 release (no public PDFium API) |
| [010](ADR-010-checkmate-for-argument-validation.md) | Accepted | Use `checkmate` for argument validation throughout the package |
| [011](ADR-011-mutation-lifecycle.md) | Accepted | Mutation lifecycle: explicit `pdf_save()` |
| [012](ADR-012-readwrite-flag.md) | Accepted | Read-write flag on `pdfium_doc` (default read-only) |
| [013](ADR-013-form-fill-env.md) | Accepted | Form-fill environment lifetime: lazy + cached |
| [014](ADR-014-structural-mutation-set.md) | Accepted | Structural mutation set: rotate, delete, reorder, merge, set-box, set-language; defer compress/linearise/encrypt to qpdf |
| [015](ADR-015-annotation-authoring.md) | Accepted | Annotation authoring: full writer mirror of the v0.1.0 reader |
| [016](ADR-016-page-object-creation.md) | Accepted | Page-object creation: new paths, rects, text, images; `pdfium_font` S3 class |
| [017](ADR-017-handle-returning-readers.md) | Accepted | Handle-returning readers + `as_tibble()` / `as_pdfium_<class>()` round-trip; tibble carries `handle` + `source` list-columns |
| [018](ADR-018-setter-conventions.md) | Accepted | Setter conventions: object-first naming, polymorphic page arg, composite + named-partial-update setters, 0-255 / 0-1 color auto-detection |
| [019](ADR-019-naming-conventions.md) | Accepted | Naming conventions: accessors are object-first (`pdf_<object>_<attr>`), verbs are verb-first (`pdf_<verb>_<modifier>`); applies to constructors / destructors / accessors / setters across the package |
| [020](ADR-020-handle-design-followups.md) | Accepted (§7 superseded by ADR-022) | Handle-design follow-ups: flat bookmark tree, per-column getters, handle-returning lookups, C-side defensive validation, render AP regen, CRAN timing, branch / PR strategy, API breakage policy, inverse-helper batch, continuous API gap audit |
| [021](ADR-021-bezier-control-points.md) | Supersedes ADR-009 | Bezier control points as `cx1`/`cy1`/`cx2`/`cy2` endpoint-row columns via `FPDFPath_GetBezierControlPoints` (PDFium chromium/8066+) |
| [022](ADR-022-no-annotation-refresh-on-render.md) | Supersedes ADR-020 §7 | Rendering does not touch annotations: drop the `FPDFAnnot_SetRect` "AP refresh" walk |
| [023](ADR-023-annotation-object-ownership.md) | Accepted (decision 3 superseded by ADR-024) | Annotation page-objects: `pdf_annot_append_object()` moves a top-level object off the annotation's page, the annotation finalizer closes the context while its page or document is open, and form-XObject child removal frees the child |
| [024](ADR-024-annotation-handles-close-with-document.md) | Supersedes ADR-023 decision 3 | Annotation handles close with their document: a per-document registry of live annotation handles, released before every `FPDF_CloseDocument`, so no annotation context outlives its document |
| [026](ADR-026-no-cran-release.md) | Supersedes ADR-008's release targeting and ADR-003's CRAN-submission wording | No CRAN release: keep ADR-008's CRAN-quality bar, ship binaries through r-universe and source through GitHub |
| [027](ADR-027-verified-pdfium-downloads.md) | Supersedes ADR-003's download-integrity consequence and ADR-006's rejection of hash pinning | PDFium archives are verified before use: SHA-256 pinned per archive in `tools/pdfium-checksums.txt` and tied to the release pin, atomic downloads into the cache, and bad cache entries replaced |

## Policy

- One ADR per material choice. Material choices include: dependency
  changes, API-shape changes, distribution model changes, memory-model
  changes, CI gating policy changes, license changes.
- ADRs are **immutable once accepted**. Update by writing a new ADR with
  status `Supersedes ADR-NNN`, and amend the index above.
- The template lives at [`ADR-000-template.md`](ADR-000-template.md).
- New ADRs increment the number monotonically.

## When to write an ADR

Yes:

- "We will use [framework X] for [layer Y]."
- "We will distribute binaries via [mechanism Z]."
- "We will name the public function `pdf_foo()` (not `pdfium_foo()`)
  because [reason]."

No:

- Bug fixes.
- Implementation details that don't constrain other choices.
- Renaming a private helper.

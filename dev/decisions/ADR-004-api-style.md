# ADR-004 — API style

- Status: Accepted
- Date: 2026-05-15

## Context

We need a public R API surface that:

1. Reads naturally to R users (snake_case, tidyverse-friendly outputs).
2. Stays close enough to PDFium's C ABI that future maintenance doesn't
   require reinventing terminology.
3. Reserves the right signatures now so post-0.1.0 features
   (encryption, annotations, AcroForms, signatures) can be added
   without breaking changes — informed by the R PDF ecosystem survey
   (`dev/r-pdf-ecosystem-survey.md`) and the upstream wrapper survey
   (`dev/upstream-feature-survey.md`).

The upstream survey shows two API shapes work in practice:
**type-safe-and-idiomatic** (pdfium-render's enum-per-object-type +
typed annotations) and **flat-and-raw** (pdfium-rs's near-1:1 C
mapping). The R PDF ecosystem survey shows `pdftools` already shapes
expectations: `pdf_doc_text()`, `pdf_data()`, `pdf_info()`, etc., with
`opw=`/`upw=` on every function.

## Decision

- **Naming convention:** snake_case, with the `pdf_*` prefix for every
  exported function (`pdf_doc_open`, `pdf_doc_close`, `pdf_page_count`,
  `pdf_path_segments`, etc.). This matches `pdftools` user
  expectations.
- **Argument naming:** lowercase snake_case. The first argument is
  always the object being queried (`doc`, `page`, `obj`) — never
  pipe-unfriendly orderings.
- **Return shape:** tibble for tabular queries (one row per path
  operator, one row per text run). Scalar atomic for scalar queries.
  Lists of tibbles for nested data only when flattening would mangle
  semantics.
- **S3 classes for handles:** `pdfium_doc`, `pdfium_page`, `pdfium_obj`.
  Print methods identify the open/closed state at a glance.
- **Reserved signature points (must be in v0.1.0):**
  - `pdf_doc_open(path, password = NULL)` — reserves the slot so future
    encrypted-PDF support is non-breaking.
  - Document and page constructors accept and propagate an "extras"
    slot (an environment) so AcroForm state, conformance metadata,
    and other later additions attach without re-architecting handles.
- **Type-safety vs. flat-and-raw:** middle path. We expose typed S3
  classes for documents/pages/objects, but the public functions stay
  close to the C ABI's vocabulary (`pdf_path_segments`, not
  `pdfium_extract_path_curves_from_page_object`). Borrowing
  pypdfium2's "raw + helpers in one package" pattern.
- **Errors:** plain R errors via `stop(..., call. = FALSE)`. We do
  *not* introduce a class hierarchy in v0.1.0; that's a Tier 2
  capability that arrives with annotation/signature support (which
  benefit from `tryCatch`-able subclasses).

## Consequences

- Users coming from `pdftools` find familiar verbs.
- The flat surface keeps the C++ glue dumb — each `pdf_*` function
  maps to one or two `FPDF_*` calls.
- We accept that some compound operations (e.g. "extract all paths
  with their style + clip-path-resolved geometry") are user-side
  composition rather than first-class functions in v0.1.0. The Tier
  2/3 roadmap can add `pdf_extract_paths()` once content-stream
  parsing lands.
- The `password = NULL` shape is permanent. Even if encrypted-PDF
  support never ships, we can't remove the argument without breaking
  callers.

## Alternatives considered

- **`pdfium_*` prefix instead of `pdf_*`.** Rejected: longer, no
  semantic gain, fights `pdftools` muscle memory.
- **Function-per-type (e.g. `pdf_path_get_segments()` vs
  `pdf_path_segments()`).** Rejected: snakier without clarity gain;
  the noun-phrase form reads naturally.
- **R6 / reference classes for handles.** Rejected — see ADR-001.
- **Error subclass hierarchy in v0.1.0.** Deferred. Adds surface area
  before we have callers that benefit. Will revisit when annotations
  and signatures land.
- **No `password=` argument until we actually need it.** Rejected per
  the R ecosystem survey — `pdftools` users expect it, and adding it
  later would force a breaking signature change.

## References

- `dev/upstream-feature-survey.md`
- `dev/r-pdf-ecosystem-survey.md`
- [`pdftools` reference](https://docs.ropensci.org/pdftools/reference/index.html)
- [Tidyverse naming conventions](https://style.tidyverse.org/syntax.html#object-names)

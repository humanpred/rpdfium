# ADR-013 — Form-fill environment lifetime: lazy cache

- Status: Accepted
- Date: 2026-05-19
- Deciders: Bill Denney

## Context

AcroForm interaction (setting field values, flattening, listbox
selection) requires an `FPDF_FORMHANDLE` obtained from
`FPDFDOC_InitFormFillEnvironment(doc, &form_fill_info)`. The handle
must outlive every form mutation and must be released via
`FPDFDOC_ExitFormFillEnvironment` before document close.

Two lifetime strategies were considered:

| Option | Shape | Pros | Cons |
|---|---|---|---|
| Lazy + cached | Spin up on first form mutation; cache on doc; release on `pdf_doc_close` | Read-only users don't pay the cost | More state to track; ordering is subtle |
| Eager when `readwrite = TRUE` | Init at open; release at close | Simpler lifecycle | Read-only form *reads* (rare but valid) need one too |

## Decision

Adopt lazy + cached. The `pdfium_doc` carries an optional `ffl_env`
externalptr that's NULL on open. An internal helper `ensure_ffl_env(doc)`
populates it on first call by invoking `cpp_form_fill_env_init`. The
form-fill env carries its own R-level finalizer that calls
`FPDFDOC_ExitFormFillEnvironment` on GC. `pdf_doc_close()` runs that
finalizer eagerly so the lifecycle ordering is correct: form-fill
env releases before the doc handle.

## Consequences

- Read-only users (the majority) never pay the cost of
  initialising the FFL env.
- Mutators that need it call `ensure_ffl_env(doc)` and read the
  cached handle thereafter.
- Lifecycle ordering matters: `pdf_doc_close(doc)` must run the FFL
  env's finalizer *before* `FPDF_CloseDocument`. Implemented by
  detaching the FFL env's externalptr from `doc` and explicitly
  invoking its finalizer before the doc's close call.
- A future feature that needs the FFL env on *read* (e.g.
  flattening preview) will trigger the same lazy init. No code
  change required at that point.

## Alternatives considered

- **Eager init when `readwrite = TRUE`**: rejected because it pays
  the cost unconditionally even when the user only edits page
  rotation (no forms involved), and because read-only form
  flattening is a legitimate use case.
- **Per-call FFL env (init + release inside each mutator)**:
  rejected — `FPDFDOC_InitFormFillEnvironment` is documented as
  per-document, and PDFium internally caches form data on it; tearing
  it down between calls would lose that state and risk
  inconsistency.

## References

- `dev/mutation-design.md` §5.
- PDFium `fpdf_formfill.h`.

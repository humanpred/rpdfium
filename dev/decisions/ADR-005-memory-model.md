# ADR-005 — Memory model

- Status: Accepted
- Date: 2026-05-15

## Context

PDFium handles (`FPDF_DOCUMENT`, `FPDF_PAGE`, `FPDF_PAGEOBJECT`,
`FPDF_BITMAP`, …) are opaque C pointers freed by paired
`FPDF_*Close*` / `FPDFBitmap_Destroy` calls. Misuse — double free,
use-after-free, leak — produces hard crashes that surface as the user's
fault even when our wrapper is at fault.

The upstream wrapper survey (`dev/upstream-feature-survey.md`) found
three viable models:

1. **Explicit close + finalizer fallback** (pypdfium2): every wrapper
   has a `close()` method; weakref finalizer runs `_close()` if the
   user forgot. Parent-tracking is explicit.
2. **Refcount + Drop** (pdfium-rs): an `Rc` inside every wrapper
   ensures the underlying handle survives until the last reference
   goes out of scope. No explicit close — Drop runs `FPDF_*Close*`.
3. **RAII + borrow checker** (pdfium-render): Rust lifetimes guarantee
   correct ordering at compile time. No runtime tracking needed.

R has no compile-time lifetime checking; option 3 is unavailable.

## Decision

- Every PDFium handle is wrapped in an R `externalptr` with a C
  finalizer registered via `R_RegisterCFinalizerEx(ptr, finalizer,
  TRUE)`. The `TRUE` argument also fires the finalizer on R session
  exit, so an interactively-closed session doesn't leak.
- The finalizer is the **only** code path that calls `FPDF_*Close*` on
  a live pointer. After closing, it calls `R_ClearExternalPtr` so the
  pointer reads as NULL. This makes the explicit user-facing close
  function (e.g. `pdf_doc_close()`) safely idempotent.
- Public `pdf_doc_close()` and equivalents flip the pointer to NULL,
  triggering the finalizer's `FPDF_*Close*` call. A second
  `pdf_doc_close()` is a no-op.
- **Parent-tracking** uses the `externalptr`'s `prot` slot: the child
  externalptr holds an R-level reference to its parent's externalptr
  through `prot`. R's GC promises that as long as a child is live,
  its parent (held in `prot`) cannot be collected. This guarantees
  children are valid for the duration of their lifetime regardless of
  when the user drops the parent variable.
- **Auto-close on GC** works: a `pdfium_doc` dropped without explicit
  close gets reclaimed by R's GC, which runs the finalizer, which
  calls `FPDF_CloseDocument`. We test this in
  `tests/testthat/test-document.R` by running many open-without-close
  iterations and calling `gc()` to confirm no crash.
- **Eventual, not deterministic.** GC is non-deterministic; users who
  need immediate release (large documents, Windows file deletion)
  must call `pdf_doc_close()`. Documented in `vignettes/architecture.Rmd`.
- **Library lifecycle.** PDFium's process-global init/destroy
  (`FPDF_InitLibraryWithConfig` / `FPDF_DestroyLibrary`) run in
  `.onLoad` / `.onUnload`. A module-level boolean tracks
  initialization so tests can force a re-init via
  `FPDF_DestroyLibrary` + re-init within `withr::defer()` without
  racing.

## Consequences

- Users get the best of both worlds: idiomatic R (no manual cleanup
  for one-off scripts) plus deterministic release when they need it.
- Implementing this correctly requires every Rcpp function that
  returns a handle to register a finalizer and (for children) set
  `prot` to the parent's externalptr. CLAUDE.md documents this.
- `pdf_doc_close()` is idempotent; this is a permanent contract.
- The auto-finalizer test in `test-document.R` is load-bearing — it's
  the only test that catches finalizer regressions. Don't remove it.
- valgrind (weekly CI) is our backstop for missed handles.

## Alternatives considered

- **Refcount inside each wrapper.** Possible but adds an allocation
  per object and obscures the lifetime in places that should be
  obvious (the parent-child reference is conceptually simple). The
  pypdfium2-style "externalptr + finalizer + prot" is cleaner.
- **No automatic close, require explicit `pdf_doc_close()`.** Rejected.
  Users will forget. Forgetting must be safe.
- **Use `weakref` instead of `externalptr` finalizers.** R's weak
  references are designed for caches, not for managing C resources.
  Finalizers on `externalptr` are the standard idiom.

## References

- `dev/upstream-feature-survey.md` (memory-management table)
- [Writing R Extensions §5.13 External pointers and weak references](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#External-pointers-and-weak-references)
- [`R_RegisterCFinalizerEx` documentation](https://cran.r-project.org/doc/manuals/r-release/R-exts.html#Garbage-Collection)
- pypdfium2's `_helpers/_internal.py` parent-tracking implementation

# ADR-031 — Handle finalizers are R functions that call in only while the shared library is loaded

- Status: Supersedes ADR-005's C finalizers and ADR-028's memory-buffer handle
- Date: 2026-09-27
- Deciders: Bill Denney

## Context

Every handle the package closes carried a C finalizer, registered with
`R_RegisterCFinalizerEx(ptr, finalizer, TRUE)` in `make_handle()`
(ADR-005, ADR-028). That covered documents, pages, annotation contexts,
fonts, XObjects, clip paths, bitmaps, and the buffer a document loaded
from memory reads. R stores the finalizer's address in the handle's weak
reference until the handle is collected, and it has no API to remove a
finalizer once registered.

`.onUnload` destroys the library, which releases every registered
handle (ADR-028), and then unloads the package's shared library
(`library.dynam.unload()`). A handle that survives the unload, whether
open, closed, or unreachable but not yet finalized, still holds a
finalizer address into unmapped code. The next collection that finds
the handle unreachable, or R's exit finalizers, calls that address from
`R_RunWeakRefFinalizer()`, and R crashes.

Measured on Linux with R 4.6.1, using a handle of every kind in each of
those states, one R process per scenario:

- `unloadNamespace()` and `detach(unload = TRUE)`: SIGSEGV in every
  state.
- `pkgload::unload()`: the same. `pkgload::load_all()` loads a fresh
  copy of the library from a new temporary file each time. After an
  identical rebuild the copy maps at the old address, so the stale
  address happens to hit the same function. After a changed rebuild it
  crashes.
- When `unloadNamespace()` fails, pkgload falls back to unregistering
  the namespace and unloading the library without `.onUnload`. Nothing
  releases the handles first, and the next collection crashes, whether
  or not the library is loaded again.

Two facts about R limit the options:

- R would call an `R_unload_pdfium()` on every unload, but it looks the
  function up through `R_dlsym()`. That honours
  `R_useDynamicSymbols(dll, FALSE)`, which the Rcpp-generated
  `R_init_pdfium()` sets, so R never finds it.
- A `NativeSymbolInfo` taken before an unload is useless after it. R
  4.6 clears its address when the library is unloaded, so `.Call()`
  through it raises an error. An error in a finalizer is printed at
  whatever point in the session the finalizer happens to run.

## Decision

1. Every handle's finalizer is the R function `finalize_handle()` in
   `R/finalizer.R`. `make_handle()` is still the only code that attaches
   a finalizer, and it registers this one with
   `R_RegisterFinalizerEx(ptr, fun, TRUE)`. `.onLoad` hands the function
   to the library through `cpp_set_handle_finalizer()`, which preserves
   it. `.onUnload` releases it after destroying the library and before
   unloading the shared library.
2. `finalize_handle()` calls into the library only while a copy of it is
   loaded, and it looks the routine up by name on every call: first
   `is.loaded("_pdfium_cpp_finalize_handle", PACKAGE = "pdfium")`, then
   `.Call("_pdfium_cpp_finalize_handle", ptr, PACKAGE = "pdfium")`. It
   never holds a symbol across an unload.
3. `cpp_finalize_handle()` releases a handle only if the loaded copy of
   the library registered it. It leaves any other handle alone. Such a
   handle was either released already, by its close, its owner's release
   or the library destroy on unload, or it was made by an earlier copy
   of the library, whose PDFium owns whatever it points to.
4. A document loaded from memory reads from a copy of the caller's bytes,
   held as a raw vector in the prot slot of the document's handle. The
   copy has no finalizer and is not a registry kind, which supersedes
   the buffer handle in ADR-028 decisions 1 and 2. R never moves a
   vector, nothing else can reach the copy, and R frees it only after
   the document's handle, so only after the document is closed.
5. `cpp_finalize_handle()` and `cpp_set_handle_finalizer()` are exported
   with `rng = false`. Rcpp's default wrapper reads `.Random.seed` and
   writes it back, creating it if it is absent, and a finalizer must not
   do that.
6. A source-tree test enforces the single registration site. `src/` must
   contain no `R_RegisterCFinalizer*()` or `R_MakeWeakRef*()` call, and
   an `R_RegisterFinalizer*()` call only in `src/handle_registry.cpp`.
   `R/` must contain no `reg.finalizer()` call, and a
   `cpp_set_handle_finalizer()` call only in `R/zzz.R`.

## Consequences

- No unload path calls into an unloaded library. The paths covered are
  `unloadNamespace()`, `detach(unload = TRUE)`, `pkgload::unload()`,
  `load_all()` reloads of the same or a changed build, and unloading the
  shared library without `.onUnload`, with or without loading it again.
  All 32 scenarios (8 paths × open, closed, pending and all) now exit
  cleanly. Before this change, 21 crashed.
- The weak-registry invariant of ADR-024 and ADR-025 still holds. R
  keeps a handle until its finalizer has run, and the finalizer
  deregisters the handle while the library that registered it is still
  loaded. Once that library is gone, so is its registry.
- At exit, R does not unload namespaces, so the library is still loaded
  when the exit finalizers run. They release every handle through the
  registry as before, and a document releases its annotation contexts,
  pages, fonts and XObjects before itself.
- Unloading the shared library without `.onUnload` leaks the PDFium
  objects of handles that are still open. Nothing may close them once
  their library is gone, and a later copy of the library must not. The
  finalizer function also stays preserved, keeping its namespace in
  memory. pkgload's fallback is the one known path.
- Cost: running `finalize_handle()` costs about 1.6 µs per handle. The
  benchmark loads page 1 of `shapes.pdf` 10,000 times and reads the type
  and bounds of each of its 5 objects. With pages left to the finalizer
  it took 8.32–8.45 s before and 8.36–8.43 s after. With pages closed
  explicitly it took 8.57–8.73 s before and 8.65–8.73 s after. These
  are three runs per build, each the median of seven, and the
  differences are within run-to-run noise. A `gc()` that finalizes
  20,000 unreachable bitmaps took 45 ms before and 44 ms after.
- The finalizer resolves `"pdfium"` to the most recently loaded shared
  library of that name (`R_FindSymbol()`). Having two copies loaded at
  once is unsupported, and only a hand-made `dyn.load()` of a second
  copy can cause it. The finalizers of one copy's handles would then
  reach the other copy, which would leave them alone (decision 3), so
  the first copy's registry would keep entries that R has freed.
- The memory buffer is now an R vector, so R's garbage collector counts
  it, and a large document read from memory makes R collect sooner. The
  `new[]` buffer it replaces was invisible to R.
- `tests/testthat/test-finalizer.R` pins each unload path, and R's exit,
  each in a fresh R process, so a regression fails a test instead of
  ending the test run.

## Alternatives considered

- **Keep the shared library mapped**, by not calling
  `library.dynam.unload()`: pkgload unloads the library itself, so
  reloads would still crash. On Windows a loaded DLL cannot be replaced,
  so reinstalling after an unload would fail.
- **`R_unload_pdfium()`** to release everything: R never calls it while
  dynamic symbols are disabled, and it could not remove the finalizer
  addresses anyway.
- **A captured `NativeSymbolInfo` plus a flag that `.onUnload`
  clears**: cheaper (a `.Call()` through a held symbol takes about
  0.25 µs, against about 1 µs by name), but only as safe as `.onUnload`
  running before every unload, which pkgload's fallback skips.
- **Checking `getLoadedDLLs()`**: correct, but it builds the whole table
  of loaded libraries, at about 870 µs per call.
- **`reg.finalizer()` from R, or an environment wrapping each
  externalptr**: the same R finalizer, at the price of an extra R call
  or allocation per handle. Registering it in `make_handle()` keeps the
  single site that ADR-028 set up.
- **A C finalizer in a helper library the package never unloads**: this
  keeps a library mapped after all, with the same Windows problem.

## References

- ADR-005 (memory model), ADR-024, ADR-025, and ADR-028, whose known
  limitation this resolves.
- `R/finalizer.R`, `R/zzz.R`, `src/handle_registry.h`,
  `src/handle_registry.cpp`, `src/init.cpp`.
- R sources: `src/main/memory.c` (`R_RegisterFinalizerEx()`,
  `R_RunWeakRefFinalizer()`, `RunFinalizers()`,
  `R_RunExitFinalizers()`) and `src/main/Rdynload.c`
  (`R_callDLLUnload()`, `DeleteDLL()`, `R_FindSymbol()`).
- `tests/testthat/test-finalizer.R`,
  `tests/testthat/scripts/unload-scenario.R`.

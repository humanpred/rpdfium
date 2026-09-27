# ADR-028 — Destroying the library closes every handle first

- Status: Accepted (extends ADR-025)
- Date: 2026-09-27
- Deciders: Bill Denney

## Context

`FPDF_DestroyLibrary()` frees PDFium's global state: font globals and
caches, the FreeType library, the stock colour spaces and other module
data. Its header says that no PDFium function may be called
afterwards, that it does not close other objects, and that they should
be closed first (`public/fpdfview.h`).

`cpp_destroy_library()` called it with documents and other handles
still open. Only `.onUnload` and two tests in `test-document.R` call
it; no exported function does. Afterwards, the next document opened
(`cpp_open_document()`, `cpp_open_document_from_memory()`,
`cpp_create_new_document()`) or `pdf_system_fonts_install_default()`
initialises the library again. Documents, pages, annotations, fonts and
XObjects opened before the destroy survived it, and were closed later,
explicitly or by their finalizers, against a destroyed or re-initialised
library. On the ADR-025 branch every such path crashed R, with and
without valgrind:

- closing a document after the destroy: SIGSEGV in
  `CPDF_FontGlobals::Clear()`, a freed global the document's destructor
  calls;
- closing it after opening another document had re-initialised the
  library: 3 invalid reads in `FT_Done_Face()`, because the document's
  fonts belong to the freed FreeType library, then SIGSEGV;
- collecting it after `pdf_system_fonts_install_default()` had
  re-initialised the library: the same;
- rendering a page after the destroy: SIGSEGV in
  `CPDF_ColorSpace::GetStockCS()`;
- handles that were unreachable but not yet collected when the destroy
  ran, collected after a re-initialisation: the same crash. A serial
  test run does this, because `test-document.R` destroys the library
  midway through the suite.

Clip paths from `pdf_clip_path_new()` and bitmaps from
`pdf_bitmap_new()` belong to no document. Closing them after a destroy
read no freed memory under valgrind, but no header promises that
either.

## Decision

1. The ADR-025 registry gains the library as an owner. Documents, the
   clip paths of `pdf_clip_path_new()`, the bitmaps of
   `pdf_bitmap_new()` and the buffers that documents loaded from memory
   read from are registered under it. Each kind has one minting
   function (`make_document_handle()`, `make_clip_path_handle()`,
   `make_bitmap_handle()`, `make_buffer_handle()`) and one releasing
   function, as in ADR-025, so `make_handle()` is the only code that
   attaches a finalizer. `src/document_handle.h` folds into
   `src/handle_registry.h`: `release_document_handle()` replaces
   `close_document_handle()`, and the four places that mint a document
   (`cpp_open_document`, `cpp_open_document_from_memory`,
   `cpp_create_new_document`, `cpp_import_n_pages_to_one`) call
   `make_document_handle()`.
2. `cpp_destroy_library()` releases every handle registered under the
   library before `FPDF_DestroyLibrary()`: each document after the
   handles registered under it (ADR-025), then clip paths, bitmaps and
   buffers. The released handles read as closed, and their finalizers
   only deregister them.
3. Destroying the library never refuses; it releases.
4. Every entry point that creates a handle without an open document
   initialises the library first (`ensure_library_initialised()`):
   documents, as before, `pdf_system_fonts_install_default()`, clip
   paths and bitmaps.

## Consequences

- No PDFium object the package holds outlives the library instance that
  made it, in any order of close, collection, destroy and
  re-initialisation.
- After `cpp_destroy_library()` every handle reads as closed: calls on
  it raise the ADR-025 errors ("Document has been closed.", "Page has
  been closed: its document was closed."), closing it again is a no-op,
  and collecting it touches no PDFium state.
- Unloading the package closes the documents still open, instead of
  leaving them open on a destroyed library.
- Tests no longer have to collect every document before destroying the
  library.
- `cpp_library_handle_counts()` reports the library's registered
  handles per kind, for tests.
- Known limitation, unchanged here: `.onUnload` also unloads the
  package's shared library (`library.dynam.unload()`). A handle that
  survives `unloadNamespace()` or `detach(unload = TRUE)`, even a
  closed one or one that is unreachable but not yet collected, keeps
  its C finalizer, which then points into unmapped code: R crashes at
  the next garbage collection or at exit, in `R_RunWeakRefFinalizer()`.
  `pkgload::load_all()` reloads hit it too, because pkgload unloads the
  shared library itself. This decision makes those finalizers no-ops,
  but cannot keep them callable. A follow-up (ADR-031) replaces the C
  finalizers with R-level finalizers that check that the shared library
  is still loaded; decision 1 keeps every finalizer in `make_handle()`,
  so that change is made in one place.

## Alternatives considered

- **Refuse to destroy while handles are registered**: whether it
  refuses would depend on garbage collection, because a handle stays
  registered until its finalizer runs, so an unreachable handle would
  block the destroy until a collection happened to run. And `.onUnload`
  cannot refuse: R runs it through `runHook()`, which turns the error
  into a warning and unloads the namespace anyway, leaving the library
  initialised with the documents open.
- **Never destroy the library**: leaves PDFium's global state, and the
  system-font provider the package installs, allocated after the
  package is unloaded.
- **Release documents only**: clip paths and bitmaps survive a destroy
  in the PDFium build measured, but nothing promises that; ADR-024 made
  the same argument for annotation contexts.
- **Keep the memory buffer's own finalizer in `init.cpp`**: leaves a
  second place that attaches finalizers, which the ADR-031 change would
  have to find.

## References

- ADR-005 (memory model), ADR-024, ADR-025, ADR-031 (R-level
  finalizers, follow-up).
- `src/handle_registry.h`, `src/handle_registry.cpp`, `src/init.cpp`,
  `R/zzz.R`.
- PDFium `public/fpdfview.h` (`FPDF_DestroyLibrary`,
  `FPDF_CloseDocument`).
- `tests/testthat/test-document.R`, tests "documents, clip paths,
  bitmaps and buffers are registered under the library",
  "cpp_destroy_library() closes every handle first (ADR-028)" and "the
  default system-font provider survives a library round-trip".

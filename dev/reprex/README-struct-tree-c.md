# struct-tree-c — standalone C reprex for humanpred/rpdfium#44

Reproduces the structure-tree walk done by `cpp_struct_tree_page`
in pure C, with no R/Rcpp glue. Useful for cross-checking PDFium
behavior independently of the R bindings.

## Build

```sh
cd dev/reprex
gcc -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined \
    -I../../inst/include -L../../inst/lib \
    -Wl,-rpath,$(pwd)/../../inst/lib \
    struct-tree-c.c -lpdfium -o struct-tree-c
```

## Run

```sh
LD_LIBRARY_PATH=../../inst/lib ./struct-tree-c ../../inst/extdata/fixtures/tagged.pdf
```

## What I learned running this

**Linux x86_64 under ASan + UBSan:** clean exit, no errors. PDFium
walks the structure tree, reads every attribute (Placement, O,
Headers, BBox, BorderStyle, Hidden, SpaceBefore), exits 0.

**Linux x86_64 under valgrind memcheck:** 442 "Mismatched free /
delete[]" reports from 84 unique call sites inside `libpdfium.so`.
Pattern: PDFium's `pdfium::internal::StringAllocOrDie` (which uses
`malloc()`) returns memory that is later released via
`operator delete()` somewhere in the compiled binding. This is
C++ UB per the standard but is functionally harmless on Linux
glibc and on macOS libsystem_malloc — both route `operator delete`
to `free()` in the default implementation, so no actual corruption
results. Worth reporting upstream as a code-quality / spec-
compliance issue separate from #44.

## Why this reprex matters for #44

The standalone C reprex passes on Linux without segfaulting and
without ASan/UBSan reports. That conclusively shows the
macOS-arm64 crash at `cpp_struct_tree_page` → `R_GetCCallable`
is NOT reproducible via PDFium's cross-platform code paths from C.
The bug must live in either:

1. PDFium's macOS-arm64-specific code (CoreText font discovery,
   filesystem-probing helpers, dispatch_async usage), OR
2. PDFium's interaction with macOS system libraries that have no
   Linux equivalent.

Both possibilities require ASan-instrumented PDFium for macOS
arm64. The bblanchon binary that rpdfium currently ships is NOT
ASan-built. See `dev/macos-segfault-triage.md` §5c for the build
recipe and `humanpred/rpdfium#44` for the fork-and-build PR.

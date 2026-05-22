# PDFium reproducer (root-caused, fix landed)

This directory captures the diagnostic journey for the segfault our
Rcpp shim was throwing when calling `FPDFAnnot_SetFontColor`,
`FPDFAnnot_SetFormFieldFlags`, and `FPDFAnnot_SetFocusableSubtypes`.
**The bug was on our side — not PDFium's.** The fix is one line
in `src/api_completion.cpp`. Keeping the files here for future
embedders who hit the same shape, since it's a subtle ownership
issue in PDFium's public API that's easy to mis-wrap.

## Symptom

R session segfault when calling any of the three setters:

```
*** caught segfault ***
address (nil), cause 'unknown'

Traceback:
 1: pdfium:::cpp_annot_set_font_color(doc$ptr, a$ptr, 255L, 100L, 50L)
```

## Root cause

Our `ScopedFormHandle` RAII wrapper around
`FPDFDOC_InitFormFillEnvironment` /
`FPDFDOC_ExitFormFillEnvironment` originally stored the
`FPDF_FORMFILLINFO` struct as a **constructor-local variable**:

```cpp
struct ScopedFormHandle {
  FPDF_FORMHANDLE handle = nullptr;
  ScopedFormHandle(FPDF_DOCUMENT doc) {
    FPDF_FORMFILLINFO ffi{};       // ← local!
    ffi.version = 2;
    handle = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  }
  ~ScopedFormHandle() {
    if (handle != nullptr) {
      FPDFDOC_ExitFormFillEnvironment(handle);
    }
  }
};
```

PDFium's `FPDFDOC_InitFormFillEnvironment` **stores the
`FPDF_FORMFILLINFO*` pointer internally** rather than copying the
struct. The pointer is then dereferenced on every subsequent
`FPDFDOC_*` call, including `_ExitFormFillEnvironment`, to look up
callback function pointers (`FFI_OnChange`, `FFI_GetPage`,
`m_pJsPlatform`, etc.). When the constructor returned, the
constructor-local `ffi` went out of scope and PDFium's stored
pointer became dangling.

The segfault came at Exit, not at Set — Exit reads
`m_pInfo->m_pJsPlatform` (or similar) and tries to `free()` a
field of the stale struct. The freed address `0x74` we saw in gdb
is whatever happened to land at that stack location.

Pure-C++ reproducers didn't crash because the C++ tests declared
`FPDF_FORMFILLINFO ffi{};` as a local in `main()`, which stayed
alive through the whole sequence.

## The fix

One line: move `ffi` from a constructor-local to a struct member
so it lives as long as `handle`:

```cpp
struct ScopedFormHandle {
  FPDF_FORMFILLINFO ffi{};         // ← now a member
  FPDF_FORMHANDLE handle = nullptr;
  ScopedFormHandle(FPDF_DOCUMENT doc) {
    ffi.version = 2;
    handle = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  }
  ...
};
```

After the fix all three setters work; the R-side wrappers
(`pdf_annot_set_font_color()`, `pdf_form_field_set_flags()`,
`pdf_doc_set_focusable_subtypes()`) are re-exported with their
tests.

## How gdb pinpointed it

```
$ R_HOME=/usr/lib/R LD_LIBRARY_PATH=.../inst/lib \
    gdb -batch -x gdb_cmds.txt /usr/lib/R/bin/exec/R
...
Thread 1 "R" received signal SIGSEGV, Segmentation fault.
__GI___libc_free (mem=0x74) at ./malloc/malloc.c:3401

#0  __GI___libc_free (mem=0x74)
#1  FPDFDOC_ExitFormFillEnvironment () from libpdfium.so
#2  ScopedFormHandle::~ScopedFormHandle (this=...) at api_completion.cpp:470
#3  cpp_annot_set_font_color (...) at api_completion.cpp:778
```

The two clues that fingered the ownership issue:

1. The crash is in **`Exit`**, not in `SetFontColor` itself. So
   the Set call mutated something that Exit then tried to free.
2. The freed address `0x74` is decimal `116` — far too small to be
   a real heap pointer. That's a sentinel value or a uninitialised
   stack-slot byte, which happens when you `free()` a field of an
   already-destroyed object.

## Other shims to check

`grep -n "FPDF_FORMFILLINFO ffi" src/*.cpp` lists the other call
sites. Every other site declares `ffi` as a local **in the same
function** as the Init+...+Exit sequence, so `ffi` stays in scope
through the whole sequence — those are fine. Only the RAII wrapper
had Init in the constructor and Exit in the destructor, which is
the lifetime split that introduced the bug.

## Lessons for other embedders

* `FPDF_FORMFILLINFO` is a **borrow**, not a copy. PDFium retains
  the pointer for the lifetime of the `FPDF_FORMHANDLE`.
* If you wrap `FPDFDOC_InitFormFillEnvironment` in a RAII class,
  the `FPDF_FORMFILLINFO` struct must be a **member**, not a
  constructor-local.
* The crash address you see won't pinpoint the dangle — gdb just
  shows whichever field PDFium happened to dereference first.

## Files in this directory

* `setfontcolor_segfault.cpp` — pure-C++ reproducer that **does
  not crash** (because the C++ `ffi` is a `main()` local that
  outlives the whole Init→Set→Exit sequence). Kept as a reference
  for the contrast that pointed us at the lifetime issue.
* `setfocusablesubtypes_segfault.cpp` — same pattern for the
  other affected function.

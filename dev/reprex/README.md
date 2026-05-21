# PDFium reproducers

Standalone reproducers for issues observed in the `pdfium` R
package while wrapping PDFium's public C API. Each `.cpp` file is
self-contained and builds against the prebuilt bblanchon binary
that ships with the package (`inst/lib/libpdfium.so`); see the
top-of-file comment for the build command.

## What's here

### `setfocusablesubtypes_segfault.cpp`, `setfontcolor_segfault.cpp`

**Status: observed in R, NOT reproducible from pure C++.**

Calling `FPDFAnnot_SetFocusableSubtypes`, `FPDFAnnot_SetFontColor`,
or `FPDFAnnot_SetFormFieldFlags` through our Rcpp shim against a
freshly-created `FPDF_CreateNewDocument()` segfaults R with
"address (nil), cause 'unknown'":

```
*** caught segfault ***
address (nil), cause 'unknown'

Traceback:
 1: pdfium:::cpp_annot_set_font_color(doc$ptr, a$ptr, 255L, 100L, 50L)
```

The shim that R calls does nothing more than:

```cpp
bool cpp_annot_set_font_color(SEXP doc_ptr, SEXP annot_ptr,
                                int r, int g, int b) {
  FPDF_DOCUMENT doc = doc_from(doc_ptr);
  FPDF_ANNOTATION annot = annot_from(annot_ptr);
  ScopedFormHandle env(doc);            // FPDFDOC_InitFormFillEnvironment
  return FPDFAnnot_SetFontColor(env.handle, annot, r, g, b) != 0;
  // ScopedFormHandle dtor: FPDFDOC_ExitFormFillEnvironment(env.handle)
}
```

Porting the same sequence to a pure-C++ `main()` (these two files)
runs cleanly through every variant we've tried — multi-cycle
Init+Exit churn, 5x SetFocusableSubtypes then SetFontColor,
fresh-doc vs loaded-doc, with and without an `FPDFPage_CreateAnnot`
beforehand.

That asymmetry tells us the bug is almost certainly **on our
side** (Rcpp marshalling, R-session memory layout, or a stale
binding we haven't yet root-caused), **not in PDFium**. We are
filing this in `dev/reprex/` rather than escalating upstream
until we can show a pure-C++ reproduction; the C++ files here
exist to make it easy for an upstream maintainer to confirm the
same — if you can compile them against a Debug PDFium build and
*do* see a crash, please ping us at <bug-tracker URL>.

In the meantime the three R-side wrappers
(`pdf_annot_set_font_color`, `pdf_annot_set_form_field_flags`,
`pdf_doc_set_focusable_subtypes`) stay un-exported with a comment
in `R/api_completion.R` documenting the symptom. The underlying
C++ shims remain in `src/api_completion.cpp` so re-exporting is
a one-line change once the root cause is found.

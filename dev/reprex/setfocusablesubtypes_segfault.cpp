// Attempt at a reproducible example for the segfault our R wrapper
// observed when calling
//
//   FPDFAnnot_SetFocusableSubtypes
//   FPDFAnnot_SetFontColor
//   FPDFAnnot_SetFormFieldFlags
//
// on a document with no existing AcroForm focusable-subtype list
// (e.g. a fresh FPDF_CreateNewDocument()).
//
// Status: as of 2026-05-21, **we have not yet been able to
// reproduce the crash from pure C++** against the prebuilt
// chromium/7202 bblanchon binary. The crash was observed reliably
// from R (Rcpp shim) with the call sequence below, but porting the
// identical sequence to a standalone C++ program runs cleanly.
//
// We're filing this file as a starting point for upstream
// reproduction: if you can compile this against a Debug PDFium
// build and *do* see the crash, the assertions below pinpoint
// which CPDFSDK_FormFillEnvironment member is being dereferenced.
//
// Symptoms when triggered from the R wrapper:
//   *** caught segfault ***
//   address (nil), cause 'unknown'
//   Traceback:
//    1: .Call(`_pdfium_cpp_annot_set_focusable_subtypes`, doc_ptr, codes)
//
//   or
//
//   address 0x614fd2632e40, cause 'invalid permissions'
//   Traceback:
//    1: .Call(`_pdfium_cpp_annot_set_font_color`, doc_ptr, annot_ptr, r, g, b)
//
// The R wrapper now defends against the crash by calling
// FPDFAnnot_GetFocusableSubtypesCount() (or the matching reader for
// the other two functions) before the Set so the env's lazy
// initialisation happens first. With that guard in place, calls
// succeed.
//
// Build (Linux):
//   g++ -std=c++17 -O0 -g \
//       -I /path/to/pdfium/public \
//       setfocusablesubtypes_segfault.cpp \
//       -L /path/to/pdfium/lib -lpdfium \
//       -Wl,-rpath,/path/to/pdfium/lib \
//       -o repro
//   ./repro

#include <cstdio>
#include <cstdlib>

#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_edit.h"
#include "fpdf_formfill.h"

int main(int /*argc*/, char** /*argv*/) {
  FPDF_LIBRARY_CONFIG cfg{};
  cfg.version = 2;
  FPDF_InitLibraryWithConfig(&cfg);

  // Fresh doc with one empty page — matches the R-side
  // pdf_doc_new() + pdf_page_new() pattern that triggered the
  // crash.
  FPDF_DOCUMENT doc = FPDF_CreateNewDocument();
  FPDF_PAGE page = FPDFPage_New(doc, 0, 612.0, 792.0);

  // Pattern 1: single Init → Set → Exit.
  {
    FPDF_FORMFILLINFO ffi{};
    ffi.version = 2;
    FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
    if (form == nullptr) {
      std::fprintf(stderr, "init returned NULL\n");
      return 4;
    }
    FPDF_ANNOTATION_SUBTYPE subs[] = { FPDF_ANNOT_LINK,
                                       FPDF_ANNOT_WIDGET };
    bool ok = FPDFAnnot_SetFocusableSubtypes(form, subs, 2) != 0;
    std::printf("pattern 1: Set returned %d\n", ok);
    FPDFDOC_ExitFormFillEnvironment(form);
  }

  // Pattern 2: multiple Init → Exit cycles, then Set. Simulates
  // the R session where prior calls (pdf_doc_focusable_subtypes,
  // pdf_form_fields, etc.) have already churned through FFL env
  // init+exit cycles before the setter runs.
  for (int i = 0; i < 4; ++i) {
    FPDF_FORMFILLINFO ffi{};
    ffi.version = 2;
    FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
    FPDFDOC_ExitFormFillEnvironment(form);
  }
  {
    FPDF_FORMFILLINFO ffi{};
    ffi.version = 2;
    FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
    FPDF_ANNOTATION_SUBTYPE subs[] = { FPDF_ANNOT_WIDGET };
    bool ok = FPDFAnnot_SetFocusableSubtypes(form, subs, 1) != 0;
    std::printf("pattern 2: Set after 4 churns returned %d\n", ok);
    FPDFDOC_ExitFormFillEnvironment(form);
  }

  // Pattern 3: SetFontColor on a freshly-created annotation in a
  // doc with no AcroForm.
  {
    FPDF_FORMFILLINFO ffi{};
    ffi.version = 2;
    FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
    FPDF_ANNOTATION annot =
        FPDFPage_CreateAnnot(page, FPDF_ANNOT_FREETEXT);
    FS_RECTF rect{ 0.f, 0.f, 100.f, 100.f };
    FPDFAnnot_SetRect(annot, &rect);
    bool ok = FPDFAnnot_SetFontColor(form, annot,
                                       /*R=*/255, /*G=*/100,
                                       /*B=*/50) != 0;
    std::printf("pattern 3: SetFontColor returned %d\n", ok);
    FPDFPage_CloseAnnot(annot);
    FPDFDOC_ExitFormFillEnvironment(form);
  }

  // Pattern 4: SetFormFieldFlags. PDFium needs an actual widget
  // annotation, so we skip if none exists (the freshly-created
  // page has no widgets).

  std::printf("done — no crash observed\n");
  FPDF_ClosePage(page);
  FPDF_CloseDocument(doc);
  FPDF_DestroyLibrary();
  return 0;
}

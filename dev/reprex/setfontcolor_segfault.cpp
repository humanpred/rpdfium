// Reproducible example for an FPDFAnnot_SetFontColor crash observed
// from the pdfium R-package wrapper. Status: REPRODUCED in R but
// NOT YET REPRODUCED in pure C++ — this file is the latest C++
// attempt and runs cleanly against the prebuilt chromium/7202
// binary on Linux x86_64.
//
// The R repro is:
//   library(pdfium)
//   doc  <- pdf_doc_new()                       # FPDF_CreateNewDocument
//   page <- pdf_page_new(doc, 1, 612, 792)      # FPDFPage_New
//   a    <- pdf_annot_new(page, "freetext",     # FPDFPage_CreateAnnot
//                          bounds = c(0,0,100,100))
//   pdfium:::cpp_annot_set_font_color(doc$ptr, a$ptr, 255, 100, 50)
//   # *** caught segfault *** address (nil), cause 'unknown'
//   # Traceback:
//   #  1: pdfium:::cpp_annot_set_font_color(...)
//
// The C++ shim that R calls is essentially this file's main(): no
// extra logic, just Init FFL env → SetFontColor → Exit. From C++
// the same sequence returns 1 (success) and exits cleanly.
//
// If you can reproduce the crash with a Debug PDFium build the
// stack trace will show which CPDFSDK_FormFillEnvironment member
// is being dereferenced as NULL.

#include <cstdio>

#include "fpdfview.h"
#include "fpdf_annot.h"
#include "fpdf_edit.h"
#include "fpdf_formfill.h"

// Helper that mimics the R wrapper's transient-env pattern.
static bool set_focusable(FPDF_DOCUMENT doc,
                          const FPDF_ANNOTATION_SUBTYPE* subs,
                          size_t count) {
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) return false;
  bool ok = FPDFAnnot_SetFocusableSubtypes(form, subs, count) != 0;
  FPDFDOC_ExitFormFillEnvironment(form);
  return ok;
}

static bool set_font_color(FPDF_DOCUMENT doc, FPDF_ANNOTATION annot,
                            int r, int g, int b) {
  FPDF_FORMFILLINFO ffi{};
  ffi.version = 2;
  FPDF_FORMHANDLE form = FPDFDOC_InitFormFillEnvironment(doc, &ffi);
  if (form == nullptr) return false;
  bool ok = FPDFAnnot_SetFontColor(form, annot, r, g, b) != 0;
  FPDFDOC_ExitFormFillEnvironment(form);
  return ok;
}

int main() {
  FPDF_LIBRARY_CONFIG cfg{};
  cfg.version = 2;
  FPDF_InitLibraryWithConfig(&cfg);

  FPDF_DOCUMENT doc = FPDF_CreateNewDocument();
  FPDF_PAGE page = FPDFPage_New(doc, 0, 612.0, 792.0);

  // Same opener as the R session: 5 SetFocusableSubtypes calls
  // (each its own Init+Set+Exit cycle).
  FPDF_ANNOTATION_SUBTYPE subs[] = { FPDF_ANNOT_WIDGET,
                                     FPDF_ANNOT_LINK };
  for (int i = 0; i < 5; ++i) {
    bool ok = set_focusable(doc, subs, 2);
    std::printf("SetFocusableSubtypes iter %d: ok=%d\n", i, ok);
  }

  // Now create a freetext annot and call SetFontColor.
  FPDF_ANNOTATION annot = FPDFPage_CreateAnnot(page, FPDF_ANNOT_FREETEXT);
  FS_RECTF rect{ 0.f, 0.f, 100.f, 100.f };
  FPDFAnnot_SetRect(annot, &rect);

  for (int i = 0; i < 5; ++i) {
    bool ok = set_font_color(doc, annot, 255, 100, 50);
    std::printf("SetFontColor iter %d: ok=%d\n", i, ok);
  }

  FPDFPage_CloseAnnot(annot);
  FPDF_ClosePage(page);
  FPDF_CloseDocument(doc);
  FPDF_DestroyLibrary();
  return 0;
}

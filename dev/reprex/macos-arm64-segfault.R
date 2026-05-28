# Minimal reprex for the macOS arm64 segfault reported in
# humanpred/rpdfium#44.
#
# This script is invoked by .github/workflows/macos-arm64-debug.yaml
# under several `Malloc*` env-var combinations to localise the
# corruption. It also runs under lldb (--batch) to capture a
# backtrace if the crash hits.
#
# To rerun a single cut locally on macOS arm64:
#   MallocNanoZone=0 \
#   Rscript dev/reprex/macos-arm64-segfault.R
#
# A successful run prints "REPREX OK" and exits 0. A crash exits
# with the signal number (139 for SEGV) — the workflow inspects
# DiagnosticReports/ and sample output for the fault address.

reprex_step <- function(label) {
  cat(sprintf("\n=== %s ===\n", label))
  flush.console()
}

reprex_step("loading pdfium")
suppressPackageStartupMessages(library(pdfium))

reprex_step("opening fixture + rendering bitmap")
fixture <- system.file("extdata", "fixtures", "shapes.pdf", package = "pdfium")
stopifnot(nzchar(fixture))
doc <- pdf_doc_open(fixture)
bmp <- pdf_render_page(doc, dpi = 72)

reprex_step("first plot(bmp) into PDF device")
out <- tempfile(fileext = ".pdf")
grDevices::pdf(out, width = 5, height = 4)
plot(bmp)                       # first lazy-load of grid happens here
grDevices::dev.off()
cat(sprintf("first plot OK (size=%d)\n", file.size(out)))
flush.console()

reprex_step("second plot(bmp, interpolate = FALSE)")
grDevices::pdf(out, width = 5, height = 4)
plot(bmp, interpolate = FALSE)  # CI reports the segfault here on macOS arm64
grDevices::dev.off()
cat(sprintf("second plot OK (size=%d)\n", file.size(out)))
flush.console()

reprex_step("cleanup")
pdf_doc_close(doc)
gc()

cat("\nREPREX OK\n")

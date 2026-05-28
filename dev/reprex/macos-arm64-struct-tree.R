# Minimal reprex for the macOS arm64 segfault in
# cpp_struct_tree_page (humanpred/rpdfium#44).
#
# Symptom on macos-latest (R 4.6.0 arm64):
#   *** caught segfault ***
#   address 0x656e6e75722f7372 (= ASCII "rs/runne"),
#   cause 'invalid permissions'
#   Traceback:
#    1: cpp_struct_tree_page(page$ptr, string_attrs)
#    2: pdf_structure_tree(doc, page_num = 1L,
#                          string_attrs = c("Placement", "O", "Headers"))
#
# Used by .github/workflows/R-CMD-check.yaml's "Run struct-tree
# reprex under lldb" step on macOS so the crash is reproduced in a
# debugger session (SIGSEGV stops; lldb dumps bt, registers,
# faulting address neighborhood).
#
# Manual local repro:
#   Rscript dev/reprex/macos-arm64-struct-tree.R

cat("== loading pdfium ==\n"); flush.console()
suppressPackageStartupMessages(library(pdfium))

fixture <- system.file("extdata", "fixtures", "tagged.pdf", package = "pdfium")
stopifnot(nzchar(fixture))
cat("fixture:", fixture, "\n"); flush.console()

cat("== pdf_doc_open ==\n"); flush.console()
doc <- pdf_doc_open(fixture)
on.exit(pdf_doc_close(doc), add = TRUE)

cat("== pdf_structure_tree (the crashing call) ==\n"); flush.console()
res <- pdf_structure_tree(
  doc,
  page_num = 1L,
  string_attrs = c("Placement", "O", "Headers")
)

cat("== survived; structure rows:", nrow(res), "==\n")
cat("colnames:", paste(colnames(res), collapse = ", "), "\n")
cat("\nREPREX OK\n")

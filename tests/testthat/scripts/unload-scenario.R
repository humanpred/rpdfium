# Run by test-unload.R in a fresh R process, so that a crash fails a
# test instead of ending the test run. Makes a handle of every kind that
# carries a finalizer, open, closed and pending finalization, unloads
# pdfium as `mode` says, then collects the handles and exits.
#
#   Rscript --vanilla unload-scenario.R <mode> <lib|src> <dir> \
#     <minimal.pdf> <annotated.pdf>
#
# <lib|src> <dir>: load pdfium installed in library <dir>, or with
# pkgload::load_all() from source tree <dir>, as the test run did.
#
# mode:
#   unloadNamespace, detach  detach(unload = TRUE)
#   reload                   unload the namespace and load it again
#   dll_unload               unload the shared library without
#                            .onUnload, as pkgload does when
#                            unloadNamespace() fails
#   dll_reload               the same, then load the library again
#   exit                     no unload: R's exit finalizers close
#                            everything, and a probe reports what is
#                            still registered once they have run
args <- commandArgs(trailingOnly = TRUE)
mode <- args[[1L]]
from <- args[[2L]]
dir <- args[[3L]]
minimal <- args[[4L]]
annotated <- args[[5L]]

load_pdfium <- function() {
  if (from == "src") {
    pkgload::load_all(
      dir,
      attach = mode == "detach", helpers = FALSE,
      attach_testthat = FALSE, quiet = TRUE
    )
  } else if (mode == "detach") {
    library(pdfium, lib.loc = dir)
  } else {
    loadNamespace("pdfium", lib.loc = dir)
  }
  invisible()
}
say <- function(...) writeLines(paste(...))
load_pdfium()
ns <- asNamespace("pdfium")
pdf <- function(name) get(name, envir = ns)
counts_line <- function(n) paste(names(n), n, sep = "=", collapse = " ")
registered <- function() counts_line(pdf("cpp_library_handle_counts")())
# Once the shared library is unloaded, the namespace's own routines are
# gone with it, so a copy loaded again is called by name.
by_name <- function(name, ...) .Call(name, ..., PACKAGE = "pdfium")

# Older than every handle, so R's exit finalizers run it last.
if (mode == "exit") {
  probe <- new.env()
  report <- function(e) say("at exit:", registered())
  invisible(reg.finalizer(probe, report, onexit = TRUE))
}

make_handles <- function() {
  doc <- pdf("pdf_doc_open")(minimal)
  mem <- pdf("pdf_doc_open")(
    source = readBin(annotated, "raw", file.size(annotated))
  )
  page <- pdf("pdf_page_load")(mem, 1L)
  new_doc <- pdf("pdf_doc_new")()
  list(
    doc = doc, mem = mem, page = page,
    annot = pdf("pdf_annot_at")(page, 1L),
    new_doc = new_doc,
    font = pdf("pdf_font_load_standard")(new_doc, "Helvetica"),
    xobject = pdf("pdf_xobject_from_page")(new_doc, doc, 1L),
    clip = pdf("pdf_clip_path_new")(c(0, 0, 10, 10)),
    bitmap = pdf("pdf_bitmap_new")(4L, 4L)
  )
}

# The annotation closes with its document.
close_handles <- function(h) {
  pdf("pdf_bitmap_close")(h$bitmap)
  pdf("pdf_clip_path_close")(h$clip)
  pdf("pdf_xobject_close")(h$xobject)
  pdf("pdf_font_close")(h$font)
  pdf("pdf_page_close")(h$page)
  for (d in h[c("new_doc", "mem", "doc")]) pdf("pdf_doc_close")(d)
  h
}

# Pending: unreachable and marked for finalization, but not finalized.
# The handles are dropped inside another finalizer, whose gc() marks
# them but cannot run them, because R's finalizer loop is already
# running; the loop has passed them, as they are newer than the trigger.
pending <- new.env()
make_pending <- function() {
  trigger <- new.env()
  reg.finalizer(trigger, function(e) {
    rm("h", envir = pending)
    gc()
  })
  pending$h <- make_handles()
  rm(trigger)
  invisible(gc())
}

open <- make_handles()
closed <- close_handles(make_handles())
make_pending()
say("pending dropped:", !exists("h", envir = pending))
say("registered:", registered())

if (mode %in% c("unloadNamespace", "reload")) {
  unloadNamespace("pdfium")
  if (mode == "reload") load_pdfium()
} else if (mode == "detach") {
  detach("package:pdfium", unload = TRUE)
} else if (mode %in% c("dll_unload", "dll_reload")) {
  dll <- getLoadedDLLs()[["pdfium"]][["path"]]
  dyn.unload(dll)
  if (mode == "dll_reload") {
    # Windows finds libpdfium.dll beside the package's DLL only through
    # DLLpath, which library.dynam() passes too; elsewhere it is ignored.
    dyn.load(dll, DLLpath = dirname(dll))
    # A fresh image (generation 1) registered none of the handles, which
    # point into the unloaded copy's PDFium. An image dyn.unload() left
    # mapped (generation 2, as in covr's -O0 builds) still holds them.
    say("load generation:", by_name("_pdfium_cpp_load_generation"))
    say(
      "registered in the new copy:",
      counts_line(by_name("_pdfium_cpp_library_handle_counts"))
    )
    say(
      "unreleased document still set:",
      by_name("_pdfium_cpp_handle_is_valid", open$doc$ptr)
    )
  }
}
say("shared library loaded:", "pdfium" %in% names(getLoadedDLLs()))

if (mode != "exit") {
  rm(open, closed)
  for (i in 1:3) invisible(gc())
}
# Either way nothing is left registered: a fresh image never held the
# handles, and a kept one released them when they were collected.
if (mode == "dll_reload") {
  say(
    "registered after collection:",
    counts_line(by_name("_pdfium_cpp_library_handle_counts"))
  )
}
say("survived")

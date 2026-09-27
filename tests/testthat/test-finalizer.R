# The finalizer every handle carries (R/finalizer.R, ADR-031), and
# handles that outlive pdfium's shared library.

test_that("finalize_handle() releases a handle the loaded library registered", {
  doc <- pdf_doc_open(fixture_path("minimal"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  bitmap <- pdf_bitmap_new(2L, 2L)
  before <- pdfium:::cpp_library_handle_counts()

  expect_null(finalize_handle(page$ptr))
  expect_null(finalize_handle(bitmap$ptr))

  expect_false(is_open(page))
  expect_false(pdfium:::cpp_handle_is_valid(bitmap$ptr))
  expect_identical(
    pdfium:::cpp_doc_handle_counts(doc$ptr),
    c(annot = 0L, page = 0L, font = 0L, xobject = 0L)
  )
  expect_identical(
    pdfium:::cpp_library_handle_counts() - before,
    c(document = 0L, clip_path = 0L, bitmap = -1L)
  )
  # The page's document stays open.
  expect_identical(pdf_page_count(doc), 1L)
})

test_that("finalize_handle() leaves alone what the registry does not hold", {
  doc <- pdf_doc_open(fixture_path("shapes"))
  on.exit(pdf_doc_close(doc), add = TRUE)
  page <- pdf_page_load(doc, 1L)
  obj <- pdf_page_objects(page)[[1L]]
  type <- pdf_obj_type(obj)
  closed <- pdf_bitmap_new(2L, 2L)
  pdf_bitmap_close(closed)
  before <- pdfium:::cpp_library_handle_counts()

  # A page-object borrows its page's memory and is never registered; a
  # closed handle left the registry when it was closed.
  expect_null(finalize_handle(obj$ptr))
  expect_null(finalize_handle(closed$ptr))
  expect_null(finalize_handle(NULL))

  expect_identical(pdf_obj_type(obj), type)
  expect_true(is_open(page))
  expect_identical(pdfium:::cpp_library_handle_counts(), before)
})

test_that("finalizing a handle leaves .Random.seed alone", {
  withr::local_preserve_seed()
  bitmap <- pdf_bitmap_new(2L, 2L)
  before <- pdfium:::cpp_library_handle_counts()
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }

  rm(bitmap)
  invisible(gc())
  # Read before calling anything else: the other exports seed it.
  seeded <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)

  # The finalizer ran, and did not seed the generator.
  expect_identical(
    pdfium:::cpp_library_handle_counts() - before,
    c(document = 0L, clip_path = 0L, bitmap = -1L)
  )
  expect_false(seeded)
})

test_that("cpp_set_handle_finalizer() refuses anything but a function or NULL", {
  expect_error(
    pdfium:::cpp_set_handle_finalizer(1L),
    "^The handle finalizer must be a function or NULL\\.$"
  )
})

# Unloading pdfium with handles still around -----------------------
# Each scenario runs tests/testthat/scripts/unload-scenario.R in its
# own R process: while the handles carried C finalizers, every one but
# `exit` crashed R when they were collected or at exit.

#' Run the unload scenario `mode` in a fresh R process that loads the
#' pdfium this test run uses: installed, or from the source tree with
#' pkgload. Returns the output lines, with the exit status in
#' `attr(, "status")` (`NULL` on success).
unload_scenario <- function(mode) {
  path <- getNamespaceInfo("pdfium", "path")
  installed <- dir.exists(file.path(path, "Meta"))
  withr::with_envvar(
    c(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)),
    suppressWarnings(system2(
      file.path(R.home("bin"), "Rscript"),
      c(
        "--vanilla",
        shQuote(testthat::test_path("scripts", "unload-scenario.R")),
        mode,
        if (installed) "lib" else "src",
        shQuote(if (installed) dirname(path) else path),
        shQuote(fixture_path("minimal")), # nolint: object_usage_linter.
        shQuote(fixture_path("annotated")) # nolint: object_usage_linter.
      ),
      stdout = TRUE, stderr = TRUE
    ))
  )
}

#' What every scenario prints before its unload step: the pending
#' handles were dropped but not finalized, so they, and the open ones,
#' are still registered.
scenario_setup_lines <- c(
  "pending dropped: TRUE",
  "registered: document=6 clip_path=2 bitmap=2"
)

test_that("handles outlive unloadNamespace() and are collected safely", {
  out <- unload_scenario("unloadNamespace")
  expect_null(attr(out, "status"))
  expect_identical(
    as.character(out),
    c(scenario_setup_lines, "shared library loaded: FALSE", "survived")
  )
})

test_that("handles outlive detach(unload = TRUE) and are collected safely", {
  out <- unload_scenario("detach")
  expect_null(attr(out, "status"))
  expect_identical(
    as.character(out),
    c(scenario_setup_lines, "shared library loaded: FALSE", "survived")
  )
})

test_that("a reloaded pdfium leaves the handles of the unloaded one alone", {
  out <- unload_scenario("reload")
  expect_null(attr(out, "status"))
  expect_identical(
    as.character(out),
    c(scenario_setup_lines, "shared library loaded: TRUE", "survived")
  )
})

test_that("handles outlive the shared library unloaded without .onUnload", {
  # pkgload's fallback when unloadNamespace() fails: nothing released
  # the handles, and the PDFium they point into is gone.
  out <- unload_scenario("dll_unload")
  expect_null(attr(out, "status"))
  expect_identical(
    as.character(out),
    c(scenario_setup_lines, "shared library loaded: FALSE", "survived")
  )
})

test_that("a shared library loaded again leaves the unreleased handles alone", {
  out <- unload_scenario("dll_reload")
  expect_null(attr(out, "status"))
  expect_identical(
    as.character(out),
    c(scenario_setup_lines, "shared library loaded: TRUE", "survived")
  )
})

test_that("R's exit closes every handle while the shared library is loaded", {
  out <- unload_scenario("exit")
  expect_null(attr(out, "status"))
  expect_identical(
    as.character(out),
    c(
      scenario_setup_lines, "shared library loaded: TRUE", "survived",
      "at exit: document=0 clip_path=0 bitmap=0"
    )
  )
})

# One place attaches finalizers --------------------------------------
# make_handle() in src/handle_registry.cpp attaches finalize_handle(),
# an R function, to every handle (ADR-028, ADR-031), and only the load
# hooks set it. A C finalizer anywhere would be called after the shared
# library is unloaded.

c_finalizer_call <- "\\bR_RegisterCFinalizer(Ex)?\\s*\\("
weak_ref_call <- "\\bR_MakeWeakRef(C)?\\s*\\("
r_finalizer_call <- "\\bR_RegisterFinalizer(Ex)?\\s*\\("
reg_finalizer_call <- "\\breg\\.finalizer\\s*\\("
set_finalizer_call <- "\\bcpp_set_handle_finalizer\\s*\\("

#' The lines of `files` that match `pattern` once `comment` is removed
#' from each, as `"<file name>:<line number>"`.
calls_in <- function(files, pattern, comment) {
  lines <- lapply(files, readLines, warn = FALSE)
  file <- rep(basename(files), lengths(lines))
  line <- sequence(lengths(lines))
  code <- sub(comment, "", unlist(lines))
  hit <- grepl(pattern, code, perl = TRUE)
  sprintf("%s:%d", file[hit], line[hit])
}

test_that("make_handle() is the only code that attaches a finalizer", {
  src <- source_tree_path("src")
  skip_if(!nzchar(src), "src/ is only in a source tree")
  cpp <- list.files(src, pattern = "\\.(c|cc|cpp|h|hpp)$", full.names = TRUE)
  r <- list.files(source_tree_path("R"), pattern = "\\.[Rr]$", full.names = TRUE)

  expect_identical(calls_in(cpp, c_finalizer_call, "//.*$"), character())
  expect_identical(calls_in(cpp, weak_ref_call, "//.*$"), character())
  expect_identical(
    sub(":.*", "", calls_in(cpp, r_finalizer_call, "//.*$")),
    "handle_registry.cpp"
  )
  expect_identical(calls_in(r, reg_finalizer_call, "#.*$"), character())
  expect_identical(
    sub(":.*", "", calls_in(r, set_finalizer_call, "#.*$")),
    c("zzz.R", "zzz.R")
  )
})

test_that("the finalizer scan finds planted registrations, not comments", {
  dir <- withr::local_tempdir()
  cpp <- file.path(dir, "planted.cpp")
  writeLines(c(
    "// R_RegisterCFinalizerEx(ptr, fin, TRUE) in a comment",
    "void f(SEXP p, SEXP fun) {",
    "  R_RegisterCFinalizerEx(p, fin, TRUE);  // planted",
    "  R_MakeWeakRefC(p, R_NilValue, fin, TRUE);",
    "  R_RegisterFinalizer (p, fun);",
    "}"
  ), cpp)
  r <- file.path(dir, "planted.R")
  writeLines(c(
    "# reg.finalizer(e, f) in a comment",
    "f <- function(e) reg.finalizer(e, g, onexit = TRUE)",
    "cpp_set_handle_finalizer(NULL)"
  ), r)

  expect_identical(calls_in(cpp, c_finalizer_call, "//.*$"), "planted.cpp:3")
  expect_identical(calls_in(cpp, weak_ref_call, "//.*$"), "planted.cpp:4")
  expect_identical(calls_in(cpp, r_finalizer_call, "//.*$"), "planted.cpp:5")
  expect_identical(calls_in(r, reg_finalizer_call, "#.*$"), "planted.R:2")
  expect_identical(calls_in(r, set_finalizer_call, "#.*$"), "planted.R:3")
  # No match is no site, not an empty one.
  expect_identical(calls_in(r, c_finalizer_call, "#.*$"), character())
  expect_identical(calls_in(character(), c_finalizer_call, "#.*$"), character())
})

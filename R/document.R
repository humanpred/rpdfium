#' Open a PDF document
#'
#' Loads a PDF from disk or from an in-memory byte buffer. The
#' returned `pdfium_doc` carries an external pointer to a PDFium
#' `FPDF_DOCUMENT` handle along with a finalizer that calls
#' `FPDF_CloseDocument()` when the R object is garbage-collected.
#' Call [pdf_close()] explicitly when you need deterministic
#' release.
#'
#' Two input forms are supported. Pass `path` to load from disk
#' (via PDFium's `FPDF_LoadDocument`), or pass `source` for an
#' in-memory raw vector (via `FPDF_LoadMemDocument64`). The
#' in-memory path is useful for documents downloaded via
#' `httr2::resp_body_raw()`, `curl::curl_fetch_memory()`, or read
#' with `readBin()` straight into RAM. Exactly one of `path` or
#' `source` must be provided.
#'
#' @param path Character scalar. Path to a PDF file. The file must
#'   exist and be readable. Mutually exclusive with `source`.
#' @param source Raw vector containing the PDF byte stream. PDFium
#'   keeps an internal reference to the bytes for the document's
#'   lifetime, so the wrapper makes its own copy on the C++ side
#'   and releases it when the `pdfium_doc` is garbage-collected.
#'   Mutually exclusive with `path`.
#' @param password Optional password for encrypted PDFs. `NULL`
#'   (the default) passes no password to PDFium.
#' @return A `pdfium_doc` object.
#'
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   pdf_page_count(doc)
#'   pdf_close(doc)
#' }
#'
#' # Round-trip via raw bytes - useful for downloaded PDFs.
#' if (nzchar(fixture)) {
#'   bytes <- readBin(fixture, "raw", file.info(fixture)$size)
#'   doc <- pdf_open(source = bytes)
#'   pdf_page_count(doc)
#'   pdf_close(doc)
#' }
#' @export
pdf_open <- function(path = NULL, source = NULL, password = NULL) {
  validate_pdf_open_args(path, source, password)
  pwd <- if (is.null(password)) "" else password
  if (!is.null(source)) {
    ptr <- cpp_open_document_from_memory(source, pwd)
    return(new_pdfium_doc(ptr, "<raw bytes>"))
  }
  ptr <- cpp_open_document(path.expand(path), pwd)
  new_pdfium_doc(ptr, normalizePath(path, winslash = "/", mustWork = FALSE))
}

# Internal: validate the three pdf_open() arguments. Split into
# per-concern helpers so each stays under lintr's cyclocomp limit.
validate_pdf_open_args <- function(path, source, password) {
  validate_pdf_open_exclusivity(path, source)
  validate_pdf_open_password(password)
  if (!is.null(source)) {
    validate_pdf_open_source(source)
  } else {
    validate_pdf_open_path(path)
  }
  invisible()
}

validate_pdf_open_exclusivity <- function(path, source) {
  if (is.null(path) && is.null(source)) {
    stop("One of `path` or `source` must be provided.", call. = FALSE)
  }
  if (!is.null(path) && !is.null(source)) {
    stop("Pass exactly one of `path` or `source`, not both.",
         call. = FALSE)
  }
}

validate_pdf_open_password <- function(password) {
  ok <- is.null(password) ||
    (is.character(password) && length(password) == 1L &&
       !is.na(password))
  if (!ok) {
    stop("`password` must be NULL or a single non-NA character string.",
         call. = FALSE)
  }
}

validate_pdf_open_source <- function(source) {
  if (!is.raw(source)) {
    stop("`source` must be a raw vector.", call. = FALSE)
  }
  if (length(source) == 0L) {
    stop("`source` must be non-empty.", call. = FALSE)
  }
}

validate_pdf_open_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) {
    stop("`path` must be a single, non-NA character string.",
         call. = FALSE)
  }
  if (!nzchar(path)) {
    stop("`path` must not be the empty string.", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("PDF file not found: ", path, call. = FALSE)
  }
}

#' Close a PDF document
#'
#' Releases the underlying PDFium handle. Idempotent — calling `pdf_close()` on
#' an already-closed document is a no-op. The finalizer registered at
#' [pdf_open()] also calls this when the R object is garbage-collected, but
#' explicit close is recommended when handling many large documents or when a
#' subsequent operation needs to delete the source file (relevant on Windows).
#'
#' @param doc A `pdfium_doc` produced by [pdf_open()].
#' @return Invisibly returns `doc` with its underlying pointer marked closed.
#' @export
pdf_close <- function(doc) {
  if (!inherits(doc, "pdfium_doc")) {
    stop("`doc` must be a `pdfium_doc` (from `pdf_open()`).", call. = FALSE)
  }
  cpp_close_document(doc$ptr)
  invisible(doc)
}

#' Count pages in a PDF document
#'
#' Returns the number of pages in `doc`. Accepts either an open `pdfium_doc`
#' or a character path (in which case it opens and closes the document
#' internally — convenient for one-shot inspection).
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character scalar path.
#' @param password Optional password for encrypted PDFs when `doc` is
#'   a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return An integer scalar — the page count.
#'
#' @examples
#' fixture <- system.file("extdata", "fixtures", "minimal.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   pdf_page_count(fixture)
#' }
#' @export
pdf_page_count <- function(doc, password = NULL) {
  if (is.character(doc)) {
    handle <- pdf_open(doc, password = password)
    on.exit(pdf_close(handle), add = TRUE)
    return(cpp_page_count(handle$ptr))
  }
  if (!inherits(doc, "pdfium_doc")) {
    stop("`doc` must be a `pdfium_doc` or a path to a PDF file.", call. = FALSE)
  }
  if (!is_open(doc)) {
    stop("Document has been closed.", call. = FALSE)
  }
  cpp_page_count(doc$ptr)
}

#' Read one entry from a PDF's Info dictionary
#'
#' Wraps `FPDF_GetMetaText`. Returns the requested standard or
#' custom Info-dictionary tag value as a UTF-8 string, or `""`
#' when the tag is absent. Standard tags are `"Title"`, `"Author"`,
#' `"Subject"`, `"Keywords"`, `"Creator"`, `"Producer"`,
#' `"CreationDate"`, `"ModDate"`, `"Trapped"`. Custom tags from a
#' particular producer's Info dictionary are also accepted.
#'
#' @param doc A `pdfium_doc` from [pdf_open()].
#' @param tag Character scalar - the Info-dictionary key.
#' @return Character scalar, UTF-8 encoded. `""` if the tag is not
#'   present.
#' @seealso [pdf_doc_info()] for a single call that returns every
#'   standard tag plus the page count and file version.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   doc <- pdf_open(fixture)
#'   pdf_doc_meta(doc, "Producer")
#'   pdf_close(doc)
#' }
#' @export
pdf_doc_meta <- function(doc, tag) {
  if (!inherits(doc, "pdfium_doc")) {
    stop("`doc` must be a `pdfium_doc` (from `pdf_open()`).",
         call. = FALSE)
  }
  if (!is_open(doc)) stop("Document has been closed.", call. = FALSE)
  if (!is.character(tag) || length(tag) != 1L || is.na(tag) ||
        !nzchar(tag)) {
    stop("`tag` must be a single non-empty character string.",
         call. = FALSE)
  }
  cpp_doc_meta_text(doc$ptr, tag)
}

#' Document-level metadata for a PDF
#'
#' Returns the page count, the PDF file version, every standard
#' Info-dictionary entry, and POSIXct parses of the two date
#' fields. The shape mirrors `pdftools::pdf_info()` to ease
#' porting.
#'
#' Standard Info-dictionary entries are UTF-8 strings; missing
#' entries appear as `""`. Date strings come back in the PDF format
#' `"D:YYYYMMDDHHmmSS+HH'mm'"` and are also parsed into POSIXct
#' (UTC) in the `creation_date_parsed` and `mod_date_parsed`
#' slots; parses that fail return `NA`.
#'
#' @param doc A `pdfium_doc` from [pdf_open()], or a character path.
#' @param password Optional password for encrypted PDFs when `doc`
#'   is a path. Ignored when `doc` is already an open `pdfium_doc`.
#' @return A list with elements:
#'   * `page_count` - integer
#'   * `file_version` - integer; PDFium reports `10 * major + minor`
#'     (e.g. `17` for PDF 1.7)
#'   * `title`, `author`, `subject`, `keywords`, `creator`,
#'     `producer`, `creation_date`, `mod_date`, `trapped` - character
#'   * `creation_date_parsed`, `mod_date_parsed` - POSIXct (UTC),
#'     `NA` when the source date is empty or unparseable
#'
#' @seealso [pdf_doc_meta()] for arbitrary tag access,
#'   [pdf_parse_date()] for the date-parser used internally.
#' @examples
#' fixture <- system.file("extdata", "fixtures", "shapes.pdf",
#'                        package = "pdfium")
#' if (nzchar(fixture)) {
#'   info <- pdf_doc_info(fixture)
#'   info$page_count
#'   info$producer
#'   info$creation_date_parsed
#' }
#' @export
pdf_doc_info <- function(doc, password = NULL) {
  if (is.character(doc)) {
    handle <- pdf_open(doc, password = password)
    on.exit(pdf_close(handle), add = TRUE)
    return(pdf_doc_info(handle))
  }
  if (!inherits(doc, "pdfium_doc")) {
    stop("`doc` must be a `pdfium_doc` or a path to a PDF file.",
         call. = FALSE)
  }
  if (!is_open(doc)) stop("Document has been closed.", call. = FALSE)

  raw <- cpp_doc_info(doc$ptr)
  meta <- raw$meta
  c(
    list(
      page_count   = as.integer(raw$page_count),
      file_version = cpp_doc_file_version(doc$ptr)
    ),
    as.list(meta),
    list(
      creation_date_parsed = pdf_parse_date(meta[["creation_date"]]),
      mod_date_parsed      = pdf_parse_date(meta[["mod_date"]])
    )
  )
}

#' Parse a PDF date string into POSIXct
#'
#' PDF Info-dictionary dates use the format
#' `"D:YYYYMMDDHHmmSS+HH'mm'"` (PDF spec, section 7.9.4 - a
#' superset of ISO 8601). This helper extracts the date and time
#' fields and returns UTC `POSIXct`; the timezone offset suffix is
#' currently ignored (the date is treated as UTC). Truncated
#' strings (e.g. `"D:2024"`) parse to the longest valid prefix.
#'
#' @param s Character vector of PDF date strings.
#' @return `POSIXct` vector (UTC), same length as `s`. `NA` for
#'   empty or unparseable entries.
#' @export
pdf_parse_date <- function(s) {
  if (length(s) == 0L) return(as.POSIXct(character(0), tz = "UTC"))
  if (!is.character(s)) {
    stop("`s` must be a character vector.", call. = FALSE)
  }
  body <- sub("^D:", "", s, perl = TRUE)
  # Default suffix for fields the PDF date omits: Jan 1 00:00:00.
  # Aligned to the YYYY-only case, so the substring we splice in
  # must START at the position that corresponds to the first
  # missing field. E.g. for YYYYMM input the first missing field is
  # the day, so we splice from offset 3 of defaults ("01000000"),
  # not from offset 1 ("01010000" - which would set day=01 from a
  # source intended to default the *month*).
  # We build the POSIXct with ISOdatetime() rather than
  # strptime()+as.POSIXct() because the latter does not reliably
  # preserve the `tz = "UTC"` attribute through the POSIXlt -> POSIXct
  # conversion on some R configurations (the result silently reads
  # back in local time).
  defaults <- "0101000000"  # MMDDHHMMSS suffix for a YYYY-only input
  parse_one <- function(x) {
    if (is.na(x) || !nzchar(x)) return(as.POSIXct(NA, tz = "UTC"))
    digits <- regmatches(x, regexpr("^\\d{1,14}", x))
    if (length(digits) == 0L || !nzchar(digits) || nchar(digits) < 4L) {
      return(as.POSIXct(NA, tz = "UTC"))
    }
    needed <- 14L - nchar(digits)
    padded <- if (needed == 0L) {
      digits
    } else {
      start <- nchar(defaults) - needed + 1L
      paste0(digits, substr(defaults, start, nchar(defaults)))
    }
    ISOdatetime(
      year  = as.integer(substr(padded,  1L,  4L)),
      month = as.integer(substr(padded,  5L,  6L)),
      day   = as.integer(substr(padded,  7L,  8L)),
      hour  = as.integer(substr(padded,  9L, 10L)),
      min   = as.integer(substr(padded, 11L, 12L)),
      sec   = as.integer(substr(padded, 13L, 14L)),
      tz    = "UTC"
    )
  }
  do.call(c, c(list(as.POSIXct(character(0), tz = "UTC")),
               lapply(body, parse_one)))
}

# nocov start
.onLoad <- function(libname, pkgname) {
  cpp_init_library()
  invisible()
}

.onUnload <- function(libpath) {
  cpp_destroy_library()
  library.dynam.unload("pdfium", libpath)
  invisible()
}
# nocov end

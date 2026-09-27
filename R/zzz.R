# nocov start
.onLoad <- function(libname, pkgname) {
  cpp_set_handle_finalizer(finalize_handle)
  cpp_init_library()
  invisible()
}

.onUnload <- function(libpath) {
  cpp_destroy_library()
  cpp_set_handle_finalizer(NULL)
  library.dynam.unload("pdfium", libpath)
  invisible()
}
# nocov end

# Internal: the finalizer of every handle the package makes
# (make_handle() in src/handle_registry.cpp, ADR-031). .onLoad hands it
# to the shared library.
#
# R keeps a handle's finalizer until the handle is collected, even
# after the package's shared library is unloaded, so the finalizer
# cannot be C code in that library. This one calls into the library
# only while a copy of it is loaded, and looks the routine up by name
# on every call, because a symbol captured before an unload does not
# survive it. Without a loaded copy there is nothing to release:
# unloading the package released every handle first (ADR-028), and
# anything a handle still points to belongs to the PDFium that was
# unloaded with it. With a loaded copy, cpp_finalize_handle() releases
# the handle only if that copy registered it.
finalize_handle <- function(ptr) {
  if (is.loaded("_pdfium_cpp_finalize_handle", PACKAGE = "pdfium")) {
    .Call("_pdfium_cpp_finalize_handle", ptr, PACKAGE = "pdfium")
  }
  invisible()
}

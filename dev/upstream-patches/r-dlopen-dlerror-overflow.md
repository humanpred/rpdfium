Title for bugs.r-project.org:

  dyn.load failure overflows DLLerror buffer (unbounded strcpy of
  dlerror() in src/unix/dynload.c) — heap corruption observable on
  macOS-arm64

----------------------------------------------------------------------
Bug body (plain text — Bugzilla renders comments without GFM markdown,
so this is written to read cleanly without any formatting renderer;
code is indented four spaces, no fenced backticks, no tables, no
inline links):
----------------------------------------------------------------------


SUMMARY

R's POSIX dynamic-loader glue copies the string returned by dlerror()
into a fixed-size static buffer using strcpy(), with no length check
and no NULL check.  The destination buffer is 1000 bytes on non-Windows
platforms.  On macOS dyld 4 (macOS 12+ / R 4.5+), the error string for
a failed dlopen of a shared object with a missing transitive
dependency easily exceeds 1500 bytes because dyld lists every search
path it tried.  The resulting strcpy overrun corrupts BSS-adjacent
static storage.  On Apple Silicon the corruption manifests as a wild
function-pointer dereference some time later; on Linux glibc, dlerror
output is short enough that the overrun never fires in practice.


REPRODUCER

On a macOS-arm64 box with R 4.5 or later AND no XQuartz installed
(so /opt/X11/lib/libXrender.1.dylib is missing):

    R --vanilla -e 'grDevices::cairo_pdf("/tmp/x.pdf"); dev.off(); cat("survived\n")'

cairo_pdf triggers a dyn.load of grDevices/libs/cairo.so, which
declares libXrender.1.dylib as a hard load-time dep.  Without XQuartz
the dlopen fails and dlerror returns ~1.5 KB of paths.  R copies that
into a 1000-byte buffer via strcpy.  Subsequent R activity then either
crashes outright or produces non-deterministic corruption.  A GitHub
macos-latest runner (no XQuartz preinstalled) reproduces this every
time; the symptom on that environment is a SIGSEGV whose faulting
address bytes spell out ASCII fragments of the dlerror message ("uch
fil" = tail of "no such file or directory", or "rs/runne" = fragment
of /Users/runner/Library/Fonts/... from a search-path entry).


ROOT-CAUSE CITATION

src/unix/dynload.c lines 70-73 (current trunk, identical in 4.5 and
4.6 releases):

    static void getSystemError(char *buf, int len)
    {
        strcpy(buf, dlerror());
    }

Called from src/main/Rdynload.c line 877:

    handle = R_osDynSymbol->loadLibrary(path, asLocal, now, DLLsearchpath);

    if(handle == NULL) {
        R_osDynSymbol->getError(DLLerror, DLLerrBUFSIZE);
        return NULL;
    }

with the destination buffer at src/main/Rdynload.c lines 815-818:

    #ifdef Win32
    #define DLLerrBUFSIZE 4000
    #else  /* Not Windows */
    #define DLLerrBUFSIZE 1000
    #endif

    static char DLLerror[DLLerrBUFSIZE] = "";

Three issues in getSystemError:

  1. The "len" argument is accepted but completely unused.  strcpy
     writes until the source NUL, regardless of destination size.

  2. dlerror() may legitimately return NULL (per POSIX, when there is
     no error to report since the last call).  strcpy(buf, NULL) is
     undefined behavior and is a NULL-dereference on glibc and Apple
     libc.

  3. On macOS with dyld 4, dlerror strings routinely exceed 1500
     bytes when listing dyld search paths for a missing transitive
     dep.  The 1000-byte DLLerror buffer is overrun by 0.5 to 3 KB.


WHY LINUX DOES NOT SHOW THIS

Linux glibc returns terse dlerror strings like:

    libfoo.so.1: cannot open shared object file: No such file or directory

Typically under 200 bytes, well within the 1000-byte buffer.  The
strcpy bug is still present in source on Linux but the overrun does
not actually happen in normal operation.


WHY MACOS-ARM64 SHOWS IT AND MACOS-X86_64 DOES NOT (RELIABLY)

dyld 4 was introduced on macOS 12 and is used on both arm64 and
x86_64.  Both platforms produce equally verbose dlerror strings and
both overrun the 1000-byte buffer.  However, Apple Silicon's
allocator uses smaller size classes by default and is stricter about
metadata adjacent to BSS-style static storage.  The same overrun that
silently scribbles unused padding on x86_64 lands on live function
pointer slots on arm64 and surfaces as a SIGSEGV some milliseconds
later.


FAULTING-ADDRESS SIGNATURE

Two independent downstream R packages have hit this bug from
completely different call paths and reported the same address shape:

  * Address 0x656c696620686375 decodes (little-endian byte order) as
    the ASCII string "uch fil", the tail of "no such file or
    directory" from the dlerror output.

  * Address 0x656e6e75722f7372 decodes as "rs/runne", a substring of
    "/Users/runner/Library/Fonts/..." appearing in dyld's search-path
    list on a GitHub macOS runner.

Both addresses are not memory locations at all — they are bytes from
the overrun dlerror string that overwrote a function-pointer slot.
When R subsequently dereferences that slot, the bytes are interpreted
as a pointer and the process faults.

This signature has been independently reported as "memory corruption,
a stale string buffer overwriting a function-pointer slot" by package
authors investigating their own crashes.  The signature is a direct
fingerprint of THIS bug.


PROPOSED PATCH

Two-line fix.  The only behavior change is that long dlerror strings
get truncated (with NUL termination) instead of overflowing the
caller's buffer.  Patch against current trunk r-trunk:

    --- a/src/unix/dynload.c
    +++ b/src/unix/dynload.c
    @@ -67,9 +67,16 @@ attribute_hidden void InitFunctionHashing(void)
         R_osDynSymbol->getFullDLLPath = getFullDLLPath;
     }

     static void getSystemError(char *buf, int len)
     {
    -    strcpy(buf, dlerror());
    +    /* dlerror() may return NULL per POSIX, and on macOS dyld 4 may
    +       return strings of several KB when listing all dyld search
    +       paths for a missing transitive dep.  The unchecked strcpy
    +       overruns the caller's buffer (DLLerror[1000] in Rdynload.c). */
    +    const char *err = dlerror();
    +    if (err == NULL) {
    +        if (len > 0) buf[0] = '\0';
    +        return;
    +    }
    +    snprintf(buf, (size_t) len, "%s", err);
     }


COMPANION PATCH FOR WINDOWS

src/gnuwin32/dynload.c lines 131-151 has the same shape.  The
destination buffer on Windows is DLLerrBUFSIZE = 4000 and typical
FormatMessage output is short, so the overrun is much less likely to
actually fire — but the bug is the same and the fix is parallel:

    --- a/src/gnuwin32/dynload.c
    +++ b/src/gnuwin32/dynload.c
    @@ -129,16 +129,22 @@ static DL_FUNC getRoutine(DllInfo *info, char const *name);

     static void R_getDLLError(char *buf, int len)
     {
         LPSTR lpMsgBuf, p;
         char *q;
    +    char *end = buf + len - 1;
         FormatMessage(
             FORMAT_MESSAGE_ALLOCATE_BUFFER |
             FORMAT_MESSAGE_FROM_SYSTEM |
             FORMAT_MESSAGE_IGNORE_INSERTS,
             NULL,
             GetLastError(),
             MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
             (LPSTR) &lpMsgBuf,
             0,
             NULL
             );
    -    strcpy(buf, "LoadLibrary failure:  ");
    -    q = buf + strlen(buf);
    -    /* It seems that Win 7 returns error messages with CRLF terminators */
    -    for (p = lpMsgBuf; *p; p++) if (*p != '\r') *q++ = *p;
    +    int n = snprintf(buf, (size_t) len, "LoadLibrary failure:  ");
    +    q = buf + (n < len ? n : len - 1);
    +    /* Strip CR (Windows uses CRLF terminators) while staying bounded. */
    +    for (p = lpMsgBuf; *p && q < end; p++) if (*p != '\r') *q++ = *p;
    +    *q = '\0';
         LocalFree(lpMsgBuf);
     }


VERIFICATION

Compile-only on Linux:

    cd r-trunk
    ./configure
    patch -p1 < r-dlopen-overflow.patch
    make -C src/unix dynload.o

Runtime on macOS-arm64 R 4.5+ requires a missing transitive dep:

    # macos-latest GitHub runner has no XQuartz preinstalled, so
    # cairo.so cannot load libXrender.  Before the patch the
    # following reprex either segfaults or leaves R in a corrupted
    # state.  After the patch R emits the (truncated) warning and
    # continues.
    R --vanilla -e 'grDevices::cairo_pdf("/tmp/x.pdf"); dev.off(); cat("survived\n")'


CROSS-REFERENCES

The discovery and bisection happened in the rpdfium R package,
https://github.com/humanpred/rpdfium, on branch
claude/macos-bisect.  19 cuts narrowed the trigger from 133 candidate
tests down to a single one-line cairo_pdf call and ruled out (with
direct evidence) libpdfium symbol pollution and macOS two-level
namespace bugs as the cause.

A separate rpdfium commit, 6075f8e, encountered the SAME 0x...uch fil
address signature via a completely different code path (lazy
dyn.load of the grid namespace from a plot() call into a PDF
device).  That commit also attributed the crash to "memory corruption,
a stale string buffer overwriting a function-pointer slot" without
identifying the source.  Both observations collapse to this single
bug.

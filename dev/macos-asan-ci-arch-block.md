# macOS CI ASan: blocked on arm64 vs arm64e arch mismatch

## TL;DR

The plan to use ASan-instrumented PDFium under macOS CI to triage the
`cpp_struct_tree_page` "rs/runne" wild write (#44) is blocked on a
fundamental architectural conflict:

- The chromium-built `libclang_rt.asan_osx_dynamic.dylib` is universal
  `x86_64+arm64` (chromium's clang does NOT target arm64e — Apple's
  private pointer-authentication ABI).
- All macOS-arm64 system tools (`/bin/sh`, `/usr/bin/sed`,
  `/usr/bin/awk`, …) are universal `x86_64+arm64e`. On Apple Silicon,
  dyld picks the arm64e slice.
- When R is launched with `DYLD_INSERT_LIBRARIES=…asan…dylib` and then
  spawns any of those system tools, dyld in the arm64e child tries to
  load the asan dylib and terminates the child with SIGABRT:

  ```
  dyld[NNN]: terminating because inserted dylib
  '…libclang_rt.asan_osx_dynamic.dylib' could not be loaded:
  tried: … (fat file, but missing compatible architecture
  (have 'x86_64,arm64', need 'arm64e'))
  ```

R's startup forks arm64e helpers BEFORE its
`Renviron.site`-based unset of `DYLD_INSERT_LIBRARIES` is processed —
so the helpers die before the unset takes effect.

## What was tried

Eleven CI iterations on `claude/macos-asan-pdfium-vendored`:

| # | Run | Approach | Result |
|---|-----|----------|--------|
| 1 | 26615795943 | `codesign --force --sign -` adhoc | runtime flag dropped but R sees empty DYLD |
| 2 | 26616131326 | + entitlements (allow-dyld-environment-variables, …) | entitlements applied; R still sees empty DYLD |
| 3 | 26616407181 | + diagnostic step (printenv, codesign -dv /bin/sh) | confirmed bash and /bin/sh are platform binaries, dyld prunes DYLD\_\* |
| 4 | 26616778056 | + resign /tmp/sh from /bin/sh copy + patch wrapper shebangs | /tmp/sh CRASHED (arm64e shell, arm64 asan dylib) |
| 5 | 26617139218 | + use Homebrew bash (arm64-only) as wrapper shell | Homebrew bash not installed on runner |
| 6 | 26617361512 | revert to `#!/bin/sh`, inject `export DYLD` inside wrapper | wrapper exec'd Rscript.orig which loaded asan into arm64 R fine; smoke tests crashed |
| 7 | 26617589923 | + Renviron.site `DYLD_INSERT_LIBRARIES=` | arm64e children still die at dyld load before R processes Renviron |
| 8 | 26617812647 | + remove DYLD_INSERT_LIBRARIES from workflow env (use file marker) | sed children of R still die at dyld load |
| 9 | 26617987699 | + read PRELOAD from file | same |
| 10 | 26618212033 | + `hashFiles()` conditional for Malloc\* | YAML parse error |
| 11 | 26618274894 | + unconditionally drop Malloc\* on this branch | same dyld arch mismatch — Malloc\* wasn't the blocker |

Each iteration eliminated a candidate hypothesis. The remaining root
cause is the asan dylib's missing arm64e slice.

## Why the obvious workarounds don't work

- **Use Apple's `libclang_rt.asan_osx_dynamic.dylib`** (which IS
  universal arm64+arm64e): risks ABI version mismatch
  (`__asan_version_mismatch_check_v8` style symbol-not-found) at
  PDFium's `@rpath`-resolved load. Two ASan runtimes in one process
  don't coexist.
- **`lipo` an arm64e label onto chromium's arm64 slice**: arm64 code
  running as arm64e will trap on the first pointer-auth instruction
  that the process or its libraries emit. Not safe.
- **`unsetenv` from a tiny DYLD_INSERT shim**: ASan must be loaded
  FIRST so it can intercept malloc; unsetting after ASan loads
  doesn't help, because the env-var pruning has to happen before
  fork+exec of the arm64e child — and that's exactly when we need
  ASan still hooked.
- **Run everything as arm64 via `arch -arm64`**: `/usr/bin/arch` is
  itself an arm64e platform binary, so it re-hits the dyld
  termination at its own startup.
- **Custom adhoc-signed launcher with
  `posix_spawnattr_setarchpref_np(CPU_TYPE_ARM64)`**: would force
  children to arm64, but only works if we control every fork-and-exec
  R does — R itself uses libc's `fork()` and `execve()`, not
  `posix_spawn` with our attr.

## Paths forward (not pursued in this branch)

1. **Rebuild PDFium for arm64 with Apple's clang.** Apple's clang
   targets arm64e and ships an asan dylib with both arm64 and arm64e
   slices. Cost: build a separate branch of pdfium-binaries that
   doesn't pin chromium's toolchain. Not trivial — chromium's GN
   build assumes its own clang.
2. **lldb hardware watchpoint on R's CEntryTable destination.**
   Reproduce locally on an Apple Silicon Mac, set a watchpoint at
   the address derived from `image lookup -n CEntryTable`, run the
   test, get the writer's backtrace. Sidesteps the arch mismatch
   entirely.
3. **Static analysis of PDFium's macOS-specific code.** The bytes
   `"/Users/runner/"` (containing the "rs/runne" fragment) suggest a
   path string. Audit PDFium's macOS file/path handling
   (`CTFontDescriptor`, `realpath`, font caches) for unbounded copies
   into fixed-size buffers.

## State of the branch

`claude/macos-asan-pdfium-vendored` carries:
- The vendored ASan-instrumented `pdfium-mac-arm64.tgz` at
  `inst/pdfium-binaries/`
- The codesign + wrapper-injection step in `.github/workflows/R-CMD-check.yaml`
- The Renviron.site DYLD-unset step

This branch is **not for merge**. The codesign step works
(R's bin/exec/R and bin/Rscript get adhoc resigned with the
allow-dyld-environment-variables entitlement; R/Rscript wrapper
scripts inject the preload), but the test suite never runs because
arm64e helpers die at dyld load before R reaches user code.

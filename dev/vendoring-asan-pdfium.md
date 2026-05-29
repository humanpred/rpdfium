# Vendoring the ASan-instrumented PDFium for #44 triage

This is the next step after the
[billdenney/pdfium-binaries `claude/asan-mac-arm64` branch](https://github.com/billdenney/pdfium-binaries/tree/claude/asan-mac-arm64)
finishes its `build-one` workflow run and produces an
ASan-instrumented `pdfium-mac-arm64.tgz`. See
[dev/macos-segfault-triage.md](macos-segfault-triage.md) for
context.

## Step 1 — download the artifact

Once
[run #26613618731](https://github.com/billdenney/pdfium-binaries/actions/runs/26613618731)
(or whatever subsequent re-run) reaches `completed/success`:

```sh
# Replace <run-id> with the actual run that produced the artifact.
gh run download <run-id> \
  --repo billdenney/pdfium-binaries \
  --name pdfium-mac-arm64 \
  --dir /tmp/asan-pdfium
ls -la /tmp/asan-pdfium
```

Expected file: `pdfium-mac-arm64.tgz` (~30-80MB instead of the
non-ASan ~6MB).

## Step 2 — vendor the archive into rpdfium

`tools/download-pdfium.R` line 323 checks
`inst/pdfium-binaries/<archive_name>` BEFORE downloading from
the upstream bblanchon GitHub release. Drop the .tgz there:

```sh
cd ~/github/rpdfium
git checkout -b claude/macos-asan-pdfium-vendored claude/macos-arm64-debug-workflow
mkdir -p inst/pdfium-binaries
cp /tmp/asan-pdfium/pdfium-mac-arm64.tgz inst/pdfium-binaries/
git add inst/pdfium-binaries/pdfium-mac-arm64.tgz
```

The archive is binary, so add it without further fiddling. Note
that `.gitignore` does not exclude this file (we checked).

## Step 3 — wire ASan runtime env vars into macOS CI

`.github/workflows/R-CMD-check.yaml`'s `env:` block already has
`MallocGuardEdges`, etc. Add ASan-specific tunables next to those:

```diff
       env:
         GITHUB_PAT: ${{ secrets.GITHUB_TOKEN }}
         R_KEEP_PKG_SOURCE: yes
+        # ASan options for the macOS R CMD check run.
+        # halt_on_error=0 lets the test suite continue past one
+        # error so we see ALL bad writes, not just the first.
+        # detect_leaks=0 because R itself leaks via its GC arena.
+        # symbolize=1 + symbolize_inlined_frames=1 produce
+        # source-line backtraces.
+        ASAN_OPTIONS: ${{ matrix.config.os == 'macos-latest' && 'halt_on_error=0:detect_leaks=0:symbolize=1:symbolize_inlined_frames=1:strict_init_order=0:detect_odr_violation=0' || '' }}
+        UBSAN_OPTIONS: ${{ matrix.config.os == 'macos-latest' && 'halt_on_error=0:print_stacktrace=1' || '' }}
```

`strict_init_order=0` and `detect_odr_violation=0` matter here:
without them, ASan flags benign ODR overlaps between R packages
loaded into the same process, drowning the real signal.

## Step 4 — commit + push

```sh
git add inst/pdfium-binaries/pdfium-mac-arm64.tgz \
        .github/workflows/R-CMD-check.yaml
git commit -m "$(cat <<'EOF'
ci(macos): vendor ASan-instrumented PDFium for #44 triage

Drop bblanchon-style libpdfium.dylib built with `is_asan = true`
+ `is_lsan = false` (via the fork at
billdenney/pdfium-binaries#claude/asan-mac-arm64) into
inst/pdfium-binaries/ so tools/download-pdfium.R picks it up
instead of fetching the unsanitized upstream binary.

ASAN_OPTIONS / UBSAN_OPTIONS added to the macOS matrix cell so
the test suite runs through every error rather than halting on
the first.

This is the triage branch for humanpred/rpdfium#44 — not for
merge. When the wild write that corrupts R's static CEntryTable
fires, ASan will report a global-buffer-overflow with a real
arm64 backtrace pointing at PDFium's writer.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push -u origin claude/macos-asan-pdfium-vendored
```

## Step 5 — read the CI logs

`gh run watch <run-id>` until the macos-latest cell finishes.
Then:

```sh
gh run view <run-id> --job <macos-job-id> --log | grep -E "AddressSanitizer|SUMMARY: AddressSanitizer|global-buffer-overflow|stack-buffer-overflow|heap-buffer-overflow|use-after-free|in libpdfium"
```

The output should look something like:

```
==NNN== ERROR: AddressSanitizer: global-buffer-overflow on address ...
    #0 0x... in some_pdfium_function ...
    #1 0x... in CPDF_StructTree::... structtree.cpp:NNN
    #2 0x... in FPDF_StructElement_GetStringAttribute fpdf_structtree.cpp:NNN
    #3 0x... in cpp_struct_tree_page RcppExports.cpp:3103
    ...
```

That stack is the answer to "who corrupts CEntryTable".

## Notes

- The ASan PDFium binary is **triage-only**: it's much slower
  and bigger than the production binary. Once we identify and
  fix the underlying bug, this vendoring branch is discarded.
- If ASan reports something inside libpdfium, file an upstream
  bug to https://crbug.com/pdfium with the stack + the rpdfium
  reprex.
- If ASan reports nothing despite the crash still happening,
  the bug is either in a non-ASan-instrumented surface
  (Apple system libraries) or is hardware-specific to AArch64.

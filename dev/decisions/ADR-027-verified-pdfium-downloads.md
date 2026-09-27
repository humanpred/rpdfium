# ADR-027 — Verified, atomic PDFium downloads

- Status: Supersedes ADR-003's download-integrity consequence and ADR-006's rejection of hash pinning
- Date: 2026-09-27
- Deciders: Bill Denney

## Context

ADR-003 said a corrupted download "must fail cleanly with a
reproducible error, not produce a half-installed package", and that
"the download script uses a sentinel filename and re-extracts
atomically". ADR-006 rejected pinning a hash alongside the release tag
because "the download script verifies the archive integrity by
extraction success". Neither was true of `tools/download-pdfium.R`:

- It downloaded straight to the cache path,
  `tools::R_user_dir("pdfium", "cache")/<tag>-<archive>`. R's libcurl
  code deletes the destination only when nothing arrived with a
  non-200 status, so an interrupted transfer left a partial archive
  there. Every later install took the "Using cached archive" branch.
  Reproduced by serving half an archive from a local HTTP server.
- `utils::untar()` only *warns* when `tar` fails. Given a truncated
  archive, the script exited 0 and left a truncated `libpdfium.so` in
  `inst/lib` for the link step to fail on. Reproduced by truncating a
  cached copy of `pdfium-linux-x64.tgz`.

Integrity matters more now that r-universe binaries (ADR-026) bundle
whatever archive the build downloaded and serve it to every user.

## Decision

1. **Pin a SHA-256 per archive.** `tools/pdfium-checksums.txt` records
   the SHA-256 of every archive `detect_platform()` can request: Linux,
   Linux musl and Windows on x64, arm64 and x86, plus macOS on x64 and
   arm64. It also has a `release:` line naming the release the hashes
   belong to.
   - `tools/update-pdfium-checksums.R` regenerates the file by
     downloading each archive and hashing it.
   - For `chromium/8066` its output equals the `digest` GitHub
     publishes for each release asset.

2. **Tie the checksums to the pin.** `tools/download-pdfium.R` stops
   when the `release:` line differs from `tools/pdfium-version.txt`, or
   when the file has no entry for the archive it needs. A pin bump
   cannot ship with stale checksums: every install and every CI job
   fails until the file is regenerated.

3. **Verify every archive before unpacking it**, whether downloaded,
   cached or vendored (`PDFIUM_OFFLINE`).
   - With `tools::sha256sum()` (R >= 4.5.0), verification means an
     exact SHA-256 match.
   - Older R can only check that the archive lists completely with R's
     own `untar`, which catches partial downloads but not a
     substituted archive. The script says so in a message.

4. **Download atomically.** A download goes to a temporary file in the
   cache directory. It is renamed to the cache path only after it
   verifies, and the temporary file is deleted on every exit path.

5. **Recover or refuse:**
   - A cached archive that fails verification is deleted and
     downloaded again.
   - A vendored archive, or a fresh download, that fails verification
     stops the install with an error naming the expected archive and
     SHA-256.
   - Warnings from unpacking are errors.

6. `PDFIUM_BINARY_URL` stays for mirrors. A mirror must serve the
   identical file. Custom PDFium builds go through `PDFIUM_HOME`, which
   downloads nothing and so checks nothing.

## Consequences

- An interrupted download can no longer poison later installs, and a
  truncated archive can no longer install a truncated library.
- r-universe and CI builds, all on R >= 4.5, install only the exact
  pinned bytes.
- A PDFium bump has one more step, regenerating
  `tools/pdfium-checksums.txt` (`dev/architecture.md`, "PDFium bump
  procedure"). The install-time check enforces it.
- On R 4.2–4.4, a substituted but complete archive would not be
  caught. Supporting those versions with SHA-256 would need a
  dependency or an R implementation of SHA-256, which isn't worth it.
- A mirror that serves different bytes is refused.
- The regression tests run the script offline against synthetic
  archives, using `file://` URLs for the download path. They cover a
  truncated cache entry, a download that fails verification, a failed
  download, a mismatched vendored archive, checksums for another
  release, and an unpinned archive.

## Alternatives considered

- **A sentinel or marker file written after a successful download**
  (what ADR-003 described). It fixes the partial-download case but not
  a complete download of the wrong bytes, and it doesn't cover cached
  or vendored archives. Verification subsumes it.
- **Fetch the expected digest from the GitHub API at install time.**
  That trusts the same source, at the same moment, that served the
  archive, so it pins nothing. It also needs a JSON parser in
  `configure`.
- **Verify bblanchon's build attestation (`pdfium-attestation.json`).**
  This needs the `gh` CLI or a Sigstore client at install time, which
  configure can't assume. It would still be a stronger check for the
  maintainer to run when regenerating the checksums.
- **MD5 (`tools::md5sum()`, available in every R).** It would work on
  R < 4.5 as well, but it is a weaker hash, and GitHub publishes SHA-256
  digests to cross-check against.

## References

- ADR-003 (binary distribution), ADR-006 (PDFium pin), ADR-026
  (distribution through r-universe)
- `tools/download-pdfium.R`, `tools/update-pdfium-checksums.R`,
  `tools/pdfium-checksums.txt`
- R source: `src/modules/internet/libcurl.c`, `download_cleanup_url()`
  (a partial destination file is kept)

# ADR-006 — PDFium version pinning policy

- Status: Accepted
- Date: 2026-05-15

## Context

The bblanchon distribution publishes a new tarball on every PDFium
release (~weekly). Pinning is mandatory because:

- PDFium occasionally breaks ABI between releases (renamed enums,
  changed function signatures).
- Even when the ABI is stable, behaviour can shift in ways that
  invalidate our conformance fixtures (rendering, path approximation,
  text extraction).
- CRAN expects reproducible source builds — the same source tarball
  must produce the same binary every time.

## Decision

- The pinned PDFium release lives in a single file:
  **`tools/pdfium-version.txt`**. Its contents are exactly the
  bblanchon release tag (e.g. `chromium/7202`).
- Bumping = updating that file + re-running conformance fixtures and
  the test suite + writing a `NEWS.md` entry + ensuring
  `LICENSE.md` still reflects the bundled binary's license.
- Bump cadence: at least once per `pdfium` release cycle, more often
  if upstream ships a security fix relevant to PDF parsing.
- The bump procedure is documented in `dev/architecture.md` under
  "PDFium bump procedure" so it's actionable by anyone (not just the
  maintainer who's done it before).
- A bump is its own commit / PR / ADR-amendment if it changes API
  surface. If the bump is purely a security backport with no
  behavioural change, no new ADR is needed.

## Consequences

- Every install of a given `pdfium` release pulls the same PDFium
  binary, no matter when it runs.
- We accept the maintenance cost of bumping periodically.
- Out-of-band bumps for security reasons remain possible (push a
  patch release with only a `tools/pdfium-version.txt` update).
- The R CMD check matrix should re-run after every bump because
  PDFium ABI surprises sometimes affect only one platform.

## Alternatives considered

- **Pin to a hash, not a tag.** Bblanchon tags are immutable in
  practice, so the additional hash adds no integrity guarantee. The
  download script verifies the archive integrity by extraction
  success.
- **Always use latest.** Rejected — breaks CRAN reproducibility, and
  upstream ABI breaks would silently destabilize users.
- **Track multiple pins (current + LTS).** Rejected — doubles
  conformance-test surface for marginal gain.

## References

- [bblanchon/pdfium-binaries releases](https://github.com/bblanchon/pdfium-binaries/releases)
- ADR-003 (binary distribution)

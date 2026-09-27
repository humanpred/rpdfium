# r-universe evaluation

Should `pdfium` be released through [r-universe](https://r-universe.dev)?
`pdfium` is not going to CRAN (see
[ADR-026](decisions/ADR-026-no-cran-release.md)). It still needs a
channel that hands users prebuilt binaries. This document checks
r-universe against the one thing that makes `pdfium` unusual: at install
time, `configure` downloads a prebuilt PDFium library from GitHub. It
then lists the steps only the repository owner can take.

## Provenance

- Evaluation date: **2026-09-27**. r-universe changes often; re-check
  the sources below before acting on anything here that is more than a
  few months old.
- Documentation read at <https://docs.r-universe.dev>: *Set up your own
  universe*, *Binaries*, *Troubleshoot package builds*, *Package
  publishing rules*, *Individual package information*, *Using
  dependencies from R-universe*, *Relation to other networks*.
- Blog posts on <https://ropensci.org/blog/>:
  - *R-universe now builds WASM binaries for all R packages* (2023-11-17)
  - *R-universe now builds MacOS ARM64 binaries* (2024-01-14)
  - *rOpenSci News Digest, June 2025*, which announced Linux ARM64
  - *Windows ARM64 comes to R-universe* (2026-08-06)
- The documentation doesn't say whether builds have network access. For
  that question, and for the exact build commands, this evaluation reads
  the build system's source at these commits:

  | Repository | Ref | Commit | Commit date |
  |---|---|---|---|
  | `r-universe-org/workflows` (`build.yml`, `deploy.yml`) | `v3` | `b003a32b0037` | 2026-09-12 |
  | `r-universe-org/actions` (build matrix, per-OS build / check actions, `check.Renviron`) | `v12` | `551e158616d5` | 2026-09-20 |
  | `r-universe-org/build-source` (`entrypoint.sh`) | `master` | `f431176c372e` | 2026-09-15 |
  | `rstudio/r-system-requirements` (sysreqs rules) | `main` | `61f151593bd0` | 2026-07-23 |
  | `r-universe-org/cran-to-git` (auto-generated registries) | `HEAD` | `99d5871092cb` | 2026-09-27 |
  | `r-wasm/webr` (`libs/recipes`, the system libraries available to wasm builds) | `main` | (listing read on 2026-09-27) | |

- PDFium side: the asset list and archive layout of the
  `bblanchon/pdfium-binaries` release `chromium/8066` (published
  2026-09-21), which is the pin in `tools/pdfium-version.txt`.
- State of the `humanpred` universe on 2026-09-27: the
  `https://humanpred.r-universe.dev/api/packages` API, the
  `r-universe/humanpred` monorepo and its latest workflow run.

## Recommendation: r-universe fits

Publish `pdfium` on r-universe. It is the closest thing to what CRAN
would have given users: `install.packages()` gets a binary on Windows and
macOS, with no compiler and no download at install time.

It fits for four reasons.

1. **The configure-time download works on r-universe builders.** Every
   build runs on a GitHub-hosted runner with ordinary network access, as
   a plain `R CMD INSTALL --build`. So `configure` and `configure.win`
   fetch the pinned PDFium release exactly as they do on our own CI (see
   [Network access](#network-access-during-builds)).
2. **The binaries it produces are self-contained.** The installed
   package already carries `libpdfium` next to, or under, the package's
   own shared library, found through a relative RPATH on Linux and macOS
   and, on Windows, through the DLL search path that `library.dynam()`
   sets to the package's `libs` directory. A binary built on r-universe
   therefore loads on a user's machine that has no PDFium at all (see
   [How binaries carry libpdfium](#how-binary-packages-carry-libpdfium)).
3. **bblanchon ships a matching archive for every native platform
   r-universe builds**: Linux, macOS and Windows, each on x86_64 and
   arm64.
4. **It costs nothing and takes no build customization.** r-universe
   also gives us free build-and-check runs on platforms our own CI
   doesn't cover: Linux arm64, macOS x86_64, Windows arm64, and Windows
   on R-devel and R-oldrel.

Not everything works out of the box. These are expected results and
known gaps; none of them blocks the other platforms, because r-universe
deploys each platform's binary separately.

- **WebAssembly will not build.** No PDFium build exists that a webR
  package can link against. r-universe leaves wasm out of the check
  status, so this is cosmetic unless webR support is wanted later.
- **Windows arm64 most likely fails** at the import-library step of
  `tools/download-pdfium.R`. This matters more than the wasm gap: CRAN
  has no Windows arm64 binaries, so r-universe is the only binary source
  on that platform, and a source install fails at the same step.
- **Fix one thing before publishing any binary.** The installed package
  does not carry PDFium's licence notices, and a binary package
  redistributes PDFium (see [Risks](#risks)).

## How r-universe works

- **Registry.** The owner publishes a GitHub repository named
  `<owner>.r-universe.dev`, all lowercase. It contains a
  `packages.json`: a JSON array of `{"package", "url"}` entries, with
  optional `subdir`, `branch` and `metadata` fields. `url` must be a
  public Git URL, because the build servers run `git clone` on it. The
  repository has to be on GitHub; the packages themselves can live on
  any public Git host.
- **GitHub app.** The [r-universe app](https://github.com/apps/r-universe/installations/new)
  is installed on the same account. It asks for one permission, *read
  and write access to commit statuses*, which it uses to post a build
  status on package commits. The docs recommend installing it for "All
  repositories".
- **Monorepo.** The system creates `https://github.com/r-universe/<owner>`.
  That repository holds the package history and runs the builds in its
  Actions tab. Build logs are there, linked from the dashboard.
- **Cadence.** Git repositories and the registry are polled every
  hour. A change triggers a build, which usually appears on the
  dashboard within an hour. Every package is also rebuilt every 30
  days.
- **Which ref is built.** The default branch is built unless you say
  otherwise. `"branch"` can name any branch or tag, or be `"*release"`
  to follow the most recent GitHub release, using the same syntax as
  `remotes`.
- **One version per package.** A universe is a CRAN-like repository,
  so it holds one version of each package, and each GitHub account has
  a single universe.
- **No customization.** The docs state "customization is overall not
  possible". A package can only add a `bootstrap.R` or `.prepare` script
  that runs before `R CMD build`, and the universe can set
  `config.json`, whose only option is `cran_version`, a Posit snapshot
  date for dependencies. Environment variables such as `PDFIUM_OFFLINE`
  cannot be set. The one variable r-universe sets itself is
  `MY_UNIVERSE`, the universe URL.
- **Publishing is not gated on checks.** The docs say packages are not
  required to pass `R CMD check`, and the owner is responsible for
  quality control. The workflow uploads a platform's binary whenever it
  was built, even if the check on that platform reported errors.

## Build matrix

For a package with compiled code in a non-CRAN universe, the
`build-matrix` action (`r-universe-org/actions@v12`) produces this
matrix. The "expected" column is this evaluation's prediction for
`pdfium`, not something observed yet.

| Job | Runner | R versions | Arch | Our platform tag | Expected |
|---|---|---|---|---|---|
| Source package + vignettes (also builds the Linux release x86_64 binary) | `ubuntu-latest`, `build-source` container (Ubuntu 26.04) | release | x86_64 | `linux-x64` | OK |
| Linux | `ubuntu-24.04` / `ubuntu-24.04-arm`, `base-image:<r>` container (Ubuntu 26.04 "resolute") | devel, release | x86_64, arm64 | `linux-x64`, `linux-arm64` | OK. Our CI does not test arm64, so this is its first run. |
| macOS | `macos-15-intel` / `macos-15` | release, oldrel | x86_64, arm64 | `mac-x64`, `mac-arm64` | OK. `install_name_tool` comes with Xcode. Our CI does not test x86_64. |
| Windows | `windows-2025` | devel, release, oldrel | x86_64 | `win-x64` | OK. This is the path our `windows-latest` CI already exercises. |
| Windows | `windows-11-arm` | devel, release (no oldrel) | arm64 | `win-arm64` | **Likely fails** (see [Risks](#risks)) |
| WebAssembly | `ubuntu-24.04`, `build-wasm` container | release | wasm32 | none | **Fails**: no linkable PDFium |

In the `humanpred` monorepo's latest run, these resolved to R 4.6.1
(release), 4.5.3 (oldrel) and 4.7.0 (devel); the wasm job used webR's
R 4.6.0.

### What r-universe checks

Each native job runs:

```
R CMD INSTALL <pkg>.tar.gz --library=mylib --build
R CMD check <pkg>.tar.gz --library=mylib --install=check:install.log --no-manual --no-vignettes
```

with `R_CHECK_ENVIRON` pointing at r-universe's `check.Renviron`.

- This is **not** `--as-cran`. The settings include
  `_R_CHECK_CRAN_INCOMING_=FALSE`, `_R_CHECK_PKG_SIZES_=FALSE` (so the
  bundled `libpdfium` raises no size NOTE) and `_R_CHECK_TIMINGS_=5`.
  They also set `_R_SHLIB_BUILD_OBJECTS_SYMBOL_TABLES_=TRUE`, the
  setting that `src/install.libs.R` supports by copying `symbols.rds`.
- The check reuses the installed build (`--install=check:…`), so
  `configure` runs once per job.
- The *check* badge summarises vignettes plus R-release and R-devel on
  Windows, macOS and Linux. It ignores R-oldrel and wasm.

r-universe's check therefore complements our own gates; it doesn't
replace them. The `--as-cran` check in `.github/workflows/R-CMD-check.yaml`
and the 100% coverage gate stay the quality bar (ADR-008, ADR-026). Our
full `R CMD check` takes about 4–6 minutes per platform on GitHub runners,
well inside r-universe's 60-minute build and check step limits.

## How `pdfium`'s install path behaves on r-universe

### Network access during builds

The documentation does not mention network access during builds. The
build system's source settles it: r-universe builds can download.

- Every job runs on a GitHub-hosted runner. Nothing in `build.yml` or
  the per-OS actions restricts the network.
- The package is built with a plain `R CMD INSTALL … --build` on Linux,
  Windows and macOS, so `configure` / `configure.win` run as usual.
- r-universe loads its `check.Renviron` as the user Renviron for the
  build step (`R_ENVIRON_USER`). That file sets `LIBARROW_BINARY=true`
  under the comment "Arrow config. This is similar to NOT_CRAN=true",
  which tells arrow's `configure` to download a prebuilt `libarrow` at
  install time, the same pattern we use. Under a "Help some packages"
  comment it also sets `R_DEFAULT_INTERNET_TIMEOUT=150`.
- The 2026-08-06 Windows ARM64 post lists arrow among the big compiled
  packages r-universe builds.

The first build log is the final confirmation. Look for the line
`[pdfium] Downloading https://github.com/bblanchon/pdfium-binaries/…`
in each platform's install step.

### Which `libpdfium` the builders pick

`configure` tries four sources in order. The third step is easy to
forget, so all four are listed:

1. `PDFIUM_HOME`;
2. `pkg-config libpdfium`;
3. the standard prefixes `/usr/local`, `/usr`, `/opt/homebrew` and
   `/opt/local`;
4. the pinned bblanchon download.

On r-universe, steps 1–3 find nothing:

- `PDFIUM_HOME` cannot be set.
- No rule in `rstudio/r-system-requirements` mentions PDFium, so
  r-universe's `pak::pkg_sysreqs()` step installs nothing for our
  `SystemRequirements` line.
- Neither Ubuntu nor Debian packages PDFium, and Homebrew has no pdfium
  formula or cask.

So every builder reaches the download. `configure.win` only honours
`PDFIUM_HOME` before downloading. `PDFIUM_OFFLINE`, `PDFIUM_BINARY_URL`
and `PDFIUM_CACHE_DIR` can't be set on r-universe and aren't needed
there: fresh runners have no cache, so each job downloads one archive of
3.5–3.8 MB.

### The source package stays binary-free

The source job runs `R CMD build` with vignettes, which installs the
package and so downloads PDFium into `inst/` in the build tree. `R CMD
build` runs the package's `cleanup` script before that install and again
afterwards: `cleanup_pkg()` in R's `src/library/tools/R/build.R` ("And
finally, clean up again."). `cleanup` deletes `inst/include`, `inst/lib` and `inst/bin`,
so the source tarball r-universe serves contains no binary. This matches
the 504 KB tarball recorded in `dev/cran-readiness-audit.md`.
r-universe rejects source packages over 100 MB.

### How binary packages carry `libpdfium`

`R CMD INSTALL --build` packs the installed package directory, and that
directory already carries the library:

| Platform | Inside the binary package | How it's found at load time |
|---|---|---|
| Linux | `pdfium/libs/pdfium.so` and `pdfium/lib/libpdfium.so` (from `inst/lib`) | RPATH `$ORIGIN/../lib`, written into `src/Makevars` by `configure` |
| macOS | `pdfium/libs/pdfium.so` and `pdfium/lib/libpdfium.dylib`, with the install name rewritten to `@rpath/libpdfium.dylib` by `tools/download-pdfium.R` | RPATH `@loader_path/../lib` |
| Windows | `pdfium/libs/<arch>/pdfium.dll` and `pdfium/libs/<arch>/libpdfium.dll`, the latter copied there by `src/install.libs.R` | Windows does not look for a DLL's dependencies in that DLL's own directory. `library.dynam()` prepends `pdfium/libs/<arch>` to `PATH` and calls `dyn.load()` with it as `DLLpath`, and R's `R_loadLibrary()` wraps a plain `LoadLibrary()` in `SetDllDirectory(DLLpath)` |

All three paths are relative, so a binary works wherever it is
installed. The Windows binary also keeps a second, unused copy at
`pdfium/bin/libpdfium.dll`, because R copies all of `inst/`. That
roughly doubles the DLL's share of the package size, but it's harmless.
An `inst/bin` exclusion could drop it later.

### Platforms without a bblanchon binary: WebAssembly

The wasm job runs `rwasm::build()` inside r-universe's `build-wasm`
container. The package's `configure` runs natively on the Linux x86_64
build host, so `tools/download-pdfium.R` would fetch `linux-x64`, and
linking that ELF library into a wasm module fails.

bblanchon does publish `pdfium-wasm.tgz`, but its `lib/` holds only a
standalone Emscripten program (`pdfium.js`, `pdfium.wasm`,
`pdfium.html`): no static `libpdfium.a` and no side module a webR
package could link. webR packages can link only the system libraries
built by webR's recipes (`r-wasm/webr` `libs/recipes`: 43 recipes on
2026-09-27, including poppler but not PDFium).

Result: the wasm job fails and no wasm binary is published. The other
platforms are unaffected, because the deploy job runs `if: always()` and
uploads whatever built. The check badge ignores wasm.

Supporting webR would take an Emscripten static build of PDFium added
to the r-wasm recipes. That's out of scope for now.

## Vignettes, documentation and the pkgdown site

- **Built by r-universe.** The source job builds the vignettes during
  `R CMD build` (they need the package installed, which works because
  the download works). If vignettes fail it retries without them and
  flags the failure. The articles appear on the package page with their
  R Markdown sources. r-universe also renders the README, the NEWS file,
  an HTML reference manual and a PDF manual. Its NEWS renderer replaces
  `(development version)` with the DESCRIPTION version.
- **pkgdown.** r-universe builds pkgdown-style docs only for the
  rOpenSci organisation (its `ropensci` job runs only there). Keep the
  existing GitHub Pages site at <https://humanpred.github.io/rpdfium/>.

## How users install

```r
install.packages(
  "pdfium",
  repos = c("https://humanpred.r-universe.dev", "https://cloud.r-project.org")
)
```

- **Windows and macOS** get a binary: no compiler, and no PDFium
  download at install time. Windows arm64 users get one too once that
  build works. CRAN has no Windows arm64 binaries, and the arm64 R
  installers are patched to take binaries from r-universe instead.
- **Linux** gets the *source* package from that URL, so installing
  compiles it and downloads PDFium (a C++17 compiler and network access
  are needed). Ubuntu 26.04 users can get binaries from
  `https://humanpred.r-universe.dev/bin/linux/resolute-<arch>/<R x.y>/`
  (see the *Binaries* chapter of the docs).
- **Development version:** `remotes::install_github("humanpred/rpdfium")`
  keeps working and builds from source.

The docs suggest adding a version badge:
`[![r-universe version](https://humanpred.r-universe.dev/pdfium/badges/version)](https://humanpred.r-universe.dev/pdfium)`.

## The existing `humanpred` universe

`https://humanpred.r-universe.dev` already exists and serves 7
packages: `PKNCA`, `formulops`, `ggtibble`, `hidradenitis`,
`meddra.read`, `tabtibble` and `thinr`.

There is no `humanpred/humanpred.r-universe.dev` repository. The
monorepo's `.registry` submodule points at `r-universe-org/cran-to-git`,
which is r-universe's **auto-generated registry**: the CRAN packages
whose `URL` or `BugReports` link to the `humanpred` GitHub organisation.

The docs say a real `packages.json` "will take precedence, and the
build system will automatically switch over". **The new `packages.json`
must therefore list those seven packages as well as `pdfium`**, or they
drop out of `humanpred.r-universe.dev`. They stay available from CRAN
and `cran.r-universe.dev` either way.

The latest monorepo run *skipped* its "Set upstream commit status"
step. That step runs only when the app is installed, so the r-universe
app does not appear to be installed on `humanpred` yet.

## Setup steps for the owner

These steps need a `humanpred` organisation owner: they create a
repository and install a GitHub app.

0. **Before anything is published:** merge the change that installs
   PDFium's licence files with the package (planned as its own PR; see
   the first row of [Risks](#risks)).

1. **Choose which ref r-universe builds.**
   - *Default branch* (omit `branch`): every push to `main` is built and
     published, and the builds double as free CI on the platforms listed
     under [Recommendation](#recommendation-r-universe-fits). `main`'s
     `DESCRIPTION` still says `Version: 0.1.0`, although `main` has moved
     well past the 0.1.0 CRAN submission (commit `e121bc9`; 0.1.0 was
     never tagged). Bump it to a development version such as
     `0.1.0.9000` first, so users can tell a build of `main` from a
     release.
   - *Releases only* (`"branch": "*release"`): r-universe builds the most
     recent GitHub release. The repository has **no releases or tags
     yet**, so publish one first. Its tag's `DESCRIPTION` version must be
     the version you mean to release.
   - Suggested: start on the default branch so the first builds shake out
     the Windows arm64 and wasm results. Switch to `*release` once
     releases are being cut, if r-universe should serve only released
     versions.

2. **Create the public repository `humanpred/humanpred.r-universe.dev`**
   with this `packages.json`. The first seven entries preserve the
   universe's current contents; the `url`s are the ones in
   `cran-to-git`'s `humanpred.json`.

   ```json
   [
     {"package": "formulops",    "url": "https://github.com/humanpred/formulops"},
     {"package": "ggtibble",     "url": "https://github.com/humanpred/ggtibble"},
     {"package": "hidradenitis", "url": "https://github.com/humanpred/hidradenitis"},
     {"package": "meddra.read",  "url": "https://github.com/humanpred/meddra.read"},
     {"package": "PKNCA",        "url": "https://github.com/humanpred/pknca"},
     {"package": "tabtibble",    "url": "https://github.com/humanpred/tabtibble"},
     {"package": "thinr",        "url": "https://github.com/humanpred/thinr"},
     {"package": "pdfium",       "url": "https://github.com/humanpred/rpdfium"}
   ]
   ```

   For releases only, the last entry becomes
   `{"package": "pdfium", "url": "https://github.com/humanpred/rpdfium", "branch": "*release"}`.

3. **Install the r-universe GitHub app** on the `humanpred` organisation
   at <https://github.com/apps/r-universe/installations/new>, choosing
   "All repositories". The only permission it requests is commit
   statuses (read and write).

4. **Wait for the first build.** It usually takes no more than an hour.
   Watch <https://github.com/r-universe/humanpred/actions>, then open
   <https://humanpred.r-universe.dev/pdfium>.

5. **Verify.**
   - The package page's check table should show OK for the source
     package, Linux (x86_64 and arm64, release and devel), macOS (x86_64
     and arm64, release and oldrel) and Windows x86_64 (devel, release
     and oldrel).
   - Windows arm64 and wasm are expected to fail. Keep their logs: they
     confirm or refute the analysis in [Risks](#risks).
   - Each platform's install log should show the `[pdfium] Downloading`
     line.
   - On a clean Windows or macOS machine with no Rtools or Xcode,
     install the package with the command above, then run
     `pdfium::pdf_page_count(pdfium::pdf_doc_open(system.file("extdata", "fixtures", "minimal.pdf", package = "pdfium")))`.

6. **Check the README.** It already gives the r-universe command
   (added together with this document). Until step 4 has produced a
   package, that command reports that `pdfium` is not available.

Optional: r-universe documents a workflow a repository can run itself
(`uses: r-universe-org/workflows/.github/workflows/build.yml@v3`, set up
with `universe::use_universe_action()`). It runs the exact r-universe
build on pull requests.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Binary packages lack PDFium's licence notices.** `tools/download-pdfium.R` copies only `include/`, `lib/` and `bin/` from the archive, dropping `LICENSE` and `licenses/`. `licenses/` holds PDFium's BSD-3 notice plus FreeType, ICU, libjpeg-turbo, libpng, zlib, lcms, OpenJPEG, Abseil, AGG, simdutf, fast_float and, on Linux, LLVM libc. An r-universe binary *redistributes* `libpdfium`, and several of these licences, BSD-3 among them, require the notices to accompany binary redistributions. `LICENSE.md` also points at an `inst/pdfium-binaries/LICENSE` that is never created, and calls bblanchon's scripts Apache-2.0 when the repository is MIT. | Certain today | Licence compliance | Copy the notices into the installed package before the first publish. Planned as a separate change. |
| **Windows arm64 build fails.** Native aarch64 R on Windows reports `Sys.info()[["machine"]] == "aarch64"`, so we fetch `pdfium-win-arm64.tgz`, which exists. `fix_windows_dll()` then needs `dlltool`. r-universe installs Rtools at `C:\rtools45-aarch64` and sets only `RTOOLS45_AARCH64_HOME`, but `find_dlltool()` searches only `PATH`, `RTOOLS45_HOME` / `RTOOLS_HOME` / `C:/rtools45` and x86_64 subdirectories. It also calls `dlltool` without a machine flag, and LLVM's `llvm-dlltool` needs `-m arm64`. The same function hard-codes the Rtools45 layout, so a machine with only Rtools46 would also depend on `PATH`. | High | Windows arm64 users can't install from binary *or* source, and r-universe is their only binary source. The check badge, which shows the worst R-release / R-devel result on Windows, may show the failure. | Held follow-up: teach `find_dlltool()` the aarch64 layout and machine flag, verified on a `windows-11-arm` runner. The first r-universe build log is the cheapest confirmation. |
| **WebAssembly build fails.** | Certain | No webR support; cosmetic otherwise, since the check badge ignores wasm. | Accept for now. Support would need an Emscripten static PDFium in the r-wasm recipes. |
| **Download integrity isn't verified.** The archive is not checked against a pinned hash. r-universe would bake whatever it downloaded into binaries served to every user. | Low | High if it ever happens | Pin SHA-256s per platform archive (bblanchon also publishes `pdfium-attestation.json`). Planned with the download-cache fix. |
| **The download fails during a build** (GitHub outage). | Low | That platform's binary isn't updated. | None needed: the next commit or the 30-day rebuild retries. |
| **bblanchon deletes or re-tags `chromium/8066`.** | Low | Every build fails. | ADR-006 pin-bump process. `PDFIUM_BINARY_URL` can't be set on r-universe, so a mirror would need a code change. |
| **A system `libpdfium` on a builder shadows the download** (configure steps 2–3). | Very low today: no distro package, formula or sysreqs rule | That binary would link a library users don't have. | Re-check if Ubuntu or Homebrew ever package PDFium. |
| **Version labelling.** `main` says `0.1.0` although it is past the 0.1.0 submission. | Certain if the default branch is tracked without a bump | Users can't tell builds apart. | Step 1 above. |
| **The existing seven packages drop out of the universe.** | Certain if `packages.json` omits them | Those packages disappear from `humanpred.r-universe.dev`. | Use the `packages.json` above. |
| **Name collision.** | None today: no CRAN or archived CRAN `pdfium`, and `pdfium` is not a reserved r-universe name | If a CRAN `pdfium` appeared, r-universe would treat it as official and warn. | None needed. |

## Alternatives considered

- **GitHub source installs only** (`remotes` / `pak`). This works
  today, but every user compiles the package (Rtools on Windows, Xcode
  command-line tools on macOS) and downloads PDFium at install time.
  There are no binaries.
- **[R-multiverse](https://r-multiverse.org/)**: a community-curated
  production repository built on r-universe's infrastructure. It gives
  release semantics with a review process. It could be a later step once
  releases are regular; not evaluated in depth here.
- **A self-hosted CRAN-like repository** (e.g. `drat` plus binaries
  built in our own CI). It reproduces what r-universe gives for free,
  at our own maintenance cost.

# Third-party pin builds — materialize, build, audit

**Status:** Authoritative (2026-08-03).  
**Audience:** developers (human or automated) who pin, rebuild, or audit external libraries used by this project.  
**Quick start:** `third_party/README.md`  
**Example:** `third_party/example/`  

**Supersedes (layout/process):** overlapping “agent handoff” and first-party-only wording in older notes.  
**Still useful:** library host multi-worktree process for long-lived product repos; this doc is the **pin contract** for every dependency under `third_party/`.

---

## 1. Problem

Prebuilt native/Java binaries without a clear **source SHA + recipe + artifact** path fail third-party review and make “why is this `.so` different?” unanswerable. Custom flags, patches, and Docker stacks must be **reproducible as a process**, even when the binary is not bit-for-bit reproducible.

---

## 2. One layout for every library

Ownership (“we maintain this GitHub repo” vs “pure upstream”) does **not** change the tree. Co-developing a library next to the app is a **method**, not a second layout.

```text
third_party/
  README.md                 # do-this-first
  fetch-deps                # materialize + optional build orchestration
  get-artifacts             # lock-driven copy src outputs → artifact/
  example/                  # hello-world pin
  <lib>/
    lock.yaml
    SOURCE.md
    patches/                # optional; only applied by fetch-deps
    build                   # executable; may invoke scripts/
    scripts/
    src/                    # git tree @ pin (when materialized)
    artifact/               # stable names committed for consumers
```

| Path | Role |
|------|------|
| `lock.yaml` | Pin identity and collection rules |
| `src/` | Authoritative **source** after materialize (git: status/dirty work) |
| `src/build/`, `src/bin/` (or upstream-equivalent) | Scratch / build outputs; created by build script; **not** the app pin |
| `artifact/` | What the app (or other consumer) **commits and links**; present after clone without `src` |
| `patches/` | Diffs applied **only** at materialize |

Dirty `src` **only** from fetch-deps patches is acceptable. Other dirt means the tree is not a clean pin.

---

## 3. Workflow

### Default (audit / reproduce)

```bash
./third_party/fetch-deps ro <lib>      # checkout pin, apply patches, chmod sources RO
./third_party/fetch-deps build <lib>   # run build script(s), get-artifacts → artifact/
```

### Iterate a build (sources already there)

```bash
# edit scripts or flags; re-run build
./third_party/<lib>/build
./third_party/get-artifacts <lib>
```

### Co-develop library + app

```bash
./third_party/fetch-deps rw <lib>      # writable branch (often named like the app branch)
# edit under third_party/<lib>/src (or host worktree)
./third_party/fetch-deps build <lib>
# bump pin when ready: lock.yaml + artifact/ + commit on the app branch
```

### Local full clone (`GIT_HOME`)

Optional. If `~/git/<lib>` (or `GIT_HOME/<lib>`) exists, fetch-deps may materialize `src` as a **worktree** or fetch objects from that host so the app tree does not hold a full object store. **Joe Random without GIT_HOME** still works via clone/fetch of the pin SHA (optional `--depth`).

---

## 4. Responsibilities

| Actor | Does | Does not |
|-------|------|----------|
| **fetch-deps** | Materialize `src` @ `git_sha`; apply `patches/`; set RO (unless lib requires RW); run build entrypoints from lock; call **get-artifacts** | Invent build flags; leave app binaries only under `src` |
| **build script(s)** | Given already-patched tree: make build/output dirs writable; compile; write products under `src/…` (or paths lock understands) | Apply patches; write final pin names under `artifact/` (optional helper ok; get-artifacts is normative) |
| **get-artifacts** | Read lock; resolve `from` globs; **pick** if needed; copy to stable `artifact/` paths | Materialize sources |

### RO sources

Default after `fetch-deps ro`: tree is read-only. Build scripts **must** create/chmod only the directories they need (e.g. `src/build`, `src/bin`). Prefer upstream’s normal out-of-source layout when it exists (OpenCV: CMake binary dir ≠ source root).

If a library **cannot** build from RO sources, set in lock (example field):

```yaml
requires_writable_src: true
```

fetch-deps then leaves `src` writable after materialize (still a git tree at the pin + patches).

---

## 5. `lock.yaml` (pin contract)

Identity and collection — not machine-specific paths like “this laptop’s GIT_HOME”.

```yaml
name: opencv
git_ssh: "git@github.com:opencv/opencv.git"
git_https: "https://github.com/opencv/opencv.git"
git_sha: "71d3237a093b60a27601c20e9ee6c3e52154e8b1"
git_describe: "4.10.0"
track_branch: "4.10.0"
reproducible: false          # true | false | unknown
build_time: tens_of_minutes  # minutes | tens_of_minutes | few_hours | tens_of_hours
requires_writable_src: false
build:
  - ./build                  # one or more entries; default ./build if omitted
artifacts:
  - path: artifact/jni/arm64-v8a/libopencv_java4.so
    from: src/bin/arm64-v8a/libopencv_java4.so
  - path: artifact/jni/x86_64/libopencv_java4.so
    from: "src/build/x86_64/**/libopencv_java4.so"   # glob example
    pick: newest             # optional; default newest when glob matches multiple
consumer_note: "…"
```

### Artifact `from` + `pick`

| Field | Meaning |
|-------|---------|
| `path` | Stable destination under the lib dir (committed pin surface) |
| `from` | Source under the lib dir after build (may be a **glob**) |
| `from_src` | Legacy alias: path relative to `src/` only |
| `pick` | When multiple files match: `newest` (mtime, **default**), `sort`, `sort-n`; **`smart`** reserved (version tiers — see project TODO) |

If `from` is not a glob, `pick` is ignored.

**Example with version/timestamp in the path:**

```yaml
  - path: artifact/hello.bin
    from: "src/bin/hello-*.bin"    # e.g. hello-1.2.3.bin or hello-20260803T120000.bin
    pick: newest                  # mtime among matches
```

### Reproducible builds

`reproducible: true` means same pin + patches + build scripts are expected to produce **bit-for-bit** identical artifacts (rare). Most pins use `false` or `unknown`. When `true`, artifact sha256 is a strong audit check; when `false`, sha256 still detects accidental change/tamper of the committed file.

---

## 6. Profiles (examples of options, same contract)

| Library | Materialize | Build notes | build_time (typical) |
|---------|-------------|-------------|----------------------|
| **opencv** | Upstream tag/SHA | Script passes CMake/NDK flags; 16KB pages; slim modules; both arm64 + x86_64 | tens_of_minutes |
| **rclone** | Upstream + **patches** (wrapper) | Script builds Kotlin/gomobile-friendly lib (± Docker) | tens_of_minutes – few_hours |
| **paddle** | Fork commit (upstream + stacked PRs) | Docker + old deps + many flags + model post-process | few_hours – tens_of_hours |
| **remotetable / extractmail** | Often `rw` while co-developing | Host tests + AAR; later pure consumer bumps | minutes – tens_of_minutes |

Near-term work may edit remotetable/extractmail **and** the app in one environment; the pin layout stays the same. After features stabilize, the app only bumps SHA + artifacts like any other consumer.

---

## 7. extractmail as a second consumer

extractmail vendors remotetable under its own `third_party/`. The same **fetch-deps / get-artifacts / lock** ideas apply. Until tooling is published as a standalone *libpin* tree, **copy** the scripts and short README into that consumer (not a live nested git dependency).

---

## 8. Future: `pick: smart` (not required for MVP)

Best-to-worst version-like tiers on **filename/path text** (then fall back to mtime): release `x.y.z` → `x.y.z-rcN` → git-describe `x.y.z-N-gHASH`, plus other common schemes. Tracked as project TODO.

---

## 9. Related docs

| Doc | Role |
|-----|------|
| `third_party/README.md` | Short “what to do” |
| `third_party/example/` | Runnable hello-world pin |
| `docs/reference/FIRST_PARTY_LIBS.md` | Product-lib hosts (remotetable/extractmail GitHub), multi-worktree orchestration |
| This file | **Pin/build/audit contract for all third_party libs** |

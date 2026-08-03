# third_party — pin, materialize, build, collect artifacts

**Audience:** any developer (human or automated) who clones this tree and needs to **audit, reproduce, or tweak** custom builds of external libraries.

**Detail:** `docs/reference/THIRD_PARTY_PIN_BUILDS.md`  
**Toy example:** `third_party/example/`  
**Future tooling name (if extracted):** *libpin* — name appears free on GitHub / PyPI / npm as of 2026-08-03; leave in-tree until OpenCV + rclone + paddle + remotetable/extractmail profiles all work.

---

## What to do (happy path)

```bash
# From the VehicleExpenses worktree root (or any consumer that vendors this layout)
./third_party/fetch-deps ro opencv          # materialize src @ lock SHA, apply patches, sources RO
./third_party/fetch-deps build opencv       # run build script(s), then collect → artifact/
# or, when iterating a build only:
./third_party/get-artifacts opencv          # copy from src build outputs → artifact/ using libpin.toml
```

Same pattern for `remotetable`, `extractmail`, `rclone`, `paddle` (when pins are real).

| Step | Tool | Responsibility |
|------|------|----------------|
| 1. Materialize | `fetch-deps ro` / `rw` | `src/` as a **git** tree at pin; **apply `patches/`**; default RO tree |
| 2. Build | `./build` (or scripts listed in lock) | Create/chmod **writable** `src/build`, `src/bin` (or upstream-equivalent dirs); compile; leave products under `src/…` |
| 3. Collect | `get-artifacts` (called by `fetch-deps build`) | Copy products into **stable** `artifact/` names using lock |

**Committed pin surface for the app:** `libpin.toml` + `artifact/*` (+ build scripts + patches).  
**Not committed on a fresh clone:** usually `src/` contents (materialize with fetch-deps). `src` must still be a **real git checkout** when present (submodule, worktree, or clone) so `git status` works.

---

## Layout (every library)

```text
third_party/<lib>/
  libpin.toml       # pin identity + [[artifact]] + build_time + reproducible?
  SOURCE.md       # human narrative (profiles, gotchas)
  patches/        # optional; applied only by fetch-deps
  build           # executable entry (may call scripts/)
  scripts/        # optional helpers
  src/            # materialized sources (git tree @ pin)
  artifact/       # STABLE outputs VE (or other consumers) use
  status.local    # gitignored — ro/rw mode (not the pin)
```

Optional local accelerator: full clone under `GIT_HOME` (e.g. `~/git/opencv`). fetch-deps may attach a **worktree** at `src/` so history stays outside the app tree. **Correctness does not require GIT_HOME.**

---

## Build-time t-shirt sizes (`build_time` in lock / SOURCE)

| Value | Meaning |
|-------|---------|
| `minutes` | Roughly under ~10 minutes |
| `tens_of_minutes` | ~10–60 minutes |
| `few_hours` | ~1–4 hours |
| `tens_of_hours` | long Docker / full SDK rebuilds |

---

## Profiles (same layout, different build stories)

| Profile | Example | Materialize | Build |
|---------|---------|-------------|--------|
| Options-only | **opencv** | pin SHA | Script + flags (ABIs, 16k pages, module list) |
| Patch + wrap | **rclone** | pin + patches | Script (± Docker) → Kotlin/gomobile lib |
| Docker + models | **paddle** | pin (fork commit) | Containers, old toolchains, model post-steps |
| Active co-dev | **remotetable / extractmail** (near term) | often `rw` | Develop lib + app together; still collect to `artifact/` |

---

## Commands (fetch-deps)

```text
./third_party/fetch-deps ro [NAME…]     # default: pin + patches + RO
./third_party/fetch-deps rw [NAME…]     # writable branch for co-development
./third_party/fetch-deps build [NAME…]  # build + get-artifacts
./third_party/fetch-deps status [-v]
./third_party/get-artifacts [NAME…]     # collect only (iterate builds)
```

`--depth N` — optional shallow clone (not default). See `fetch-deps --help`.

---

## Do not

- Apply patches in the **build** script (fetch-deps already did).
- Leave app-consumed binaries **only** under `src/` (they vanish without materialize).
- Treat `~/git/...` as the pin if `src/` was never materialized.
- `git add` a full non-submodule dump of library sources into the app repo.

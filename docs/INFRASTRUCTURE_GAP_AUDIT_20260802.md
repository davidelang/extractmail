# Infrastructure gap audit — first-party libs bootstrap (2026-08-02)

## Why “matched intent” was wrong

The post-bootstrap verify checked a **narrow** green bar:

- GitHub repos exist and are public  
- `~/git/{remotetable,extractmail}` exist with remotes and thin policy files  
- agent-4 has a `third_party/` **skeleton** and docs  

It did **not** check whether an agent could:

1. **Populate `third_party/*/src`** (fetch-deps)  
2. **Run multi-agent tooling** on library hosts (real launchers, eng-log, TODO, filters, merge drivers)  
3. **Develop product on `master`** (full seed trees)  

Calling that “bootstrap succeeded / matches intent” after hours of planning was **incorrect**. The planning intent was end-to-end infrastructure for independent library development **and** VE consumption. We delivered **scaffolding** and labeled it done.

### Root causes of the miss

1. **Definition of done** = “files and remotes exist,” not “agent-4 can fetch src and a lib agent can run.”  
2. **`fetch-deps` was knowingly a stub** (NOTE-only without submodule + real SHA) and still counted as a shipped tool.  
3. **Multi-agent v2 pack** stayed as templates under orchestration; **no install script** ran against `~/git/*`.  
4. **Verify scripts** did not fail when `src` was empty or launchers were stubs.  
5. Orchestrator **cannot write** `dlang:dlang` library trees; install was deferred to “human later” without a single complete install path.

This document is the corrective checklist. Prefer it over chat memory.

---

## Intended vs actual (honest)

| Intended | Actual after first bootstrap | Status |
|----------|------------------------------|--------|
| Public GitHub repos | Yes | Done |
| Local multi-worktree hosts | Yes (orch + master worktree) | Partial |
| Product seed on **master** | Thin (policy + partial); product often only on orch root | **Gap** |
| `third_party/` on VE + docs | Yes | Done |
| **fetch-deps populates src** | Stub no-op | **Gap → fix in pack tools/** |
| Locks with real SHAs | TBD | **Gap** |
| Submodules or co-dev src | None | **Gap** |
| Real run-grok* (no rules in launcher) | Echo stubs | **Gap** (pack has generic launchers) |
| eng-log wrapper + chattr +a | Missing on libs | **Gap** |
| todo-append/close | Missing | **Gap** |
| .gitattributes + merge drivers | Missing on libs | **Gap** |
| project.config + filters on libs | Missing | **Gap** |
| setup_agent / update-rules / remove_worktree | Missing | **Gap** |
| VE filters on agent-4 | Present (unrelated to fetch-deps) | OK for VE |
| Library agents independent of VE sandbox | Not really runnable | **Gap** |

---

## What is *not* a filter/smudge issue

VE `filter.manage-configs` stamps `@@TOKEN@@` in selected scripts. It does **not** populate `third_party/*/src`.  
Empty `src` = fetch-deps design + TBD pins, not broken smudge on agent-4.

Library hosts still need project.config + filters **for launchers/perms**, once real launchers are installed — separate from fetch-deps.

---

## Corrective install path

As **dlang**, from VE orchestration root:

```bash
./install-first-party-infra.sh
```

That script (when complete) must:

1. Install fixed `fetch-deps` into agent-4 `third_party/`  
2. Run fetch-deps `--write-lock` for remotetable + extractmail and assert `src` exists  
3. Install multi-agent v2 pack into both library hosts (policy, launchers, wrappers, filters, merge drivers, project.config)  
4. Repair product seed onto `master/` worktrees  
5. `install-merge-drivers` + `chattr +a` eng-log  
6. Run `./verify-first-party-infra.sh` and **exit non-zero** if any critical check fails  

Until that script is green, **do not** claim infrastructure is ready for project work.

---

## Verification bar (must all pass)

1. `./third_party/fetch-deps --write-lock remotetable extractmail` → `src` git checkouts exist  
2. `git -C third_party/remotetable/src rev-parse HEAD` succeeds  
3. `~/git/remotetable/run-grok-planner` does **not** contain the word `stub`  
4. `~/git/remotetable/append-to-engineering-log` executable  
5. `~/git/remotetable/.gitattributes` has eng-log merge driver lines  
6. `~/git/remotetable/project.config` exists  
7. `~/git/remotetable/master` has seed product dirs (e.g. go/ or conformance/ per seed)  
8. Verify script exit code 0  

---

## Apology / process change

Future “done” for infra = **verify script green**, not “directory listing looks right.”  
Orchestrator reports **gaps explicitly** when templates are not installed.

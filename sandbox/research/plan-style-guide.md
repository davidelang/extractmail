# Sandbox Plan Style Guide (library host)

Full rules: `AGENT_MANDATES.md`.

## Filename

```text
<descriptive-kebab>-YYYYMMDD-HHMM-plan.md
```

Minutes required when stamping. New contract → new file + new minutes.

## Status

DRAFT → APPROVED → CODE LANDED | BLOCKED — needs replan

Do not nag humans about stale DRAFT after they ordered execute.

## Size (soft)

~2–8 KB typical; split if >12 KB.

## Structure

Context · Recommended Approach · Critical Files · Existing utilities · **Phased Execution** (what + files + observable success) · Verification / **Acceptance**.

**Compliance:** one line citing `standard-plan-compliance-block.md` — **do not paste**.

Name **verify** commands explicitly until a stable `./verify` exists (compile + tests).

## Do not

- Mandate Acknowledgment in plans  
- Paste STANDARD BLOCK  
- Ultra-micro phases except post–inning recovery  
- Repeat per-phase gate checklist (STANDARD BLOCK covers once)

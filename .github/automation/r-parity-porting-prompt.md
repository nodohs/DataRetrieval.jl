# Porting Prompt For Coding Agent

You are porting upstream changes from `DOI-USGS/dataRetrieval` (R dataRetrieval) into this Julia repository.

## Scope
- Previous upstream SHA: `none`
- Latest upstream SHA: `acbed0e3346742cfda1c885a51f05aefd7796bd2`
- Source of truth for changed files and commits: `.github/automation/r-sync-report.md`

## Required Work
1. Port behavior changes from R into Julia implementation under `src/`.
2. Add or update tests under `test/`.
3. Update docs in `docs/src/` and `README.md`.
4. Keep Julia API naming conventions and avoid introducing R-only wrappers unless explicitly required.
5. Run tests and include key results.

## Constraints
- Prefer minimal, focused patches.
- Preserve existing public APIs unless upstream parity requires an addition/change.
- Do not revert unrelated local changes.

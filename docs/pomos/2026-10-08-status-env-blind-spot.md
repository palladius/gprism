# PostMortem: Untracked `.env` Blind Spot in `gprism status` (GHI #9)

## Executive Summary

On 2026-09-12 (and confirmed 2026-10-08), a critical user experience blind spot was reported in `gprism`: when modifying `.env` in a repository where `.env` was not explicitly listed in `.git-privatize.list` (such as `pupurabbu-3d`), `gprism status` reported `[ ✅ Sync ]` for other tracked files and gave zero indication that `.env` had un-synced modifications or was untracked. This created a false sense of security for developers assuming their environment secrets were protected and backed up in Google Cloud Secret Manager.

## Impact

Developers modifying `.env` secrets believed their changes were backed up and in sync when running `gprism status`, while in fact `.env` was never uploaded or monitored. If local copies were deleted, machines changed, or containers spun up from clean clones, developers suffered secret loss or missing configurations. No secret data was leaked or corrupted, but synchronization guarantees broke silently.

## Background

`gprism` is a Git-Privatize replacement that encrypts and stores sensitive configuration files in Google Cloud Secret Manager and Google Cloud Storage. Tracking is coordinated via `.git-privatize.list` at the root of git repositories (Carlessian Constitution Article 8). Commands like `gprism status` compare local files against remote secrets and report synchronization states (`✅ Sync`, `⚠️ M`, `❌ Miss`).

## Root Causes and Trigger

1. **Trigger**: Developer edited `.env` in `pupurabbu-3d` and executed `gprisma st`, expecting to see `.env` flagged as modified (`⚠️ M`) or tracked.
2. **Strict File List Isolation**: `gprism status` obtained candidate files exclusively from `list_files`, which read only lines from `.git-privatize.list`.
3. **Empty Scaffold in `init` & Single File `add`**: `gprism init` created an empty `.git-privatize.list` via `FileUtils.touch` without populating `.env`. Furthermore, adding a different secret file via `gprism add private/key.json` did not prompt or seed `.env`.
4. **Lack of Untracked Secrets Detection**: Unlike `git status` which explicitly surfaces untracked files (Constitution Article 11: "Git Semantics"), `gprism status` remained completely silent about `.env` presence unless already in `.git-privatize.list`.
5. **False "Sync" Illusion**: If all files explicitly in `.git-privatize.list` were synchronized, `gprism status` concluded without warnings, falsely conveying that the entire repository's secret state was healthy.

## Detection and Monitoring

The issue was detected manually by Riccardo Carlesso while verifying secret syncing in `pupurabbu-3d`. He observed `gprisma st` reporting `[ ✅ Sync ]` despite substantial local modifications in `.env`.

## Mitigation

1. **Issue Tracking**: Filed GitHub Issue [#9](https://github.com/palladius/gprism/issues/9) detailing reproduction, root cause, and intended architectural resolution.
2. **Untracked Secret Detection in `status`**: Modified `gprism status` to actively scan for `.env` (and remote Secret Manager counterparts) when not explicitly opted-out via `#.env`. If untracked, it is surfaced with `[ ⚠️ Untracked ]` and a clear warning.
3. **Self-Healing `--fix`**: Integrated auto-fix into `gprism status --fix` to append untracked secret files directly to `.git-privatize.list` and `.gitignore`.
4. **Auto-Seeding in `init` & `add`**: Updated `gprism init` to automatically include `.env` in `.git-privatize.list` if present on disk. When creating `.git-privatize.list` for the first time via `add`, `.env` is also automatically staged.
5. **Auto-Tracking on Push**: When pushing a file (`gprism push <file>`), it is automatically ensured inside `.git-privatize.list`.

## Lessons Learned

### Things That Went Well
* The Carlessian Constitution already provided explicit principles (Articles 8, 9, 10, and 11) for Git semantics, root configuration, and self-healing commands (`--fix`), making the architectural solution clear and aligned.
* Unified diff (`show_diff`) and modified state badge (`⚠️ M`) logic in `gprism` were already functional once files were detected.

### Things That Went Poorly
* `gprism status` assumed `.git-privatize.list` was an exhaustive registry, neglecting untracked files on disk.
* `gprism init` touched an empty file without scaffolding the primary secret file (`.env`).

### Where We Got Lucky
* The user noticed the omission before losing any unpushed credentials during a machine wipe or repo clone.

## Action Items

| Action Item | Owner | Priority | Type | Bug_id |
|-------------|-------|----------|------|--------|
| File GitHub Issue documenting bug & repro | ricc@ | **P1** | Detect | [#9](https://github.com/palladius/gprism/issues/9) |
| Implement untracked secret detection in `gprism status` | ricc@ | **P1** | Mitigate | [#9](https://github.com/palladius/gprism/issues/9) |
| Add auto-fix (`status --fix`) for untracked `.env` | ricc@ | **P2** | Mitigate | [#9](https://github.com/palladius/gprism/issues/9) |
| Auto-seed `.env` in `gprism init` and initial `gprism add` | ricc@ | **P2** | Prevent | [#9](https://github.com/palladius/gprism/issues/9) |
| Add automated regression test for untracked `.env` detection | ricc@ | **P1** | Prevent | [#9](https://github.com/palladius/gprism/issues/9) |

## Timeline

Day: **2026-09-12** TZ=Europe/Rome
* `10:39:10`: `private/gitlab-deployer-key.json` pushed to Secret Manager in `pupurabbu-3d`.
* `12:39:28`: `.git-privatize.list` committed with only `gitlab-deployer-key.json`.
* `13:55:00`: Developer edits `.env` with new secrets and executes `gprisma st`. <== <span style="color:red">Start of Incident</span>
* `13:55:48`: `gprisma st` outputs `[ ✅ Sync ]` and ignores `.env`. Developer discovers silent failure. <== <span style="color:red">Incident Detected</span>

Day: **2026-10-08** TZ=Europe/Rome
* `08:48:00`: Deep codebase investigation reveals `list_files` strictly parses `.git-privatize.list`.
* `08:55:09`: GitHub Issue [#9](https://github.com/palladius/gprism/issues/9) filed on `palladius/gprism`.
* `09:05:00`: Implementation of untracked `.env` detection, `--fix` auto-repair, and `init` auto-seeding. <== <span style="color:red">Mitigation</span>
* `09:15:00`: Automated test suite passed, version bumped to 0.3.7, and postmortem finalized. <== <span style="color:red">End of Incident</span>

## IMPORTANT

This PostMortem is AI-generated and verified following SRE incident management guidelines.

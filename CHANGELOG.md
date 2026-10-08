# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.7] - 2026-10-08
### Fixed
- Fixed critical blind spot where `.env` and untracked secret files were silently excluded from `gprism status`, misleading users with a false `[ ✅ Sync ]` state when secrets were modified or unbacked up (fixes #9).
- `gprism status` now detects untracked secret files (`.env`) and displays an explicit `⚠️ Untracked` badge alongside sync state and remote status.
- Added self-healing auto-fix via `gprism status --fix` (and `--git-ignore`) to automatically add untracked secret files to `.git-privatize.list` and `.gitignore`.
- Updated `gprism init` to automatically seed `.env` into `.git-privatize.list` if present on disk.
- Updated `gprism add` to automatically stage `.env` when creating `.git-privatize.list` for the first time.
- Updated `gprism push` to automatically register successfully pushed secret files into `.git-privatize.list`.

## [0.3.6] - 2026-09-09
### Added
- Added `--version`, `-v`, and `version` commands/flags to display current gprism version.

### Changed
- Propagated `GPRISM_IDENTITY` to `ENV['CLOUDSDK_CORE_ACCOUNT']` so GCP commands correctly authenticate with the configured identity.
- Improved error handling for GCP Secret Manager and GCS: explicit detection and reporting of `PERMISSION_DENIED`, authentication token expiration/revocation (`invalid_grant`), or missing credentials rather than silently reporting remote secrets as missing.

## [0.3.5] - 2026-08-20
### Added
- Enabled `gprism push` and `gprism pull` to accept specific file arguments instead of only `--all`.
- Added usage instructions and hints showing target files to standard help and AI-help screens.

## [0.3.4] - 2026-07-27
### Added
- Added `gprism show <filepath>` (aliases: `inspect`, `diff`, `describe`) to display a detailed HERE vs THERE comparison including MD5 checksums, Secret Manager version counts, remote timestamps, and unified diffs.
- Added git-like modification hint in `gprism status` when local files differ from remote.

### Changed
- Upgraded `gprism status` to report a git-like modified status (`⚠️ M`) when a local secret differs from remote instead of generic `Mod` or `OK`.
- Calling `gprism` without arguments now defaults to printing `gprism --help`.

## [0.3.3] - 2026-07-21
### Added
- Added `--force` flag to `gprism push` to enable re-uploading unmodified local files (e.g. to fix remote metadata).
- Added `--git-ignore` and `--fix` flags to `gprism status` to automatically handle un-ignored and wrongly tracked secrets in `.gitignore`.

### Changed
- Improved `gprism status` warnings by aggregating them into a single summary block.
- Updated git-related suggestions in `status` to use root-relative paths (`cd $(git rev-parse --show-toplevel)`), supporting execution from subfolders.

## [0.3.0] - 2026-07-20
### Added
- Added `gprism init` command to bootstrap `.env.template`, `.git-privatize.list`, and create the GCS bucket.
- Added GCS bucket offloading for payloads larger than 60KB. They are securely uploaded to GCS and Secret Manager holds a `GPRISM_GCS_URI=` pointer instead.
- Improved `list` and `status` commands to differentiate between secrets stored natively in Secret Manager and those offloaded to GCS.

## [0.2.3] - 2026-07-15
### Added
- Added automated test to ensure folder additions correctly fail with an error.

## [0.2.2] - 2026-07-15
### Changed
- **Forbid Folder Additions:** The `gprism add` command now explicitly checks if the provided path is a directory and returns an error message instead of failing silently or down the line.

## [0.2.1] - 2026-07-15
### Changed
- Improved `gprism list` output format to properly display repository names and append a list of matching file names at the end.
- Updated `gprism status` formatting to use a 💾 emoji and color-code filenames based on their file type.

## [0.2.0] - 2026-07-14
### Added
- Aliases `ls` for `list` and `st` for `status`.
- MD5 and timestamp-based conflict detection when running `push` or `pull`.
- Colored terminal warnings for conflicting local/remote states.
- Re-enabling write permissions on files after running `gprism add`.

### Changed
- `gprism pull` now creates files with read-only (`chmod 0400`) permissions as a guardrail.
- Status output explicitly highlights when a tracked local file is missing and suggests pulling it.

## [0.1.0] - 2026-07-14
### Added
- Initial release.
- Core CLI commands `add`, `push`, `pull`, `status`.
- Local `.git-privatize.list` and `.env` config file handling.
- Readme substitution and `.gitignore` integration to prevent secret leaks.

## 0.3.1
- Upgraded `gprism st` to show sync state and diffs.
- Added `--download-binaries` flag.

## 0.3.2
- BUGFIX: gprism now operates on the git root directory (like `git`) instead of the current folder. All paths are resolved relative to the git root.
- BUGFIX: Removed useless `.env.template` creation during `gprism init`.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

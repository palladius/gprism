# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

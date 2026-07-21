# THE CARLESSIAN CONSTITUTION

1. **Deterministic Naming:** Secrets MUST strictly follow `<env>--<repo-slug>--<file-slug>`.
2. **Unified Syncing:** `pull -a` and `push -a` MUST handle SM, GS, and GP seamlessly.
3. **No Silent Failures:** `gcloud` calls MUST use `Open3.capture3` and bubble up errors. *Why? Because silently swallowing network/auth errors creates a false sense of success. If a user encrypts a file, but the key fails to backup to GCP, the user permanently loses their data when they delete the plaintext!*
4. **Three Pillars:** Data lives in Secret Manager (🔑 SM), GCS (🪣 GS), or Offline Encrypted (🔐 GP).
5. **Security First:** `gprism add` or `encrypt` MUST automatically `.gitignore` plaintext files.
6. **Automagical DX:** The CLI should be deterministic, single-command, and zero-friction.
7. **Visual Simplicity:** Keep statuses to 1 emoji + 2 letters (e.g. 🔑 SM) for a clean UI.
8. **Configuration Files:** Gprism strictly uses `~/.config/gprism/config.yaml` for global configs. Project-level files (`.git-privatize.list` for tracking, and `.env` for secrets) MUST reside in the **GIT ROOT**, not anywhere else.
9. **Self-Healing Commands:** The CLI should empower users with auto-fix capabilities (e.g. `status --fix`) rather than just printing raw copy-paste commands, providing frictionless "one-click" error recovery.
10. **Subdirectory Resilience:** Any git-related or fix commands executed by the CLI MUST run relative to the git root (e.g. `cd $(git rev-parse --show-toplevel)`), ensuring deterministic behavior regardless of the user's current directory.
11. **Git Semantics:** Core commands like `push`, `pull`, and `status` MUST mimic Git's look, feel, and semantics. This means operating consistently from the repository space (not folder space), accepting familiar arguments, and providing intuitive CLI feedback.

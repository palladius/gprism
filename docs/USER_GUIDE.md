# Gprism User Guide

Gprism is a magical CLI tool to sync environment secrets and encrypted files seamlessly using Google Cloud Platform (Secret Manager & GCS) combined with offline encryption.

## Configuration

Gprism manages the `.git-privatize.list` config file automatically when you run `gprism add`. The architecture stores global project metadata in `~/.config/gprism/config.yaml` and repository-level mappings in `[repo]/.git-privatize.list`.

## Core Commands

### 1. `gprism add <file>`
Pushes a local file (e.g. `.env`) into GCP.
- Small files go straight to **Google Secret Manager (🔑 SM)**.
- Large files (like `.mp3` or `.bin`) are sent to **Google Cloud Storage (🪣 GS)**, while Secret Manager simply stores the URI pointer to the bucket (`GPRISM_GCS_URI=gs://...`).
- Auto-adds the file to your `.gitignore`.

### 2. `gprism encrypt <file> [--yes]`
Ideal for offline secrets or repo-bound files you want to track securely in Git.
- Symmetrically encrypts `<file>` into `<file>.gprenc`.
- Generates a unique encryption key for the repo and saves it to GCP Secret Manager. 
- You can commit `<file>.gprenc` to git, knowing it can only be decrypted by those who have access to the GCP Secret Manager key.
- Auto-adds the plaintext `<file>` to `.gitignore`.

### 3. `gprism status` (or `gprism st`)
Displays a visual status of your secrets with emoji indicators:
- `🔑 SM`: Managed by Secret Manager
- `🪣 GS`: Managed by Google Cloud Storage
- `🔐 GP`: Managed via Offline Encryption (`.gprenc`)
- `💻 Local` / `❌ Local`: Tells you if the file exists on your disk.
- `☁️ Remote` / `❌ Remote`: Tells you if the secret is backed up to GCP.
- **Auto-Fixing**: Run `gprism status --git-ignore` (or `--fix`) to automatically add untracked secrets to `.gitignore` and remove erroneously tracked secrets from the git cache (`git rm --cached`).

### 4. `gprism push [file]`
- Pushes local files (e.g. `.env`) into GCP.
- Supports the `--force` flag to force re-uploading your local file to GCP, even if the content hash hasn't changed (useful to fix broken remote metadata).

### 5. `gprism pull -a`
The ultimate unified sync command.
When you clone a repository on a new machine, simply run `gprism pull -a`:
1. It downloads all secrets defined in `.git-privatize.list` from Secret Manager and GCS.
2. It auto-discovers any `.gprenc` files in your repository.
3. It fetches the repository's encryption key from GCP and seamlessly decrypts them into their plaintext equivalents.

## Summary of Emojis
* 🔑 **SM**: Google Cloud Secret Manager
* 🪣 **GS**: Google Cloud Storage
* 🔐 **GP**: Locally Encrypted File (Key stored in SM)
* 💻 **Local**: File is present locally
* ❌ **Local**: File is missing locally (Run `pull -a` to fix!)
* ☁️ **Remote**: Secret is backed up on GCP
* ❌ **Remote**: Secret is missing from GCP (Run `push` to fix!)
* 📝 **Readme**: Documented in `README.md`

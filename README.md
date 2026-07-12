# Gprism: Git Privatize in Secret Manager

`gprism` is a lightweight, secure tool designed to manage private configuration files (like `.env` or other secrets) inside Git repositories without checking them into version control.

Instead of keeping secrets in a central private Git repository, `gprism` encrypts your secret files symmetrically using **AES-256-CBC** and stores them in **Google Cloud Secret Manager**.

When a file is privatized, the original file is added to `.gitignore` and replaced with a `.readme` breadcrumb file. This breadcrumb file contains the necessary metadata and commands for humans or AI agents to easily retrieve and decrypt the secret.

## Features

- **GCP Secret Manager Backend**: Secure, durable cloud storage.
- **Symmetric Encryption**: Secrets are encrypted locally (via AES-256-CBC + PBKDF2 key derivation) using a passphrase *before* uploading to GCP. Without the passphrase, your secrets are unrecoverable.
- **macOS Keychain Integration**: Cache your cryptographic password securely in the macOS Keychain under service `gprism`.
- **Environment Namespacing**: Namespace your secrets (e.g. `dev`, `prod`) to prevent accidental overwrites between staging/development environments.
- **Breadcrumb Documentation**: Leaves a `<file>.readme` (e.g., `.env.readme`) containing the restoration instructions.
- **Centralized Secrets List**: Define secrets in `.git-privatize.list` for bulk pushing and pulling using the `--all` flag.
- **Automatic Restore**: Scans the repository for breadcrumbs and automatically pulls down missing local secrets.
- **Clean `.gitignore` Integration**: Automatically appends the secret files to `.gitignore`.

## Requirements

1. **Ruby**: Installed on your system (standard library components only, no external Gem dependencies).
2. **gcloud CLI**: Installed, configured, and authenticated.

## Installation

Clone the repository and link or copy the executable to your `PATH`:

```bash
cd /path/to/gprism
ln -s "$(pwd)/bin/gprism" /usr/local/bin/gprism
```

## Configuration

Create a configuration file at `~/.config/gprism/config.yaml` or `~/.gprism.yaml`:

```yaml
# ~/.config/gprism/config.yaml
gcp_project_id: "palladius-genai"
gcp_account: "palladiusbonton@gmail.com"
environment: "dev" # e.g. dev, staging, prod (used for secret namespacing)
```

## Usage

Run the commands from the root or any subdirectory of a Git repository:

### 1. Check Status
Scan the repository for breadcrumb files, compare them with local files and GCP Secret Manager status:
```bash
gprism status
```

### 2. Privatize and Push secrets
Encrypt and upload secret files:
```bash
# Push specific files
gprism push .env

# Push all files listed in .git-privatize.list
gprism push --all
```
This will:
- Read password from macOS Keychain (if available) or prompt you to enter it (and offer to save it in Keychain).
- Encrypt file using AES-256-CBC.
- Create the secret `gp--[env]--[host]--[owner]--[repo]--env` in Secret Manager if it doesn't exist.
- Upload the encrypted ciphertext.
- Add secret file to `.gitignore`.
- Write `<file>.readme` containing metadata and manual restore instructions.

### 3. Restore and Pull Files
Restore all missing secrets in the repository using the breadcrumb files:
```bash
# Auto-detect missing files from breadcrumbs and pull
gprism pull

# Pull specific files
gprism pull .env

# Pull all files configured in .git-privatize.list
gprism pull --all
```

## Key Management & Keychain

All file contents are encrypted using a passphrase. You can provide this passphrase in four ways:

1. **Environment Variable** (Recommended for automation):
   ```bash
   export GIT_PRIVATIZE_KEY="your-cryptographic-passphrase"
   ```
2. **macOS Keychain**:
   Stored automatically under Service name `gprism` and Account name `gprism`.
3. **Interactive Prompt**:
   If the environment variable is not set, `gprism` will prompt you for the password securely (hiding input).
4. **YAML Configuration**:
   You can specify `crypto_password` in your config file (not recommended for security).

> [!WARNING]
> Keep your encryption passphrase safe (e.g. in a Password Manager, Google Doc, or Obsidian vault). If you lose this key, **ALL secrets are unrecoverable**.

## License

This project is licensed under the MIT License.

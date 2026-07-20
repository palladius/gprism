# Gprism (Git Privatize in Secret Manager)

An evolution of `git-privatize` that stores your secret files (like `.env`) securely in Google Cloud Secret Manager instead of a git repository.

## Setup

1. **Configuration**:
   Copy `.env.template` to `.env` or create `~/.config/gprism/config.yaml` with the following variables:
   ```yaml
   project_id: your-gcp-project-id
   identity: your-gcp-account-email
   environment: prod # or dev, staging, etc.
   gcs_bucket: your-secure-gcs-bucket-name # Optional: required for files > 64KB
   ```
   Or in `.env`:
   ```bash
   GPRISM_PROJECT_ID=your-gcp-project-id
   GPRISM_IDENTITY=your-gcp-account-email
   GPRISM_ENVIRONMENT=prod
   GPRISM_GCS_BUCKET=your-secure-gcs-bucket-name # Optional: required for files > 64KB
   ```

2. **Large File Support (GCS Offloading)**:
   Google Cloud Secret Manager has a 64KB payload limit. For files larger than 64KB, `gprism` automatically offloads the encrypted data to the configured GCS bucket, and stores a pointer in Secret Manager. Make sure `GPRISM_GCS_BUCKET` is set and you have write access to it via `gcloud`.

3. **Encryption Key**:
   The tool encrypts your secrets locally before uploading them to GCP.
   It will attempt to retrieve the passphrase from your macOS Keychain (Service: `gprism`, Account: `gprism`).
   If not found, you will be prompted to enter it, and optionally save it to the keychain.

4. **Ignore List**:
   Create a `.git-privatize.list` file in your repository root, listing the patterns of files you want to privatize, just like a `.gitignore`.

## Usage

* `gprism add <filepath>`: Adds a file to `.git-privatize.list` and `.gitignore`. **Note: Adding folders is NOT supported.**
* `gprism push --all`: Encrypts and pushes all files matching the `.git-privatize.list` to GCP Secret Manager. Replaces the files locally with `.readme` breadcrumbs containing the secret names.
* `gprism pull --all`: Fetches, decrypts, and restores the files from GCP Secret Manager to their original locations.
* `gprism status`: Shows the current status of your privatized files.

## Testing

Run the test suite via `just`:
```bash
just test
```

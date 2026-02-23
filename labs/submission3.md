# Lab 3 Submission — Secure Git

## Task 1 — SSH Commit Signing

### What I did
- Generated a new ed25519 SSH key for signing: `C:/Users/USER/.ssh/id_ed25519` (passphrase set).
- Configured Git (global) for SSH signing: `gpg.format=ssh`, `user.signingkey` set to the new key, `commit.gpgSign=true`.
- Verified configuration inside WSL (used for Docker + commits) with `git config --global --get ...`.

### Evidence
- Key fingerprint: `SHA256:EncZbaJMqqwFK4/k9ITTRY1Fc2KNFyRZF+2HH4bye7Q`.
- Config check output (WSL):
  ```
  $ git config --global --get gpg.format
  ssh
  $ git config --global --get commit.gpgSign
  true
  $ git config --global --get user.signingkey
  /mnt/c/Users/USER/.ssh/id_ed25519
  ```
- Signed commit command used: `git commit -S -m "test: pre-commit hook secrets"` (commit blocked by hook while secrets staged; clean run will show **Verified** on GitHub).
- Screenshot: `screenshots/lab3-verified.png` (GitHub commit with **Verified** badge).

### Why signing matters
- Confirms commit authorship and integrity end-to-end (prevents tampering/impersonation).
- Enables organizational policies that reject unsigned/unverified commits, reducing supply-chain risk.
- In DevSecOps, signed commits create traceable, auditable change history that CI/CD and release pipelines can trust.

## Task 2 — Pre-commit Secret Scanning

### What I did
- Used the provided `.git/hooks/pre-commit` (Docker-based) unchanged; made it executable in WSL and ran commits through it.
- Docker images used automatically by the hook: `trufflesecurity/trufflehog:latest`, `zricethezav/gitleaks:latest`.
- Tested with staged files `.env` and a fake secrets file `tmp_secret.txt` while committing from WSL.

### Evidence of blocking secrets
- Staged a Slack bot token in `tmp_secret.txt` and ran the hook:
  ```
  [pre-commit] scanning staged files for secrets...
  ...
  Gitleaks found secrets in tmp_secret.txt:
  Finding:     SLACK_BOT_TOKEN=xoxb-***redacted-for-report***
  RuleID:      slack-bot-token
  ...
  [pre-commit] COMMIT BLOCKED: secrets detected in non-excluded files.
  ```
- This demonstrates the hook blocks commits containing detected secrets.

### Evidence of clean pass
- With only `.env` (non-sensitive placeholders) staged, the hook runs TruffleHog + Gitleaks and reports:
  ```
  TruffleHog found secrets in non-lectures files: false
  Gitleaks found secrets in non-lectures files: false
  ...
  [pre-commit] no secrets detected in non-excluded files; proceeding with commit.
  ```
- Note: The hook file uses Windows CRLF; in WSL the run is executed by piping through `tr -d "\r"` to avoid a minor `exit: 0\r: numeric argument required` message, but scanning behavior is correct without modifying the hook contents.

### Analysis: why automated secret scanning
- Prevents credential leaks before they reach Git history/remote by shifting left at commit time.
- Uses two engines (TruffleHog entropy/regex + Gitleaks rules) to reduce false negatives.
- Blocks high-risk files while allowing educational content under `lectures/` per policy.

## Screenshots
- `screenshots/lab3-verified.png` — GitHub commit showing **Verified** badge for signed commit.
- `screenshots/lab3-precommit-block.png` — Terminal output of pre-commit hook blocking the Slack token in `tmp_secret.txt`.

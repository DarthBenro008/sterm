# Security defaults

First-wave security defaults:

- remote agent listens on a Unix socket by default,
- no public TCP listener by default,
- `~/.sterm` parent directory should be `0700`,
- socket and auth token should be `0600`,
- app config must not store plaintext passwords, passphrases, private keys, or agent tokens,
- logs must redact secrets and should not include sensitive terminal contents by default,
- no root services, privileged services, shell-startup modification, or `loginctl enable-linger` without explicit approval.

These defaults are represented in Zig CLI helpers, Rust config/keychain abstractions, docs, and verification checks.

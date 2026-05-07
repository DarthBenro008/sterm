# Security defaults

Production hardening defaults:

- remote agent listens on a Unix socket by default,
- no public TCP listener by default,
- `~/.sterm` parent directory should be `0700`,
- socket and auth token should be `0600`,
- app config must not store plaintext passwords, passphrases, private keys, or agent tokens,
- logs must redact secrets and should not include sensitive terminal contents by default,
- no root services, privileged services, shell-startup modification, or `loginctl enable-linger` without explicit approval.
- strict host-key policy is the SSH default, and host-key evidence must come
  from known_hosts, a pinned fingerprint, or an explicitly persisted trust-on-
  first-use approval,
- bootstrap planning is idempotent (`mkdir -p`, install to
  `~/.sterm/bin/sterm-cli`, version check before daemon start) and rejects
  secrets, privileged operations, and destructive commands,
- tunnel planning allows Unix sockets by default and loopback TCP only under an
  explicit local policy; public TCP remains disabled,
- unlinked native dependencies are surfaced as explicit gates rather than hidden
  success.

These defaults are represented in Zig CLI helpers, Rust config/keychain abstractions, docs, and verification checks.

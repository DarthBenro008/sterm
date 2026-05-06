# Observability

First-wave observability surfaces:

- desktop log path documentation,
- remote log path documentation,
- `sterm-cli doctor`,
- version/socket/permission/storage/PTY/VT readiness checks,
- redaction helpers for secrets,
- verification output from `scripts/verify.sh`.

Logs must not include secrets or sensitive terminal contents by default.

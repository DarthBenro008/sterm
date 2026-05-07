# Observability

Production-gate observability surfaces:

- desktop log path documentation,
- remote log path documentation,
- `sterm-cli doctor`,
- version/socket/permission/storage/PTY/VT readiness checks,
- multi-client, roaming transport, and agent-detection readiness checks,
- redaction helpers for secrets,
- verification output from `scripts/verify.sh`.

Logs must not include secrets or sensitive terminal contents by default.

## Executable checks

`scripts/check-doctor-output.sh` builds and runs `sterm-cli doctor`, then asserts
the JSON includes real readiness fields for socket permissions, storage, VT,
multi-client attach policy, roaming transport, agent detection, and recent error
reporting. The script also rejects secret-looking values in doctor output.

`scripts/verify.sh` runs the doctor contract on every full verification pass so
doctor/logging claims stay mapped to code rather than docs-only promises.

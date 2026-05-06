# Agent tiers

This repository follows the OMX/Ralph tier guidance:

- **LOW**: bounded lookup or small local edit with narrow blast radius.
- **STANDARD**: normal implementation or verification lane with package-local ownership.
- **THOROUGH**: architecture/security-sensitive review, cross-stack integration, or final sign-off.

Ralph execution for `sterm` uses STANDARD implementation lanes and THOROUGH/architect verification because the project spans protocol, SSH/security, desktop backend, remote agent, renderer, and CI.

# sterm

`sterm` is a remote-first persistent terminal workspace for AI-agent-heavy server workflows.

The product invariant from `plans/prd.md` is binding: the remote `sterm-cli` daemon owns PTYs, VT state, scrollback, workspace/tab/split layout truth, persistence, and process lifecycle. The desktop app is a rich reconnecting client.

## First-wave scope

This repository is currently in the broad-product-build foundation wave:

- scaffold the PRD-shaped monorepo,
- define shared protocol/domain contracts,
- provide Zig, Rust, TypeScript, renderer, security, observability, and CI foundations,
- prove a mock-local vertical flow,
- keep real SSH/PTY/libghostty production integration and hardening visibly deferred.

## Verification

Run:

```bash
bash scripts/verify.sh
```

The script reports concrete command evidence and explicit skip/blocker reasons when a local toolchain is unavailable.

JavaScript/TypeScript package management, scripts, and tests use Bun throughout this repository.

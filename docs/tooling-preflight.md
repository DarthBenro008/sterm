# Tooling preflight

Official-doc checks used for first-wave scaffolding:

- Tauri v2 supports `create-tauri-app` and Vite/React templates; this repo keeps a manual skeleton because the approved plan needs custom monorepo boundaries.
- Tauri's Vite integration uses `devUrl` and `frontendDist` in `tauri.conf.json`.
- Vite supports React/TypeScript scaffolds and build scripts.
- Zig's current build-system docs use `b.addExecutable` with `root_module = b.createModule(...)`.
- Bun workspaces are configured through the root `package.json` `workspaces` field.

Local observations:

- `source ~/.zshrc && zig version` reports `0.17.0-dev.256+04481c76c`.
- `bun --version` reports `1.3.11`.
- `node --version` reports `v24.13.1`.
- Current npm metadata observed TypeScript `6.0.3`, Vite `8.0.10`, React `19.2.6`, and `@vitejs/plugin-react` `6.0.1`.

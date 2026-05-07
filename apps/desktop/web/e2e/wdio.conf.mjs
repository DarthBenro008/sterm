import os from "node:os";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const repoRoot = path.resolve(__dirname, "../../../..");
const tauriRoot = path.join(repoRoot, "apps/desktop/src-tauri");
const application = path.join(repoRoot, "target/debug/sterm");

let tauriDriver;
let shuttingDown = false;

export const config = {
  host: "127.0.0.1",
  port: 4444,
  logLevel: "warn",
  specs: ["./specs/**/*.e2e.mjs"],
  maxInstances: 1,
  capabilities: [
    {
      maxInstances: 1,
      "tauri:options": {
        application,
      },
    },
  ],
  reporters: ["spec"],
  framework: "mocha",
  mochaOpts: {
    ui: "bdd",
    timeout: 180000,
  },
  onPrepare() {
    const result = spawnSync("bunx", ["tauri", "build", "--debug", "--no-bundle", "--ci"], {
      cwd: tauriRoot,
      env: {
        ...process.env,
        PATH: process.env.PATH?.includes("/root/zig") ? process.env.PATH : `/root/zig:${process.env.PATH ?? ""}`,
      },
      stdio: "inherit",
    });
    if (result.status !== 0) {
      throw new Error(`Tauri debug build failed with status ${result.status}`);
    }
  },
  beforeSession() {
    tauriDriver = spawn(path.join(os.homedir(), ".cargo/bin/tauri-driver"), [], {
      stdio: ["ignore", process.stdout, process.stderr],
    });
    tauriDriver.on("error", (error) => {
      console.error("tauri-driver error:", error);
      process.exit(1);
    });
    tauriDriver.on("exit", (code) => {
      if (!shuttingDown) {
        console.error("tauri-driver exited with code:", code);
        process.exit(1);
      }
    });
  },
  afterSession() {
    closeTauriDriver();
  },
};

function closeTauriDriver() {
  shuttingDown = true;
  tauriDriver?.kill();
}

function onShutdown(fn) {
  process.on("exit", fn);
  process.on("SIGINT", () => {
    fn();
    process.exit(130);
  });
  process.on("SIGTERM", () => {
    fn();
    process.exit(143);
  });
  process.on("SIGHUP", () => {
    fn();
    process.exit(129);
  });
  process.on("SIGBREAK", () => {
    fn();
    process.exit(130);
  });
}

onShutdown(closeTauriDriver);

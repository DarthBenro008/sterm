import { describe, expect, test } from "bun:test";
import { parseConnectionResult, validateConnectionInput } from "../src/connection";

describe("desktop connection flow", () => {
  test("requires the three fields visible on the first screen", () => {
    expect(validateConnectionInput({ host: "", username: "root", password: "pw", port: 22 })).toContain("Server IP");
    expect(validateConnectionInput({ host: "0.0.0.0", username: "", password: "pw", port: 22 })).toContain("Username");
    expect(validateConnectionInput({ host: "0.0.0.0", username: "root", password: "", port: 22 })).toContain("Password");
    expect(validateConnectionInput({ host: "0.0.0.0", username: "root", password: "pw", port: 22 })).toBeNull();
  });

  test("parses backend connection result for terminal attach", () => {
    const result = parseConnectionResult(JSON.stringify({
      status: "connected",
      host: "0.0.0.0",
      username: "root",
      port: 22,
      remoteHome: "/root",
      installDir: "/root/.sterm",
      socketPath: "/root/.sterm/sterm.sock",
      agentVersion: "0.1.0",
      protocolVersion: 1,
      steps: [{ id: "daemon-start", label: "Daemon start requested", status: "complete", detail: "ok" }],
      terminalBanner: "attached",
    }));

    expect(result.host).toBe("0.0.0.0");
    expect(result.steps[0]?.label).toBe("Daemon start requested");
  });
});

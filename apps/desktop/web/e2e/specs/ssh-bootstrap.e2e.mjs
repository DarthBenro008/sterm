import { existsSync, rmSync } from "node:fs";

const markerPath = "/root/iwashere.txt";
const sshHost = process.env.STERM_E2E_SSH_HOST ?? "0.0.0.0";
const sshUser = process.env.STERM_E2E_SSH_USERNAME ?? "root";
const sshPassword = process.env.STERM_E2E_SSH_PASSWORD ?? "krishna5243";

describe("sterm SSH bootstrap flow", () => {
  before(() => {
    rmSync(markerPath, { force: true });
  });

  it("connects over SSH, installs the Zig agent, starts the terminal, and creates the marker file", async () => {
    const title = await $("#connect-title");
    await title.waitForDisplayed({ timeout: 30000 });
    await expect(title).toHaveText("Connect to your server");

    await $("input[name='host']").setValue(sshHost);
    await $("input[name='username']").setValue(sshUser);
    await $("input[name='password']").setValue(sshPassword);
    await $("button[type='submit']").click();

    const terminal = await $(".terminal-canvas");
    await terminal.waitForDisplayed({ timeout: 120000 });

    await browser.waitUntil(() => existsSync(markerPath), {
      timeout: 15000,
      interval: 250,
      timeoutMsg: `${markerPath} was not created by the SSH bootstrap flow`,
    });

    await expect($(".connection-note")).toHaveText(expect.stringContaining("Connected"));
    await expect($(".right-rail")).toHaveText(expect.stringContaining("Daemon start requested"));
  });
});

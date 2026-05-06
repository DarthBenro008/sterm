import { expect, test } from "bun:test";
import { theme } from "./index";

test("theme exposes terminal-safe defaults", () => {
  expect(theme.colors.background).toStartWith("#");
  expect(theme.font.mono).toContain("monospace");
});

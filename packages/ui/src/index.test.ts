import { expect, test } from "bun:test";
import { basePanelStyle, formatPaneBadge } from "./index";

test("formats pane badges", () => {
  expect(formatPaneBadge("needs approval")).toBe("needs approval");
});

test("panel style uses theme colors", () => {
  expect(basePanelStyle().background).toStartWith("#");
});

import { theme } from "@sterm/theme";

export interface NavItem {
  id: string;
  label: string;
  badge?: string;
}

export function formatPaneBadge(status: string): string {
  return status === "needs approval" ? "needs approval" : status;
}

export function basePanelStyle(): Record<string, string> {
  return {
    background: theme.colors.panel,
    color: theme.colors.text,
    borderColor: theme.colors.border,
  };
}

export interface SurfaceProps {
  title: string;
  description?: string;
}

export function formatSurfaceLabel(surface: SurfaceProps): string {
  return surface.description ? `${surface.title} — ${surface.description}` : surface.title;
}

export function notificationTone(level: "info" | "attention" | "warning" | "error" | string): "neutral" | "attention" | "warning" | "danger" {
  if (level === "attention") return "attention";
  if (level === "warning") return "warning";
  if (level === "error") return "danger";
  return "neutral";
}

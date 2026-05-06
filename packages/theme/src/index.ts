export const theme = {
  colors: {
    background: "#090b10",
    panel: "#111827",
    border: "#1f2937",
    text: "#e5e7eb",
    muted: "#9ca3af",
    accent: "#7dd3fc",
    attention: "#f59e0b",
    error: "#ef4444",
  },
  font: {
    mono: "Berkeley Mono, SFMono-Regular, Menlo, Consolas, monospace",
  },
} as const;

export type StermTheme = typeof theme;

export const darkTheme = {
  name: "sterm-dark",
  colors: {
    appBackground: theme.colors.background,
    sidebarBackground: "#0d1320",
    panelBackground: theme.colors.panel,
    paneBackground: "#05070c",
    border: theme.colors.border,
    text: theme.colors.text,
    mutedText: theme.colors.muted,
    accent: theme.colors.accent,
    attention: theme.colors.attention,
    warning: "#fb923c",
    error: theme.colors.error,
  },
  spacing: {
    xs: "0.25rem",
    sm: "0.5rem",
    md: "1rem",
    lg: "1.5rem",
  },
} as const;

export function themeToCssVariables(selectedTheme = darkTheme): Record<string, string> {
  return {
    "--sterm-app-bg": selectedTheme.colors.appBackground,
    "--sterm-sidebar-bg": selectedTheme.colors.sidebarBackground,
    "--sterm-panel-bg": selectedTheme.colors.panelBackground,
    "--sterm-pane-bg": selectedTheme.colors.paneBackground,
    "--sterm-border": selectedTheme.colors.border,
    "--sterm-text": selectedTheme.colors.text,
    "--sterm-muted-text": selectedTheme.colors.mutedText,
    "--sterm-accent": selectedTheme.colors.accent,
    "--sterm-attention": selectedTheme.colors.attention,
    "--sterm-warning": selectedTheme.colors.warning,
    "--sterm-error": selectedTheme.colors.error,
  };
}

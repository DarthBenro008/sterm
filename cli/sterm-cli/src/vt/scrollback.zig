pub const ScrollbackWindow = struct {
    available_lines: u64,
    window_start: u64,
    window_lines: u64,
};

pub const ScrollbackPolicy = struct {
    default_lines: u32 = 100_000,
    max_lines_per_pane: u32 = 500_000,
    persist_scrollback: bool = true,
};

pub const Cursor = struct {
    row: u16,
    col: u16,
    visible: bool,
    style: []const u8,
};

pub const Snapshot = struct {
    pane_id: []const u8,
    seq: u64,
    rows: u16,
    cols: u16,
    cells: []const u8,
};

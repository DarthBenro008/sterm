pub const DirtyRow = struct {
    row: u16,
    cells: []const u8,
};

pub const DirtyRegion = struct {
    row: u16,
    col_start: u16,
    col_end: u16,
};

pub const Diff = struct {
    pane_id: []const u8,
    seq: u64,
    dirty_rows: []const DirtyRow,
};

pub const Direction = enum { horizontal, vertical };

pub const SplitNode = union(enum) {
    pane: []const u8,
    split: struct {
        direction: Direction,
        ratio: f32,
    },
};

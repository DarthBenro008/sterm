const std = @import("std");

pub const AdapterError = error{
    Unsupported,
    InvalidSize,
};

pub const PaneSize = struct {
    rows: u16,
    cols: u16,

    pub fn validate(size: PaneSize) AdapterError!void {
        if (size.rows == 0 or size.cols == 0) return AdapterError.InvalidSize;
    }
};

pub const WriteResult = struct {
    bytes_written: usize,
};

pub const DirtyRegion = struct {
    row: u16,
    col_start: u16,
    col_end: u16,
};

pub const ScrollbackRequest = struct {
    start_line: u64,
    max_lines: u16,
};

pub const ScrollbackChunk = struct {
    pane_id: []const u8,
    start_line: u64,
    lines: []const []const u8,
    has_more: bool,
};

pub const Cursor = struct {
    row: u16,
    col: u16,
    visible: bool,
    style: []const u8,
};

pub const Snapshot = struct {
    pane_id: []const u8,
    rows: u16,
    cols: u16,
    cells: []const u8,
};

pub const Adapter = struct {
    ptr: *anyopaque,
    createPaneFn: *const fn (*anyopaque, PaneSize) AdapterError![]const u8,
    feedFn: *const fn (*anyopaque, []const u8, []const u8) AdapterError!WriteResult,
    writeFn: *const fn (*anyopaque, []const u8, []const u8) AdapterError!WriteResult,
    inputFn: *const fn (*anyopaque, []const u8, []const u8) AdapterError!WriteResult,
    resizeFn: *const fn (*anyopaque, []const u8, PaneSize) AdapterError!void,
    snapshotFn: *const fn (*anyopaque, []const u8) AdapterError!Snapshot,
    dirtyRegionsFn: *const fn (*anyopaque, []const u8) AdapterError![]const DirtyRegion,
    scrollbackFn: *const fn (*anyopaque, []const u8, ScrollbackRequest) AdapterError!ScrollbackChunk,
    cursorFn: *const fn (*anyopaque, []const u8) AdapterError!Cursor,
    titleFn: *const fn (*anyopaque, []const u8) AdapterError![]const u8,
    destroyFn: *const fn (*anyopaque, []const u8) AdapterError!void,

    pub fn createPane(adapter: Adapter, size: PaneSize) AdapterError![]const u8 {
        try size.validate();
        return adapter.createPaneFn(adapter.ptr, size);
    }

    pub fn feed(adapter: Adapter, pane_id: []const u8, bytes: []const u8) AdapterError!WriteResult {
        return adapter.feedFn(adapter.ptr, pane_id, bytes);
    }

    pub fn write(adapter: Adapter, pane_id: []const u8, bytes: []const u8) AdapterError!WriteResult {
        return adapter.writeFn(adapter.ptr, pane_id, bytes);
    }

    pub fn input(adapter: Adapter, pane_id: []const u8, bytes: []const u8) AdapterError!WriteResult {
        return adapter.inputFn(adapter.ptr, pane_id, bytes);
    }

    pub fn resize(adapter: Adapter, pane_id: []const u8, size: PaneSize) AdapterError!void {
        try size.validate();
        return adapter.resizeFn(adapter.ptr, pane_id, size);
    }

    pub fn snapshot(adapter: Adapter, pane_id: []const u8) AdapterError!Snapshot {
        return adapter.snapshotFn(adapter.ptr, pane_id);
    }

    pub fn dirtyRegions(adapter: Adapter, pane_id: []const u8) AdapterError![]const DirtyRegion {
        return adapter.dirtyRegionsFn(adapter.ptr, pane_id);
    }

    pub fn scrollback(adapter: Adapter, pane_id: []const u8, request: ScrollbackRequest) AdapterError!ScrollbackChunk {
        return adapter.scrollbackFn(adapter.ptr, pane_id, request);
    }

    pub fn cursor(adapter: Adapter, pane_id: []const u8) AdapterError!Cursor {
        return adapter.cursorFn(adapter.ptr, pane_id);
    }

    pub fn title(adapter: Adapter, pane_id: []const u8) AdapterError![]const u8 {
        return adapter.titleFn(adapter.ptr, pane_id);
    }

    pub fn destroy(adapter: Adapter, pane_id: []const u8) AdapterError!void {
        return adapter.destroyFn(adapter.ptr, pane_id);
    }
};

pub const MockAdapter = struct {
    pub const name = "mock-only";

    pane_id: []const u8 = "pane_mock_01",
    title_text: []const u8 = "mock-local",
    cells: []const u8 = "mock-cell-grid:v1",
    last_feed_len: usize = 0,
    last_write_len: usize = 0,
    size: PaneSize = .{ .rows = 40, .cols = 120 },
    cursor_state: Cursor = .{ .row = 0, .col = 0, .visible = true, .style = "block" },
    dirty: [1]DirtyRegion = .{.{ .row = 0, .col_start = 0, .col_end = 120 }},
    scrollback_lines: [3][]const u8 = .{ "bun test", "13 pass", "0 fail" },
    destroyed: bool = false,

    pub fn adapter(self: *MockAdapter) Adapter {
        return .{
            .ptr = self,
            .createPaneFn = createPane,
            .feedFn = feed,
            .writeFn = write,
            .inputFn = input,
            .resizeFn = resize,
            .snapshotFn = snapshot,
            .dirtyRegionsFn = dirtyRegions,
            .scrollbackFn = scrollback,
            .cursorFn = cursor,
            .titleFn = title,
            .destroyFn = destroy,
        };
    }

    fn from(ptr: *anyopaque) *MockAdapter {
        return @ptrCast(@alignCast(ptr));
    }

    fn createPane(ptr: *anyopaque, size: PaneSize) AdapterError![]const u8 {
        const self = from(ptr);
        self.size = size;
        return self.pane_id;
    }

    fn write(ptr: *anyopaque, pane_id: []const u8, bytes: []const u8) AdapterError!WriteResult {
        return input(ptr, pane_id, bytes);
    }

    fn feed(ptr: *anyopaque, pane_id: []const u8, bytes: []const u8) AdapterError!WriteResult {
        const self = from(ptr);
        if (!std.mem.eql(u8, pane_id, self.pane_id)) return AdapterError.Unsupported;
        self.last_feed_len = bytes.len;
        self.dirty[0] = .{ .row = self.cursor_state.row, .col_start = 0, .col_end = self.size.cols };
        return .{ .bytes_written = bytes.len };
    }

    fn input(ptr: *anyopaque, pane_id: []const u8, bytes: []const u8) AdapterError!WriteResult {
        const self = from(ptr);
        if (!std.mem.eql(u8, pane_id, self.pane_id)) return AdapterError.Unsupported;
        self.last_write_len = bytes.len;
        return .{ .bytes_written = bytes.len };
    }

    fn resize(ptr: *anyopaque, pane_id: []const u8, size: PaneSize) AdapterError!void {
        const self = from(ptr);
        if (!std.mem.eql(u8, pane_id, self.pane_id)) return AdapterError.Unsupported;
        self.size = size;
        self.dirty[0] = .{ .row = self.cursor_state.row, .col_start = 0, .col_end = size.cols };
    }

    fn snapshot(ptr: *anyopaque, pane_id: []const u8) AdapterError!Snapshot {
        const self = from(ptr);
        if (!std.mem.eql(u8, pane_id, self.pane_id)) return AdapterError.Unsupported;
        return .{
            .pane_id = self.pane_id,
            .rows = self.size.rows,
            .cols = self.size.cols,
            .cells = self.cells,
        };
    }

    fn dirtyRegions(ptr: *anyopaque, pane_id: []const u8) AdapterError![]const DirtyRegion {
        const self = from(ptr);
        if (!std.mem.eql(u8, pane_id, self.pane_id)) return AdapterError.Unsupported;
        return self.dirty[0..];
    }

    fn scrollback(ptr: *anyopaque, pane_id: []const u8, request: ScrollbackRequest) AdapterError!ScrollbackChunk {
        const self = from(ptr);
        if (!std.mem.eql(u8, pane_id, self.pane_id)) return AdapterError.Unsupported;
        const max_lines: usize = request.max_lines;
        const line_count = @min(max_lines, self.scrollback_lines.len);
        return .{
            .pane_id = self.pane_id,
            .start_line = request.start_line,
            .lines = self.scrollback_lines[0..line_count],
            .has_more = true,
        };
    }

    fn cursor(ptr: *anyopaque, pane_id: []const u8) AdapterError!Cursor {
        const self = from(ptr);
        if (!std.mem.eql(u8, pane_id, self.pane_id)) return AdapterError.Unsupported;
        return self.cursor_state;
    }

    fn title(ptr: *anyopaque, pane_id: []const u8) AdapterError![]const u8 {
        const self = from(ptr);
        if (!std.mem.eql(u8, pane_id, self.pane_id)) return AdapterError.Unsupported;
        return self.title_text;
    }

    fn destroy(ptr: *anyopaque, pane_id: []const u8) AdapterError!void {
        const self = from(ptr);
        if (!std.mem.eql(u8, pane_id, self.pane_id)) return AdapterError.Unsupported;
        self.destroyed = true;
    }
};

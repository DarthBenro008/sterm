pub const UploadPlan = struct {
    source: []const u8,
    destination: []const u8,
    verify_sha256: bool = true,
};

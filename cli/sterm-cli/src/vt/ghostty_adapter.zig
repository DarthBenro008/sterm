pub const integration_status = "libghostty-vt-unavailable";
pub const compiled = false;

pub const GhosttyError = error{
    LibghosttyUnavailable,
};

pub fn adapterName() []const u8 {
    return "libghostty-vt-adapter-gate";
}

pub fn requireAvailable() GhosttyError!void {
    return GhosttyError.LibghosttyUnavailable;
}

pub fn unavailableReason() []const u8 {
    return "libghostty-vt is not linked into this build; the adapter boundary is present and fails explicitly instead of silently using frontend VT parsing";
}

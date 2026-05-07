const std = @import("std");
const protocol = @import("protocol.zig");

pub const magic = [_]u8{ 'S', 'T', 'R', 'M' };
pub const wire_version: u16 = 1;
pub const protocol_wire_version: u16 = @intCast(protocol.version);
pub const header_len: usize = 12;
pub const max_payload_bytes: u32 = 16 * 1024 * 1024;

pub const TransportError = error{
    BadMagic,
    UnsupportedWireVersion,
    UnsupportedProtocolVersion,
    PayloadTooLarge,
    Truncated,
    TrailingBytes,
};

pub const Header = struct {
    wire: u16,
    protocol_version: u16,
    payload_len: u32,

    pub fn validate(header: Header) TransportError!void {
        if (header.wire != wire_version) return TransportError.UnsupportedWireVersion;
        if (header.protocol_version != protocol_wire_version) return TransportError.UnsupportedProtocolVersion;
        if (header.payload_len > max_payload_bytes) return TransportError.PayloadTooLarge;
    }
};

pub fn encodeHeader(out: *[header_len]u8, payload_len: u32) TransportError!void {
    const header = Header{
        .wire = wire_version,
        .protocol_version = protocol_wire_version,
        .payload_len = payload_len,
    };
    try header.validate();
    @memcpy(out[0..4], &magic);
    writeU16(out[4..6], header.wire);
    writeU16(out[6..8], header.protocol_version);
    writeU32(out[8..12], header.payload_len);
}

pub fn decodeHeader(bytes: []const u8) TransportError!Header {
    if (bytes.len < header_len) return TransportError.Truncated;
    if (!std.mem.eql(u8, bytes[0..4], &magic)) return TransportError.BadMagic;
    const header = Header{
        .wire = readU16(bytes[4..6]),
        .protocol_version = readU16(bytes[6..8]),
        .payload_len = readU32(bytes[8..12]),
    };
    try header.validate();
    return header;
}

pub fn validateFrameBytes(bytes: []const u8) TransportError!Header {
    const header = try decodeHeader(bytes);
    const expected_len = header_len + header.payload_len;
    if (bytes.len < expected_len) return TransportError.Truncated;
    if (bytes.len > expected_len) return TransportError.TrailingBytes;
    return header;
}

pub fn negotiate(client_protocol_version: u16, agent_protocol_version: u16) TransportError!void {
    if (client_protocol_version != protocol_wire_version or agent_protocol_version != protocol_wire_version) {
        return TransportError.UnsupportedProtocolVersion;
    }
}

fn writeU16(out: []u8, value: u16) void {
    out[0] = @intCast(value >> 8);
    out[1] = @intCast(value & 0xff);
}

fn writeU32(out: []u8, value: u32) void {
    out[0] = @intCast(value >> 24);
    out[1] = @intCast((value >> 16) & 0xff);
    out[2] = @intCast((value >> 8) & 0xff);
    out[3] = @intCast(value & 0xff);
}

fn readU16(bytes: []const u8) u16 {
    return (@as(u16, bytes[0]) << 8) | @as(u16, bytes[1]);
}

fn readU32(bytes: []const u8) u32 {
    return (@as(u32, bytes[0]) << 24) |
        (@as(u32, bytes[1]) << 16) |
        (@as(u32, bytes[2]) << 8) |
        @as(u32, bytes[3]);
}

test "transport header validates wire and protocol versions" {
    var header_bytes: [header_len]u8 = undefined;
    try encodeHeader(&header_bytes, 128);
    const header = try decodeHeader(&header_bytes);
    try std.testing.expectEqual(@as(u16, wire_version), header.wire);
    try std.testing.expectEqual(@as(u16, protocol_wire_version), header.protocol_version);
    try std.testing.expectEqual(@as(u32, 128), header.payload_len);
}

test "transport frame validation rejects bad headers" {
    var header_bytes: [header_len]u8 = undefined;
    try encodeHeader(&header_bytes, 0);

    var bad_magic = header_bytes;
    bad_magic[0] = 'X';
    try std.testing.expectError(TransportError.BadMagic, decodeHeader(&bad_magic));

    var bad_wire = header_bytes;
    bad_wire[5] = 2;
    try std.testing.expectError(TransportError.UnsupportedWireVersion, decodeHeader(&bad_wire));

    try std.testing.expectError(TransportError.Truncated, decodeHeader(header_bytes[0 .. header_len - 1]));
    try std.testing.expectError(TransportError.TrailingBytes, validateFrameBytes(&[_]u8{ 'S', 'T', 'R', 'M', 0, 1, 0, 1, 0, 0, 0, 0, 1 }));
}

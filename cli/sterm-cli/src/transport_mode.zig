const std = @import("std");

pub const ControlPlane = enum {
    ssh_tunnel,
};

pub const StreamPlane = enum {
    ssh_tunnel,
    roaming_udp,
};

pub const Encryption = enum {
    ssh,
    noise_xk,
};

pub const TransportModeError = error{
    MissingSshControl,
    MissingUdpPort,
    InsecureRoamingEncryption,
    InvalidFallback,
};

pub const TransportOffer = struct {
    control: ControlPlane = .ssh_tunnel,
    stream: StreamPlane = .ssh_tunnel,
    encryption: Encryption = .ssh,
    requires_ssh_control: bool = true,
    udp_port: ?u16 = null,
    fallback: StreamPlane = .ssh_tunnel,

    pub fn roaming(udp_port: u16) TransportOffer {
        return .{
            .control = .ssh_tunnel,
            .stream = .roaming_udp,
            .encryption = .noise_xk,
            .requires_ssh_control = true,
            .udp_port = udp_port,
            .fallback = .ssh_tunnel,
        };
    }

    pub fn validate(offer: TransportOffer) TransportModeError!void {
        if (offer.fallback != .ssh_tunnel) return TransportModeError.InvalidFallback;
        if (offer.stream == .roaming_udp) {
            if (!offer.requires_ssh_control) return TransportModeError.MissingSshControl;
            if (offer.udp_port == null or offer.udp_port.? == 0) return TransportModeError.MissingUdpPort;
            if (offer.encryption != .noise_xk) return TransportModeError.InsecureRoamingEncryption;
        }
    }
};

pub fn status() []const u8 {
    return "ssh-control with encrypted roaming-udp stream boundary and ssh fallback";
}

test "roaming UDP offer requires SSH control, encryption, and fallback" {
    try (TransportOffer.roaming(60000)).validate();
    try std.testing.expectError(TransportModeError.MissingUdpPort, (TransportOffer.roaming(0)).validate());
    try std.testing.expectError(TransportModeError.MissingSshControl, (TransportOffer{
        .stream = .roaming_udp,
        .encryption = .noise_xk,
        .requires_ssh_control = false,
        .udp_port = 60000,
    }).validate());
    try std.testing.expectError(TransportModeError.InsecureRoamingEncryption, (TransportOffer{
        .stream = .roaming_udp,
        .encryption = .ssh,
        .requires_ssh_control = true,
        .udp_port = 60000,
    }).validate());
}

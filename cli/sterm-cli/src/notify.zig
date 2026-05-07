const std = @import("std");

pub const AgentKind = enum {
    claude,
    codex,
    aider,
    cursor_agent,
    opencode,
    custom,
    unknown,
};

pub const AgentStatus = enum {
    running,
    thinking,
    waiting_for_input,
    needs_approval,
    error_state,
    completed,
    idle,
    disconnected,
};

pub const DetectionConfidence = enum {
    low,
    medium,
    high,
};

pub const Notification = struct {
    pane_id: []const u8,
    level: []const u8,
    reason: []const u8,
};

pub const DetectionInput = struct {
    pane_id: []const u8,
    process_command: []const u8 = "",
    pane_title: []const u8 = "",
    output_tail: []const u8 = "",
    manual_tag: ?AgentKind = null,
};

pub const AgentDetection = struct {
    pane_id: []const u8,
    kind: AgentKind,
    status: AgentStatus,
    confidence: DetectionConfidence,
    evidence_count: u8,
    reason: []const u8,

    pub fn notification(detection: AgentDetection) Notification {
        return .{
            .pane_id = detection.pane_id,
            .level = if (detection.status == .needs_approval or detection.status == .waiting_for_input) "attention" else "info",
            .reason = detection.reason,
        };
    }
};

pub fn detect(input: DetectionInput) AgentDetection {
    const kind = input.manual_tag orelse detectKind(input.process_command, input.pane_title);
    const detected_status = detectStatus(input.output_tail, kind);
    const has_agent_evidence = kind != .unknown;
    const has_status_evidence = detected_status != .running and detected_status != .idle;
    return .{
        .pane_id = input.pane_id,
        .kind = kind,
        .status = detected_status,
        .confidence = if (has_agent_evidence and has_status_evidence) .high else if (has_agent_evidence or has_status_evidence) .medium else .low,
        .evidence_count = boolToU8(has_agent_evidence) + boolToU8(has_status_evidence) + boolToU8(input.manual_tag != null),
        .reason = reasonFor(kind, detected_status),
    };
}

pub fn status() []const u8 {
    return "builtin claude/codex/aider/cursor-agent/opencode detection with explicit low-confidence fallback";
}

fn detectKind(command: []const u8, title: []const u8) AgentKind {
    if (containsEither(command, title, "claude")) return .claude;
    if (containsEither(command, title, "codex")) return .codex;
    if (containsEither(command, title, "aider")) return .aider;
    if (containsEither(command, title, "cursor-agent")) return .cursor_agent;
    if (containsEither(command, title, "opencode")) return .opencode;
    if (command.len > 0 or title.len > 0) return .custom;
    return .unknown;
}

fn detectStatus(output: []const u8, kind: AgentKind) AgentStatus {
    if (output.len == 0) return if (kind == .unknown) .idle else .running;
    if (contains(output, "do you want to proceed") or contains(output, "approve") or contains(output, "permission")) return .needs_approval;
    if (contains(output, "waiting for input") or contains(output, "enter your choice") or contains(output, "continue?")) return .waiting_for_input;
    if (contains(output, "thinking") or contains(output, "analyzing")) return .thinking;
    if (contains(output, "error") or contains(output, "failed") or contains(output, "panic")) return .error_state;
    if (contains(output, "completed") or contains(output, "done") or contains(output, "finished")) return .completed;
    return .running;
}

fn reasonFor(kind: AgentKind, agent_status: AgentStatus) []const u8 {
    _ = kind;
    return switch (agent_status) {
        .needs_approval => "agent-needs-approval",
        .waiting_for_input => "agent-waiting-for-input",
        .thinking => "agent-thinking",
        .error_state => "agent-error",
        .completed => "agent-completed",
        .idle => "pane-idle",
        .disconnected => "pane-disconnected",
        .running => "agent-running",
    };
}

fn containsEither(left: []const u8, right: []const u8, needle: []const u8) bool {
    return contains(left, needle) or contains(right, needle);
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0 or haystack.len < needle.len) return false;
    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[index .. index + needle.len], needle)) return true;
    }
    return false;
}

fn boolToU8(value: bool) u8 {
    return if (value) 1 else 0;
}

test "agent detection handles known agents and approval prompts" {
    const detection = detect(.{
        .pane_id = "pane_01",
        .process_command = "claude",
        .pane_title = "Claude Agent",
        .output_tail = "Do you want to proceed?",
    });
    try std.testing.expectEqual(AgentKind.claude, detection.kind);
    try std.testing.expectEqual(AgentStatus.needs_approval, detection.status);
    try std.testing.expectEqual(DetectionConfidence.high, detection.confidence);
    try std.testing.expectEqualStrings("agent-needs-approval", detection.notification().reason);
}

test "agent detection falls back safely for unknown panes" {
    const detection = detect(.{ .pane_id = "pane_02" });
    try std.testing.expectEqual(AgentKind.unknown, detection.kind);
    try std.testing.expectEqual(AgentStatus.idle, detection.status);
    try std.testing.expectEqual(DetectionConfidence.low, detection.confidence);
}

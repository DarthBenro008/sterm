pub use sterm_protocol::{Frame, FrameType, Hello, PROTOCOL_VERSION};

pub fn hot_path_policy() -> &'static str {
    "persistent-channel"
}

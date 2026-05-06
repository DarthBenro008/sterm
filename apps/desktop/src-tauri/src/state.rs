use std::sync::{Arc, Mutex};
use sterm_protocol::Frame;
use sterm_shared::redact;

#[derive(Debug, Clone, Default)]
pub struct BackendState {
    inner: Arc<Mutex<StateInner>>,
}

#[derive(Debug, Default)]
struct StateInner {
    last_frame: Option<Frame>,
    events: Vec<String>,
}

impl BackendState {
    pub fn remember_frame(&self, frame: Frame) {
        let mut inner = self.inner.lock().expect("backend state lock poisoned");
        inner.last_frame = Some(frame);
    }

    pub fn last_frame(&self) -> Option<Frame> {
        self.inner
            .lock()
            .expect("backend state lock poisoned")
            .last_frame
            .clone()
    }

    pub fn push_event(&self, event: impl AsRef<str>) {
        let mut inner = self.inner.lock().expect("backend state lock poisoned");
        inner.events.push(redact(event.as_ref()));
    }

    pub fn events(&self) -> Vec<String> {
        self.inner
            .lock()
            .expect("backend state lock poisoned")
            .events
            .clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn state_redacts_events() {
        let state = BackendState::default();
        state.push_event("connected token=<fixture>");
        assert_eq!(state.events(), vec!["connected [REDACTED]".to_string()]);
    }
}

//! Agent persistence and state management.
//!
//! This module provides:
//! - Data models for scene snapshots, character states, and memory records
//! - Storage layer for persisting agent runtime state
//! - Turn trace logging for debugging and analysis

mod models;
mod storage;

pub use models::*;
pub use storage::AgentStorage;

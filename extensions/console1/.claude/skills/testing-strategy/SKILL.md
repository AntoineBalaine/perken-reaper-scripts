---
name: testing-strategy
description: Understand the model-based property-based testing strategy used in the REAPER Console1 extension. Use when writing tests, understanding test infrastructure, or working with src/tests and src/models/reaper_mock.zig.
---

# Testing Strategy: Model-Based PBT

This skill explains the testing strategy used in the REAPER Console1 extension, which employs a model-based property-based testing approach.

## Overview

This project uses a model-based, property-based testing (PBT) strategy to test a complex Reaper plugin. This approach addresses the challenges of testing stateful logic in an integrated host environment.

## Core Components

### 1. Mock Reaper Model

A simplified, in-memory model of Reaper's state (`src/models/reaper_mock.zig`) allows for fast, deterministic testing without a live Reaper instance. It simulates Reaper API calls by updating its internal state.

### 2. Property-Based Testing (PBT)

Random sequences of user actions (commands) are generated. Each action is applied to both the real plugin's state and the mock Reaper model's state. Tests verify that both states remain consistent, ensuring the plugin's logic accurately reflects Reaper's behavior.

## Key Benefits

- High Coverage: Explores vast interaction sequences, uncovering subtle bugs.
- State Consistency: Guarantees the plugin's state is always in sync with Reaper's simulated state.

## Future Direction

The project is transitioning from the Rapidcheck library to a custom, in-house PBT library. The underlying model-based testing principles will remain unchanged.

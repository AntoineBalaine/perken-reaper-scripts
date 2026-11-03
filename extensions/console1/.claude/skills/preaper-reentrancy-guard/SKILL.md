---
name: preaper-reentrancy-guard
description: Understand the pReaper reentrancy guard mechanism that prevents infinite loops when calling REAPER API. Use when debugging reentrancy issues, working with src/pReaper.zig, or making REAPER API calls.
---

# pReaper Module: Re-entrancy Guard

This skill explains the pReaper module and its critical reentrancy guard mechanism in the REAPER Console1 extension.

## Overview

The `pReaper` module serves as a critical re-entrancy guard for the application. It is a proxy module that wraps the entire native Reaper API (`reaper.zig`). Its sole purpose is to prevent recursive or re-entrant calls from the Reaper host back into the plugin when the plugin is making a call to the Reaper API.

## Problem: Re-entrancy

Many Reaper API calls can trigger notifications or state changes within the host. For example, changing a track's volume via an API call will cause Reaper to notify all registered control surfaces (like this plugin) about the volume change.

This creates a potential for infinite loops:

1. The plugin calls a Reaper API function (e.g., `SetMediaTrackInfo_Value(..., 'D_VOL', ...)`).
2. Reaper changes the volume and immediately sends a `SetSurfaceVolume` notification back to the plugin's control surface (`csurf`).
3. If the plugin's `csurf` handler for `SetSurfaceVolume` is not designed to handle this, it might interpret the notification as a user action or another external event, potentially triggering another state change or even the same API call again, leading to a loop.

## Solution: API Proxy with a Csurf Lock

To solve this, the `pReaper` module implements a simple but effective locking mechanism. It acts as a complete proxy for the `reaper.zig` module, exposing an identical API. Before any call to the underlying Reaper API is made, it sets a global flag, `csurf.ignore_notifications`, to `true`.

### Implementation

The implementation uses a consistent pattern for every wrapped Reaper API function:

```
const csurf = @import("csurf/control_surface.zig");
const reaper = @import("reaper.zig").reaper;

pub fn SomeReaperApiFunction(arg1: anytype, arg2: anytype) -> anytype {
    // 1. Lock the control surface to ignore incoming notifications
    csurf.ignore_notifications = true;

    // 2. Ensure the lock is released when the function exits, even if it errors
    defer csurf.ignore_notifications = false;

    // 3. Call the actual Reaper API function
    return reaper.SomeReaperApiFunction(arg1, arg2);
}
```

This pattern ensures that while the plugin is actively changing the state of the Reaper host, it will ignore any notifications that are a direct result of its own actions. The use of `defer` guarantees that the lock is always released, preventing the plugin from getting stuck in a state where it ignores all host notifications.

### Usage

Throughout the codebase, all calls to the Reaper API must be made through the `pReaper` module instead of the `reaper` module directly. This enforces the re-entrancy guard globally and makes the application safer and more predictable.

Correct Usage:
```
const pReaper = @import("pReaper.zig");
pReaper.CSurf_OnStop(); // Call through the proxy
```

Incorrect Usage:
```
const reaper = @import("reaper.zig").reaper;
reaper.CSurf_OnStop(); // Bypasses the re-entrancy guard
```

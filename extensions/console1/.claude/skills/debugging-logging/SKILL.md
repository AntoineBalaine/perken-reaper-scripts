---
name: debugging-logging
description: Understand debugging and logging infrastructure in the REAPER Console1 extension. Use when adding logging, working with the debug panel, or debugging issues in src/logger.zig or src/debug_panel.zig.
---

# Debugging and Logging

This skill explains the debugging and logging infrastructure in the REAPER Console1 extension. The extension provides comprehensive logging facilities and a debug panel for visualizing application state during development.

## Logging System

The logging system is implemented in src/logger.zig and builds on top of the standard Zig logging facilities. The logFn function serves as the custom log handler that processes all log messages from throughout the application.

Log levels follow the standard Zig convention: debug for detailed diagnostic information, info for general informational messages, warn for warnings about potential issues, and err for error conditions. Each module can define its own logging scope using std.log.scoped to tag messages with their source module.

The logFn function checks the log level and processes messages accordingly. For debug and info messages, it formats them with colored output using ANSI escape codes. The function also handles special cases like reentrancy messages that need to be captured for testing purposes.

## File Logging

The extension supports optional logging to a file for persistent debugging information. The log_to_file preference in the settings controls whether file logging is enabled. When enabled, the updateLoggerState function in the Globals structure opens a log file in the resource directory.

Log messages are written to the file using the standard file writer interface. The file remains open for the lifetime of the extension session and is closed during cleanup. This approach provides a complete record of the session for post-mortem debugging.

## Event Logging

The Event union in src/logger.zig defines structured events that can be logged and displayed in the debug panel. The union supports three event types: state_change for mode transitions, midi_input for incoming MIDI messages, and parameter_update for FX parameter changes.

Each event type stores relevant data. The state_change variant includes the old mode and new mode. The midi_input variant stores the CC number and value. The parameter_update variant stores the module, parameter index, and new value.

The Event union implements a custom format function that renders events as human-readable strings. This allows events to be logged using the standard format infrastructure and displayed in the debug panel.

## Debug Panel

The debug panel is implemented in src/debug_panel.zig and provides a graphical interface for visualizing application state. The drawDebugPanel function creates an ImGui window that displays various aspects of the current state.

The panel shows the current frame rate, the active mode, information about the current track and selected tracks, and module locations for the current track. The panel uses collapsing headers to organize information into sections that can be expanded or collapsed.

The panel is only displayed when the debug_window_active flag is true, which is set based on the build mode. In debug builds, the panel is available for inspection. In release builds, the panel is not compiled into the binary.

## Safe String Formatting

The safePrint helper function in src/debug_panel.zig provides safe string formatting for GUI display. This function wraps the standard bufPrintZ function and handles the NoSpaceLeft error by truncating the output and appending an ellipsis character.

This approach prevents crashes from buffer overflow while still providing useful output. The truncated output includes as much of the formatted string as possible followed by an ellipsis to indicate truncation.

## Color Coding

The logger module defines color constants for ANSI terminal output. The Color structure contains escape sequences for red (errors), yellow (warnings), blue (info), green (debug), and reset (default color).

These colors are applied to log messages based on their level to improve readability when viewing logs in a terminal. Error messages appear in red, warnings in yellow, info messages in blue, and debug messages in green.

## Reentrancy Debugging

The logger includes special handling for reentrancy debugging messages. When the logging scope is reentrancy, the logFn function checks if a test is currently running and captures the reentrancy notification or API call for test verification.

This mechanism allows the reentrancy protection system to be tested by collecting notifications about blocked calls and ensuring that the protection is working correctly. The current_test global variable holds the active test state when tests are running.

## Debug Overlays

The debug panel uses ImGui's collapsing header feature to create expandable sections for different categories of information. This allows the user to focus on specific areas of interest while keeping the panel compact.

The Recent Events section would display a log of recent events if an event logging system were implemented. The Track State section shows information about the currently selected track, including its ID and module locations. The MIDI section could display recent MIDI activity if implemented.

## Assertion and Error Handling

Throughout the codebase, the extension uses Zig's error handling mechanisms to propagate errors up the call stack. In debug mode, additional assertions check invariants and catch programming errors early.

The std.debug.assert function is used to validate assumptions about the program state. These assertions are removed in release builds, so they do not impact performance or binary size in production.

## Performance Monitoring

The debug panel displays the current frame rate using ImGui's GetFramerate function. This provides immediate feedback about GUI performance and helps identify performance issues during development.

The frame rate is displayed at the top of the debug panel and updates in real-time as the application runs. This makes it easy to spot performance degradation when making changes to the GUI rendering code.

## Module Identification

Each module in the codebase uses std.log.scoped to create a logging scope with a descriptive name. For example, the mappings module uses std.log.scoped(.mappings) to tag its log messages.

This scoping allows log messages to be filtered by module and makes it easy to trace where messages originate. When debugging a specific module, you can focus on messages from that module's scope while ignoring messages from other parts of the application.

---
name: storage-management
description: Understand storage and state management in the REAPER Console1 extension, including INI file handling, MapStore, and lazy loading. Use when working with persistence, configuration files, or src/mappings.zig and src/settings.zig.
---

# Storage and State Management

This skill explains how the storage and state management system works in the REAPER Console1 extension. The extension persists user preferences and parameter mappings to disk and manages both global and mode-specific state in memory.

## Resource Directory Structure

The extension stores all persistent data in a directory structure under the REAPER resource path. The base directory is located at REAPER_RESOURCE_PATH/Data/Perken/Console1. Under this base directory, the extension organizes files as follows:

- preferences.ini: User preferences and default FX assignments.
- maps/COMP: INI files containing parameter mappings for compressor plugins.
- maps/EQ: INI files containing parameter mappings for EQ plugins.
- maps/GATE: INI files containing parameter mappings for gate plugins.
- maps/INPUT: INI files containing parameter mappings for input processing plugins.
- maps/OUTPT: INI files containing parameter mappings for output processing plugins.

The getControllerPath function in src/fs_helpers.zig constructs this path by combining the REAPER resource path with the extension's directory structure.

## INI File Format

All persistent storage uses the INI file format parsed by the ini library. The format consists of key-value pairs and section headers:

Preferences files use top-level key-value pairs for boolean and string settings, followed by sections for each module's default FX assignment.

Mapping files use key-value pairs where the keys are Console1 control names and the values are FX parameter indices. Each mapping file begins with an fx_name property that identifies the plugin.

## MapStore Structure

The MapStore structure in src/mappings.zig manages parameter mappings with lazy loading from disk. The structure contains five string array hashmaps, one for each module category. Each hashmap maps FX plugin names to their corresponding mapping structures.

The MapStore stores the controller directory path and an allocator for managing memory. When the application starts, the MapStore.init function loads mappings for the default FX plugins specified in the preferences. Other mappings are loaded on demand when plugins are encountered.

## Lazy Loading

The MapStore implements a lazy loading strategy to minimize startup time and memory usage. When a mapping is requested through the get method, the system follows this process:

1. Check if the mapping exists in the in-memory hashmap for the requested module.
2. If found, return the mapping immediately.
3. If not found, call getMap to load the mapping from disk.
4. If the file exists, parse it and store the mapping in the hashmap before returning.
5. If the file does not exist, return null indicating no mapping is available.

This approach ensures that frequently used mappings remain in memory while rarely used mappings are loaded only when needed.

## File Sanitization

When loading or saving mappings, the extension sanitizes FX plugin names to create valid filenames. The sanitizeFxName function in reaziglib's fs_helpers.zig replaces each character that Windows forbids in names (`< > : " / \ | ? *` and control characters) with an underscore and trims trailing spaces and dots, so "JS: ReaComp" is stored as "JS_ ReaComp". The sanitized name is then used to construct the file path. Because older versions replaced only slashes, startup renames legacy folders once (migrateFolderNames / migrateFolderNamesRecursive).

## Saving Mappings

The saveToFile method in src/mappings.zig writes a mapping to disk. The method takes a MappingState structure containing the target FX name and current mappings. The process is:

1. Sanitize the FX name to create a valid filename.
2. Construct the full file path based on the module category.
3. Create or open the file for writing.
4. Write the fx_name property.
5. Write a section header for the module category.
6. Iterate through all fields in the mapping structure and write key-value pairs for assigned controls.

The file is written using formatted output with the INI structure.

## Preferences Storage

The Preferences structure in src/settings.zig manages user preferences. The init function loads preferences from disk during application startup. The load method opens the preferences.ini file, parses it using the INI parser, and populates the structure fields.

The saveToDisk method writes preferences back to disk. It writes boolean settings as true/false strings and module defaults as sections with the FX name as the value.

Both loading and saving use error handling to gracefully degrade when files cannot be accessed. If loading fails, the application falls back to hardcoded defaults. If saving fails, the error is logged but the application continues running.

## Default Configuration Files

The extension embeds default configuration files in the binary using the embedFile directive. The fs_helpers module defines default_preferences and default_mappings constants that contain the embedded file contents. The ensureConfigPath function checks for the existence of configuration files and creates them from the embedded defaults if they do not exist. This ensures that the extension has a working configuration even on first run or after manual deletion of configuration files.

## State Structure

The application maintains a global State structure defined in src/statemachine.zig. This structure contains:

Mode-specific state:
Each mode has its own state structure containing mode-specific data. For example, FxControlState tracks the current track state and parameter values, while MappingState holds the current mapping being edited.

Shared state:
Some state is shared across modes, such as the current track ID and the set of selected tracks. This shared state allows modes to coordinate and maintain consistency.

Current mode:
The current_mode field determines which mode is active and which handlers process events.

## Memory Management

The extension uses arena allocators for managing memory in configuration loading operations. When loading mappings or preferences, a temporary arena allocator is created for the parsing operation. After parsing completes and the data is copied to the appropriate structures, the arena is deallocated, freeing all temporary memory at once. This approach simplifies memory management and prevents leaks during configuration loading.

The main application state uses a global arena allocator that persists for the lifetime of the extension. This arena is used for allocating strings and structures that need to remain valid throughout the session.

## Caching Strategy

The current implementation caches all loaded mappings in memory using the MapStore hashmaps. Once a mapping is loaded from disk, it remains in memory until the extension exits. This strategy provides fast access for repeated lookups at the cost of some memory usage. Since mapping files are small and the number of unique plugins used in a typical session is limited, this approach provides good performance without excessive memory consumption.

## Error Handling

All file operations use Zig error unions to handle failure cases. The extension logs warnings when mappings cannot be loaded and logs errors when saving fails. In most cases, the extension continues operating with degraded functionality rather than crashing. For example, if a mapping file cannot be loaded, the extension opens the mapping panel to allow the user to create a new mapping.

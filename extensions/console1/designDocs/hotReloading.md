# 1. **Refactor Global State**
```
a. Audit globals.zig
   - Identify which globals are GUI-specific
   - Identify which globals are shared
   - Identify which globals are main-app specific

b. Restructure globals.zig
   - Move everything into a proper State struct
   - Ensure clean separation of concerns
   - Update all code that uses globals
```
# 2. **Setup Build System**
a. Modify build.zig
   - Add GUI lib as separate compilation target
   - Ensure both main and GUI can access existing modules

b. Create development build script
   - Quick rebuild of GUI lib

The development build script would be a simple script (shell script or batch file depending on your OS) that:

1. Watches for changes in your GUI-related source files
2. Rebuilds the GUI library when changes are detected
3. Places the new library where your extension can find it

Basic example (for Unix-like systems):
```bash
#!/bin/bash

# Watch GUI source files and rebuild on changes
while true; do
    # Rebuild GUI library
    zig build-lib gui_lib.zig -dynamic -o gui_lib.so

    # Wait for any source file changes
    inotifywait -e modify src/*.zig
done
```

Or you could use existing tools like:
- `entr`: `find src/ -name "*.zig" | entr zig build-lib gui_lib.zig -dynamic`
- `watchexec`: `watchexec -w src/ "zig build-lib gui_lib.zig -dynamic"`


# 2. **Create GUI Library**
a. Create gui_lib.zig
   - Export main drawing function
   - Import existing modules as needed
   - Move GUI code from imgui_loop.zig

b. Create gui_loader.zig in main app
   - Implement dynamic library loading
   - Add reload functionality

# 3. **Modify ImGui Loop**
a. Update imgui_loop.zig
   - Add hot-reload checking
   - Handle context recreation
   - Call into GUI lib

# 4. **Integration**
a. Initial testing
   - Verify basic hot-reload works
   - Check state preservation
   - Test error handling

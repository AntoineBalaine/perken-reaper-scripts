# Spike: a webview UI for the VR-09 plugin

## Question

Can the VR-09 CLAP plugin show its UI in a webview on Linux, macOS and Windows, inside REAPER, without embedding it in REAPER's FX window?

The answer decides between two ways of making the UI look professional:

- keep ReaImGui and build depth primitives (layered surfaces, cards, bitmap filmstrips and 9-slice panels) by hand;
- move the UI to a webview and reuse existing web component libraries.

## What is already known

- The plugin opens a floating window (`guiGetPreferredApi` sets `is_floating = true` in `vr09/src/plugin.zig`), so the webview does not have to attach to REAPER's X11 window. Embedding is the hard case on Linux and is out of scope.
- CHOC (`github.com/Tracktion/choc`, header-only C++) wraps the native webview of each platform: WebView2 on Windows, WKWebView on macOS, WebKitGTK on Linux. The webview-gui CLAP examples (`github.com/geraintluff/signalsmith-clap-cpp`) and dpfwebui (`github.com/lucianoiam/dpfwebui`) use the same approach.
- macOS and Windows ship their webview with the system, so the bundle grows by tens of kilobytes plus the HTML, CSS and JS.
- On Linux, WebKitGTK is a system library (about 38 MB to download, 141 MB installed). This machine has `webkit2gtk` 2.50 (the 4.0 API) but not `webkit2gtk-4.1`.
- The plugin already answers JSON commands (`vr09/src/debug_api.zig`: state, set, load_registration, devices), which can become the protocol between the page and the plugin.

## The unknown

WebKitGTK needs the GLib main loop to run on the thread that owns the webview. REAPER on Linux draws through SWELL on GDK3, and it is not known whether its event loop iterates the GLib default context. If it does not, the page will not draw or will not respond.

## Spike

```
build
  compile CHOC's webview with `zig c++` behind a small C interface:
    webview_create(title, w, h) -> handle
    webview_set_html(handle, html)
    webview_bind(handle, name, callback)      # page -> plugin
    webview_eval(handle, js)                  # plugin -> page
    webview_destroy(handle)
  Linux: link webkit2gtk (4.0 or 4.1, whichever CHOC accepts)

plugin
  gui.show:
    handle = webview_create("VR-09", 600, 400)
    webview_set_html(handle, "<h1>VR-09</h1><button onclick=clicked()>click</button>")
    webview_bind(handle, "clicked", log "clicked")
  plugin timer, every tick:
    webview_eval(handle, "document.title = '<tick count>'")
  gui.hide / gui.destroy:
    webview_destroy(handle)
```

## Checks

On Linux, first in the headless REAPER (xvfb) through the debug bridge, then in the user's REAPER:

1. The page draws when the FX window opens.
2. A click reaches the plugin (the log shows "clicked").
3. The plugin's timer updates the page (the title changes).
4. Closing and reopening the FX window several times leaves no frozen window and no crash.
5. Two instances of the plugin each get a working window.
6. Closing the project and quitting REAPER do not hang.

On macOS and Windows, checks 1 to 6 once, when a machine is available.

## Outcomes

- All checks pass on Linux in-process: move the UI to the webview with CHOC.
- The page does not draw or does not respond on Linux: try driving the GLib loop from the plugin's timer (`g_main_context_iteration(NULL, FALSE)`); if that is fragile, run the webview in a helper process that talks to the plugin over a local socket.
- Both fail: stay with ReaImGui and build the depth primitives.

TOGGLE ACTIONS
I want to implement the ability for users to use toggle actions in reaper’s action list, and I want to better handle the case where the user hasn’t yet connected his controller to my extension.
This requires registering some toggle actions when the extension starts. 
Let’s think about the state.

- we want the extension to run only when the console is connected. If the console is not connected, we might need a new mode for the state machine. What should be the name for this mode? `inactive`? `no_controller`? Is there a canonical name for these cases?

- since «no_controller» mode is probably going to be the default state of the application, I reckon we probably still want to be calling the regular setup when the extension is loaded by the host: calling the extension’s init(), reading config files, etc. 

- in `no_controller` mode, if the user’s config calls for displaying the UI, we should probably draw the fx_ctrl_panel, with a message that says «No controller found» and the knobs disabled.
So, aside from it being the default mode, we probably have to update the extension’s entry point somehow: the GUI loop should only be registered depending on the user settings.

- When the console connects, the control_surface.zig calls its init() function. That’s when the mode should switch to fx_ctrl. If the user config calls for displaying the fx_ctrl_panel, then we should register the imgui loop to draw the UI.

- If the control_surface calls deinit(), we should set the mode back to no_controller.

- We also want to have an action for the user to toggle the functioning of the console, even if the controller is found. Toggle the functioning of the console means that we don’t perform any track validation, we don’t display the UI anymore, midi input messages are ignored, maybe the LED feedback on the console is suspended, but we don’t deinit the control_surface. That’s basically the «inactive» mode. I’m still debating what should be done about the rest of the data: should I deinit anything at all, other than the GUI context pointer? It feels stupid to deinit before the host unloads the extension.
  
2. user calls action to toggle the UI of fx_ctrl mode
In this case, the rest of the extension still works, we just have to destroy the imgui ctx, and de-register the timer callback which calls the imgui loop.
For this case, I’m not sure whether this should be an entire mode, or if we should just use a boolean flag? Should we use an action handler for this case - action handler which can set whatever mode or flags we need, and takes care of cleaning up the registrations with the host? I like this option, but there might be some edge cases I’m not thinking of.

Also, in this situation the UI should still be accessible for the other modes: settings panel, mapping panel, fx selection panel, etc. For example, if the user calls the settings panel but - coming from fx_ctrl mode - the UI loop wasn’t running, then we should register the gui loop again and start drawing. When the user switches back to fx_ctrl mode, we should de-register the gui loop again.


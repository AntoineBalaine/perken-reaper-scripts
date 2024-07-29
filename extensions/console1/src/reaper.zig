const std = @import("std");

pub const reaper = struct { // @import("reaper");
    pub const ACCEL = *opaque {};
    pub const AudioAccessor = *opaque {};
    pub const AudioWriter = *opaque {};
    pub const BR_Envelope = *opaque {};
    pub const CF_Preview = *opaque {};
    pub const FxChain = *opaque {};
    pub const GUID = *opaque {};
    pub const HDC = *opaque {};
    pub const HFONT = *opaque {};
    pub const HINSTANCE = *opaque {};
    pub const HMENU = *opaque {};
    pub const HWND = *opaque {};
    pub const INT_PTR = *opaque {};
    pub const IReaperControlSurface = *opaque {};
    pub const IReaperPitchShift = *opaque {};
    pub const ISimpleMediaDecoder = *opaque {};
    pub const KbdSectionInfo = *opaque {};
    pub const LICE_IBitmap = *opaque {};
    pub const LICE_IFont = *opaque {};
    pub const LICE_pixel = *opaque {};
    pub const LICE_pixel_chan = *opaque {};
    // pub const MIDI_event_t = *opaque {};

    pub const MIDI_event_t = extern struct {
        frame_offset: c_int,
        size: c_int,
        midi_message: [4]u8,
        pub fn is_note(self: *MIDI_event_t) bool {
            return (self.midi_message[0] & 0xe0) == 0x80;
        }
        pub fn is_note_on(self: *MIDI_event_t) bool {
            return (self.midi_message[0] & 0xf0) == 0x90 and self.midi_message[2];
        }
        pub fn is_note_off(self: *MIDI_event_t) bool {
            switch (self.midi_message[0] & 0xf0) {
                0x80 => return true,
                0x90 => return self.midi_message[2] == 0,
            }
            return false;
        }
        pub const cc = enum(u8) {
            CC_ALL_SOUND_OFF = 120,
            CC_ALL_NOTES_OFF = 123,
            CC_EOF_INDICATOR = 123, // same as CC_ALL_NOTES_OFF
        };
    };
    pub const MIDI_eventlist = *opaque {};
    pub const MSG = *opaque {};
    pub const MediaItem = *opaque {};
    pub const MediaItem_Take = *opaque {};
    pub const MediaTrack = *opaque {};
    pub const PCM_sink = *opaque {};
    pub const PCM_source = *opaque {};
    pub const PCM_source_peaktransfer_t = *opaque {};
    pub const PCM_source_transfer_t = *opaque {};
    pub const PLUGIN_VERSION = 0x20E;
    pub const REAPER_PeakBuild_Interface = *opaque {};
    pub const REAPER_PeakGet_Interface = *opaque {};
    pub const REAPER_Resample_Interface = *opaque {};
    pub const RECT = *opaque {};
    pub const ReaProject = c_int;
    pub const RprMidiNote = *opaque {};
    pub const RprMidiTake = *opaque {};
    pub const TrackEnvelope = *opaque {};
    pub const UINT = *opaque {};
    pub const WDL_FastString = *opaque {};
    pub const WDL_VirtualWnd_BGCfg = *opaque {};
    pub const audio_hook_register_t = *opaque {};
    pub const gfx = *opaque {};
    pub const joystick_device = *opaque {};
    pub const midi_Input = opaque {};
    pub const midi_Output = *anyopaque;
    pub const preview_register_t = *opaque {};
    pub const screensetNewCallbackFunc = *opaque {};
    pub const size_t = *opaque {};
    pub const takename = *opaque {};
    pub const plugin_info_t = extern struct {
        caller_version: c_int,
        hwnd_main: HWND,
        register: ?@TypeOf(plugin_register),
        getFunc: ?@TypeOf(plugin_getapi),
    };

    pub const custom_action_register_t = extern struct {
        section: c_int,
        id_str: [*:0]const u8,
        name: [*:0]const u8,
        extra: ?*anyopaque = null,
    };

    pub fn init(rec: *plugin_info_t) bool {
        if (rec.caller_version != PLUGIN_VERSION) {
            // std.debug.print("expected REAPER API version {x}, got {x}\n", .{ PLUGIN_VERSION, rec.caller_version });
            return false;
        }

        const getFunc = rec.getFunc.?;
        inline for (@typeInfo(@This()).Struct.decls) |decl| {
            comptime var decl_type = @typeInfo(@TypeOf(@field(@This(), decl.name)));
            const is_optional = decl_type == .Optional;
            if (is_optional)
                decl_type = @typeInfo(decl_type.Optional.child);
            if (decl_type != .Pointer or @typeInfo(decl_type.Pointer.child) != .Fn)
                continue;
            if (getFunc(decl.name)) |func|
                @field(@This(), decl.name) = @alignCast(@ptrCast(func))
            else if (is_optional)
                @field(@This(), decl.name) = null
            else {
                // std.debug.print("unable to import the API function '{s}'\n", .{decl.name});
                return false;
            }
        }

        return true;
    }

    pub var plugin_register: *fn (name: [*:0]const u8, infostruct: *anyopaque) callconv(.C) c_int = undefined;
    pub var plugin_getapi: *fn (name: [*:0]const u8) callconv(.C) ?*anyopaque = undefined;
    // pub var ShowMessageBox: *fn (body: [*:0]const u8, title: [*:0]const u8, flags: c_int) callconv(.C) void = undefined;
    // pub var ShowConsoleMsg: *fn (str: [*:0]const u8) callconv(.C) void = undefined;

    /// __mergesort
    /// __mergesort is a stable sorting function with an API similar to qsort().
    /// HOWEVER, it requires some temporary space, equal to the size of the data being sorted, so you can pass it as the last parameter,
    /// or NULL and it will allocate and free space internally.
    // TODO fix merge sort
    // __mergesort: *fn (*void base, size_t nmemb, size_t size, c_int (*cmpfunc)(*const void,*const void), *void tmpspace) callconv(.C) void,

    /// AddCustomizableMenu
    /// menuidstr is some unique identifying string
    /// menuname is for main menus only (displayed in a menu bar somewhere), NULL otherwise
    /// kbdsecname is the name of the KbdSectionInfo registered by this plugin, or NULL for the main actions section
    pub var AddCustomizableMenu: *fn (menuidstr: [*:0]const u8, menuname: [*:0]const u8, kbdsecname: [*:0]const u8, addtomainmenu: bool) callconv(.C) bool = undefined;

    /// AddExtensionsMainMenu
    /// Add an Extensions main menu, which the extension can populate/modify with plugin_register("hookcustommenu")
    pub var AddExtensionsMainMenu: *fn () callconv(.C) bool = undefined;

    /// AddMediaItemToTrack
    /// creates a new media item.
    pub var AddMediaItemToTrack: *fn (tr: *MediaTrack) callconv(.C) *MediaItem = undefined;

    /// AddProjectMarker
    /// Returns the index of the created marker/region, or -1 on failure. Supply wantidx>=0 if you want a particular index number, but you'll get a different index number a region and wantidx is already in use.
    pub var AddProjectMarker: *fn (proj: *ReaProject, isrgn: bool, pos: f64, rgnend: f64, name: [*:0]const u8, wantidx: c_int) callconv(.C) c_int = undefined;

    /// AddProjectMarker2
    /// Returns the index of the created marker/region, or -1 on failure. Supply wantidx>=0 if you want a particular index number, but you'll get a different index number a region and wantidx is already in use. color should be 0 (default color), or ColorToNative(r,g,b)|0x1000000
    pub var AddProjectMarker2: *fn (proj: *ReaProject, isrgn: bool, pos: f64, rgnend: f64, name: [*:0]const u8, wantidx: c_int, color: c_int) callconv(.C) c_int = undefined;

    /// AddRemoveReaScript
    /// Add a ReaScript (return the new command ID, or 0 if failed) or remove a ReaScript (return >0 on success). Use commit==true when adding/removing a single script. When bulk adding/removing n scripts, you can optimize the n-1 first calls with commit==false and commit==true for the last call.
    pub var AddRemoveReaScript: *fn (add: bool, sectionID: c_int, scriptfn: [*:0]const u8, commit: bool) callconv(.C) c_int = undefined;

    /// AddTakeToMediaItem
    /// creates a new take in an item
    pub var AddTakeToMediaItem: *fn (item: *MediaItem) callconv(.C) *MediaItem_Take = undefined;

    /// AddTempoTimeSigMarker
    /// Deprecated. Use SetTempoTimeSigMarker with ptidx=-1.
    pub var AddTempoTimeSigMarker: *fn (proj: *ReaProject, timepos: f64, bpm: f64, timesig_num: c_int, timesig_denom: c_int, lineartempochange: bool) callconv(.C) bool = undefined;

    /// adjustZoom
    /// forceset=0,doupd=true,centermode=-1 for default
    pub var adjustZoom: *fn (amt: f64, forceset: c_int, doupd: bool, centermode: c_int) callconv(.C) void = undefined;

    /// AnyTrackSolo
    pub var AnyTrackSolo: *fn (proj: *ReaProject) callconv(.C) bool = undefined;

    /// APIExists
    /// Returns true if function_name exists in the REAPER API
    pub var APIExists: *fn (function_name: [*:0]const u8) callconv(.C) bool = undefined;

    /// APITest
    /// Displays a message window if the API was successfully called.
    pub var APITest: *fn () callconv(.C) void = undefined;

    /// ApplyNudge
    /// nudgeflag: &1=set to value (otherwise nudge by value), &2=snap
    /// nudgewhat: 0=position, 1=left trim, 2=left edge, 3=right edge, 4=contents, 5=duplicate, 6=edit cursor
    /// nudgeunit: 0=ms, 1=seconds, 2=grid, 3=256th notes, ..., 15=whole notes, 16=measures.beats (1.15 = 1 measure + 1.5 beats), 17=samples, 18=frames, 19=pixels, 20=item lengths, 21=item selections
    /// value: amount to nudge by, or value to set to
    /// reverse: in nudge mode, nudges left (otherwise ignored)
    /// copies: in nudge duplicate mode, number of copies (otherwise ignored)
    pub var ApplyNudge: *fn (project: *ReaProject, nudgeflag: c_int, nudgewhat: c_int, nudgeunits: c_int, value: f64, reverse: bool, copies: c_int) callconv(.C) bool = undefined;

    /// ArmCommand
    /// arms a command (or disarms if 0 passed) in section sectionname (empty string for main)
    pub var ArmCommand: *fn (cmd: c_int, sectionname: [*:0]const u8) callconv(.C) void = undefined;

    /// Audio_Init
    /// open all audio and MIDI devices, if not open
    pub var Audio_Init: *fn () callconv(.C) void = undefined;

    /// Audio_IsPreBuffer
    /// is in pre-buffer? threadsafe
    pub var Audio_IsPreBuffer: *fn () callconv(.C) c_int = undefined;

    /// Audio_IsRunning
    /// is audio running at all? threadsafe
    pub var Audio_IsRunning: *fn () callconv(.C) c_int = undefined;

    /// Audio_Quit
    /// close all audio and MIDI devices, if open
    pub var Audio_Quit: *fn () callconv(.C) void = undefined;

    /// Audio_RegHardwareHook
    /// return >0 on success
    pub var Audio_RegHardwareHook: *fn (isAdd: bool, reg: *audio_hook_register_t) callconv(.C) c_int = undefined;

    /// AudioAccessorStateChanged
    /// Returns true if the underlying samples (track or media item take) have changed, but does not update the audio accessor, so the user can selectively call AudioAccessorValidateState only when needed. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, DestroyAudioAccessor, GetAudioAccessorEndTime, GetAudioAccessorSamples.
    pub var AudioAccessorStateChanged: *fn (accessor: *AudioAccessor) callconv(.C) bool = undefined;

    /// AudioAccessorUpdate
    /// Force the accessor to reload its state from the underlying track or media item take. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorEndTime, GetAudioAccessorSamples.
    pub var AudioAccessorUpdate: *fn (accessor: *AudioAccessor) callconv(.C) void = undefined;

    /// AudioAccessorValidateState
    /// Validates the current state of the audio accessor -- must ONLY call this from the main thread. Returns true if the state changed.
    pub var AudioAccessorValidateState: *fn (accessor: *AudioAccessor) callconv(.C) bool = undefined;

    /// BypassFxAllTracks
    /// -1 = bypass all if not all bypassed,otherwise unbypass all
    pub var BypassFxAllTracks: *fn (bypass: c_int) callconv(.C) void = undefined;

    /// CalcMediaSrcLoudness
    /// Calculates loudness statistics of media via dry run render. Statistics will be displayed to the user; call GetSetProjectInfo_String("RENDER_STATS") to retrieve via API. Returns 1 if loudness was calculated successfully, -1 if user canceled the dry run render.
    pub var CalcMediaSrcLoudness: *fn (mediasource: *PCM_source) callconv(.C) c_int = undefined;

    /// CalculateNormalization
    /// Calculate normalize adjustment for source media. normalizeTo: 0=LUFS-I, 1=RMS-I, 2=peak, 3=true peak, 4=LUFS-M max, 5=LUFS-S max. normalizeTarget: dBFS or LUFS value. normalizeStart, normalizeEnd: time bounds within source media for normalization calculation. If normalizationStart=0 and normalizationEnd=0, the full duration of the media will be used for the calculation.
    pub var CalculateNormalization: *fn (source: *PCM_source, normalizeTo: c_int, normalizeTarget: f64, normalizeStart: f64, normalizeEnd: f64) callconv(.C) f64 = undefined;

    /// CalculatePeaks
    pub var CalculatePeaks: *fn (srcBlock: *PCM_source_transfer_t, pksBlock: *PCM_source_peaktransfer_t) callconv(.C) c_int = undefined;

    /// CalculatePeaksFloatSrcPtr
    /// NOTE: source samples field is a pointer to f32s instead
    pub var CalculatePeaksFloatSrcPtr: *fn (srcBlock: *PCM_source_transfer_t, pksBlock: *PCM_source_peaktransfer_t) callconv(.C) c_int = undefined;

    /// ClearAllRecArmed
    pub var ClearAllRecArmed: *fn () callconv(.C) void = undefined;

    /// ClearConsole
    /// Clear the ReaScript console. See ShowConsoleMsg
    pub var ClearConsole: *fn () callconv(.C) void = undefined;

    /// ClearPeakCache
    /// resets the global peak caches
    pub var ClearPeakCache: *fn () callconv(.C) void = undefined;

    /// ColorFromNative
    /// Extract RGB values from an OS dependent color. See ColorToNative.
    pub var ColorFromNative: *fn (col: c_int, rOut: *c_int, gOut: *c_int, bOut: *c_int) callconv(.C) void = undefined;

    /// ColorToNative
    /// Make an OS dependent color from RGB values (e.g. RGB() macro on Windows). r,g and b are in [0..255]. See ColorFromNative.
    pub var ColorToNative: *fn (r: c_int, g: c_int, b: c_int) callconv(.C) c_int = undefined;

    /// CountActionShortcuts
    /// Returns the number of shortcuts that exist for the given command ID.
    /// see GetActionShortcutDesc, DeleteActionShortcut, DoActionShortcutDialog.
    pub var CountActionShortcuts: *fn (section: *KbdSectionInfo, cmdID: c_int) callconv(.C) c_int = undefined;

    /// CountAutomationItems
    /// Returns the number of automation items on this envelope. See GetSetAutomationItemInfo
    pub var CountAutomationItems: *fn (env: *TrackEnvelope) callconv(.C) c_int = undefined;

    /// CountEnvelopePoints
    /// Returns the number of points in the envelope. See CountEnvelopePointsEx.
    pub var CountEnvelopePoints: *fn (envelope: *TrackEnvelope) callconv(.C) c_int = undefined;

    /// CountEnvelopePointsEx
    /// Returns the number of points in the envelope.
    /// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
    /// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
    /// even if the automation item is trimmed so that not all points are visible.
    /// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
    /// See GetEnvelopePointEx, SetEnvelopePointEx, InsertEnvelopePointEx, DeleteEnvelopePointEx.
    pub var CountEnvelopePointsEx: *fn (envelope: *TrackEnvelope, autoitem_idx: c_int) callconv(.C) c_int = undefined;

    /// CountMediaItems
    /// count the number of items in the project (proj=0 for active project)
    pub var CountMediaItems: *fn (proj: *ReaProject) callconv(.C) c_int = undefined;

    /// CountProjectMarkers
    /// num_markersOut and num_regionsOut may be NULL.
    pub var CountProjectMarkers: *fn (proj: *ReaProject, num_markersOut: *c_int, num_regionsOut: *c_int) callconv(.C) c_int = undefined;

    /// CountSelectedMediaItems
    /// count the number of selected items in the project (proj=0 for active project)
    pub var CountSelectedMediaItems: *fn (proj: *ReaProject) callconv(.C) c_int = undefined;

    /// CountSelectedTracks
    /// Count the number of selected tracks in the project (proj=0 for active project). This function ignores the master track, see CountSelectedTracks2.
    pub var CountSelectedTracks: *fn (proj: *ReaProject) callconv(.C) c_int = undefined;

    /// CountSelectedTracks2
    /// Count the number of selected tracks in the project (proj=0 for active project).
    pub var CountSelectedTracks2: *fn (proj: *ReaProject, wantmaster: bool) callconv(.C) c_int = undefined;

    /// CountTakeEnvelopes
    /// See GetTakeEnvelope
    pub var CountTakeEnvelopes: *fn (take: *MediaItem_Take) callconv(.C) c_int = undefined;

    /// CountTakes
    /// count the number of takes in the item
    pub var CountTakes: *fn (item: *MediaItem) callconv(.C) c_int = undefined;

    /// CountTCPFXParms
    /// Count the number of FX parameter knobs displayed on the track control panel.
    pub var CountTCPFXParms: *fn (project: *ReaProject, track: *MediaTrack) callconv(.C) c_int = undefined;

    /// CountTempoTimeSigMarkers
    /// Count the number of tempo/time signature markers in the project. See GetTempoTimeSigMarker, SetTempoTimeSigMarker, AddTempoTimeSigMarker.
    pub var CountTempoTimeSigMarkers: *fn (proj: *ReaProject) callconv(.C) c_int = undefined;

    /// CountTrackEnvelopes
    /// see GetTrackEnvelope
    pub var CountTrackEnvelopes: *fn (track: *MediaTrack) callconv(.C) c_int = undefined;

    /// CountTrackMediaItems
    /// count the number of items in the track
    pub var CountTrackMediaItems: *fn (track: *MediaTrack) callconv(.C) c_int = undefined;

    /// CountTracks
    /// count the number of tracks in the project (proj=0 for active project)
    pub var CountTracks: *fn (projOptional: *ReaProject) callconv(.C) c_int = undefined;

    /// CreateLocalOscHandler
    /// callback is a function pointer: void (*callback)(*void obj, [*:0]const u8 msg, c_int msglen), which handles OSC messages sent from REAPER. The function return is a local osc handler. See SendLocalOscMessage, DestroyOscHandler.
    pub var CreateLocalOscHandler: *fn (obj: *void, callback: *void) callconv(.C) *void = undefined;

    /// CreateMIDIInput
    /// Can only reliably create midi access for devices not already opened in prefs/MIDI, suitable for control surfaces etc.
    pub var CreateMIDIInput: *fn (dev: c_int) callconv(.C) *midi_Input = undefined;

    /// CreateMIDIOutput
    /// Can only reliably create midi access for devices not already opened in prefs/MIDI, suitable for control surfaces etc. If streamMode is set, msoffset100 points to a persistent variable that can change and reflects added delay to output in 100ths of a millisecond.
    pub var CreateMIDIOutput: *fn (dev: c_int, streamMode: bool, msoffset100: ?*c_int) callconv(.C) midi_Output = undefined;

    /// CreateNewMIDIItemInProj
    /// Create a new MIDI media item, containing no MIDI events. Time is in seconds unless qn is set.
    pub var CreateNewMIDIItemInProj: *fn (track: *MediaTrack, starttime: f64, endtime: f64, qnInOptional: *const bool) callconv(.C) *MediaItem = undefined;

    /// CreateTakeAudioAccessor
    /// Create an audio accessor object for this take. Must only call from the main thread. See CreateTrackAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorEndTime, GetAudioAccessorSamples.
    pub var CreateTakeAudioAccessor: *fn (take: *MediaItem_Take) callconv(.C) *AudioAccessor = undefined;

    /// CreateTrackAudioAccessor
    /// Create an audio accessor object for this track. Must only call from the main thread. See CreateTakeAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorEndTime, GetAudioAccessorSamples.
    pub var CreateTrackAudioAccessor: *fn (track: *MediaTrack) callconv(.C) *AudioAccessor = undefined;

    /// CreateTrackSend
    /// Create a send/receive (desttrInOptional!=NULL), or a hardware output (desttrInOptional==NULL) with default properties, return >=0 on success (== new send/receive index). See RemoveTrackSend, GetSetTrackSendInfo, GetTrackSendInfo_Value, SetTrackSendInfo_Value.
    pub var CreateTrackSend: *fn (tr: *MediaTrack, desttrInOptional: *MediaTrack) callconv(.C) c_int = undefined;

    /// CSurf_FlushUndo
    /// call this to force flushing of the undo states after using *CSurf_OnChange()
    pub var CSurf_FlushUndo: *fn (force: bool) callconv(.C) void = undefined;

    /// CSurf_GetTouchState
    pub var CSurf_GetTouchState: *fn (trackid: *MediaTrack, isPan: c_int) callconv(.C) bool = undefined;

    /// CSurf_GoEnd
    pub var CSurf_GoEnd: *fn () callconv(.C) void = undefined;

    /// CSurf_GoStart
    pub var CSurf_GoStart: *fn () callconv(.C) void = undefined;

    /// CSurf_NumTracks
    pub var CSurf_NumTracks: *fn (mcpView: bool) callconv(.C) c_int = undefined;

    /// CSurf_OnArrow
    pub var CSurf_OnArrow: *fn (whichdir: c_int, wantzoom: bool) callconv(.C) void = undefined;

    /// CSurf_OnFwd
    pub var CSurf_OnFwd: *fn (seekplay: c_int) callconv(.C) void = undefined;

    /// CSurf_OnFXChange
    pub var CSurf_OnFXChange: *fn (trackid: *MediaTrack, en: c_int) callconv(.C) bool = undefined;

    /// CSurf_OnInputMonitorChange
    pub var CSurf_OnInputMonitorChange: *fn (trackid: *MediaTrack, monitor: c_int) callconv(.C) c_int = undefined;

    /// CSurf_OnInputMonitorChangeEx
    pub var CSurf_OnInputMonitorChangeEx: *fn (trackid: *MediaTrack, monitor: c_int, allowgang: bool) callconv(.C) c_int = undefined;

    /// CSurf_OnMuteChange
    pub var CSurf_OnMuteChange: *fn (trackid: MediaTrack, mute: c_int) callconv(.C) bool = undefined;

    /// CSurf_OnMuteChangeEx
    pub var CSurf_OnMuteChangeEx: *fn (trackid: *MediaTrack, mute: c_int, allowgang: bool) callconv(.C) bool = undefined;

    /// CSurf_OnOscControlMessage
    pub var CSurf_OnOscControlMessage: *fn (msg: [*:0]const u8, arg: *const f32) callconv(.C) void = undefined;

    /// CSurf_OnOscControlMessage2
    pub var CSurf_OnOscControlMessage2: *fn (msg: [*:0]const u8, arg: *const f32, argstr: [*:0]const u8) callconv(.C) void = undefined;

    /// CSurf_OnPanChange
    pub var CSurf_OnPanChange: *fn (trackid: MediaTrack, pan: f64, relative: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnPanChangeEx
    pub var CSurf_OnPanChangeEx: *fn (trackid: *MediaTrack, pan: f64, relative: bool, allowGang: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnPause
    pub var CSurf_OnPause: *fn () callconv(.C) void = undefined;

    /// CSurf_OnPlay
    pub var CSurf_OnPlay: *fn () callconv(.C) void = undefined;

    /// CSurf_OnPlayRateChange
    pub var CSurf_OnPlayRateChange: *fn (playrate: f64) callconv(.C) void = undefined;

    /// CSurf_OnRecArmChange
    pub var CSurf_OnRecArmChange: *fn (trackid: *MediaTrack, recarm: c_int) callconv(.C) bool = undefined;

    /// CSurf_OnRecArmChangeEx
    pub var CSurf_OnRecArmChangeEx: *fn (trackid: *MediaTrack, recarm: c_int, allowgang: bool) callconv(.C) bool = undefined;

    /// CSurf_OnRecord
    pub var CSurf_OnRecord: *fn () callconv(.C) void = undefined;

    /// CSurf_OnRecvPanChange
    pub var CSurf_OnRecvPanChange: *fn (trackid: *MediaTrack, recv_index: c_int, pan: f64, relative: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnRecvVolumeChange
    pub var CSurf_OnRecvVolumeChange: *fn (trackid: *MediaTrack, recv_index: c_int, volume: f64, relative: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnRew
    pub var CSurf_OnRew: *fn (seekplay: c_int) callconv(.C) void = undefined;

    /// CSurf_OnRewFwd
    pub var CSurf_OnRewFwd: *fn (seekplay: c_int, dir: c_int) callconv(.C) void = undefined;

    /// CSurf_OnScroll
    pub var CSurf_OnScroll: *fn (xdir: c_int, ydir: c_int) callconv(.C) void = undefined;

    /// CSurf_OnSelectedChange
    pub var CSurf_OnSelectedChange: *fn (trackid: *MediaTrack, selected: c_int) callconv(.C) bool = undefined;

    /// CSurf_OnSendPanChange
    pub var CSurf_OnSendPanChange: *fn (trackid: *MediaTrack, send_index: c_int, pan: f64, relative: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnSendVolumeChange
    pub var CSurf_OnSendVolumeChange: *fn (trackid: *MediaTrack, send_index: c_int, volume: f64, relative: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnSoloChange
    pub var CSurf_OnSoloChange: *fn (trackid: MediaTrack, solo: c_int) callconv(.C) bool = undefined;

    /// CSurf_OnSoloChangeEx
    pub var CSurf_OnSoloChangeEx: *fn (trackid: *MediaTrack, solo: c_int, allowgang: bool) callconv(.C) bool = undefined;

    /// CSurf_OnStop
    pub var CSurf_OnStop: *fn () callconv(.C) void = undefined;

    /// CSurf_OnTempoChange
    pub var CSurf_OnTempoChange: *fn (bpm: f64) callconv(.C) void = undefined;

    /// CSurf_OnTrackSelection
    pub var CSurf_OnTrackSelection: *fn (trackid: *MediaTrack) callconv(.C) void = undefined;

    /// CSurf_OnVolumeChange
    pub var CSurf_OnVolumeChange: *fn (trackid: MediaTrack, volume: f64, relative: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnVolumeChangeEx
    pub var CSurf_OnVolumeChangeEx: *fn (trackid: *MediaTrack, volume: f64, relative: bool, allowGang: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnWidthChange
    pub var CSurf_OnWidthChange: *fn (trackid: *MediaTrack, width: f64, relative: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnWidthChangeEx
    pub var CSurf_OnWidthChangeEx: *fn (trackid: *MediaTrack, width: f64, relative: bool, allowGang: bool) callconv(.C) f64 = undefined;

    /// CSurf_OnZoom
    pub var CSurf_OnZoom: *fn (xdir: c_int, ydir: c_int) callconv(.C) void = undefined;

    /// CSurf_ResetAllCachedVolPanStates
    pub var CSurf_ResetAllCachedVolPanStates: *fn () callconv(.C) void = undefined;

    /// CSurf_ScrubAmt
    pub var CSurf_ScrubAmt: *fn (amt: f64) callconv(.C) void = undefined;

    /// CSurf_SetAutoMode
    pub var CSurf_SetAutoMode: *fn (mode: c_int, ignoresurf: *IReaperControlSurface) callconv(.C) void = undefined;

    /// CSurf_SetPlayState
    pub var CSurf_SetPlayState: *fn (play: bool, pause: bool, rec: bool, ignoresurf: *IReaperControlSurface) callconv(.C) void = undefined;

    /// CSurf_SetRepeatState
    pub var CSurf_SetRepeatState: *fn (rep: bool, ignoresurf: *IReaperControlSurface) callconv(.C) void = undefined;

    /// CSurf_SetSurfaceMute
    pub var CSurf_SetSurfaceMute: *fn (trackid: MediaTrack, mute: bool, ignoresurf: ?*IReaperControlSurface) callconv(.C) void = undefined;

    /// CSurf_SetSurfacePan
    pub var CSurf_SetSurfacePan: *fn (trackid: MediaTrack, pan: f64, ignoresurf: ?*IReaperControlSurface) callconv(.C) void = undefined;

    /// CSurf_SetSurfaceRecArm
    pub var CSurf_SetSurfaceRecArm: *fn (trackid: *MediaTrack, recarm: bool, ignoresurf: *IReaperControlSurface) callconv(.C) void = undefined;

    /// CSurf_SetSurfaceSelected
    pub var CSurf_SetSurfaceSelected: *fn (trackid: *MediaTrack, selected: bool, ignoresurf: *IReaperControlSurface) callconv(.C) void = undefined;

    /// CSurf_SetSurfaceSolo
    pub var CSurf_SetSurfaceSolo: *fn (trackid: MediaTrack, solo: bool, ignoresurf: ?*IReaperControlSurface) callconv(.C) void = undefined;

    /// CSurf_SetSurfaceVolume
    pub var CSurf_SetSurfaceVolume: *fn (trackid: MediaTrack, volume: f64, ignoresurf: ?*IReaperControlSurface) callconv(.C) void = undefined;

    /// CSurf_SetTrackListChange
    pub var CSurf_SetTrackListChange: *fn () callconv(.C) void = undefined;

    /// CSurf_TrackFromID
    pub var CSurf_TrackFromID: *fn (idx: c_int, mcpView: bool) callconv(.C) MediaTrack = undefined;

    /// CSurf_TrackToID
    pub var CSurf_TrackToID: *fn (track: MediaTrack, mcpView: bool) callconv(.C) c_int = undefined;

    /// DB2SLIDER
    pub var DB2SLIDER: *fn (x: f64) callconv(.C) f64 = undefined;

    /// DeleteActionShortcut
    /// Delete the specific shortcut for the given command ID.
    /// See CountActionShortcuts, GetActionShortcutDesc, DoActionShortcutDialog.
    pub var DeleteActionShortcut: *fn (section: *KbdSectionInfo, cmdID: c_int, shortcutidx: c_int) callconv(.C) bool = undefined;

    /// DeleteEnvelopePointEx
    /// Delete an envelope point. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done.
    /// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
    /// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
    /// even if the automation item is trimmed so that not all points are visible.
    /// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
    /// See CountEnvelopePointsEx, GetEnvelopePointEx, SetEnvelopePointEx, InsertEnvelopePointEx.
    pub var DeleteEnvelopePointEx: *fn (envelope: *TrackEnvelope, autoitem_idx: c_int, ptidx: c_int) callconv(.C) bool = undefined;

    /// DeleteEnvelopePointRange
    /// Delete a range of envelope points. See DeleteEnvelopePointRangeEx, DeleteEnvelopePointEx.
    pub var DeleteEnvelopePointRange: *fn (envelope: *TrackEnvelope, time_start: f64, time_end: f64) callconv(.C) bool = undefined;

    /// DeleteEnvelopePointRangeEx
    /// Delete a range of envelope points. autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
    pub var DeleteEnvelopePointRangeEx: *fn (envelope: *TrackEnvelope, autoitem_idx: c_int, time_start: f64, time_end: f64) callconv(.C) bool = undefined;

    /// DeleteExtState
    /// Delete the extended state value for a specific section and key. persist=true means the value should remain deleted the next time REAPER is opened. See SetExtState, GetExtState, HasExtState.
    pub var DeleteExtState: *fn (section: [*:0]const u8, key: [*:0]const u8, persist: bool) callconv(.C) void = undefined;

    /// DeleteProjectMarker
    /// Delete a marker.  proj==NULL for the active project.
    pub var DeleteProjectMarker: *fn (proj: *ReaProject, markrgnindexnumber: c_int, isrgn: bool) callconv(.C) bool = undefined;

    /// DeleteProjectMarkerByIndex
    /// Differs from DeleteProjectMarker only in that markrgnidx is 0 for the first marker/region, 1 for the next, etc (see EnumProjectMarkers3), rather than representing the displayed marker/region ID number (see SetProjectMarker4).
    pub var DeleteProjectMarkerByIndex: *fn (proj: *ReaProject, markrgnidx: c_int) callconv(.C) bool = undefined;

    /// DeleteTakeMarker
    /// Delete a take marker. Note that idx will change for all following take markers. See GetNumTakeMarkers, GetTakeMarker, SetTakeMarker
    pub var DeleteTakeMarker: *fn (take: *MediaItem_Take, idx: c_int) callconv(.C) bool = undefined;

    /// DeleteTakeStretchMarkers
    /// Deletes one or more stretch markers. Returns number of stretch markers deleted.
    pub var DeleteTakeStretchMarkers: *fn (take: *MediaItem_Take, idx: c_int, countInOptional: *const c_int) callconv(.C) c_int = undefined;

    /// DeleteTempoTimeSigMarker
    /// Delete a tempo/time signature marker.
    pub var DeleteTempoTimeSigMarker: *fn (project: *ReaProject, markerindex: c_int) callconv(.C) bool = undefined;

    /// DeleteTrack
    /// deletes a track
    pub var DeleteTrack: *fn (tr: *MediaTrack) callconv(.C) void = undefined;

    /// DeleteTrackMediaItem
    pub var DeleteTrackMediaItem: *fn (tr: *MediaTrack, it: *MediaItem) callconv(.C) bool = undefined;

    /// DestroyAudioAccessor
    /// Destroy an audio accessor. Must only call from the main thread. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorEndTime, GetAudioAccessorSamples.
    pub var DestroyAudioAccessor: *fn (accessor: *AudioAccessor) callconv(.C) void = undefined;

    /// DestroyLocalOscHandler
    /// See CreateLocalOscHandler, SendLocalOscMessage.
    pub var DestroyLocalOscHandler: *fn (local_osc_handler: *void) callconv(.C) void = undefined;

    /// DoActionShortcutDialog
    /// Open the action shortcut dialog to edit or add a shortcut for the given command ID. If (shortcutidx >= 0 && shortcutidx < CountActionShortcuts()), that specific shortcut will be replaced, otherwise a new shortcut will be added.
    /// See CountActionShortcuts, GetActionShortcutDesc, DeleteActionShortcut.
    pub var DoActionShortcutDialog: *fn (hwnd: HWND, section: *KbdSectionInfo, cmdID: c_int, shortcutidx: c_int) callconv(.C) bool = undefined;

    /// Dock_UpdateDockID
    /// updates preference for docker window ident_str to be in dock whichDock on next open
    pub var Dock_UpdateDockID: *fn (ident_str: [*:0]const u8, whichDock: c_int) callconv(.C) void = undefined;

    /// DockGetPosition
    /// -1=not found, 0=bottom, 1=left, 2=top, 3=right, 4=f32ing
    pub var DockGetPosition: *fn (whichDock: c_int) callconv(.C) c_int = undefined;

    /// DockIsChildOfDock
    /// returns dock index that contains hwnd, or -1
    pub var DockIsChildOfDock: *fn (hwnd: HWND, isFloatingDockerOut: *bool) callconv(.C) c_int = undefined;

    /// DockWindowActivate
    pub var DockWindowActivate: *fn (hwnd: HWND) callconv(.C) void = undefined;

    /// DockWindowAdd
    pub var DockWindowAdd: *fn (hwnd: HWND, name: [*:0]const u8, pos: c_int, allowShow: bool) callconv(.C) void = undefined;

    /// DockWindowAddEx
    pub var DockWindowAddEx: *fn (hwnd: HWND, name: [*:0]const u8, identstr: [*:0]const u8, allowShow: bool) callconv(.C) void = undefined;

    /// DockWindowRefresh
    pub var DockWindowRefresh: *fn () callconv(.C) void = undefined;

    /// DockWindowRefreshForHWND
    pub var DockWindowRefreshForHWND: *fn (hwnd: HWND) callconv(.C) void = undefined;

    /// DockWindowRemove
    pub var DockWindowRemove: *fn (hwnd: HWND) callconv(.C) void = undefined;

    /// DuplicateCustomizableMenu
    /// Populate destmenu with all the entries and submenus found in srcmenu
    pub var DuplicateCustomizableMenu: *fn (srcmenu: *void, destmenu: *void) callconv(.C) bool = undefined;

    /// EditTempoTimeSigMarker
    /// Open the tempo/time signature marker editor dialog.
    pub var EditTempoTimeSigMarker: *fn (project: *ReaProject, markerindex: c_int) callconv(.C) bool = undefined;

    /// EnsureNotCompletelyOffscreen
    /// call with a saved window rect for your window and it'll correct any positioning info.
    pub var EnsureNotCompletelyOffscreen: *fn (rInOut: *RECT) callconv(.C) void = undefined;

    /// EnumerateFiles
    /// List the files in the "path" directory. Returns NULL/nil when all files have been listed. Use fileindex = -1 to force re-read of directory (invalidate cache). See EnumerateSubdirectories
    pub var EnumerateFiles: *fn (path: [*:0]const u8, fileindex: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// EnumerateSubdirectories
    /// List the subdirectories in the "path" directory. Use subdirindex = -1 to force re-read of directory (invalidate cache). Returns NULL/nil when all subdirectories have been listed. See EnumerateFiles
    pub var EnumerateSubdirectories: *fn (path: [*:0]const u8, subdirindex: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// EnumInstalledFX
    /// Enumerates installed FX. Returns true if successful, sets nameOut and identOut to name and ident of FX at index.
    pub var EnumInstalledFX: *fn (index: c_int, nameOut: [*:0]const u8, identOut: [*:0]const u8) callconv(.C) bool = undefined;

    /// EnumPitchShiftModes
    /// Start querying modes at 0, returns FALSE when no more modes possible, sets strOut to NULL if a mode is currently unsupported
    pub var EnumPitchShiftModes: *fn (mode: c_int, strOut: [*:0]const u8) callconv(.C) bool = undefined;

    /// EnumPitchShiftSubModes
    /// Returns submode name, or NULL
    pub var EnumPitchShiftSubModes: *fn (mode: c_int, submode: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// EnumProjectMarkers
    pub var EnumProjectMarkers: *fn (idx: c_int, isrgnOut: *bool, posOut: *f64, rgnendOut: *f64, nameOut: [*:0]const u8, markrgnindexnumberOut: *c_int) callconv(.C) c_int = undefined;

    /// EnumProjectMarkers2
    pub var EnumProjectMarkers2: *fn (proj: *ReaProject, idx: c_int, isrgnOut: *bool, posOut: *f64, rgnendOut: *f64, nameOut: [*:0]const u8, markrgnindexnumberOut: *c_int) callconv(.C) c_int = undefined;

    /// EnumProjectMarkers3
    pub var EnumProjectMarkers3: *fn (proj: *ReaProject, idx: c_int, isrgnOut: *bool, posOut: *f64, rgnendOut: *f64, nameOut: [*:0]const u8, markrgnindexnumberOut: *c_int, colorOut: *c_int) callconv(.C) c_int = undefined;

    /// EnumProjects
    /// idx=-1 for current project,projfn can be NULL if not interested in filename. use idx 0x40000000 for currently rendering project, if any.
    pub var EnumProjects: *fn (idx: c_int, projfnOutOptional: ?*c_char) callconv(.C) *ReaProject = undefined;

    /// EnumProjExtState
    /// Enumerate the data stored with the project for a specific extname. Returns false when there is no more data. See SetProjExtState, GetProjExtState.
    pub var EnumProjExtState: *fn (proj: *ReaProject, extname: [*:0]const u8, idx: c_int, keyOutOptional: *c_char, keyOutOptional_sz: c_int, valOutOptional: *c_char, valOutOptional_sz: c_int) callconv(.C) bool = undefined;

    /// EnumRegionRenderMatrix
    /// Enumerate which tracks will be rendered within this region when using the region render matrix. When called with rendertrack==0, the function returns the first track that will be rendered (which may be the master track); rendertrack==1 will return the next track rendered, and so on. The function returns NULL when there are no more tracks that will be rendered within this region.
    pub var EnumRegionRenderMatrix: *fn (proj: *ReaProject, regionindex: c_int, rendertrack: c_int) callconv(.C) *MediaTrack = undefined;

    /// EnumTrackMIDIProgramNames
    /// returns false if there are no plugins on the track that support MIDI programs,or if all programs have been enumerated
    pub var EnumTrackMIDIProgramNames: *fn (track: c_int, programNumber: c_int, programName: *c_char, programName_sz: c_int) callconv(.C) bool = undefined;

    /// EnumTrackMIDIProgramNamesEx
    /// returns false if there are no plugins on the track that support MIDI programs,or if all programs have been enumerated
    pub var EnumTrackMIDIProgramNamesEx: *fn (proj: *ReaProject, track: *MediaTrack, programNumber: c_int, programName: *c_char, programName_sz: c_int) callconv(.C) bool = undefined;

    /// Envelope_Evaluate
    /// Get the effective envelope value at a given time position. samplesRequested is how long the caller expects until the next call to Envelope_Evaluate (often, the buffer block size). The return value is how many samples beyond that time position that the returned values are valid. dVdS is the change in value per sample (first derivative), ddVdS is the second derivative, dddVdS is the third derivative. See GetEnvelopeScalingMode.
    pub var Envelope_Evaluate: *fn (envelope: *TrackEnvelope, time: f64, samplerate: f64, samplesRequested: c_int, valueOut: *f64, dVdSOut: *f64, ddVdSOut: *f64, dddVdSOut: *f64) callconv(.C) c_int = undefined;

    /// Envelope_FormatValue
    /// Formats the value of an envelope to a user-readable form
    pub var Envelope_FormatValue: *fn (env: *TrackEnvelope, value: f64, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) void = undefined;

    /// Envelope_GetParentTake
    /// If take envelope, gets the take from the envelope. If FX, indexOut set to FX index, index2Out set to parameter index, otherwise -1.
    pub var Envelope_GetParentTake: *fn (env: *TrackEnvelope, indexOut: *c_int, index2Out: *c_int) callconv(.C) *MediaItem_Take = undefined;

    /// Envelope_GetParentTrack
    /// If track envelope, gets the track from the envelope. If FX, indexOut set to FX index, index2Out set to parameter index, otherwise -1.
    pub var Envelope_GetParentTrack: *fn (env: *TrackEnvelope, indexOut: *c_int, index2Out: *c_int) callconv(.C) *MediaTrack = undefined;

    /// Envelope_SortPoints
    /// Sort envelope points by time. See SetEnvelopePoint, InsertEnvelopePoint.
    pub var Envelope_SortPoints: *fn (envelope: *TrackEnvelope) callconv(.C) bool = undefined;

    /// Envelope_SortPointsEx
    /// Sort envelope points by time. autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc. See SetEnvelopePoint, InsertEnvelopePoint.
    pub var Envelope_SortPointsEx: *fn (envelope: *TrackEnvelope, autoitem_idx: c_int) callconv(.C) bool = undefined;

    /// ExecProcess
    /// Executes command line, returns NULL on total failure, otherwise the return value, a newline, and then the output of the command. If timeoutmsec is 0, command will be allowed to run indefinitely (recommended for large amounts of returned output). timeoutmsec is -1 for no wait/terminate, -2 for no wait and minimize
    pub var ExecProcess: *fn (cmdline: [*:0]const u8, timeoutmsec: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// file_exists
    /// returns true if path points to a valid, readable file
    pub var file_exists: *fn (path: [*:0]const u8) callconv(.C) bool = undefined;

    /// FindTempoTimeSigMarker
    /// Find the tempo/time signature marker that falls at or before this time position (the marker that is in effect as of this time position).
    pub var FindTempoTimeSigMarker: *fn (project: *ReaProject, time: f64) callconv(.C) c_int = undefined;

    /// format_timestr
    /// Format tpos (which is time in seconds) as hh:mm:ss.sss. See format_timestr_pos, format_timestr_len.
    pub var format_timestr: *fn (tpos: f64, buf: *c_char, buf_sz: c_int) callconv(.C) void = undefined;

    /// format_timestr_len
    /// time formatting mode overrides: -1=proj default.
    /// 0=time
    /// 1=measures.beats + time
    /// 2=measures.beats
    /// 3=seconds
    /// 4=samples
    /// 5=h:m:s:f
    /// offset is start of where the length will be calculated from
    pub var format_timestr_len: *fn (tpos: f64, buf: *c_char, buf_sz: c_int, offset: f64, modeoverride: c_int) callconv(.C) void = undefined;

    /// format_timestr_pos
    /// time formatting mode overrides: -1=proj default.
    /// 0=time
    /// 1=measures.beats + time
    /// 2=measures.beats
    /// 3=seconds
    /// 4=samples
    /// 5=h:m:s:f
    ///
    pub var format_timestr_pos: *fn (tpos: f64, buf: *c_char, buf_sz: c_int, modeoverride: c_int) callconv(.C) void = undefined;

    /// FreeHeapPtr
    /// free heap memory returned from a Reaper API function
    pub var FreeHeapPtr: *fn (ptr: *void) callconv(.C) void = undefined;

    /// genGuid
    pub var genGuid: *fn (g: *GUID) callconv(.C) void = undefined;

    /// get_config_var
    /// gets ini configuration variable by name, raw, returns size of variable in szOut and pointer to variable. special values queryable are also:
    ///   __numcpu (c_int) cpu count.
    ///   __fx_loadstate_ctx (c_char): 0 if unknown, or during FX state loading: 'u' (instantiating via undo), 'U' (updating via undo), 'P' (loading preset).
    pub var get_config_var: *fn (name: [*:0]const u8, szOut: *c_int) callconv(.C) *void = undefined;

    /// get_config_var_string
    /// gets ini configuration variable value as string
    pub var get_config_var_string: *fn (name: [*:0]const u8, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// get_ini_file
    /// Get reaper.ini full filename.
    pub var get_ini_file: *fn () callconv(.C) [*:0]const u8 = undefined;

    /// get_midi_config_var
    /// Deprecated.
    pub var get_midi_config_var: *fn (name: [*:0]const u8, szOut: *c_int) callconv(.C) *void = undefined;

    /// GetActionShortcutDesc
    /// Get the text description of a specific shortcut for the given command ID.
    /// See CountActionShortcuts,DeleteActionShortcut,DoActionShortcutDialog.
    pub var GetActionShortcutDesc: *fn (section: *KbdSectionInfo, cmdID: c_int, shortcutidx: c_int, descOut: *c_char, descOut_sz: c_int) callconv(.C) bool = undefined;

    /// GetActiveTake
    /// get the active take in this item
    pub var GetActiveTake: *fn (item: *MediaItem) callconv(.C) *MediaItem_Take = undefined;

    /// GetAllProjectPlayStates
    /// returns the bitwise OR of all project play states (1=playing, 2=pause, 4=recording)
    pub var GetAllProjectPlayStates: *fn (ignoreProject: *ReaProject) callconv(.C) c_int = undefined;

    /// GetAppVersion
    /// Returns app version which may include an OS/arch signifier, such as: "6.17" (windows 32-bit), "6.17/x64" (windows 64-bit), "6.17/OSX64" (macOS 64-bit Intel), "6.17/OSX" (macOS 32-bit), "6.17/macOS-arm64", "6.17/linux-x86_64", "6.17/linux-i686", "6.17/linux-aarch64", "6.17/linux-armv7l", etc
    pub var GetAppVersion: *fn () callconv(.C) [*:0]const u8 = undefined;

    /// GetArmedCommand
    /// gets the currently armed command and section name (returns 0 if nothing armed). section name is empty-string for main section.
    pub var GetArmedCommand: *fn (secOut: *c_char, secOut_sz: c_int) callconv(.C) c_int = undefined;

    /// GetAudioAccessorEndTime
    /// Get the end time of the audio that can be returned from this accessor. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorSamples.
    pub var GetAudioAccessorEndTime: *fn (accessor: *AudioAccessor) callconv(.C) f64 = undefined;

    /// GetAudioAccessorHash
    /// Deprecated. See AudioAccessorStateChanged instead.
    pub var GetAudioAccessorHash: *fn (accessor: *AudioAccessor, hashNeed128: *c_char) callconv(.C) void = undefined;

    /// GetAudioAccessorSamples
    /// Get a block of samples from the audio accessor. Samples are extracted immediately pre-FX, and returned interleaved (first sample of first channel, first sample of second channel...). Returns 0 if no audio, 1 if audio, -1 on error. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorEndTime.//
    ///
    /// This function has special handling in Python, and only returns two objects, the API function return value, and the sample buffer. Example usage:
    ///
    /// <code>tr = RPR_GetTrack(0, 0)
    /// aa = RPR_CreateTrackAudioAccessor(tr)
    /// buf = list([0]*2*1024) # 2 channels, 1024 samples each, initialized to zero
    /// pos = 0.0
    /// (ret, buf) = GetAudioAccessorSamples(aa, 44100, 2, pos, 1024, buf)
    /// # buf now holds the first 2*1024 audio samples from the track.
    /// # typically GetAudioAccessorSamples() would be called within a loop, increasing pos each time.
    /// </code>
    pub var GetAudioAccessorSamples: *fn (accessor: *AudioAccessor, samplerate: c_int, numchannels: c_int, starttime_sec: f64, numsamplesperchannel: c_int, samplebuffer: *f64) callconv(.C) c_int = undefined;

    /// GetAudioAccessorStartTime
    /// Get the start time of the audio that can be returned from this accessor. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorEndTime, GetAudioAccessorSamples.
    pub var GetAudioAccessorStartTime: *fn (accessor: *AudioAccessor) callconv(.C) f64 = undefined;

    /// GetAudioDeviceInfo
    /// get information about the currently open audio device. attribute can be MODE, IDENT_IN, IDENT_OUT, BSIZE, SRATE, BPS. returns false if unknown attribute or device not open.
    pub var GetAudioDeviceInfo: *fn (attribute: [*:0]const u8, descOut: *c_char, descOut_sz: c_int) callconv(.C) bool = undefined;

    /// GetColorTheme
    /// Deprecated, see GetColorThemeStruct.
    // GetColorTheme: *fn(idx: c_int, defval:  c_int) callconv(.C) c_int_PTR ,

    /// GetColorThemeStruct
    /// returns the whole color theme (icontheme.h) and the size
    pub var GetColorThemeStruct: *fn (szOut: *c_int) callconv(.C) *void = undefined;

    /// GetConfigWantsDock
    /// gets the dock ID desired by ident_str, if any
    pub var GetConfigWantsDock: *fn (ident_str: [*:0]const u8) callconv(.C) c_int = undefined;

    /// GetContextMenu
    /// gets context menus. submenu 0:trackctl, 1:mediaitems, 2:ruler, 3:empty track area
    pub var GetContextMenu: *fn (idx: c_int) callconv(.C) HMENU = undefined;

    /// GetCurrentProjectInLoadSave
    /// returns current project if in load/save (usually only used from project_config_extension_t)
    pub var GetCurrentProjectInLoadSave: *fn () callconv(.C) *ReaProject = undefined;

    /// GetCursorContext
    /// return the current cursor context: 0 if track panels, 1 if items, 2 if envelopes, otherwise unknown
    pub var GetCursorContext: *fn () callconv(.C) c_int = undefined;

    /// GetCursorContext2
    /// 0 if track panels, 1 if items, 2 if envelopes, otherwise unknown (unlikely when want_last_valid is true)
    pub var GetCursorContext2: *fn (want_last_valid: bool) callconv(.C) c_int = undefined;

    /// GetCursorPosition
    /// edit cursor position
    pub var GetCursorPosition: *fn () callconv(.C) f64 = undefined;

    /// GetCursorPositionEx
    /// edit cursor position
    pub var GetCursorPositionEx: *fn (proj: *ReaProject) callconv(.C) f64 = undefined;

    /// GetDisplayedMediaItemColor
    /// see GetDisplayedMediaItemColor2.
    pub var GetDisplayedMediaItemColor: *fn (item: *MediaItem) callconv(.C) c_int = undefined;

    /// GetDisplayedMediaItemColor2
    /// Returns the custom take, item, or track color that is used (according to the user preference) to color the media item. The returned color is OS dependent|0x01000000 (i.e. ColorToNative(r,g,b)|0x01000000), so a return of zero means "no color", not black.
    pub var GetDisplayedMediaItemColor2: *fn (item: *MediaItem, take: *MediaItem_Take) callconv(.C) c_int = undefined;

    /// GetEnvelopeInfo_Value
    /// Gets an envelope numerical-value attribute:
    /// I_TCPY : c_int : Y offset of envelope relative to parent track (may be separate lane or overlap with track contents)
    /// I_TCPH : c_int : visible height of envelope
    /// I_TCPY_USED : c_int : Y offset of envelope relative to parent track, exclusive of padding
    /// I_TCPH_USED : c_int : visible height of envelope, exclusive of padding
    /// P_TRACK : MediaTrack * : parent track pointer (if any)
    /// P_DESTTRACK : MediaTrack * : destination track pointer, if on a send
    /// P_ITEM : MediaItem * : parent item pointer (if any)
    /// P_TAKE : MediaItem_Take * : parent take pointer (if any)
    /// I_SEND_IDX : c_int : 1-based index of send in P_TRACK, or 0 if not a send
    /// I_HWOUT_IDX : c_int : 1-based index of hardware output in P_TRACK or 0 if not a hardware output
    /// I_RECV_IDX : c_int : 1-based index of receive in P_DESTTRACK or 0 if not a send/receive
    ///
    pub var GetEnvelopeInfo_Value: *fn (env: *TrackEnvelope, parmname: [*:0]const u8) callconv(.C) f64 = undefined;

    /// GetEnvelopeName
    pub var GetEnvelopeName: *fn (env: *TrackEnvelope, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// GetEnvelopePoint
    /// Get the attributes of an envelope point. See GetEnvelopePointEx.
    pub var GetEnvelopePoint: *fn (envelope: *TrackEnvelope, ptidx: c_int, timeOut: *f64, valueOut: *f64, shapeOut: *c_int, tensionOut: *f64, selectedOut: *bool) callconv(.C) bool = undefined;

    /// GetEnvelopePointByTime
    /// Returns the envelope point at or immediately prior to the given time position. See GetEnvelopePointByTimeEx.
    pub var GetEnvelopePointByTime: *fn (envelope: *TrackEnvelope, time: f64) callconv(.C) c_int = undefined;

    /// GetEnvelopePointByTimeEx
    /// Returns the envelope point at or immediately prior to the given time position.
    /// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
    /// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
    /// even if the automation item is trimmed so that not all points are visible.
    /// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
    /// See GetEnvelopePointEx, SetEnvelopePointEx, InsertEnvelopePointEx, DeleteEnvelopePointEx.
    pub var GetEnvelopePointByTimeEx: *fn (envelope: *TrackEnvelope, autoitem_idx: c_int, time: f64) callconv(.C) c_int = undefined;

    /// GetEnvelopePointEx
    /// Get the attributes of an envelope point.
    /// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
    /// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
    /// even if the automation item is trimmed so that not all points are visible.
    /// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
    /// See CountEnvelopePointsEx, SetEnvelopePointEx, InsertEnvelopePointEx, DeleteEnvelopePointEx.
    pub var GetEnvelopePointEx: *fn (envelope: *TrackEnvelope, autoitem_idx: c_int, ptidx: c_int, timeOut: *f64, valueOut: *f64, shapeOut: *c_int, tensionOut: *f64, selectedOut: *bool) callconv(.C) bool = undefined;

    /// GetEnvelopeScalingMode
    /// Returns the envelope scaling mode: 0=no scaling, 1=fader scaling. All API functions deal with raw envelope point values, to convert raw from/to scaled values see ScaleFromEnvelopeMode, ScaleToEnvelopeMode.
    pub var GetEnvelopeScalingMode: *fn (env: *TrackEnvelope) callconv(.C) c_int = undefined;

    /// GetEnvelopeStateChunk
    /// Gets the RPPXML state of an envelope, returns true if successful. Undo flag is a performance/caching hint.
    pub var GetEnvelopeStateChunk: *fn (env: *TrackEnvelope, strNeedBig: *c_char, strNeedBig_sz: c_int, isundoOptional: bool) callconv(.C) bool = undefined;

    /// GetEnvelopeUIState
    /// gets information on the UI state of an envelope: returns &1 if automation/modulation is playing back, &2 if automation is being actively written, &4 if the envelope recently had an effective automation mode change
    pub var GetEnvelopeUIState: *fn (env: *TrackEnvelope) callconv(.C) c_int = undefined;

    /// GetExePath
    /// returns path of REAPER.exe (not including EXE), i.e. C:\Program Files\REAPER
    pub var GetExePath: *fn () callconv(.C) [*:0]const u8 = undefined;

    /// GetExtState
    /// Get the extended state value for a specific section and key. See SetExtState, DeleteExtState, HasExtState.
    pub var GetExtState: *fn (section: [*:0]const u8, key: [*:0]const u8) callconv(.C) [*:0]const u8 = undefined;

    /// GetFocusedFX
    /// This function is deprecated (returns GetFocusedFX2()&3), see GetTouchedOrFocusedFX.
    pub var GetFocusedFX: *fn (tracknumberOut: *c_int, itemnumberOut: *c_int, fxnumberOut: *c_int) callconv(.C) c_int = undefined;

    /// GetFocusedFX2
    /// Return value has 1 set if track FX, 2 if take/item FX, 4 set if FX is no longer focused but still open. tracknumber==0 means the master track, 1 means track 1, etc. itemnumber is zero-based (or -1 if not an item). For interpretation of fxnumber, see GetLastTouchedFX. Deprecated, see GetTouchedOrFocusedFX
    pub var GetFocusedFX2: *fn (tracknumberOut: *c_int, itemnumberOut: *c_int, fxnumberOut: *c_int) callconv(.C) c_int = undefined;

    /// GetFreeDiskSpaceForRecordPath
    /// returns free disk space in megabytes, pathIdx 0 for normal, 1 for alternate.
    pub var GetFreeDiskSpaceForRecordPath: *fn (proj: *ReaProject, pathidx: c_int) callconv(.C) c_int = undefined;

    /// GetFXEnvelope
    /// Returns the FX parameter envelope. If the envelope does not exist and create=true, the envelope will be created. If the envelope already exists and is bypassed and create=true, then the envelope will be unbypassed.
    pub var GetFXEnvelope: *fn (track: *MediaTrack, fxindex: c_int, parameterindex: c_int, create: bool) callconv(.C) *TrackEnvelope = undefined;

    /// GetGlobalAutomationOverride
    /// return -1=no override, 0=trim/read, 1=read, 2=touch, 3=write, 4=latch, 5=bypass
    pub var GetGlobalAutomationOverride: *fn () callconv(.C) c_int = undefined;

    /// GetHZoomLevel
    /// returns pixels/second
    pub var GetHZoomLevel: *fn () callconv(.C) f64 = undefined;

    /// GetIconThemePointer
    /// returns a named icontheme entry
    pub var GetIconThemePointer: *fn (name: [*:0]const u8) callconv(.C) *void = undefined;

    /// GetIconThemePointerForDPI
    /// returns a named icontheme entry for a given DPI-scaling (256=1:1). Note: the return value should not be stored, it should be queried at each paint! Querying name=NULL returns the start of the structure
    pub var GetIconThemePointerForDPI: *fn (name: [*:0]const u8, dpisc: c_int) callconv(.C) *void = undefined;

    /// GetIconThemeStruct
    /// returns a pointer to the icon theme (icontheme.h) and the size of that struct
    pub var GetIconThemeStruct: *fn (szOut: *c_int) callconv(.C) *void = undefined;

    /// GetInputActivityLevel
    /// returns approximate input level if available, 0-511 mono inputs, |1024 for stereo pairs, 4096+*devidx32 for MIDI devices
    pub var GetInputActivityLevel: *fn (input_id: c_int) callconv(.C) f64 = undefined;

    /// GetInputChannelName
    pub var GetInputChannelName: *fn (channelIndex: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// GetInputOutputLatency
    /// Gets the audio device input/output latency in samples
    pub var GetInputOutputLatency: *fn (inputlatencyOut: *c_int, outputLatencyOut: *c_int) callconv(.C) void = undefined;

    /// GetItemEditingTime2
    /// returns time of relevant edit, set which_item to the pcm_source (if applicable), flags (if specified) will be set to 1 for edge resizing, 2 for fade change, 4 for item move, 8 for item slip edit (edit cursor time or start of item)
    pub var GetItemEditingTime2: *fn (which_itemOut: *PCM_source, flagsOut: *c_int) callconv(.C) f64 = undefined;

    /// GetItemFromPoint
    /// Returns the first item at the screen coordinates specified. If allow_locked is false, locked items are ignored. If takeOutOptional specified, returns the take hit. See GetThingFromPoint.
    pub var GetItemFromPoint: *fn (screen_x: c_int, screen_y: c_int, allow_locked: bool, takeOutOptional: *MediaItem_Take) callconv(.C) *MediaItem = undefined;

    /// GetItemProjectContext
    pub var GetItemProjectContext: *fn (item: *MediaItem) callconv(.C) *ReaProject = undefined;

    /// GetItemStateChunk
    /// Gets the RPPXML state of an item, returns true if successful. Undo flag is a performance/caching hint.
    pub var GetItemStateChunk: *fn (item: *MediaItem, strNeedBig: *c_char, strNeedBig_sz: c_int, isundoOptional: bool) callconv(.C) bool = undefined;

    /// GetLastColorThemeFile
    pub var GetLastColorThemeFile: *fn () callconv(.C) [*:0]const u8 = undefined;

    /// GetLastMarkerAndCurRegion
    /// Get the last project marker before time, and/or the project region that includes time. markeridx and regionidx are returned not necessarily as the displayed marker/region index, but as the index that can be passed to EnumProjectMarkers. Either or both of markeridx and regionidx may be NULL. See EnumProjectMarkers.
    pub var GetLastMarkerAndCurRegion: *fn (proj: *ReaProject, time: f64, markeridxOut: *c_int, regionidxOut: *c_int) callconv(.C) void = undefined;

    /// GetLastTouchedFX
    /// Returns true if the last touched FX parameter is valid, false otherwise. The low word of tracknumber is the 1-based track index -- 0 means the master track, 1 means track 1, etc. If the high word of tracknumber is nonzero, it refers to the 1-based item index (1 is the first item on the track, etc). For track FX, the low 24 bits of fxnumber refer to the FX index in the chain, and if the next 8 bits are 01, then the FX is record FX. For item FX, the low word defines the FX index in the chain, and the high word defines the take number. Deprecated, see GetTouchedOrFocusedFX.
    pub var GetLastTouchedFX: *fn (tracknumberOut: *c_int, fxnumberOut: *c_int, paramnumberOut: *c_int) callconv(.C) bool = undefined;

    /// GetLastTouchedTrack
    pub var GetLastTouchedTrack: *fn () callconv(.C) *MediaTrack = undefined;

    /// GetMainHwnd
    pub var GetMainHwnd: *fn () callconv(.C) HWND = undefined;

    /// GetMasterMuteSoloFlags
    /// &1=master mute,&2=master solo. This is deprecated as you can just query the master track as well.
    pub var GetMasterMuteSoloFlags: *fn () callconv(.C) c_int = undefined;

    /// GetMasterTrack
    pub var GetMasterTrack: *fn (proj: *ReaProject) callconv(.C) *MediaTrack = undefined;

    /// GetMasterTrackVisibility
    /// returns &1 if the master track is visible in the TCP, &2 if NOT visible in the mixer. See SetMasterTrackVisibility.
    pub var GetMasterTrackVisibility: *fn () callconv(.C) c_int = undefined;

    /// GetMaxMidiInputs
    /// returns max dev for midi inputs/outputs
    pub var GetMaxMidiInputs: *fn () callconv(.C) c_int = undefined;

    /// GetMaxMidiOutputs
    pub var GetMaxMidiOutputs: *fn () callconv(.C) c_int = undefined;

    /// GetMediaFileMetadata
    /// Get text-based metadata from a media file for a given identifier. Call with identifier="" to list all identifiers contained in the file, separated by newlines. May return "[Binary data]" for metadata that REAPER doesn't handle.
    pub var GetMediaFileMetadata: *fn (mediaSource: *PCM_source, identifier: [*:0]const u8, bufOutNeedBig: *c_char, bufOutNeedBig_sz: c_int) callconv(.C) c_int = undefined;

    /// GetMediaItem
    /// get an item from a project by item count (zero-based) (proj=0 for active project)
    pub var GetMediaItem: *fn (proj: *ReaProject, itemidx: c_int) callconv(.C) *MediaItem = undefined;

    /// GetMediaItem_Track
    /// Get parent track of media item
    pub var GetMediaItem_Track: *fn (item: *MediaItem) callconv(.C) *MediaTrack = undefined;

    /// GetMediaItemInfo_Value
    /// Get media item numerical-value attributes.
    /// B_MUTE : bool * : muted (item solo overrides). setting this value will clear C_MUTE_SOLO.
    /// B_MUTE_ACTUAL : bool * : muted (ignores solo). setting this value will not affect C_MUTE_SOLO.
    /// C_LANEPLAYS : c_char * : in fixed lane tracks, 0=this item lane does not play, 1=this item lane plays exclusively, 2=this item lane plays and other lanes also play, -1=this item is on a non-visible, non-playing lane on a non-fixed-lane track (read-only)
    /// C_MUTE_SOLO : c_char * : solo override (-1=soloed, 0=no override, 1=unsoloed). note that this API does not automatically unsolo other items when soloing (nor clear the unsolos when clearing the last soloed item), it must be done by the caller via action or via this API.
    /// B_LOOPSRC : bool * : loop source
    /// B_ALLTAKESPLAY : bool * : all takes play
    /// B_UISEL : bool * : selected in arrange view
    /// C_BEATATTACHMODE : c_char * : item timebase, -1=track or project default, 1=beats (position, length, rate), 2=beats (position only). for auto-stretch timebase: C_BEATATTACHMODE=1, C_AUTOSTRETCH=1
    /// C_AUTOSTRETCH: : c_char * : auto-stretch at project tempo changes, 1=enabled, requires C_BEATATTACHMODE=1
    /// C_LOCK : c_char * : locked, &1=locked
    /// D_VOL : f64 * : item volume,  0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
    /// D_POSITION : f64 * : item position in seconds
    /// D_LENGTH : f64 * : item length in seconds
    /// D_SNAPOFFSET : f64 * : item snap offset in seconds
    /// D_FADEINLEN : f64 * : item manual fadein length in seconds
    /// D_FADEOUTLEN : f64 * : item manual fadeout length in seconds
    /// D_FADEINDIR : f64 * : item fadein curvature, -1..1
    /// D_FADEOUTDIR : f64 * : item fadeout curvature, -1..1
    /// D_FADEINLEN_AUTO : f64 * : item auto-fadein length in seconds, -1=no auto-fadein
    /// D_FADEOUTLEN_AUTO : f64 * : item auto-fadeout length in seconds, -1=no auto-fadeout
    /// C_FADEINSHAPE : c_int * : fadein shape, 0..6, 0=linear
    /// C_FADEOUTSHAPE : c_int * : fadeout shape, 0..6, 0=linear
    /// I_GROUPID : c_int * : group ID, 0=no group
    /// I_LASTY : c_int * : Y-position (relative to top of track) in pixels (read-only)
    /// I_LASTH : c_int * : height in pixels (read-only)
    /// I_CUSTOMCOLOR : c_int * : custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
    /// I_CURTAKE : c_int * : active take number
    /// IP_ITEMNUMBER : c_int : item number on this track (read-only, returns the item number directly)
    /// F_FREEMODE_Y : f32 * : free item positioning or fixed lane Y-position. 0=top of track, 1.0=bottom of track
    /// F_FREEMODE_H : f32 * : free item positioning or fixed lane height. 0.5=half the track height, 1.0=full track height
    /// I_FIXEDLANE : c_int * : fixed lane of item (fine to call with setNewValue, but returned value is read-only)
    /// B_FIXEDLANE_HIDDEN : bool * : true if displaying only one fixed lane and this item is in a different lane (read-only)
    /// P_TRACK : MediaTrack * : (read-only)
    ///
    pub var GetMediaItemInfo_Value: *fn (item: *MediaItem, parmname: [*:0]const u8) callconv(.C) f64 = undefined;

    /// GetMediaItemNumTakes
    pub var GetMediaItemNumTakes: *fn (item: *MediaItem) callconv(.C) c_int = undefined;

    /// GetMediaItemTake
    pub var GetMediaItemTake: *fn (item: *MediaItem, tk: c_int) callconv(.C) *MediaItem_Take = undefined;

    /// GetMediaItemTake_Item
    /// Get parent item of media item take
    pub var GetMediaItemTake_Item: *fn (take: *MediaItem_Take) callconv(.C) *MediaItem = undefined;

    /// GetMediaItemTake_Peaks
    /// Gets block of peak samples to buf. Note that the peak samples are interleaved, but in two or three blocks (maximums, then minimums, then extra). Return value has 20 bits of returned sample count, then 4 bits of output_mode (0xf00000), then a bit to signify whether extra_type was available (0x1000000). extra_type can be 115 ('s') for spectral information, which will return peak samples as integers with the low 15 bits frequency, next 14 bits tonality.
    pub var GetMediaItemTake_Peaks: *fn (take: *MediaItem_Take, peakrate: f64, starttime: f64, numchannels: c_int, numsamplesperchannel: c_int, want_extra_type: c_int, buf: *f64) callconv(.C) c_int = undefined;

    /// GetMediaItemTake_Source
    /// Get media source of media item take
    pub var GetMediaItemTake_Source: *fn (take: *MediaItem_Take) callconv(.C) *PCM_source = undefined;

    /// GetMediaItemTake_Track
    /// Get parent track of media item take
    pub var GetMediaItemTake_Track: *fn (take: *MediaItem_Take) callconv(.C) *MediaTrack = undefined;

    /// GetMediaItemTakeByGUID
    pub var GetMediaItemTakeByGUID: *fn (project: *ReaProject, guid: *const GUID) callconv(.C) *MediaItem_Take = undefined;

    /// GetMediaItemTakeInfo_Value
    /// Get media item take numerical-value attributes.
    /// D_STARTOFFS : f64 * : start offset in source media, in seconds
    /// D_VOL : f64 * : take volume, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc, negative if take polarity is flipped
    /// D_PAN : f64 * : take pan, -1..1
    /// D_PANLAW : f64 * : take pan law, -1=default, 0.5=-6dB, 1.0=+0dB, etc
    /// D_PLAYRATE : f64 * : take playback rate, 0.5=half speed, 1=normal, 2=f64 speed, etc
    /// D_PITCH : f64 * : take pitch adjustment in semitones, -12=one octave down, 0=normal, +12=one octave up, etc
    /// B_PPITCH : bool * : preserve pitch when changing playback rate
    /// I_LASTY : c_int * : Y-position (relative to top of track) in pixels (read-only)
    /// I_LASTH : c_int * : height in pixels (read-only)
    /// I_CHANMODE : c_int * : channel mode, 0=normal, 1=reverse stereo, 2=downmix, 3=left, 4=right
    /// I_PITCHMODE : c_int * : pitch shifter mode, -1=project default, otherwise high 2 bytes=shifter, low 2 bytes=parameter
    /// I_STRETCHFLAGS : c_int * : stretch marker flags (&7 mask for mode override: 0=default, 1=balanced, 2/3/6=tonal, 4=transient, 5=no pre-echo)
    /// F_STRETCHFADESIZE : f32 * : stretch marker fade size in seconds (0.0025 default)
    /// I_RECPASSID : c_int * : record pass ID
    /// I_TAKEFX_NCH : c_int * : number of internal audio channels for per-take FX to use (OK to call with setNewValue, but the returned value is read-only)
    /// I_CUSTOMCOLOR : c_int * : custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
    /// IP_TAKENUMBER : c_int : take number (read-only, returns the take number directly)
    /// P_TRACK : pointer to MediaTrack (read-only)
    /// P_ITEM : pointer to MediaItem (read-only)
    /// P_SOURCE : PCM_source *. Note that if setting this, you should first retrieve the old source, set the new, THEN delete the old.
    ///
    pub var GetMediaItemTakeInfo_Value: *fn (take: *MediaItem_Take, parmname: [*:0]const u8) callconv(.C) f64 = undefined;

    /// GetMediaItemTrack
    pub var GetMediaItemTrack: *fn (item: *MediaItem) callconv(.C) *MediaTrack = undefined;

    /// GetMediaSourceFileName
    /// Copies the media source filename to filenamebuf. Note that in-project MIDI media sources have no associated filename. See GetMediaSourceParent.
    pub var GetMediaSourceFileName: *fn (source: *PCM_source, filenamebufOut: *c_char, filenamebufOut_sz: c_int) callconv(.C) void = undefined;

    /// GetMediaSourceLength
    /// Returns the length of the source media. If the media source is beat-based, the length will be in quarter notes, otherwise it will be in seconds.
    pub var GetMediaSourceLength: *fn (source: *PCM_source, lengthIsQNOut: *bool) callconv(.C) f64 = undefined;

    /// GetMediaSourceNumChannels
    /// Returns the number of channels in the source media.
    pub var GetMediaSourceNumChannels: *fn (source: *PCM_source) callconv(.C) c_int = undefined;

    /// GetMediaSourceParent
    /// Returns the parent source, or NULL if src is the root source. This can be used to retrieve the parent properties of sections or reversed sources for example.
    pub var GetMediaSourceParent: *fn (src: *PCM_source) callconv(.C) *PCM_source = undefined;

    /// GetMediaSourceSampleRate
    /// Returns the sample rate. MIDI source media will return zero.
    pub var GetMediaSourceSampleRate: *fn (source: *PCM_source) callconv(.C) c_int = undefined;

    /// GetMediaSourceType
    /// copies the media source type ("WAV", "MIDI", etc) to typebuf
    pub var GetMediaSourceType: *fn (source: *PCM_source, typebufOut: *c_char, typebufOut_sz: c_int) callconv(.C) void = undefined;

    /// GetMediaTrackInfo_Value
    /// Get track numerical-value attributes.
    /// B_MUTE : bool * : muted
    /// B_PHASE : bool * : track phase inverted
    /// B_RECMON_IN_EFFECT : bool * : record monitoring in effect (current audio-thread playback state, read-only)
    /// IP_TRACKNUMBER : c_int : track number 1-based, 0=not found, -1=master track (read-only, returns the c_int directly)
    /// I_SOLO : c_int * : soloed, 0=not soloed, 1=soloed, 2=soloed in place, 5=safe soloed, 6=safe soloed in place
    /// B_SOLO_DEFEAT : bool * : when set, if anything else is soloed and this track is not muted, this track acts soloed
    /// I_FXEN : c_int * : fx enabled, 0=bypassed, !0=fx active
    /// I_RECARM : c_int * : record armed, 0=not record armed, 1=record armed
    /// I_RECINPUT : c_int * : record input, <0=no input. if 4096 set, input is MIDI and low 5 bits represent channel (0=all, 1-16=only chan), next 6 bits represent physical input (63=all, 62=VKB). If 4096 is not set, low 10 bits (0..1023) are input start channel (ReaRoute/Loopback start at 512). If 2048 is set, input is multichannel input (using track channel count), or if 1024 is set, input is stereo input, otherwise input is mono.
    /// I_RECMODE : c_int * : record mode, 0=input, 1=stereo out, 2=none, 3=stereo out w/latency compensation, 4=midi output, 5=mono out, 6=mono out w/ latency compensation, 7=midi overdub, 8=midi replace
    /// I_RECMODE_FLAGS : c_int * : record mode flags, &3=output recording mode (0=post fader, 1=pre-fx, 2=post-fx/pre-fader)
    /// I_RECMON : c_int * : record monitoring, 0=off, 1=normal, 2=not when playing (tape style)
    /// I_RECMONITEMS : c_int * : monitor items while recording, 0=off, 1=on
    /// B_AUTO_RECARM : bool * : automatically set record arm when selected (does not immediately affect recarm state, script should set directly if desired)
    /// I_VUMODE : c_int * : track vu mode, &1:disabled, &30==0:stereo peaks, &30==2:multichannel peaks, &30==4:stereo RMS, &30==8:combined RMS, &30==12:LUFS-M, &30==16:LUFS-S (readout=max), &30==20:LUFS-S (readout=current), &32:LUFS calculation on channels 1+2 only
    /// I_AUTOMODE : c_int * : track automation mode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
    /// I_NCHAN : c_int * : number of track channels, 2-128, even numbers only
    /// I_SELECTED : c_int * : track selected, 0=unselected, 1=selected
    /// I_WNDH : c_int * : current TCP window height in pixels including envelopes (read-only)
    /// I_TCPH : c_int * : current TCP window height in pixels not including envelopes (read-only)
    /// I_TCPY : c_int * : current TCP window Y-position in pixels relative to top of arrange view (read-only)
    /// I_MCPX : c_int * : current MCP X-position in pixels relative to mixer container (read-only)
    /// I_MCPY : c_int * : current MCP Y-position in pixels relative to mixer container (read-only)
    /// I_MCPW : c_int * : current MCP width in pixels (read-only)
    /// I_MCPH : c_int * : current MCP height in pixels (read-only)
    /// I_FOLDERDEPTH : c_int * : folder depth change, 0=normal, 1=track is a folder parent, -1=track is the last in the innermost folder, -2=track is the last in the innermost and next-innermost folders, etc
    /// I_FOLDERCOMPACT : c_int * : folder collapsed state (only valid on folders), 0=normal, 1=collapsed, 2=fully collapsed
    /// I_MIDIHWOUT : c_int * : track midi hardware output index, <0=disabled, low 5 bits are which channels (0=all, 1-16), next 5 bits are output device index (0-31)
    /// I_MIDI_INPUT_CHANMAP : c_int * : -1 maps to source channel, otherwise 1-16 to map to MIDI channel
    /// I_MIDI_CTL_CHAN : c_int * : -1 no link, 0-15 link to MIDI volume/pan on channel, 16 link to MIDI volume/pan on all channels
    /// I_MIDI_TRACKSEL_FLAG : c_int * : MIDI editor track list options: &1=expand media items, &2=exclude from list, &4=auto-pruned
    /// I_PERFFLAGS : c_int * : track performance flags, &1=no media buffering, &2=no anticipative FX
    /// I_CUSTOMCOLOR : c_int * : custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
    /// I_HEIGHTOVERRIDE : c_int * : custom height override for TCP window, 0 for none, otherwise size in pixels
    /// I_SPACER : c_int * : 1=TCP track spacer above this trackB_HEIGHTLOCK : bool * : track height lock (must set I_HEIGHTOVERRIDE before locking)
    /// D_VOL : f64 * : trim volume of track, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
    /// D_PAN : f64 * : trim pan of track, -1..1
    /// D_WIDTH : f64 * : width of track, -1..1
    /// D_DUALPANL : f64 * : dualpan position 1, -1..1, only if I_PANMODE==6
    /// D_DUALPANR : f64 * : dualpan position 2, -1..1, only if I_PANMODE==6
    /// I_PANMODE : c_int * : pan mode, 0=classic 3.x, 3=new balance, 5=stereo pan, 6=dual pan
    /// D_PANLAW : f64 * : pan law of track, <0=project default, 0.5=-6dB, 0.707..=-3dB, 1=+0dB, 1.414..=-3dB with gain compensation, 2=-6dB with gain compensation, etc
    /// I_PANLAW_FLAGS : c_int * : pan law flags, 0=sine taper, 1=hybrid taper with deprecated behavior when gain compensation enabled, 2=linear taper, 3=hybrid taper
    /// P_ENV:<envchunkname or P_ENV:GUID... : TrackEnvelope * : (read-only) chunkname can be <VOLENV, <PANENV, etc; GUID is the stringified envelope GUID.
    /// B_SHOWINMIXER : bool * : track control panel visible in mixer (do not use on master track)
    /// B_SHOWINTCP : bool * : track control panel visible in arrange view (do not use on master track)
    /// B_MAINSEND : bool * : track sends audio to parent
    /// C_MAINSEND_OFFS : c_char * : channel offset of track send to parent
    /// C_MAINSEND_NCH : c_char * : channel count of track send to parent (0=use all child track channels, 1=use one channel only)
    /// I_FREEMODE : c_int * : 1=track free item positioning enabled, 2=track fixed lanes enabled (call UpdateTimeline() after changing)
    /// I_NUMFIXEDLANES : c_int * : number of track fixed lanes (fine to call with setNewValue, but returned value is read-only)
    /// C_LANESCOLLAPSED : c_char * : fixed lane collapse state (1=lanes collapsed, 2=track displays as non-fixed-lanes but hidden lanes exist)
    /// C_LANESETTINGS : c_char * : fixed lane settings (&1=auto-remove empty lanes at bottom, &2=do not auto-comp new recording, &4=newly recorded lanes play exclusively (else add lanes in layers), &8=big lanes (else small lanes), &16=add new recording at bottom (else record into first available lane), &32=hide lane buttons
    /// C_LANEPLAYS:N : c_char * :  on fixed lane tracks, 0=lane N does not play, 1=lane N plays exclusively, 2=lane N plays and other lanes also play (fine to call with setNewValue, but returned value is read-only)
    /// C_ALLLANESPLAY : c_char * : on fixed lane tracks, 0=no lanes play, 1=all lanes play, 2=some lanes play (fine to call with setNewValue 0 or 1, but returned value is read-only)
    /// C_BEATATTACHMODE : c_char * : track timebase, -1=project default, 0=time, 1=beats (position, length, rate), 2=beats (position only)
    /// F_MCP_FXSEND_SCALE : f32 * : scale of fx+send area in MCP (0=minimum allowed, 1=maximum allowed)
    /// F_MCP_FXPARM_SCALE : f32 * : scale of fx parameter area in MCP (0=minimum allowed, 1=maximum allowed)
    /// F_MCP_SENDRGN_SCALE : f32 * : scale of send area as proportion of the fx+send total area (0=minimum allowed, 1=maximum allowed)
    /// F_TCP_FXPARM_SCALE : f32 * : scale of TCP parameter area when TCP FX are embedded (0=min allowed, default, 1=max allowed)
    /// I_PLAY_OFFSET_FLAG : c_int * : track media playback offset state, &1=bypassed, &2=offset value is measured in samples (otherwise measured in seconds)
    /// D_PLAY_OFFSET : f64 * : track media playback offset, units depend on I_PLAY_OFFSET_FLAG
    /// P_PARTRACK : MediaTrack * : parent track (read-only)
    /// P_PROJECT : ReaProject * : parent project (read-only)
    ///
    pub var GetMediaTrackInfo_Value: *fn (tr: MediaTrack, parmname: [*:0]const u8) callconv(.C) f64 = undefined;

    /// GetMIDIInputName
    /// returns true if device present
    pub var GetMIDIInputName: *fn (dev: c_int, nameout: [*]c_char, nameout_sz: c_int) callconv(.C) bool = undefined;

    /// GetMIDIOutputName
    /// returns true if device present
    pub var GetMIDIOutputName: *fn (dev: c_int, nameout: [*]c_char, nameout_sz: c_int) callconv(.C) bool = undefined;

    /// GetMixerScroll
    /// Get the leftmost track visible in the mixer
    pub var GetMixerScroll: *fn () callconv(.C) *MediaTrack = undefined;

    /// GetMouseModifier
    /// Get the current mouse modifier assignment for a specific modifier key assignment, in a specific context.
    /// action will be filled in with the command ID number for a built-in mouse modifier
    /// or built-in REAPER command ID, or the custom action ID string.
    /// Note: the action string may have a space and 'c' or 'm' appended to it to specify command ID vs mouse modifier ID.
    /// See SetMouseModifier for more information.
    ///
    pub var GetMouseModifier: *fn (context: [*:0]const u8, modifier_flag: c_int, actionOut: *c_char, actionOut_sz: c_int) callconv(.C) void = undefined;

    /// GetMousePosition
    /// get mouse position in screen coordinates
    pub var GetMousePosition: *fn (xOut: *c_int, yOut: *c_int) callconv(.C) void = undefined;

    /// GetNumAudioInputs
    /// Return number of normal audio hardware inputs available
    pub var GetNumAudioInputs: *fn () callconv(.C) c_int = undefined;

    /// GetNumAudioOutputs
    /// Return number of normal audio hardware outputs available
    pub var GetNumAudioOutputs: *fn () callconv(.C) c_int = undefined;

    /// GetNumMIDIInputs
    /// returns max number of real midi hardware inputs
    pub var GetNumMIDIInputs: *fn () callconv(.C) c_int = undefined;

    /// GetNumMIDIOutputs
    /// returns max number of real midi hardware outputs
    pub var GetNumMIDIOutputs: *fn () callconv(.C) c_int = undefined;

    /// GetNumTakeMarkers
    /// Returns number of take markers. See GetTakeMarker, SetTakeMarker, DeleteTakeMarker
    pub var GetNumTakeMarkers: *fn (take: *MediaItem_Take) callconv(.C) c_int = undefined;

    /// GetNumTracks
    pub var GetNumTracks: *fn () callconv(.C) c_int = undefined;

    /// GetOS
    /// Returns "Win32", "Win64", "OSX32", "OSX64", "macOS-arm64", or "Other".
    pub var GetOS: *fn () callconv(.C) [*:0]const u8 = undefined;

    /// GetOutputChannelName
    pub var GetOutputChannelName: *fn (channelIndex: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// GetOutputLatency
    /// returns output latency in seconds
    pub var GetOutputLatency: *fn () callconv(.C) f64 = undefined;

    /// GetParentTrack
    pub var GetParentTrack: *fn (track: *MediaTrack) callconv(.C) *MediaTrack = undefined;

    /// GetPeakFileName
    /// get the peak file name for a given file (can be either filename.reapeaks,or a hashed filename in another path)
    pub var GetPeakFileName: *fn (fn_: [*:0]const u8, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) void = undefined;

    /// GetPeakFileNameEx
    /// get the peak file name for a given file (can be either filename.reapeaks,or a hashed filename in another path)
    pub var GetPeakFileNameEx: *fn (fn_: [*:0]const u8, buf: *c_char, buf_sz: c_int, forWrite: bool) callconv(.C) void = undefined;

    /// GetPeakFileNameEx2
    /// Like GetPeakFileNameEx, but you can specify peaksfileextension such as ".reapeaks"
    pub var GetPeakFileNameEx2: *fn (fn_: [*:0]const u8, buf: *c_char, buf_sz: c_int, forWrite: bool, peaksfileextension: [*:0]const u8) callconv(.C) void = undefined;

    /// GetPeaksBitmap
    /// see note in reaper_plugin.h about PCM_source_peaktransfer_t::samplerate
    pub var GetPeaksBitmap: *fn (pks: *PCM_source_peaktransfer_t, maxamp: f64, w: c_int, h: c_int, bmp: *LICE_IBitmap) callconv(.C) *void = undefined;

    /// GetPlayPosition
    /// returns latency-compensated actual-what-you-hear position
    pub var GetPlayPosition: *fn () callconv(.C) f64 = undefined;

    /// GetPlayPosition2
    /// returns position of next audio block being processed
    pub var GetPlayPosition2: *fn () callconv(.C) f64 = undefined;

    /// GetPlayPosition2Ex
    /// returns position of next audio block being processed
    pub var GetPlayPosition2Ex: *fn (proj: *ReaProject) callconv(.C) f64 = undefined;

    /// GetPlayPositionEx
    /// returns latency-compensated actual-what-you-hear position
    pub var GetPlayPositionEx: *fn (proj: *ReaProject) callconv(.C) f64 = undefined;

    /// GetPlayState
    /// &1=playing, &2=paused, &4=is recording
    pub var GetPlayState: *fn () callconv(.C) c_int = undefined;

    /// GetPlayStateEx
    /// &1=playing, &2=paused, &4=is recording
    pub var GetPlayStateEx: *fn (proj: *ReaProject) callconv(.C) c_int = undefined;

    /// GetPreferredDiskReadMode
    /// Gets user configured preferred disk read mode. mode/nb/bs are all parameters that should be passed to WDL_FileRead, see for more information.
    pub var GetPreferredDiskReadMode: *fn (mode: *c_int, nb: *c_int, bs: *c_int) callconv(.C) void = undefined;

    /// GetPreferredDiskReadModePeak
    /// Gets user configured preferred disk read mode for use when building peaks. mode/nb/bs are all parameters that should be passed to WDL_FileRead, see for more information.
    pub var GetPreferredDiskReadModePeak: *fn (mode: *c_int, nb: *c_int, bs: *c_int) callconv(.C) void = undefined;

    /// GetPreferredDiskWriteMode
    /// Gets user configured preferred disk write mode. nb will receive two values, the initial and maximum write buffer counts. mode/nb/bs are all parameters that should be passed to WDL_FileWrite, see for more information.
    pub var GetPreferredDiskWriteMode: *fn (mode: *c_int, nb: *c_int, bs: *c_int) callconv(.C) void = undefined;

    /// GetProjectLength
    /// returns length of project (maximum of end of media item, markers, end of regions, tempo map
    pub var GetProjectLength: *fn (proj: *ReaProject) callconv(.C) f64 = undefined;

    /// GetProjectName
    pub var GetProjectName: *fn (proj: *ReaProject, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) void = undefined;

    /// GetProjectPath
    /// Get the project recording path.
    pub var GetProjectPath: *fn (bufOut: *c_char, bufOut_sz: c_int) callconv(.C) void = undefined;

    /// GetProjectPathEx
    /// Get the project recording path.
    pub var GetProjectPathEx: *fn (proj: *ReaProject, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) void = undefined;

    /// GetProjectStateChangeCount
    /// returns an integer that changes when the project state changes
    pub var GetProjectStateChangeCount: *fn (proj: *ReaProject) callconv(.C) c_int = undefined;

    /// GetProjectTimeOffset
    /// Gets project time offset in seconds (project settings - project start time). If rndframe is true, the offset is rounded to a multiple of the project frame size.
    pub var GetProjectTimeOffset: *fn (proj: *ReaProject, rndframe: bool) callconv(.C) f64 = undefined;

    /// GetProjectTimeSignature
    /// deprecated
    pub var GetProjectTimeSignature: *fn (bpmOut: *f64, bpiOut: *f64) callconv(.C) void = undefined;

    /// GetProjectTimeSignature2
    /// Gets basic time signature (beats per minute, numerator of time signature in bpi)
    /// this does not reflect tempo envelopes but is purely what is set in the project settings.
    pub var GetProjectTimeSignature2: *fn (proj: *ReaProject, bpmOut: *f64, bpiOut: *f64) callconv(.C) void = undefined;

    /// GetProjExtState
    /// Get the value previously associated with this extname and key, the last time the project was saved. See SetProjExtState, EnumProjExtState.
    pub var GetProjExtState: *fn (proj: *ReaProject, extname: [*:0]const u8, key: [*:0]const u8, valOutNeedBig: *c_char, valOutNeedBig_sz: c_int) callconv(.C) c_int = undefined;

    /// GetResourcePath
    /// returns path where ini files are stored, other things are in subdirectories.
    pub var GetResourcePath: *const fn () callconv(.C) [*:0]const u8 = undefined;

    /// GetSelectedEnvelope
    /// get the currently selected envelope, returns NULL/nil if no envelope is selected
    pub var GetSelectedEnvelope: *fn (proj: *ReaProject) callconv(.C) *TrackEnvelope = undefined;

    /// GetSelectedMediaItem
    /// get a selected item by selected item count (zero-based) (proj=0 for active project)
    pub var GetSelectedMediaItem: *fn (proj: *ReaProject, selitem: c_int) callconv(.C) *MediaItem = undefined;

    /// GetSelectedTrack
    /// Get a selected track from a project (proj=0 for active project) by selected track count (zero-based). This function ignores the master track, see GetSelectedTrack2.
    pub var GetSelectedTrack: *fn (proj: *ReaProject, seltrackidx: c_int) callconv(.C) *MediaTrack = undefined;

    /// GetSelectedTrack2
    /// Get a selected track from a project (proj=0 for active project) by selected track count (zero-based).
    pub var GetSelectedTrack2: *fn (proj: *ReaProject, seltrackidx: c_int, wantmaster: bool) callconv(.C) *MediaTrack = undefined;

    /// GetSelectedTrackEnvelope
    /// get the currently selected track envelope, returns NULL/nil if no envelope is selected
    pub var GetSelectedTrackEnvelope: *fn (proj: *ReaProject) callconv(.C) *TrackEnvelope = undefined;

    /// GetSet_ArrangeView2
    /// Gets or sets the arrange view start/end time for screen coordinates. use screen_x_start=screen_x_end=0 to use the full arrange view's start/end time
    pub var GetSet_ArrangeView2: *fn (proj: *ReaProject, isSet: bool, screen_x_start: c_int, screen_x_end: c_int, start_timeInOut: *f64, end_timeInOut: *f64) callconv(.C) void = undefined;

    /// GetSet_LoopTimeRange
    pub var GetSet_LoopTimeRange: *fn (isSet: bool, isLoop: bool, startOut: *f64, endOut: *f64, allowautoseek: bool) callconv(.C) void = undefined;

    /// GetSet_LoopTimeRange2
    pub var GetSet_LoopTimeRange2: *fn (proj: *ReaProject, isSet: bool, isLoop: bool, startOut: *f64, endOut: *f64, allowautoseek: bool) callconv(.C) void = undefined;

    /// GetSetAutomationItemInfo
    /// Get or set automation item information. autoitem_idx=0 for the first automation item on an envelope, 1 for the second item, etc. desc can be any of the following:
    /// D_POOL_ID : f64 * : automation item pool ID (as an integer); edits are propagated to all other automation items that share a pool ID
    /// D_POSITION : f64 * : automation item timeline position in seconds
    /// D_LENGTH : f64 * : automation item length in seconds
    /// D_STARTOFFS : f64 * : automation item start offset in seconds
    /// D_PLAYRATE : f64 * : automation item playback rate
    /// D_BASELINE : f64 * : automation item baseline value in the range [0,1]
    /// D_AMPLITUDE : f64 * : automation item amplitude in the range [-1,1]
    /// D_LOOPSRC : f64 * : nonzero if the automation item contents are looped
    /// D_UISEL : f64 * : nonzero if the automation item is selected in the arrange view
    /// D_POOL_QNLEN : f64 * : automation item pooled source length in quarter notes (setting will affect all pooled instances)
    ///
    pub var GetSetAutomationItemInfo: *fn (env: *TrackEnvelope, autoitem_idx: c_int, desc: [*:0]const u8, value: f64, is_set: bool) callconv(.C) f64 = undefined;

    /// GetSetAutomationItemInfo_String
    /// Get or set automation item information. autoitem_idx=0 for the first automation item on an envelope, 1 for the second item, etc. returns true on success. desc can be any of the following:
    /// P_POOL_NAME : c_char * : name of the underlying automation item pool
    /// P_POOL_EXT:xyz : c_char * : extension-specific persistent data
    ///
    pub var GetSetAutomationItemInfo_String: *fn (env: *TrackEnvelope, autoitem_idx: c_int, desc: [*:0]const u8, valuestrNeedBig: *c_char, is_set: bool) callconv(.C) bool = undefined;

    /// GetSetEnvelopeInfo_String
    /// Gets/sets an attribute string:
    /// P_EXT:xyz : c_char * : extension-specific persistent data
    /// GUID : GUID * : 16-byte GUID, can query only, not set. If using a _String() function, GUID is a string {xyz-...}.
    ///
    pub var GetSetEnvelopeInfo_String: *fn (env: *TrackEnvelope, parmname: [*:0]const u8, stringNeedBig: *c_char, setNewValue: bool) callconv(.C) bool = undefined;

    /// GetSetEnvelopeState
    /// deprecated -- see SetEnvelopeStateChunk, GetEnvelopeStateChunk
    pub var GetSetEnvelopeState: *fn (env: *TrackEnvelope, str: *c_char, str_sz: c_int) callconv(.C) bool = undefined;

    /// GetSetEnvelopeState2
    /// deprecated -- see SetEnvelopeStateChunk, GetEnvelopeStateChunk
    pub var GetSetEnvelopeState2: *fn (env: *TrackEnvelope, str: *c_char, str_sz: c_int, isundo: bool) callconv(.C) bool = undefined;

    /// GetSetItemState
    /// deprecated -- see SetItemStateChunk, GetItemStateChunk
    pub var GetSetItemState: *fn (item: *MediaItem, str: *c_char, str_sz: c_int) callconv(.C) bool = undefined;

    /// GetSetItemState2
    /// deprecated -- see SetItemStateChunk, GetItemStateChunk
    pub var GetSetItemState2: *fn (item: *MediaItem, str: *c_char, str_sz: c_int, isundo: bool) callconv(.C) bool = undefined;

    /// GetSetMediaItemInfo
    /// P_TRACK : MediaTrack * : (read-only)
    /// B_MUTE : bool * : muted (item solo overrides). setting this value will clear C_MUTE_SOLO.
    /// B_MUTE_ACTUAL : bool * : muted (ignores solo). setting this value will not affect C_MUTE_SOLO.
    /// C_LANEPLAYS : c_char * : in fixed lane tracks, 0=this item lane does not play, 1=this item lane plays exclusively, 2=this item lane plays and other lanes also play, -1=this item is on a non-visible, non-playing lane on a non-fixed-lane track (read-only)
    /// C_MUTE_SOLO : c_char * : solo override (-1=soloed, 0=no override, 1=unsoloed). note that this API does not automatically unsolo other items when soloing (nor clear the unsolos when clearing the last soloed item), it must be done by the caller via action or via this API.
    /// B_LOOPSRC : bool * : loop source
    /// B_ALLTAKESPLAY : bool * : all takes play
    /// B_UISEL : bool * : selected in arrange view
    /// C_BEATATTACHMODE : c_char * : item timebase, -1=track or project default, 1=beats (position, length, rate), 2=beats (position only). for auto-stretch timebase: C_BEATATTACHMODE=1, C_AUTOSTRETCH=1
    /// C_AUTOSTRETCH: : c_char * : auto-stretch at project tempo changes, 1=enabled, requires C_BEATATTACHMODE=1
    /// C_LOCK : c_char * : locked, &1=locked
    /// D_VOL : f64 * : item volume,  0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
    /// D_POSITION : f64 * : item position in seconds
    /// D_LENGTH : f64 * : item length in seconds
    /// D_SNAPOFFSET : f64 * : item snap offset in seconds
    /// D_FADEINLEN : f64 * : item manual fadein length in seconds
    /// D_FADEOUTLEN : f64 * : item manual fadeout length in seconds
    /// D_FADEINDIR : f64 * : item fadein curvature, -1..1
    /// D_FADEOUTDIR : f64 * : item fadeout curvature, -1..1
    /// D_FADEINLEN_AUTO : f64 * : item auto-fadein length in seconds, -1=no auto-fadein
    /// D_FADEOUTLEN_AUTO : f64 * : item auto-fadeout length in seconds, -1=no auto-fadeout
    /// C_FADEINSHAPE : c_int * : fadein shape, 0..6, 0=linear
    /// C_FADEOUTSHAPE : c_int * : fadeout shape, 0..6, 0=linear
    /// I_GROUPID : c_int * : group ID, 0=no group
    /// I_LASTY : c_int * : Y-position (relative to top of track) in pixels (read-only)
    /// I_LASTH : c_int * : height in pixels (read-only)
    /// I_CUSTOMCOLOR : c_int * : custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
    /// I_CURTAKE : c_int * : active take number
    /// IP_ITEMNUMBER : c_int : item number on this track (read-only, returns the item number directly)
    /// F_FREEMODE_Y : f32 * : free item positioning or fixed lane Y-position. 0=top of track, 1.0=bottom of track
    /// F_FREEMODE_H : f32 * : free item positioning or fixed lane height. 0.5=half the track height, 1.0=full track height
    /// I_FIXEDLANE : c_int * : fixed lane of item (fine to call with setNewValue, but returned value is read-only)
    /// B_FIXEDLANE_HIDDEN : bool * : true if displaying only one fixed lane and this item is in a different lane (read-only)
    /// P_NOTES : c_char * : item note text (do not write to returned pointer, use setNewValue to update)
    /// P_EXT:xyz : c_char * : extension-specific persistent data
    /// GUID : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
    ///
    pub var GetSetMediaItemInfo: *fn (item: *MediaItem, parmname: [*:0]const u8, setNewValue: *void) callconv(.C) *void = undefined;

    /// GetSetMediaItemInfo_String
    /// Gets/sets an item attribute string:
    /// P_NOTES : c_char * : item note text (do not write to returned pointer, use setNewValue to update)
    /// P_EXT:xyz : c_char * : extension-specific persistent data
    /// GUID : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
    ///
    pub var GetSetMediaItemInfo_String: *fn (item: *MediaItem, parmname: [*:0]const u8, stringNeedBig: *c_char, setNewValue: bool) callconv(.C) bool = undefined;

    /// GetSetMediaItemTakeInfo
    /// P_TRACK : pointer to MediaTrack (read-only)
    /// P_ITEM : pointer to MediaItem (read-only)
    /// P_SOURCE : PCM_source *. Note that if setting this, you should first retrieve the old source, set the new, THEN delete the old.
    /// P_NAME : c_char * : take name
    /// P_EXT:xyz : c_char * : extension-specific persistent data
    /// GUID : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
    /// D_STARTOFFS : f64 * : start offset in source media, in seconds
    /// D_VOL : f64 * : take volume, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc, negative if take polarity is flipped
    /// D_PAN : f64 * : take pan, -1..1
    /// D_PANLAW : f64 * : take pan law, -1=default, 0.5=-6dB, 1.0=+0dB, etc
    /// D_PLAYRATE : f64 * : take playback rate, 0.5=half speed, 1=normal, 2=f64 speed, etc
    /// D_PITCH : f64 * : take pitch adjustment in semitones, -12=one octave down, 0=normal, +12=one octave up, etc
    /// B_PPITCH : bool * : preserve pitch when changing playback rate
    /// I_LASTY : c_int * : Y-position (relative to top of track) in pixels (read-only)
    /// I_LASTH : c_int * : height in pixels (read-only)
    /// I_CHANMODE : c_int * : channel mode, 0=normal, 1=reverse stereo, 2=downmix, 3=left, 4=right
    /// I_PITCHMODE : c_int * : pitch shifter mode, -1=project default, otherwise high 2 bytes=shifter, low 2 bytes=parameter
    /// I_STRETCHFLAGS : c_int * : stretch marker flags (&7 mask for mode override: 0=default, 1=balanced, 2/3/6=tonal, 4=transient, 5=no pre-echo)
    /// F_STRETCHFADESIZE : f32 * : stretch marker fade size in seconds (0.0025 default)
    /// I_RECPASSID : c_int * : record pass ID
    /// I_TAKEFX_NCH : c_int * : number of internal audio channels for per-take FX to use (OK to call with setNewValue, but the returned value is read-only)
    /// I_CUSTOMCOLOR : c_int * : custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
    /// IP_TAKENUMBER : c_int : take number (read-only, returns the take number directly)
    ///
    pub var GetSetMediaItemTakeInfo: *fn (tk: *MediaItem_Take, parmname: [*:0]const u8, setNewValue: *void) callconv(.C) *void = undefined;

    /// GetSetMediaItemTakeInfo_String
    /// Gets/sets a take attribute string:
    /// P_NAME : c_char * : take name
    /// P_EXT:xyz : c_char * : extension-specific persistent data
    /// GUID : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
    ///
    pub var GetSetMediaItemTakeInfo_String: *fn (tk: *MediaItem_Take, parmname: [*:0]const u8, stringNeedBig: *c_char, setNewValue: bool) callconv(.C) bool = undefined;

    /// GetSetMediaTrackInfo
    /// Get or set track attributes.
    /// P_PARTRACK : MediaTrack * : parent track (read-only)
    /// P_PROJECT : ReaProject * : parent project (read-only)
    /// P_NAME : c_char * : track name (on master returns NULL)
    /// P_ICON : const c_char * : track icon (full filename, or relative to resource_path/data/track_icons)
    /// P_LANENAME:n : c_char * : lane name (returns NULL for non-fixed-lane-tracks)
    /// P_MCP_LAYOUT : const c_char * : layout name
    /// P_RAZOREDITS : const c_char * : list of razor edit areas, as space-separated triples of start time, end time, and envelope GUID string.
    ///   Example: "0.0 1.0 \"\" 0.0 1.0 "{xyz-...}"
    /// P_RAZOREDITS_EXT : const c_char * : list of razor edit areas, as comma-separated sets of space-separated tuples of start time, end time, optional: envelope GUID string, fixed/fipm top y-position, fixed/fipm bottom y-position.
    ///   Example: "0.0 1.0,0.0 1.0 "{xyz-...}",1.0 2.0 "" 0.25 0.75"
    /// P_TCP_LAYOUT : const c_char * : layout name
    /// P_EXT:xyz : c_char * : extension-specific persistent data
    /// P_UI_RECT:tcp.mute : c_char * : read-only, allows querying screen position + size of track WALTER elements (tcp.size queries screen position and size of entire TCP, etc).
    /// GUID : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
    /// B_MUTE : bool * : muted
    /// B_PHASE : bool * : track phase inverted
    /// B_RECMON_IN_EFFECT : bool * : record monitoring in effect (current audio-thread playback state, read-only)
    /// IP_TRACKNUMBER : c_int : track number 1-based, 0=not found, -1=master track (read-only, returns the c_int directly)
    /// I_SOLO : c_int * : soloed, 0=not soloed, 1=soloed, 2=soloed in place, 5=safe soloed, 6=safe soloed in place
    /// B_SOLO_DEFEAT : bool * : when set, if anything else is soloed and this track is not muted, this track acts soloed
    /// I_FXEN : c_int * : fx enabled, 0=bypassed, !0=fx active
    /// I_RECARM : c_int * : record armed, 0=not record armed, 1=record armed
    /// I_RECINPUT : c_int * : record input, <0=no input. if 4096 set, input is MIDI and low 5 bits represent channel (0=all, 1-16=only chan), next 6 bits represent physical input (63=all, 62=VKB). If 4096 is not set, low 10 bits (0..1023) are input start channel (ReaRoute/Loopback start at 512). If 2048 is set, input is multichannel input (using track channel count), or if 1024 is set, input is stereo input, otherwise input is mono.
    /// I_RECMODE : c_int * : record mode, 0=input, 1=stereo out, 2=none, 3=stereo out w/latency compensation, 4=midi output, 5=mono out, 6=mono out w/ latency compensation, 7=midi overdub, 8=midi replace
    /// I_RECMODE_FLAGS : c_int * : record mode flags, &3=output recording mode (0=post fader, 1=pre-fx, 2=post-fx/pre-fader)
    /// I_RECMON : c_int * : record monitoring, 0=off, 1=normal, 2=not when playing (tape style)
    /// I_RECMONITEMS : c_int * : monitor items while recording, 0=off, 1=on
    /// B_AUTO_RECARM : bool * : automatically set record arm when selected (does not immediately affect recarm state, script should set directly if desired)
    /// I_VUMODE : c_int * : track vu mode, &1:disabled, &30==0:stereo peaks, &30==2:multichannel peaks, &30==4:stereo RMS, &30==8:combined RMS, &30==12:LUFS-M, &30==16:LUFS-S (readout=max), &30==20:LUFS-S (readout=current), &32:LUFS calculation on channels 1+2 only
    /// I_AUTOMODE : c_int * : track automation mode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
    /// I_NCHAN : c_int * : number of track channels, 2-128, even numbers only
    /// I_SELECTED : c_int * : track selected, 0=unselected, 1=selected
    /// I_WNDH : c_int * : current TCP window height in pixels including envelopes (read-only)
    /// I_TCPH : c_int * : current TCP window height in pixels not including envelopes (read-only)
    /// I_TCPY : c_int * : current TCP window Y-position in pixels relative to top of arrange view (read-only)
    /// I_MCPX : c_int * : current MCP X-position in pixels relative to mixer container (read-only)
    /// I_MCPY : c_int * : current MCP Y-position in pixels relative to mixer container (read-only)
    /// I_MCPW : c_int * : current MCP width in pixels (read-only)
    /// I_MCPH : c_int * : current MCP height in pixels (read-only)
    /// I_FOLDERDEPTH : c_int * : folder depth change, 0=normal, 1=track is a folder parent, -1=track is the last in the innermost folder, -2=track is the last in the innermost and next-innermost folders, etc
    /// I_FOLDERCOMPACT : c_int * : folder collapsed state (only valid on folders), 0=normal, 1=collapsed, 2=fully collapsed
    /// I_MIDIHWOUT : c_int * : track midi hardware output index, <0=disabled, low 5 bits are which channels (0=all, 1-16), next 5 bits are output device index (0-31)
    /// I_MIDI_INPUT_CHANMAP : c_int * : -1 maps to source channel, otherwise 1-16 to map to MIDI channel
    /// I_MIDI_CTL_CHAN : c_int * : -1 no link, 0-15 link to MIDI volume/pan on channel, 16 link to MIDI volume/pan on all channels
    /// I_MIDI_TRACKSEL_FLAG : c_int * : MIDI editor track list options: &1=expand media items, &2=exclude from list, &4=auto-pruned
    /// I_PERFFLAGS : c_int * : track performance flags, &1=no media buffering, &2=no anticipative FX
    /// I_CUSTOMCOLOR : c_int * : custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
    /// I_HEIGHTOVERRIDE : c_int * : custom height override for TCP window, 0 for none, otherwise size in pixels
    /// I_SPACER : c_int * : 1=TCP track spacer above this trackB_HEIGHTLOCK : bool * : track height lock (must set I_HEIGHTOVERRIDE before locking)
    /// D_VOL : f64 * : trim volume of track, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
    /// D_PAN : f64 * : trim pan of track, -1..1
    /// D_WIDTH : f64 * : width of track, -1..1
    /// D_DUALPANL : f64 * : dualpan position 1, -1..1, only if I_PANMODE==6
    /// D_DUALPANR : f64 * : dualpan position 2, -1..1, only if I_PANMODE==6
    /// I_PANMODE : c_int * : pan mode, 0=classic 3.x, 3=new balance, 5=stereo pan, 6=dual pan
    /// D_PANLAW : f64 * : pan law of track, <0=project default, 0.5=-6dB, 0.707..=-3dB, 1=+0dB, 1.414..=-3dB with gain compensation, 2=-6dB with gain compensation, etc
    /// I_PANLAW_FLAGS : c_int * : pan law flags, 0=sine taper, 1=hybrid taper with deprecated behavior when gain compensation enabled, 2=linear taper, 3=hybrid taper
    /// P_ENV:<envchunkname or P_ENV:GUID... : TrackEnvelope * : (read-only) chunkname can be <VOLENV, <PANENV, etc; GUID is the stringified envelope GUID.
    /// B_SHOWINMIXER : bool * : track control panel visible in mixer (do not use on master track)
    /// B_SHOWINTCP : bool * : track control panel visible in arrange view (do not use on master track)
    /// B_MAINSEND : bool * : track sends audio to parent
    /// C_MAINSEND_OFFS : c_char * : channel offset of track send to parent
    /// C_MAINSEND_NCH : c_char * : channel count of track send to parent (0=use all child track channels, 1=use one channel only)
    /// I_FREEMODE : c_int * : 1=track free item positioning enabled, 2=track fixed lanes enabled (call UpdateTimeline() after changing)
    /// I_NUMFIXEDLANES : c_int * : number of track fixed lanes (fine to call with setNewValue, but returned value is read-only)
    /// C_LANESCOLLAPSED : c_char * : fixed lane collapse state (1=lanes collapsed, 2=track displays as non-fixed-lanes but hidden lanes exist)
    /// C_LANESETTINGS : c_char * : fixed lane settings (&1=auto-remove empty lanes at bottom, &2=do not auto-comp new recording, &4=newly recorded lanes play exclusively (else add lanes in layers), &8=big lanes (else small lanes), &16=add new recording at bottom (else record into first available lane), &32=hide lane buttons
    /// C_LANEPLAYS:N : c_char * :  on fixed lane tracks, 0=lane N does not play, 1=lane N plays exclusively, 2=lane N plays and other lanes also play (fine to call with setNewValue, but returned value is read-only)
    /// C_ALLLANESPLAY : c_char * : on fixed lane tracks, 0=no lanes play, 1=all lanes play, 2=some lanes play (fine to call with setNewValue 0 or 1, but returned value is read-only)
    /// C_BEATATTACHMODE : c_char * : track timebase, -1=project default, 0=time, 1=beats (position, length, rate), 2=beats (position only)
    /// F_MCP_FXSEND_SCALE : f32 * : scale of fx+send area in MCP (0=minimum allowed, 1=maximum allowed)
    /// F_MCP_FXPARM_SCALE : f32 * : scale of fx parameter area in MCP (0=minimum allowed, 1=maximum allowed)
    /// F_MCP_SENDRGN_SCALE : f32 * : scale of send area as proportion of the fx+send total area (0=minimum allowed, 1=maximum allowed)
    /// F_TCP_FXPARM_SCALE : f32 * : scale of TCP parameter area when TCP FX are embedded (0=min allowed, default, 1=max allowed)
    /// I_PLAY_OFFSET_FLAG : c_int * : track media playback offset state, &1=bypassed, &2=offset value is measured in samples (otherwise measured in seconds)
    /// D_PLAY_OFFSET : f64 * : track media playback offset, units depend on I_PLAY_OFFSET_FLAG
    ///
    pub var GetSetMediaTrackInfo: *fn (tr: MediaTrack, parmname: [*:0]const u8, setNewValue: *u8) callconv(.C) *void = undefined;

    /// GetSetMediaTrackInfo_String
    /// Get or set track string attributes.
    /// P_NAME : c_char * : track name (on master returns NULL)
    /// P_ICON : const c_char * : track icon (full filename, or relative to resource_path/data/track_icons)
    /// P_LANENAME:n : c_char * : lane name (returns NULL for non-fixed-lane-tracks)
    /// P_MCP_LAYOUT : const c_char * : layout name
    /// P_RAZOREDITS : const c_char * : list of razor edit areas, as space-separated triples of start time, end time, and envelope GUID string.
    ///   Example: "0.0 1.0 \"\" 0.0 1.0 "{xyz-...}"
    /// P_RAZOREDITS_EXT : const c_char * : list of razor edit areas, as comma-separated sets of space-separated tuples of start time, end time, optional: envelope GUID string, fixed/fipm top y-position, fixed/fipm bottom y-position.
    ///   Example: "0.0 1.0,0.0 1.0 "{xyz-...}",1.0 2.0 "" 0.25 0.75"
    /// P_TCP_LAYOUT : const c_char * : layout name
    /// P_EXT:xyz : c_char * : extension-specific persistent data
    /// P_UI_RECT:tcp.mute : c_char * : read-only, allows querying screen position + size of track WALTER elements (tcp.size queries screen position and size of entire TCP, etc).
    /// GUID : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
    ///
    pub var GetSetMediaTrackInfo_String: *fn (tr: *MediaTrack, parmname: [*:0]const u8, stringNeedBig: *c_char, setNewValue: bool) callconv(.C) bool = undefined;

    /// GetSetObjectState
    /// get or set the state of a {track,item,envelope} as an RPPXML chunk
    /// str="" to get the chunk string returned (must call FreeHeapPtr when done)
    /// supply str to set the state (returns zero)
    pub var GetSetObjectState: *fn (obj: *void, str: [*:0]const u8) callconv(.C) *c_char = undefined;

    /// GetSetObjectState2
    /// get or set the state of a {track,item,envelope} as an RPPXML chunk
    /// str="" to get the chunk string returned (must call FreeHeapPtr when done)
    /// supply str to set the state (returns zero)
    /// set isundo if the state will be used for undo purposes (which may allow REAPER to get the state more efficiently
    pub var GetSetObjectState2: *fn (obj: *void, str: [*:0]const u8, isundo: bool) callconv(.C) *c_char = undefined;

    /// GetSetProjectAuthor
    /// deprecated, see GetSetProjectInfo_String with desc="PROJECT_AUTHOR"
    pub var GetSetProjectAuthor: *fn (proj: *ReaProject, set: bool, author: *c_char, author_sz: c_int) callconv(.C) void = undefined;

    /// GetSetProjectGrid
    /// Get or set the arrange view grid division. 0.25=quarter note, 1.0/3.0=half note triplet, etc. swingmode can be 1 for swing enabled, swingamt is -1..1. swingmode can be 3 for measure-grid. Returns grid configuration flags
    pub var GetSetProjectGrid: *fn (project: *ReaProject, set: bool, divisionInOutOptional: *f64, swingmodeInOutOptional: *c_int, swingamtInOutOptional: *f64) callconv(.C) c_int = undefined;

    /// GetSetProjectInfo
    /// Get or set project information.
    /// RENDER_SETTINGS : &(1|2)=0:master mix, &1=stems+master mix, &2=stems only, &4=multichannel tracks to multichannel files, &8=use render matrix, &16=tracks with only mono media to mono files, &32=selected media items, &64=selected media items via master, &128=selected tracks via master, &256=embed transients if format supports, &512=embed metadata if format supports, &1024=embed take markers if format supports, &2048=2nd pass render
    /// RENDER_BOUNDSFLAG : 0=custom time bounds, 1=entire project, 2=time selection, 3=all project regions, 4=selected media items, 5=selected project regions, 6=all project markers, 7=selected project markers
    /// RENDER_CHANNELS : number of channels in rendered file
    /// RENDER_SRATE : sample rate of rendered file (or 0 for project sample rate)
    /// RENDER_STARTPOS : render start time when RENDER_BOUNDSFLAG=0
    /// RENDER_ENDPOS : render end time when RENDER_BOUNDSFLAG=0
    /// RENDER_TAILFLAG : apply render tail setting when rendering: &1=custom time bounds, &2=entire project, &4=time selection, &8=all project markers/regions, &16=selected media items, &32=selected project markers/regions
    /// RENDER_TAILMS : tail length in ms to render (only used if RENDER_BOUNDSFLAG and RENDER_TAILFLAG are set)
    /// RENDER_ADDTOPROJ : &1=add rendered files to project, &2=do not render files that are likely silent
    /// RENDER_DITHER : &1=dither, &2=noise shaping, &4=dither stems, &8=noise shaping on stems
    /// RENDER_NORMALIZE: &1=enable, (&14==0)=LUFS-I, (&14==2)=RMS, (&14==4)=peak, (&14==6)=true peak, (&14==8)=LUFS-M max, (&14==10)=LUFS-S max, &32=normalize stems to common gain based on master, &64=enable brickwall limit, &128=brickwall limit true peak, (&2304==256)=only normalize files that are too loud, (&2304==2048)=only normalize files that are too quiet, &512=apply fade-in, &1024=apply fade-out
    /// RENDER_NORMALIZE_TARGET: render normalization target as amplitude, so 0.5 means -6.02dB, 0.25 means -12.04dB, etc
    /// RENDER_BRICKWALL: render brickwall limit as amplitude, so 0.5 means -6.02dB, 0.25 means -12.04dB, etc
    /// RENDER_FADEIN: render fade-in (0.001 means 1 ms, requires RENDER_NORMALIZE&512)
    /// RENDER_FADEOUT: render fade-out (0.001 means 1 ms, requires RENDER_NORMALIZE&1024)
    /// RENDER_FADEINSHAPE: render fade-in shape
    /// RENDER_FADEOUTSHAPE: render fade-out shape
    /// PROJECT_SRATE : samplerate (ignored unless PROJECT_SRATE_USE set)
    /// PROJECT_SRATE_USE : set to 1 if project samplerate is used
    ///
    pub var GetSetProjectInfo: *fn (project: *ReaProject, desc: [*:0]const u8, value: f64, is_set: bool) callconv(.C) f64 = undefined;

    /// GetSetProjectInfo_String
    /// Get or set project information.
    /// PROJECT_NAME : project file name (read-only, is_set will be ignored)
    /// PROJECT_TITLE : title field from Project Settings/Notes dialog
    /// PROJECT_AUTHOR : author field from Project Settings/Notes dialog
    /// TRACK_GROUP_NAME:X : track group name, X should be 1..64
    /// MARKER_GUID:X : get the GUID (unique ID) of the marker or region with index X, where X is the index passed to EnumProjectMarkers, not necessarily the displayed number (read-only)
    /// MARKER_INDEX_FROM_GUID:{GUID} : get the GUID index of the marker or region with GUID {GUID} (read-only)
    /// OPENCOPY_CFGIDX : integer for the configuration of format to use when creating copies/applying FX. 0=wave (auto-depth), 1=APPLYFX_FORMAT, 2=RECORD_FORMAT
    /// RECORD_PATH : recording directory -- may be blank or a relative path, to get the effective path see GetProjectPathEx()
    /// RECORD_PATH_SECONDARY : secondary recording directory
    /// RECORD_FORMAT : base64-encoded sink configuration (see project files, etc). Callers can also pass a simple 4-byte string (non-base64-encoded), e.g. "evaw" or "l3pm", to use default settings for that sink type.
    /// APPLYFX_FORMAT : base64-encoded sink configuration (see project files, etc). Used only if RECFMT_OPENCOPY is set to 1. Callers can also pass a simple 4-byte string (non-base64-encoded), e.g. "evaw" or "l3pm", to use default settings for that sink type.
    /// RENDER_FILE : render directory
    /// RENDER_PATTERN : render file name (may contain wildcards)
    /// RENDER_METADATA : get or set the metadata saved with the project (not metadata embedded in project media). Example, ID3 album name metadata: valuestr="ID3:TALB" to get, valuestr="ID3:TALB|my album name" to set. Call with valuestr="" and is_set=false to get a semicolon-separated list of defined project metadata identifiers.
    /// RENDER_TARGETS : semicolon separated list of files that would be written if the project is rendered using the most recent render settings
    /// RENDER_STATS : (read-only) semicolon separated list of statistics for the most recently rendered files. call with valuestr="XXX" to run an action (for example, "42437"=dry run render selected items) before returning statistics.
    /// RENDER_FORMAT : base64-encoded sink configuration (see project files, etc). Callers can also pass a simple 4-byte string (non-base64-encoded), e.g. "evaw" or "l3pm", to use default settings for that sink type.
    /// RENDER_FORMAT2 : base64-encoded secondary sink configuration. Callers can also pass a simple 4-byte string (non-base64-encoded), e.g. "evaw" or "l3pm", to use default settings for that sink type, or "" to disable secondary render.
    ///
    pub var GetSetProjectInfo_String: *fn (project: *ReaProject, desc: [*:0]const u8, valuestrNeedBig: *c_char, is_set: bool) callconv(.C) bool = undefined;

    /// GetSetProjectNotes
    /// gets or sets project notes, notesNeedBig_sz is ignored when setting
    pub var GetSetProjectNotes: *fn (proj: *ReaProject, set: bool, notesNeedBig: *c_char, notesNeedBig_sz: c_int) callconv(.C) void = undefined;

    /// GetSetRepeat
    /// -1 == query,0=clear,1=set,>1=toggle . returns new value
    pub var GetSetRepeat: *fn (val: c_int) callconv(.C) c_int = undefined;

    /// GetSetRepeatEx
    /// -1 == query,0=clear,1=set,>1=toggle . returns new value
    pub var GetSetRepeatEx: *fn (proj: *ReaProject, val: c_int) callconv(.C) c_int = undefined;

    /// GetSetTrackGroupMembership
    /// Gets or modifies the group membership for a track. Returns group state prior to call (each bit represents one of the 32 group numbers). if setmask has bits set, those bits in setvalue will be applied to group. Group can be one of:
    /// MEDIA_EDIT_LEAD
    /// MEDIA_EDIT_FOLLOW
    /// VOLUME_LEAD
    /// VOLUME_FOLLOW
    /// VOLUME_VCA_LEAD
    /// VOLUME_VCA_FOLLOW
    /// PAN_LEAD
    /// PAN_FOLLOW
    /// WIDTH_LEAD
    /// WIDTH_FOLLOW
    /// MUTE_LEAD
    /// MUTE_FOLLOW
    /// SOLO_LEAD
    /// SOLO_FOLLOW
    /// RECARM_LEAD
    /// RECARM_FOLLOW
    /// POLARITY_LEAD
    /// POLARITY_FOLLOW
    /// AUTOMODE_LEAD
    /// AUTOMODE_FOLLOW
    /// VOLUME_REVERSE
    /// PAN_REVERSE
    /// WIDTH_REVERSE
    /// NO_LEAD_WHEN_FOLLOW
    /// VOLUME_VCA_FOLLOW_ISPREFX
    ///
    /// Note: REAPER v6.11 and earlier used _MASTER and _SLAVE rather than _LEAD and _FOLLOW, which is deprecated but still supported (scripts that must support v6.11 and earlier can use the deprecated strings).
    ///
    pub var GetSetTrackGroupMembership: *fn (tr: *MediaTrack, groupname: [*:0]const u8, setmask: c_uint, setvalue: c_uint) callconv(.C) c_uint = undefined;

    /// GetSetTrackGroupMembershipHigh
    /// Gets or modifies the group membership for a track. Returns group state prior to call (each bit represents one of the high 32 group numbers). if setmask has bits set, those bits in setvalue will be applied to group. Group can be one of:
    /// MEDIA_EDIT_LEAD
    /// MEDIA_EDIT_FOLLOW
    /// VOLUME_LEAD
    /// VOLUME_FOLLOW
    /// VOLUME_VCA_LEAD
    /// VOLUME_VCA_FOLLOW
    /// PAN_LEAD
    /// PAN_FOLLOW
    /// WIDTH_LEAD
    /// WIDTH_FOLLOW
    /// MUTE_LEAD
    /// MUTE_FOLLOW
    /// SOLO_LEAD
    /// SOLO_FOLLOW
    /// RECARM_LEAD
    /// RECARM_FOLLOW
    /// POLARITY_LEAD
    /// POLARITY_FOLLOW
    /// AUTOMODE_LEAD
    /// AUTOMODE_FOLLOW
    /// VOLUME_REVERSE
    /// PAN_REVERSE
    /// WIDTH_REVERSE
    /// NO_LEAD_WHEN_FOLLOW
    /// VOLUME_VCA_FOLLOW_ISPREFX
    ///
    /// Note: REAPER v6.11 and earlier used _MASTER and _SLAVE rather than _LEAD and _FOLLOW, which is deprecated but still supported (scripts that must support v6.11 and earlier can use the deprecated strings).
    ///
    pub var GetSetTrackGroupMembershipHigh: *fn (tr: *MediaTrack, groupname: [*:0]const u8, setmask: c_uint, setvalue: c_uint) callconv(.C) c_uint = undefined;

    /// GetSetTrackMIDISupportFile
    /// Get or set the filename for storage of various track MIDI c_characteristics. 0=MIDI colormap image file, 1 or 2=MIDI bank/program select file (2=set new default). If fn != NULL, a new track MIDI storage file will be set; otherwise the existing track MIDI storage file will be returned.
    pub var GetSetTrackMIDISupportFile: *fn (proj: *ReaProject, track: *MediaTrack, which: c_int, filename: [*:0]const u8) callconv(.C) [*:0]const u8 = undefined;

    /// GetSetTrackSendInfo
    /// Get or set send/receive/hardware output attributes.
    /// category is <0 for receives, 0=sends, >0 for hardware outputs
    ///  sendidx is 0..n (to enumerate, iterate over sendidx until it returns NULL)
    /// parameter names:
    /// P_DESTTRACK : MediaTrack * : destination track, only applies for sends/recvs (read-only)
    /// P_SRCTRACK : MediaTrack * : source track, only applies for sends/recvs (read-only)
    /// P_ENV:<envchunkname : TrackEnvelope * : call with :<VOLENV, :<PANENV, etc appended (read-only)
    /// P_EXT:xyz : c_char * : extension-specific persistent data
    /// B_MUTE : bool *
    /// B_PHASE : bool * : true to flip phase
    /// B_MONO : bool *
    /// D_VOL : f64 * : 1.0 = +0dB etc
    /// D_PAN : f64 * : -1..+1
    /// D_PANLAW : f64 * : 1.0=+0.0db, 0.5=-6dB, -1.0 = projdef etc
    /// I_SENDMODE : c_int * : 0=post-fader, 1=pre-fx, 2=post-fx (deprecated), 3=post-fx
    /// I_AUTOMODE : c_int * : automation mode (-1=use track automode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch)
    /// I_SRCCHAN : c_int * : -1 for no audio send. Low 10 bits specify channel offset, and higher bits specify channel count. (srcchan>>10) == 0 for stereo, 1 for mono, 2 for 4 channel, 3 for 6 channel, etc.
    /// I_DSTCHAN : c_int * : low 10 bits are destination index, &1024 set to mix to mono.
    /// I_MIDIFLAGS : c_int * : low 5 bits=source channel 0=all, 1-16, 31=MIDI send disabled, next 5 bits=dest channel, 0=orig, 1-16=chan. &1024 for faders-send MIDI vol/pan. (>>14)&255 = src bus (0 for all, 1 for normal, 2+). (>>22)&255=destination bus (0 for all, 1 for normal, 2+)
    /// See CreateTrackSend, RemoveTrackSend.
    pub var GetSetTrackSendInfo: *fn (tr: *MediaTrack, category: c_int, sendidx: c_int, parmname: [*:0]const u8, setNewValue: *void) callconv(.C) *void = undefined;

    /// GetSetTrackSendInfo_String
    /// Gets/sets a send attribute string:
    /// P_EXT:xyz : c_char * : extension-specific persistent data
    ///
    pub var GetSetTrackSendInfo_String: *fn (tr: *MediaTrack, category: c_int, sendidx: c_int, parmname: [*:0]const u8, stringNeedBig: *c_char, setNewValue: bool) callconv(.C) bool = undefined;

    /// GetSetTrackState
    /// deprecated -- see SetTrackStateChunk, GetTrackStateChunk
    pub var GetSetTrackState: *fn (track: *MediaTrack, str: *c_char, str_sz: c_int) callconv(.C) bool = undefined;

    /// GetSetTrackState2
    /// deprecated -- see SetTrackStateChunk, GetTrackStateChunk
    pub var GetSetTrackState2: *fn (track: *MediaTrack, str: *c_char, str_sz: c_int, isundo: bool) callconv(.C) bool = undefined;

    /// GetSubProjectFromSource
    pub var GetSubProjectFromSource: *fn (src: *PCM_source) callconv(.C) *ReaProject = undefined;

    /// GetTake
    /// get a take from an item by take count (zero-based)
    pub var GetTake: *fn (item: *MediaItem, takeidx: c_int) callconv(.C) *MediaItem_Take = undefined;

    /// GetTakeEnvelope
    pub var GetTakeEnvelope: *fn (take: *MediaItem_Take, envidx: c_int) callconv(.C) *TrackEnvelope = undefined;

    /// GetTakeEnvelopeByName
    pub var GetTakeEnvelopeByName: *fn (take: *MediaItem_Take, envname: [*:0]const u8) callconv(.C) *TrackEnvelope = undefined;

    /// GetTakeMarker
    /// Get information about a take marker. Returns the position in media item source time, or -1 if the take marker does not exist. See GetNumTakeMarkers, SetTakeMarker, DeleteTakeMarker
    pub var GetTakeMarker: *fn (take: *MediaItem_Take, idx: c_int, nameOut: *c_char, nameOut_sz: c_int, colorOutOptional: *c_int) callconv(.C) f64 = undefined;

    /// GetTakeName
    /// returns NULL if the take is not valid
    pub var GetTakeName: *fn (take: *MediaItem_Take) callconv(.C) [*:0]const u8 = undefined;

    /// GetTakeNumStretchMarkers
    /// Returns number of stretch markers in take
    pub var GetTakeNumStretchMarkers: *fn (take: *MediaItem_Take) callconv(.C) c_int = undefined;

    /// GetTakeStretchMarker
    /// Gets information on a stretch marker, idx is 0..n. Returns -1 if stretch marker not valid. posOut will be set to position in item, srcposOutOptional will be set to source media position. Returns index. if input index is -1, the following marker is found using position (or source position if position is -1). If position/source position are used to find marker position, their values are not updated.
    pub var GetTakeStretchMarker: *fn (take: *MediaItem_Take, idx: c_int, posOut: *f64, srcposOutOptional: *f64) callconv(.C) c_int = undefined;

    /// GetTakeStretchMarkerSlope
    /// See SetTakeStretchMarkerSlope
    pub var GetTakeStretchMarkerSlope: *fn (take: *MediaItem_Take, idx: c_int) callconv(.C) f64 = undefined;

    /// GetTCPFXParm
    /// Get information about a specific FX parameter knob (see CountTCPFXParms).
    pub var GetTCPFXParm: *fn (project: *ReaProject, track: *MediaTrack, index: c_int, fxindexOut: *c_int, parmidxOut: *c_int) callconv(.C) bool = undefined;

    /// GetTempoMatchPlayRate
    /// finds the playrate and target length to insert this item stretched to a round power-of-2 number of bars, between 1/8 and 256
    pub var GetTempoMatchPlayRate: *fn (source: *PCM_source, srcscale: f64, position: f64, mult: f64, rateOut: *f64, targetlenOut: *f64) callconv(.C) bool = undefined;

    /// GetTempoTimeSigMarker
    /// Get information about a tempo/time signature marker. See CountTempoTimeSigMarkers, SetTempoTimeSigMarker, AddTempoTimeSigMarker.
    pub var GetTempoTimeSigMarker: *fn (proj: *ReaProject, ptidx: c_int, timeposOut: *f64, measureposOut: *c_int, beatposOut: *f64, bpmOut: *f64, timesig_numOut: *c_int, timesig_denomOut: *c_int, lineartempoOut: *bool) callconv(.C) bool = undefined;

    /// GetThemeColor
    /// Returns the theme color specified, or -1 on failure. If the low bit of flags is set, the color as originally specified by the theme (before any transformations) is returned, otherwise the current (possibly transformed and modified) color is returned. See SetThemeColor for a list of valid ini_key.
    pub var GetThemeColor: *fn (ini_key: [*:0]const u8, flagsOptional: c_int) callconv(.C) c_int = undefined;

    /// GetThingFromPoint
    /// Hit tests a point in screen coordinates. Updates infoOut with information such as "arrange", "fx_chain", "fx_0" (first FX in chain, f32ing), "spacer_0" (spacer before first track). If a track panel is hit, string will begin with "tcp" or "mcp" or "tcp.mute" etc (future versions may append additional information). May return NULL with valid info string to indicate non-track thing.
    pub var GetThingFromPoint: *fn (screen_x: c_int, screen_y: c_int, infoOut: *c_char, infoOut_sz: c_int) callconv(.C) *MediaTrack = undefined;

    /// GetToggleCommandState
    /// See GetToggleCommandStateEx.
    pub var GetToggleCommandState: *fn (command_id: c_int) callconv(.C) c_int = undefined;

    /// GetToggleCommandState2
    /// See GetToggleCommandStateEx.
    pub var GetToggleCommandState2: *fn (section: *KbdSectionInfo, command_id: c_int) callconv(.C) c_int = undefined;

    /// GetToggleCommandStateEx
    /// For the main action context, the MIDI editor, or the media explorer, returns the toggle state of the action. 0=off, 1=on, -1=NA because the action does not have on/off states. For the MIDI editor, the action state for the most recently focused window will be returned.
    pub var GetToggleCommandStateEx: *fn (section_id: c_int, command_id: c_int) callconv(.C) c_int = undefined;

    /// GetToggleCommandStateThroughHooks
    /// Returns the state of an action via extension plugins' hooks.
    pub var GetToggleCommandStateThroughHooks: *fn (section: *KbdSectionInfo, command_id: c_int) callconv(.C) c_int = undefined;

    /// GetTooltipWindow
    /// gets a tooltip window,in case you want to ask it for font information. Can return NULL.
    pub var GetTooltipWindow: *fn () callconv(.C) HWND = undefined;

    /// GetTouchedOrFocusedFX
    /// mode can be 0 to query last touched parameter, or 1 to query currently focused FX. Returns false if failed. If successful, trackIdxOut will be track index (-1 is master track, 0 is first track). itemidxOut will be 0-based item index if an item, or -1 if not an item. takeidxOut will be 0-based take index. fxidxOut will be FX index, potentially with 0x2000000 set to signify container-addressing, or with 0x1000000 set to signify record-input FX. parmOut will be set to the parameter index if querying last-touched. parmOut will have 1 set if querying focused state and FX is no longer focused but still open.
    pub var GetTouchedOrFocusedFX: *fn (mode: c_int, trackidxOut: *c_int, itemidxOut: *c_int, takeidxOut: *c_int, fxidxOut: *c_int, parmOut: *c_int) callconv(.C) bool = undefined;

    /// GetTrack
    /// get a track from a project by track count (zero-based) (proj=0 for active project)
    pub var GetTrack: *fn (proj: *ReaProject, trackidx: c_int) callconv(.C) *MediaTrack = undefined;

    /// GetTrackAutomationMode
    /// return the track mode, regardless of global override
    pub var GetTrackAutomationMode: *fn (tr: *MediaTrack) callconv(.C) c_int = undefined;

    /// GetTrackColor
    /// Returns the track custom color as OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). Black is returned as 0x1000000, no color setting is returned as 0.
    pub var GetTrackColor: *fn (track: *MediaTrack) callconv(.C) c_int = undefined;

    /// GetTrackDepth
    pub var GetTrackDepth: *fn (track: *MediaTrack) callconv(.C) c_int = undefined;

    /// GetTrackEnvelope
    pub var GetTrackEnvelope: *fn (track: *MediaTrack, envidx: c_int) callconv(.C) *TrackEnvelope = undefined;

    /// GetTrackEnvelopeByChunkName
    /// Gets a built-in track envelope by configuration chunk name, like "<VOLENV", or GUID string, like "{B577250D-146F-B544-9B34-F24FBE488F1F}".
    ///
    pub var GetTrackEnvelopeByChunkName: *fn (tr: *MediaTrack, cfgchunkname_or_guid: [*:0]const u8) callconv(.C) *TrackEnvelope = undefined;

    /// GetTrackEnvelopeByName
    pub var GetTrackEnvelopeByName: *fn (track: *MediaTrack, envname: [*:0]const u8) callconv(.C) *TrackEnvelope = undefined;

    /// GetTrackFromPoint
    /// Returns the track from the screen coordinates specified. If the screen coordinates refer to a window associated to the track (such as FX), the track will be returned. infoOutOptional will be set to 1 if it is likely an envelope, 2 if it is likely a track FX. For a free item positioning or fixed lane track, the second byte of infoOutOptional will be set to the (approximate, for fipm tracks) item lane underneath the mouse. See GetThingFromPoint.
    pub var GetTrackFromPoint: *fn (screen_x: c_int, screen_y: c_int, infoOutOptional: *c_int) callconv(.C) *MediaTrack = undefined;

    /// GetTrackGUID
    pub var GetTrackGUID: *fn (tr: *MediaTrack) callconv(.C) *GUID = undefined;

    /// GetTrackInfo
    /// gets track info (returns name).
    /// track index, -1=master, 0..n, or cast a *MediaTrack to c_int
    /// if flags is non-NULL, will be set to:
    /// &1=folder
    /// &2=selected
    /// &4=has fx enabled
    /// &8=muted
    /// &16=soloed
    /// &32=SIP'd (with &16)
    /// &64=rec armed
    /// &128=rec monitoring on
    /// &256=rec monitoring auto
    /// &512=hide from TCP
    /// &1024=hide from MCP
    pub var GetTrackInfo: *fn (track: INT_PTR, flags: *c_int) callconv(.C) [*:0]const u8 = undefined;

    /// GetTrackMediaItem
    pub var GetTrackMediaItem: *fn (tr: *MediaTrack, itemidx: c_int) callconv(.C) *MediaItem = undefined;

    /// GetTrackMIDILyrics
    /// Get all MIDI lyrics on the track. Lyrics will be returned as one string with tabs between each word. flag&1: f64 tabs at the end of each measure and triple tabs when skipping measures, flag&2: each lyric is preceded by its beat position in the project (example with flag=2: "1.1.2\tLyric for measure 1 beat 2\t2.1.1\tLyric for measure 2 beat 1	"). See SetTrackMIDILyrics
    pub var GetTrackMIDILyrics: *fn (track: *MediaTrack, flag: c_int, bufOutWantNeedBig: *c_char, bufOutWantNeedBig_sz: *c_int) callconv(.C) bool = undefined;

    /// GetTrackMIDINoteName
    /// see GetTrackMIDINoteNameEx
    pub var GetTrackMIDINoteName: *fn (track: c_int, pitch: c_int, chan: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// GetTrackMIDINoteNameEx
    /// Get note/CC name. pitch 128 for CC0 name, 129 for CC1 name, etc. See SetTrackMIDINoteNameEx
    pub var GetTrackMIDINoteNameEx: *fn (proj: *ReaProject, track: *MediaTrack, pitch: c_int, chan: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// GetTrackMIDINoteRange
    pub var GetTrackMIDINoteRange: *fn (proj: *ReaProject, track: *MediaTrack, note_loOut: *c_int, note_hiOut: *c_int) callconv(.C) void = undefined;

    /// GetTrackName
    /// Returns "MASTER" for master track, "Track N" if track has no name.
    pub var GetTrackName: *fn (track: *MediaTrack, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// GetTrackNumMediaItems
    pub var GetTrackNumMediaItems: *fn (tr: *MediaTrack) callconv(.C) c_int = undefined;

    /// GetTrackNumSends
    /// returns number of sends/receives/hardware outputs - category is <0 for receives, 0=sends, >0 for hardware outputs
    pub var GetTrackNumSends: *fn (tr: *MediaTrack, category: c_int) callconv(.C) c_int = undefined;

    /// GetTrackReceiveName
    /// See GetTrackSendName.
    pub var GetTrackReceiveName: *fn (track: *MediaTrack, recv_index: c_int, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// GetTrackReceiveUIMute
    /// See GetTrackSendUIMute.
    pub var GetTrackReceiveUIMute: *fn (track: *MediaTrack, recv_index: c_int, muteOut: *bool) callconv(.C) bool = undefined;

    /// GetTrackReceiveUIVolPan
    /// See GetTrackSendUIVolPan.
    pub var GetTrackReceiveUIVolPan: *fn (track: *MediaTrack, recv_index: c_int, volumeOut: *f64, panOut: *f64) callconv(.C) bool = undefined;

    /// GetTrackSendInfo_Value
    /// Get send/receive/hardware output numerical-value attributes.
    /// category is <0 for receives, 0=sends, >0 for hardware outputs
    /// parameter names:
    /// B_MUTE : bool *
    /// B_PHASE : bool * : true to flip phase
    /// B_MONO : bool *
    /// D_VOL : f64 * : 1.0 = +0dB etc
    /// D_PAN : f64 * : -1..+1
    /// D_PANLAW : f64 * : 1.0=+0.0db, 0.5=-6dB, -1.0 = projdef etc
    /// I_SENDMODE : c_int * : 0=post-fader, 1=pre-fx, 2=post-fx (deprecated), 3=post-fx
    /// I_AUTOMODE : c_int * : automation mode (-1=use track automode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch)
    /// I_SRCCHAN : c_int * : -1 for no audio send. Low 10 bits specify channel offset, and higher bits specify channel count. (srcchan>>10) == 0 for stereo, 1 for mono, 2 for 4 channel, 3 for 6 channel, etc.
    /// I_DSTCHAN : c_int * : low 10 bits are destination index, &1024 set to mix to mono.
    /// I_MIDIFLAGS : c_int * : low 5 bits=source channel 0=all, 1-16, 31=MIDI send disabled, next 5 bits=dest channel, 0=orig, 1-16=chan. &1024 for faders-send MIDI vol/pan. (>>14)&255 = src bus (0 for all, 1 for normal, 2+). (>>22)&255=destination bus (0 for all, 1 for normal, 2+)
    /// P_DESTTRACK : MediaTrack * : destination track, only applies for sends/recvs (read-only)
    /// P_SRCTRACK : MediaTrack * : source track, only applies for sends/recvs (read-only)
    /// P_ENV:<envchunkname : TrackEnvelope * : call with :<VOLENV, :<PANENV, etc appended (read-only)
    /// See CreateTrackSend, RemoveTrackSend, GetTrackNumSends.
    pub var GetTrackSendInfo_Value: *fn (tr: *MediaTrack, category: c_int, sendidx: c_int, parmname: [*:0]const u8) callconv(.C) f64 = undefined;

    /// GetTrackSendName
    /// send_idx>=0 for hw ouputs, >=nb_of_hw_ouputs for sends. See GetTrackReceiveName.
    pub var GetTrackSendName: *fn (track: *MediaTrack, send_index: c_int, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// GetTrackSendUIMute
    /// send_idx>=0 for hw ouputs, >=nb_of_hw_ouputs for sends. See GetTrackReceiveUIMute.
    pub var GetTrackSendUIMute: *fn (track: *MediaTrack, send_index: c_int, muteOut: *bool) callconv(.C) bool = undefined;

    /// GetTrackSendUIVolPan
    /// send_idx>=0 for hw ouputs, >=nb_of_hw_ouputs for sends. See GetTrackReceiveUIVolPan.
    pub var GetTrackSendUIVolPan: *fn (track: *MediaTrack, send_index: c_int, volumeOut: *f64, panOut: *f64) callconv(.C) bool = undefined;

    /// GetTrackState
    /// Gets track state, returns track name.
    /// flags will be set to:
    /// &1=folder
    /// &2=selected
    /// &4=has fx enabled
    /// &8=muted
    /// &16=soloed
    /// &32=SIP'd (with &16)
    /// &64=rec armed
    /// &128=rec monitoring on
    /// &256=rec monitoring auto
    /// &512=hide from TCP
    /// &1024=hide from MCP
    pub var GetTrackState: *fn (track: *MediaTrack, flagsOut: *c_int) callconv(.C) [*:0]const u8 = undefined;

    /// GetTrackStateChunk
    /// Gets the RPPXML state of a track, returns true if successful. Undo flag is a performance/caching hint.
    pub var GetTrackStateChunk: *fn (track: *MediaTrack, strNeedBig: *c_char, strNeedBig_sz: c_int, isundoOptional: bool) callconv(.C) bool = undefined;

    /// GetTrackUIMute
    pub var GetTrackUIMute: *fn (track: *MediaTrack, muteOut: *bool) callconv(.C) bool = undefined;

    /// GetTrackUIPan
    pub var GetTrackUIPan: *fn (track: *MediaTrack, pan1Out: *f64, pan2Out: *f64, panmodeOut: *c_int) callconv(.C) bool = undefined;

    /// GetTrackUIVolPan
    pub var GetTrackUIVolPan: *fn (track: *MediaTrack, volumeOut: *f64, panOut: *f64) callconv(.C) bool = undefined;

    /// GetUnderrunTime
    /// retrieves the last timestamps of audio xrun (yellow-flash, if available), media xrun (red-flash), and the current time stamp (all milliseconds)
    pub var GetUnderrunTime: *fn (audio_xrunOut: *c_uint, media_xrunOut: *c_uint, curtimeOut: *c_uint) callconv(.C) void = undefined;

    /// GetUserFileNameForRead
    /// returns true if the user selected a valid file, false if the user canceled the dialog
    pub var GetUserFileNameForRead: *fn (filenameNeed4096: *c_char, title: [*:0]const u8, defext: [*:0]const u8) callconv(.C) bool = undefined;

    /// GetUserInputs
    /// Get values from the user.
    /// If a caption begins with *, for example "*password", the edit field will not display the input text.
    /// Maximum fields is 16. Values are returned as a comma-separated string. Returns false if the user canceled the dialog. You can supply special extra information via additional caption fields: extrawidth=XXX to increase text field width, separator=X to use a different separator for returned fields.
    pub var GetUserInputs: *fn (title: [*:0]const u8, num_inputs: c_int, captions_csv: [*:0]const u8, retvals_csv: *c_char, retvals_csv_sz: c_int) callconv(.C) bool = undefined;

    /// GoToMarker
    /// Go to marker. If use_timeline_order==true, marker_index 1 refers to the first marker on the timeline.  If use_timeline_order==false, marker_index 1 refers to the first marker with the user-editable index of 1.
    pub var GoToMarker: *fn (proj: *ReaProject, marker_index: c_int, use_timeline_order: bool) callconv(.C) void = undefined;

    /// GoToRegion
    /// Seek to region after current region finishes playing (smooth seek). If use_timeline_order==true, region_index 1 refers to the first region on the timeline.  If use_timeline_order==false, region_index 1 refers to the first region with the user-editable index of 1.
    pub var GoToRegion: *fn (proj: *ReaProject, region_index: c_int, use_timeline_order: bool) callconv(.C) void = undefined;

    /// GR_SelectColor
    /// Runs the system color chooser dialog.  Returns 0 if the user cancels the dialog.
    pub var GR_SelectColor: *fn (hwnd: HWND, colorOut: *c_int) callconv(.C) c_int = undefined;

    /// GSC_mainwnd
    /// this is just like win32 GetSysColor() but can have overrides.
    pub var GSC_mainwnd: *fn (t: c_int) callconv(.C) c_int = undefined;

    /// guidToString
    /// dest should be at least 64 c_chars long to be safe
    pub var guidToString: *fn (g: *const GUID, destNeed64: *c_char) callconv(.C) void = undefined;

    /// HasExtState
    /// Returns true if there exists an extended state value for a specific section and key. See SetExtState, GetExtState, DeleteExtState.
    pub var HasExtState: *fn (section: [*:0]const u8, key: [*:0]const u8) callconv(.C) bool = undefined;

    /// HasTrackMIDIPrograms
    /// returns name of track plugin that is supplying MIDI programs,or NULL if there is none
    pub var HasTrackMIDIPrograms: *fn (track: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// HasTrackMIDIProgramsEx
    /// returns name of track plugin that is supplying MIDI programs,or NULL if there is none
    pub var HasTrackMIDIProgramsEx: *fn (proj: *ReaProject, track: *MediaTrack) callconv(.C) [*:0]const u8 = undefined;

    /// Help_Set
    pub var Help_Set: *fn (helpstring: [*:0]const u8, is_temporary_help: bool) callconv(.C) void = undefined;

    /// HiresPeaksFromSource
    pub var HiresPeaksFromSource: *fn (src: *PCM_source, block: *PCM_source_peaktransfer_t) callconv(.C) void = undefined;

    /// image_resolve_fn
    pub var image_resolve_fn: *fn (in: [*:0]const u8, out: *c_char, out_sz: c_int) callconv(.C) void = undefined;

    /// InsertAutomationItem
    /// Insert a new automation item. pool_id < 0 collects existing envelope points into the automation item; if pool_id is >= 0 the automation item will be a new instance of that pool (which will be created as an empty instance if it does not exist). Returns the index of the item, suitable for passing to other automation item API functions. See GetSetAutomationItemInfo.
    pub var InsertAutomationItem: *fn (env: *TrackEnvelope, pool_id: c_int, position: f64, length: f64) callconv(.C) c_int = undefined;

    /// InsertEnvelopePoint
    /// Insert an envelope point. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done. See InsertEnvelopePointEx.
    pub var InsertEnvelopePoint: *fn (envelope: *TrackEnvelope, time: f64, value: f64, shape: c_int, tension: f64, selected: bool, noSortInOptional: *bool) callconv(.C) bool = undefined;

    /// InsertEnvelopePointEx
    /// Insert an envelope point. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done.
    /// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
    /// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
    /// even if the automation item is trimmed so that not all points are visible.
    /// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
    /// See CountEnvelopePointsEx, GetEnvelopePointEx, SetEnvelopePointEx, DeleteEnvelopePointEx.
    pub var InsertEnvelopePointEx: *fn (envelope: *TrackEnvelope, autoitem_idx: c_int, time: f64, value: f64, shape: c_int, tension: f64, selected: bool, noSortInOptional: *bool) callconv(.C) bool = undefined;

    /// InsertMedia
    /// mode: 0=add to current track, 1=add new track, 3=add to selected items as takes, &4=stretch/loop to fit time sel, &8=try to match tempo 1x, &16=try to match tempo 0.5x, &32=try to match tempo 2x, &64=don't preserve pitch when matching tempo, &128=no loop/section if startpct/endpct set, &256=force loop regardless of global preference for looping imported items, &512=use high word as absolute track index if mode&3==0 or mode&2048, &1024=insert into reasamplomatic on a new track (add 1 to insert on last selected track), &2048=insert into open reasamplomatic instance (add 512 to use high word as absolute track index), &4096=move to source preferred position (BWF start offset), &8192=reverse
    pub var InsertMedia: *fn (file: [*:0]const u8, mode: c_int) callconv(.C) c_int = undefined;

    /// InsertMediaSection
    /// See InsertMedia.
    pub var InsertMediaSection: *fn (file: [*:0]const u8, mode: c_int, startpct: f64, endpct: f64, pitchshift: f64) callconv(.C) c_int = undefined;

    /// InsertTrackAtIndex
    /// inserts a track at idx,of course this will be clamped to 0..GetNumTracks(). wantDefaults=TRUE for default envelopes/FX,otherwise no enabled fx/env
    pub var InsertTrackAtIndex: *fn (idx: c_int, wantDefaults: bool) callconv(.C) void = undefined;

    /// IsInRealTimeAudio
    /// are we in a realtime audio thread (between OnAudioBuffer calls,not in some worker/anticipative FX thread)? threadsafe
    pub var IsInRealTimeAudio: *fn () callconv(.C) c_int = undefined;

    /// IsItemTakeActiveForPlayback
    /// get whether a take will be played (active take, unmuted, etc)
    pub var IsItemTakeActiveForPlayback: *fn (item: *MediaItem, take: *MediaItem_Take) callconv(.C) bool = undefined;

    /// IsMediaExtension
    /// Tests a file extension (i.e. "wav" or "mid") to see if it's a media extension.
    /// If wantOthers is set, then "RPP", "TXT" and other project-type formats will also pass.
    pub var IsMediaExtension: *fn (ext: [*:0]const u8, wantOthers: bool) callconv(.C) bool = undefined;

    /// IsMediaItemSelected
    pub var IsMediaItemSelected: *fn (item: *MediaItem) callconv(.C) bool = undefined;

    /// IsProjectDirty
    /// Is the project dirty (needing save)? Always returns 0 if 'undo/prompt to save' is disabled in preferences.
    pub var IsProjectDirty: *fn (proj: *ReaProject) callconv(.C) c_int = undefined;

    /// IsREAPER
    /// Returns true if dealing with REAPER, returns false for ReaMote, etc
    pub var IsREAPER: *fn () callconv(.C) bool = undefined;

    /// IsTrackSelected
    pub var IsTrackSelected: *fn (track: *MediaTrack) callconv(.C) bool = undefined;

    /// IsTrackVisible
    /// If mixer==true, returns true if the track is visible in the mixer.  If mixer==false, returns true if the track is visible in the track control panel.
    pub var IsTrackVisible: *fn (track: *MediaTrack, mixer: bool) callconv(.C) bool = undefined;

    /// joystick_create
    /// creates a joystick device
    pub var joystick_create: *fn (guid: *const GUID) callconv(.C) *joystick_device = undefined;

    /// joystick_destroy
    /// destroys a joystick device
    pub var joystick_destroy: *fn (device: *joystick_device) callconv(.C) void = undefined;

    /// joystick_enum
    /// enumerates installed devices, returns GUID as a string
    pub var joystick_enum: *fn (index: c_int, namestrOutOptional: [*:0]const u8) callconv(.C) [*:0]const u8 = undefined;

    /// joystick_getaxis
    /// returns axis value (-1..1)
    pub var joystick_getaxis: *fn (dev: *joystick_device, axis: c_int) callconv(.C) f64 = undefined;

    /// joystick_getbuttonmask
    /// returns button pressed mask, 1=first button, 2=second...
    pub var joystick_getbuttonmask: *fn (dev: *joystick_device) callconv(.C) c_uint = undefined;

    /// joystick_getinfo
    /// returns button count
    pub var joystick_getinfo: *fn (dev: *joystick_device, axesOutOptional: *c_int, povsOutOptional: *c_int) callconv(.C) c_int = undefined;

    /// joystick_getpov
    /// returns POV value (usually 0..655.35, or 655.35 on error)
    pub var joystick_getpov: *fn (dev: *joystick_device, pov: c_int) callconv(.C) f64 = undefined;

    /// joystick_update
    /// Updates joystick state from hardware, returns true if successful (*joystick_get will not be valid until joystick_update() is called successfully)
    pub var joystick_update: *fn (dev: *joystick_device) callconv(.C) bool = undefined;

    /// kbd_enumerateActions
    pub var kbd_enumerateActions: *fn (section: *KbdSectionInfo, idx: c_int, nameOut: [*:0]const u8) callconv(.C) c_int = undefined;

    /// kbd_formatKeyName
    pub var kbd_formatKeyName: *fn (ac: *ACCEL, s: *c_char) callconv(.C) void = undefined;

    /// kbd_getCommandName
    /// Get the string of a key assigned to command "cmd" in a section.
    /// This function is poorly named as it doesn't return the command's name, see kbd_getTextFromCmd.
    pub var kbd_getCommandName: *fn (cmd: c_int, s: *c_char, section: *KbdSectionInfo) callconv(.C) void = undefined;

    /// kbd_getTextFromCmd
    pub var kbd_getTextFromCmd: *fn (cmd: c_int, section: *KbdSectionInfo) callconv(.C) [*:0]const u8 = undefined;

    /// KBD_OnMainActionEx
    /// val/valhw are used for midi stuff.
    /// val=[0..127] and valhw=-1 (midi CC),
    /// valhw >=0 (midi pitch (valhw | val<<7)),
    /// relmode absolute (0) or 1/2/3 for relative adjust modes
    pub var KBD_OnMainActionEx: *fn (cmd: c_int, val: c_int, valhw: c_int, relmode: c_int, hwnd: HWND, proj: *ReaProject) callconv(.C) c_int = undefined;

    /// kbd_OnMidiEvent
    /// can be called from anywhere (threadsafe)
    pub var kbd_OnMidiEvent: *fn (evt: *MIDI_event_t, dev_index: c_int) callconv(.C) void = undefined;

    /// kbd_OnMidiList
    /// can be called from anywhere (threadsafe)
    pub var kbd_OnMidiList: *fn (list: *MIDI_eventlist, dev_index: c_int) callconv(.C) void = undefined;

    /// kbd_ProcessActionsMenu
    pub var kbd_ProcessActionsMenu: *fn (menu: HMENU, section: *KbdSectionInfo) callconv(.C) void = undefined;

    /// kbd_processMidiEventActionEx
    pub var kbd_processMidiEventActionEx: *fn (evt: *MIDI_event_t, section: *KbdSectionInfo, hwndCtx: HWND) callconv(.C) bool = undefined;

    /// kbd_reprocessMenu
    /// Reprocess a menu recursively, setting key assignments to what their command IDs are mapped to.
    pub var kbd_reprocessMenu: *fn (menu: HMENU, section: *KbdSectionInfo) callconv(.C) void = undefined;

    /// kbd_RunCommandThroughHooks
    /// actioncommandID may get modified
    pub var kbd_RunCommandThroughHooks: *fn (section: *KbdSectionInfo, actionCommandID: *const c_int, val: *const c_int, valhw: *const c_int, relmode: *const c_int, hwnd: HWND) callconv(.C) bool = undefined;

    /// kbd_translateAccelerator
    /// Pass in the HWND to receive commands, a MSG of a key command,  and a valid section,
    /// and kbd_translateAccelerator() will process it looking for any keys bound to it, and send the messages off.
    /// Returns 1 if processed, 0 if no key binding found.
    pub var kbd_translateAccelerator: *fn (hwnd: HWND, msg: *MSG, section: *KbdSectionInfo) callconv(.C) c_int = undefined;

    /// LICE__Destroy
    pub var LICE__Destroy: *fn (bm: *LICE_IBitmap) callconv(.C) void = undefined;

    /// LICE__DestroyFont
    pub var LICE__DestroyFont: *fn (font: *LICE_IFont) callconv(.C) void = undefined;

    /// LICE__DrawText
    pub var LICE__DrawText: *fn (font: *LICE_IFont, bm: *LICE_IBitmap, str: [*:0]const u8, strcnt: c_int, rect: *RECT, dtFlags: UINT) callconv(.C) c_int = undefined;

    /// LICE__GetBits
    pub var LICE__GetBits: *fn (bm: *LICE_IBitmap) callconv(.C) *void = undefined;

    /// LICE__GetDC
    pub var LICE__GetDC: *fn (bm: *LICE_IBitmap) callconv(.C) HDC = undefined;

    /// LICE__GetHeight
    pub var LICE__GetHeight: *fn (bm: *LICE_IBitmap) callconv(.C) c_int = undefined;

    /// LICE__GetRowSpan
    pub var LICE__GetRowSpan: *fn (bm: *LICE_IBitmap) callconv(.C) c_int = undefined;

    /// LICE__GetWidth
    pub var LICE__GetWidth: *fn (bm: *LICE_IBitmap) callconv(.C) c_int = undefined;

    /// LICE__IsFlipped
    pub var LICE__IsFlipped: *fn (bm: *LICE_IBitmap) callconv(.C) bool = undefined;

    /// LICE__resize
    pub var LICE__resize: *fn (bm: *LICE_IBitmap, w: c_int, h: c_int) callconv(.C) bool = undefined;

    /// LICE__SetBkColor
    pub var LICE__SetBkColor: *fn (font: *LICE_IFont, color: LICE_pixel) callconv(.C) LICE_pixel = undefined;

    /// LICE__SetFromHFont
    /// font must REMAIN valid,unless LICE_FONT_FLAG_PRECALCALL is set
    pub var LICE__SetFromHFont: *fn (font: *LICE_IFont, hfont: HFONT, flags: c_int) callconv(.C) void = undefined;

    /// LICE__SetTextColor
    pub var LICE__SetTextColor: *fn (font: *LICE_IFont, color: LICE_pixel) callconv(.C) LICE_pixel = undefined;

    /// LICE__SetTextCombineMode
    pub var LICE__SetTextCombineMode: *fn (ifont: *LICE_IFont, mode: c_int, alpha: f32) callconv(.C) void = undefined;

    /// LICE_Arc
    pub var LICE_Arc: *fn (dest: *LICE_IBitmap, cx: f32, cy: f32, r: f32, minAngle: f32, maxAngle: f32, color: LICE_pixel, alpha: f32, mode: c_int, aa: bool) callconv(.C) void = undefined;

    /// LICE_Blit
    pub var LICE_Blit: *fn (dest: *LICE_IBitmap, src: *LICE_IBitmap, dstx: c_int, dsty: c_int, srcx: c_int, srcy: c_int, srcw: c_int, srch: c_int, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_Blur
    pub var LICE_Blur: *fn (dest: *LICE_IBitmap, src: *LICE_IBitmap, dstx: c_int, dsty: c_int, srcx: c_int, srcy: c_int, srcw: c_int, srch: c_int) callconv(.C) void = undefined;

    /// LICE_BorderedRect
    pub var LICE_BorderedRect: *fn (dest: *LICE_IBitmap, x: c_int, y: c_int, w: c_int, h: c_int, bgcolor: LICE_pixel, fgcolor: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_Circle
    pub var LICE_Circle: *fn (dest: *LICE_IBitmap, cx: f32, cy: f32, r: f32, color: LICE_pixel, alpha: f32, mode: c_int, aa: bool) callconv(.C) void = undefined;

    /// LICE_Clear
    pub var LICE_Clear: *fn (dest: *LICE_IBitmap, color: LICE_pixel) callconv(.C) void = undefined;

    /// LICE_ClearRect
    pub var LICE_ClearRect: *fn (dest: *LICE_IBitmap, x: c_int, y: c_int, w: c_int, h: c_int, mask: LICE_pixel, orbits: LICE_pixel) callconv(.C) void = undefined;

    /// LICE_ClipLine
    /// Returns false if the line is entirely offscreen.
    pub var LICE_ClipLine: *fn (pX1Out: *c_int, pY1Out: *c_int, pX2Out: *c_int, pY2Out: *c_int, xLo: c_int, yLo: c_int, xHi: c_int, yHi: c_int) callconv(.C) bool = undefined;

    /// LICE_CombinePixels
    pub var LICE_CombinePixels: *fn (dest: LICE_pixel, src: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) LICE_pixel = undefined;

    /// LICE_Copy
    pub var LICE_Copy: *fn (dest: *LICE_IBitmap, src: *LICE_IBitmap) callconv(.C) void = undefined;

    /// LICE_CreateBitmap
    /// create a new bitmap. this is like calling new LICE_MemBitmap (mode=0) or new LICE_SysBitmap (mode=1).
    pub var LICE_CreateBitmap: *fn (mode: c_int, w: c_int, h: c_int) callconv(.C) *LICE_IBitmap = undefined;

    /// LICE_CreateFont
    pub var LICE_CreateFont: *fn () callconv(.C) *LICE_IFont = undefined;

    /// LICE_DrawCBezier
    pub var LICE_DrawCBezier: *fn (dest: *LICE_IBitmap, xstart: f64, ystart: f64, xctl1: f64, yctl1: f64, xctl2: f64, yctl2: f64, xend: f64, yend: f64, color: LICE_pixel, alpha: f32, mode: c_int, aa: bool, tol: f64) callconv(.C) void = undefined;

    /// LICE_DrawChar
    pub var LICE_DrawChar: *fn (bm: *LICE_IBitmap, x: c_int, y: c_int, c: c_char, color: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_DrawGlyph
    pub var LICE_DrawGlyph: *fn (dest: *LICE_IBitmap, x: c_int, y: c_int, color: LICE_pixel, alphas: *LICE_pixel_chan, glyph_w: c_int, glyph_h: c_int, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_DrawRect
    pub var LICE_DrawRect: *fn (dest: *LICE_IBitmap, x: c_int, y: c_int, w: c_int, h: c_int, color: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_DrawText
    pub var LICE_DrawText: *fn (bm: *LICE_IBitmap, x: c_int, y: c_int, string: [*:0]const u8, color: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_FillCBezier
    pub var LICE_FillCBezier: *fn (dest: *LICE_IBitmap, xstart: f64, ystart: f64, xctl1: f64, yctl1: f64, xctl2: f64, yctl2: f64, xend: f64, yend: f64, yfill: c_int, color: LICE_pixel, alpha: f32, mode: c_int, aa: bool, tol: f64) callconv(.C) void = undefined;

    /// LICE_FillCircle
    pub var LICE_FillCircle: *fn (dest: *LICE_IBitmap, cx: f32, cy: f32, r: f32, color: LICE_pixel, alpha: f32, mode: c_int, aa: bool) callconv(.C) void = undefined;

    /// LICE_FillConvexPolygon
    pub var LICE_FillConvexPolygon: *fn (dest: *LICE_IBitmap, x: *c_int, y: *c_int, npoints: c_int, color: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_FillRect
    pub var LICE_FillRect: *fn (dest: *LICE_IBitmap, x: c_int, y: c_int, w: c_int, h: c_int, color: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_FillTrapezoid
    pub var LICE_FillTrapezoid: *fn (dest: *LICE_IBitmap, x1a: c_int, x1b: c_int, y1: c_int, x2a: c_int, x2b: c_int, y2: c_int, color: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_FillTriangle
    pub var LICE_FillTriangle: *fn (dest: *LICE_IBitmap, x1: c_int, y1: c_int, x2: c_int, y2: c_int, x3: c_int, y3: c_int, color: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_GetPixel
    pub var LICE_GetPixel: *fn (bm: *LICE_IBitmap, x: c_int, y: c_int) callconv(.C) LICE_pixel = undefined;

    /// LICE_GradRect
    pub var LICE_GradRect: *fn (dest: *LICE_IBitmap, dstx: c_int, dsty: c_int, dstw: c_int, dsth: c_int, ir: f32, ig: f32, ib: f32, ia: f32, drdx: f32, dgdx: f32, dbdx: f32, dadx: f32, drdy: f32, dgdy: f32, dbdy: f32, dady: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_Line
    pub var LICE_Line: *fn (dest: *LICE_IBitmap, x1: f32, y1: f32, x2: f32, y2: f32, color: LICE_pixel, alpha: f32, mode: c_int, aa: bool) callconv(.C) void = undefined;

    /// LICE_LineInt
    pub var LICE_LineInt: *fn (dest: *LICE_IBitmap, x1: c_int, y1: c_int, x2: c_int, y2: c_int, color: LICE_pixel, alpha: f32, mode: c_int, aa: bool) callconv(.C) void = undefined;

    /// LICE_LoadPNG
    pub var LICE_LoadPNG: *fn (filename: [*:0]const u8, bmp: *LICE_IBitmap) callconv(.C) *LICE_IBitmap = undefined;

    /// LICE_LoadPNGFromResource
    pub var LICE_LoadPNGFromResource: *fn (hInst: HINSTANCE, resid: [*:0]const u8, bmp: *LICE_IBitmap) callconv(.C) *LICE_IBitmap = undefined;

    /// LICE_MeasureText
    pub var LICE_MeasureText: *fn (string: [*:0]const u8, w: *c_int, h: *c_int) callconv(.C) void = undefined;

    /// LICE_MultiplyAddRect
    pub var LICE_MultiplyAddRect: *fn (dest: *LICE_IBitmap, x: c_int, y: c_int, w: c_int, h: c_int, rsc: f32, gsc: f32, bsc: f32, asc: f32, radd: f32, gadd: f32, badd: f32, aadd: f32) callconv(.C) void = undefined;

    /// LICE_PutPixel
    pub var LICE_PutPixel: *fn (bm: *LICE_IBitmap, x: c_int, y: c_int, color: LICE_pixel, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_RotatedBlit
    /// these coordinates are offset from the center of the image,in source pixel coordinates
    pub var LICE_RotatedBlit: *fn (dest: *LICE_IBitmap, src: *LICE_IBitmap, dstx: c_int, dsty: c_int, dstw: c_int, dsth: c_int, srcx: f32, srcy: f32, srcw: f32, srch: f32, angle: f32, cliptosourcerect: bool, alpha: f32, mode: c_int, rotxcent: f32, rotycent: f32) callconv(.C) void = undefined;

    /// LICE_RoundRect
    pub var LICE_RoundRect: *fn (drawbm: *LICE_IBitmap, xpos: f32, ypos: f32, w: f32, h: f32, cornerradius: c_int, col: LICE_pixel, alpha: f32, mode: c_int, aa: bool) callconv(.C) void = undefined;

    /// LICE_ScaledBlit
    pub var LICE_ScaledBlit: *fn (dest: *LICE_IBitmap, src: *LICE_IBitmap, dstx: c_int, dsty: c_int, dstw: c_int, dsth: c_int, srcx: f32, srcy: f32, srcw: f32, srch: f32, alpha: f32, mode: c_int) callconv(.C) void = undefined;

    /// LICE_SimpleFill
    pub var LICE_SimpleFill: *fn (dest: *LICE_IBitmap, x: c_int, y: c_int, newcolor: LICE_pixel, comparemask: LICE_pixel, keepmask: LICE_pixel) callconv(.C) void = undefined;

    /// LICE_ThickFLine
    /// always AA. wid is not affected by scaling (1 is always normal line, 2 is always 2 physical pixels, etc)
    pub var LICE_ThickFLine: *fn (dest: *LICE_IBitmap, x1: f64, y1: f64, x2: f64, y2: f64, color: LICE_pixel, alpha: f32, mode: c_int, wid: c_int) callconv(.C) void = undefined;

    /// LocalizeString
    /// Returns a localized version of src_string, in section section. flags can have 1 set to only localize if sprintf-style formatting matches the original.
    pub var LocalizeString: *fn (src_string: [*:0]const u8, section: [*:0]const u8, flagsOptional: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// Loop_OnArrow
    /// Move the loop selection left or right. Returns true if snap is enabled.
    pub var Loop_OnArrow: *fn (project: *ReaProject, direction: c_int) callconv(.C) bool = undefined;

    /// Main_OnCommand
    /// See Main_OnCommandEx.
    pub var Main_OnCommand: *fn (command: c_int, flag: c_int) callconv(.C) void = undefined;

    /// Main_OnCommandEx
    /// Performs an action belonging to the main action section. To perform non-native actions (ReaScripts, custom or extension plugins' actions) safely, see NamedCommandLookup().
    pub var Main_OnCommandEx: *fn (command: c_int, flag: c_int, proj: *ReaProject) callconv(.C) void = undefined;

    /// Main_openProject
    /// opens a project. will prompt the user to save unless name is prefixed with 'noprompt:'. If name is prefixed with 'template:', project file will be loaded as a template.
    /// If passed a .RTrackTemplate file, adds the template to the existing project.
    pub var Main_openProject: *fn (name: [*:0]const u8) callconv(.C) void = undefined;

    /// Main_SaveProject
    /// Save the project.
    pub var Main_SaveProject: *fn (proj: *ReaProject, forceSaveAsInOptional: bool) callconv(.C) void = undefined;

    /// Main_SaveProjectEx
    /// Save the project. options: &1=save selected tracks as track template, &2=include media with track template, &4=include envelopes with track template. See Main_openProject, Main_SaveProject.
    pub var Main_SaveProjectEx: *fn (proj: *ReaProject, filename: [*:0]const u8, options: c_int) callconv(.C) void = undefined;

    /// Main_UpdateLoopInfo
    pub var Main_UpdateLoopInfo: *fn (ignoremask: c_int) callconv(.C) void = undefined;

    /// MarkProjectDirty
    /// Marks project as dirty (needing save) if 'undo/prompt to save' is enabled in preferences.
    pub var MarkProjectDirty: *fn (proj: *ReaProject) callconv(.C) void = undefined;

    /// MarkTrackItemsDirty
    /// If track is supplied, item is ignored
    pub var MarkTrackItemsDirty: *fn (track: *MediaTrack, item: *MediaItem) callconv(.C) void = undefined;

    /// Master_GetPlayRate
    pub var Master_GetPlayRate: *fn (project: *ReaProject) callconv(.C) f64 = undefined;

    /// Master_GetPlayRateAtTime
    pub var Master_GetPlayRateAtTime: *fn (time_s: f64, proj: *ReaProject) callconv(.C) f64 = undefined;

    /// Master_GetTempo
    pub var Master_GetTempo: *fn () callconv(.C) f64 = undefined;

    /// Master_NormalizePlayRate
    /// Convert play rate to/from a value between 0 and 1, representing the position on the project playrate slider.
    pub var Master_NormalizePlayRate: *fn (playrate: f64, isnormalized: bool) callconv(.C) f64 = undefined;

    /// Master_NormalizeTempo
    /// Convert the tempo to/from a value between 0 and 1, representing bpm in the range of 40-296 bpm.
    pub var Master_NormalizeTempo: *fn (bpm: f64, isnormalized: bool) callconv(.C) f64 = undefined;

    /// MB
    /// type 0=OK,1=OKCANCEL,2=ABORTRETRYIGNORE,3=YESNOCANCEL,4=YESNO,5=RETRYCANCEL : ret 1=OK,2=CANCEL,3=ABORT,4=RETRY,5=IGNORE,6=YES,7=NO
    pub var MB: *fn (msg: [*:0]const u8, title: [*:0]const u8, type: c_int) callconv(.C) c_int = undefined;

    /// MediaItemDescendsFromTrack
    /// Returns 1 if the track holds the item, 2 if the track is a folder containing the track that holds the item, etc.
    pub var MediaItemDescendsFromTrack: *fn (item: *MediaItem, track: *MediaTrack) callconv(.C) c_int = undefined;

    /// Menu_GetHash
    /// Get a string that only changes when menu/toolbar entries are added or removed (not re-ordered). Can be used to determine if a customized menu/toolbar differs from the default, or if the default changed after a menu/toolbar was customized. flag==0: current default menu/toolbar; flag==1: current customized menu/toolbar; flag==2: default menu/toolbar at the time the current menu/toolbar was most recently customized, if it was customized in REAPER v7.08 or later.
    pub var Menu_GetHash: *fn (menuname: [*:0]const u8, flag: c_int, hashOut: *c_char, hashOut_sz: c_int) callconv(.C) bool = undefined;

    /// MIDI_CountEvts
    /// Count the number of notes, CC events, and text/sysex events in a given MIDI item.
    pub var MIDI_CountEvts: *fn (take: *MediaItem_Take, notecntOut: *c_int, ccevtcntOut: *c_int, textsyxevtcntOut: *c_int) callconv(.C) c_int = undefined;

    /// MIDI_DeleteCC
    /// Delete a MIDI CC event.
    pub var MIDI_DeleteCC: *fn (take: *MediaItem_Take, ccidx: c_int) callconv(.C) bool = undefined;

    /// MIDI_DeleteEvt
    /// Delete a MIDI event.
    pub var MIDI_DeleteEvt: *fn (take: *MediaItem_Take, evtidx: c_int) callconv(.C) bool = undefined;

    /// MIDI_DeleteNote
    /// Delete a MIDI note.
    pub var MIDI_DeleteNote: *fn (take: *MediaItem_Take, noteidx: c_int) callconv(.C) bool = undefined;

    /// MIDI_DeleteTextSysexEvt
    /// Delete a MIDI text or sysex event.
    pub var MIDI_DeleteTextSysexEvt: *fn (take: *MediaItem_Take, textsyxevtidx: c_int) callconv(.C) bool = undefined;

    /// MIDI_DisableSort
    /// Disable sorting for all MIDI insert, delete, get and set functions, until MIDI_Sort is called.
    pub var MIDI_DisableSort: *fn (take: *MediaItem_Take) callconv(.C) void = undefined;

    /// MIDI_EnumSelCC
    /// Returns the index of the next selected MIDI CC event after ccidx (-1 if there are no more selected events).
    pub var MIDI_EnumSelCC: *fn (take: *MediaItem_Take, ccidx: c_int) callconv(.C) c_int = undefined;

    /// MIDI_EnumSelEvts
    /// Returns the index of the next selected MIDI event after evtidx (-1 if there are no more selected events).
    pub var MIDI_EnumSelEvts: *fn (take: *MediaItem_Take, evtidx: c_int) callconv(.C) c_int = undefined;

    /// MIDI_EnumSelNotes
    /// Returns the index of the next selected MIDI note after noteidx (-1 if there are no more selected events).
    pub var MIDI_EnumSelNotes: *fn (take: *MediaItem_Take, noteidx: c_int) callconv(.C) c_int = undefined;

    /// MIDI_EnumSelTextSysexEvts
    /// Returns the index of the next selected MIDI text/sysex event after textsyxidx (-1 if there are no more selected events).
    pub var MIDI_EnumSelTextSysexEvts: *fn (take: *MediaItem_Take, textsyxidx: c_int) callconv(.C) c_int = undefined;

    /// MIDI_eventlist_Create
    /// Create a MIDI_eventlist object. The returned object must be deleted with MIDI_eventlist_destroy().
    pub var MIDI_eventlist_Create: *fn () callconv(.C) *MIDI_eventlist = undefined;

    /// MIDI_eventlist_Destroy
    /// Destroy a MIDI_eventlist object that was created using MIDI_eventlist_Create().
    pub var MIDI_eventlist_Destroy: *fn (evtlist: *MIDI_eventlist) callconv(.C) void = undefined;

    /// MIDI_GetAllEvts
    /// Get all MIDI data. MIDI buffer is returned as a list of { c_int offset, c_char flag, c_int msglen, unsigned c_char msg[] }.
    /// offset: MIDI ticks from previous event
    /// flag: &1=selected &2=muted
    /// flag high 4 bits for CC shape: &16=linear, &32=slow start/end, &16|32=fast start, &64=fast end, &64|16=bezier
    /// msg: the MIDI message.
    /// A meta-event of type 0xF followed by 'CCBZ ' and 5 more bytes represents bezier curve data for the previous MIDI event: 1 byte for the bezier type (usually 0) and 4 bytes for the bezier tension as a f32.
    /// For tick intervals longer than a 32 bit word can represent, zero-length meta events may be placed between valid events.
    /// See MIDI_SetAllEvts.
    pub var MIDI_GetAllEvts: *fn (take: *MediaItem_Take, bufOutNeedBig: *c_char, bufOutNeedBig_sz: *c_int) callconv(.C) bool = undefined;

    /// MIDI_GetCC
    /// Get MIDI CC event properties.
    pub var MIDI_GetCC: *fn (take: *MediaItem_Take, ccidx: c_int, selectedOut: *bool, mutedOut: *bool, ppqposOut: *f64, chanmsgOut: *c_int, chanOut: *c_int, msg2Out: *c_int, msg3Out: *c_int) callconv(.C) bool = undefined;

    /// MIDI_GetCCShape
    /// Get CC shape and bezier tension. See MIDI_GetCC, MIDI_SetCCShape
    pub var MIDI_GetCCShape: *fn (take: *MediaItem_Take, ccidx: c_int, shapeOut: *c_int, beztensionOut: *f64) callconv(.C) bool = undefined;

    /// MIDI_GetEvt
    /// Get MIDI event properties.
    pub var MIDI_GetEvt: *fn (take: *MediaItem_Take, evtidx: c_int, selectedOut: *bool, mutedOut: *bool, ppqposOut: *f64, msgOut: *c_char, msgOut_sz: *c_int) callconv(.C) bool = undefined;

    /// MIDI_GetGrid
    /// Returns the most recent MIDI editor grid size for this MIDI take, in QN. Swing is between 0 and 1. Note length is 0 if it follows the grid size.
    pub var MIDI_GetGrid: *fn (take: *MediaItem_Take, swingOutOptional: *f64, noteLenOutOptional: *f64) callconv(.C) f64 = undefined;

    /// MIDI_GetHash
    /// Get a string that only changes when the MIDI data changes. If notesonly==true, then the string changes only when the MIDI notes change. See MIDI_GetTrackHash
    pub var MIDI_GetHash: *fn (take: *MediaItem_Take, notesonly: bool, hashOut: *c_char, hashOut_sz: c_int) callconv(.C) bool = undefined;

    /// MIDI_GetNote
    /// Get MIDI note properties.
    pub var MIDI_GetNote: *fn (take: *MediaItem_Take, noteidx: c_int, selectedOut: *bool, mutedOut: *bool, startppqposOut: *f64, endppqposOut: *f64, chanOut: *c_int, pitchOut: *c_int, velOut: *c_int) callconv(.C) bool = undefined;

    /// MIDI_GetPPQPos_EndOfMeasure
    /// Returns the MIDI tick (ppq) position corresponding to the end of the measure.
    pub var MIDI_GetPPQPos_EndOfMeasure: *fn (take: *MediaItem_Take, ppqpos: f64) callconv(.C) f64 = undefined;

    /// MIDI_GetPPQPos_StartOfMeasure
    /// Returns the MIDI tick (ppq) position corresponding to the start of the measure.
    pub var MIDI_GetPPQPos_StartOfMeasure: *fn (take: *MediaItem_Take, ppqpos: f64) callconv(.C) f64 = undefined;

    /// MIDI_GetPPQPosFromProjQN
    /// Returns the MIDI tick (ppq) position corresponding to a specific project time in quarter notes.
    pub var MIDI_GetPPQPosFromProjQN: *fn (take: *MediaItem_Take, projqn: f64) callconv(.C) f64 = undefined;

    /// MIDI_GetPPQPosFromProjTime
    /// Returns the MIDI tick (ppq) position corresponding to a specific project time in seconds.
    pub var MIDI_GetPPQPosFromProjTime: *fn (take: *MediaItem_Take, projtime: f64) callconv(.C) f64 = undefined;

    /// MIDI_GetProjQNFromPPQPos
    /// Returns the project time in quarter notes corresponding to a specific MIDI tick (ppq) position.
    pub var MIDI_GetProjQNFromPPQPos: *fn (take: *MediaItem_Take, ppqpos: f64) callconv(.C) f64 = undefined;

    /// MIDI_GetProjTimeFromPPQPos
    /// Returns the project time in seconds corresponding to a specific MIDI tick (ppq) position.
    pub var MIDI_GetProjTimeFromPPQPos: *fn (take: *MediaItem_Take, ppqpos: f64) callconv(.C) f64 = undefined;

    /// MIDI_GetRecentInputEvent
    /// Gets a recent MIDI input event from the global history. idx=0 for the most recent event, which also latches to the latest MIDI event state (to get a more recent list, calling with idx=0 is necessary). idx=1 next most recent event, returns a non-zero sequence number for the event, or zero if no more events. tsOut will be set to the timestamp in samples relative to the current position (0 is current, -48000 is one second ago, etc). devIdxOut will have the low 16 bits set to the input device index, and 0x10000 will be set if device was enabled only for control. projPosOut will be set to project position in seconds if project was playing back at time of event, otherwise -1. Large SysEx events will not be included in this event list.
    pub var MIDI_GetRecentInputEvent: *fn (idx: c_int, bufOut: *c_char, bufOut_sz: *c_int, tsOut: *c_int, devIdxOut: *c_int, projPosOut: *f64, projLoopCntOut: *c_int) callconv(.C) c_int = undefined;

    /// MIDI_GetScale
    /// Get the active scale in the media source, if any. root 0=C, 1=C#, etc. scale &0x1=root, &0x2=minor 2nd, &0x4=major 2nd, &0x8=minor 3rd, &0xF=fourth, etc.
    pub var MIDI_GetScale: *fn (take: *MediaItem_Take, rootOut: *c_int, scaleOut: *c_int, nameOut: *c_char, nameOut_sz: c_int) callconv(.C) bool = undefined;

    /// MIDI_GetTextSysexEvt
    /// Get MIDI meta-event properties. Allowable types are -1:sysex (msg should not include bounding F0..F7), 1-14:MIDI text event types, 15=REAPER notation event. For all other meta-messages, type is returned as -2 and msg returned as all zeroes. See MIDI_GetEvt.
    pub var MIDI_GetTextSysexEvt: *fn (take: *MediaItem_Take, textsyxevtidx: c_int, selectedOutOptional: *bool, mutedOutOptional: *bool, ppqposOutOptional: *f64, typeOutOptional: *c_int, msgOptional: *c_char, msgOptional_sz: *c_int) callconv(.C) bool = undefined;

    /// MIDI_GetTrackHash
    /// Get a string that only changes when the MIDI data changes. If notesonly==true, then the string changes only when the MIDI notes change. See MIDI_GetHash
    pub var MIDI_GetTrackHash: *fn (track: *MediaTrack, notesonly: bool, hashOut: *c_char, hashOut_sz: c_int) callconv(.C) bool = undefined;

    /// midi_init
    /// Opens MIDI devices as configured in preferences. force_reinit_input and force_reinit_output force a particular device index to close/re-open (pass -1 to not force any devices to reopen).
    pub var midi_init: *fn (force_reinit_input: c_int, force_reinit_output: c_int) callconv(.C) void = undefined;

    /// MIDI_InsertCC
    /// Insert a new MIDI CC event.
    pub var MIDI_InsertCC: *fn (take: *MediaItem_Take, selected: bool, muted: bool, ppqpos: f64, chanmsg: c_int, chan: c_int, msg2: c_int, msg3: c_int) callconv(.C) bool = undefined;

    /// MIDI_InsertEvt
    /// Insert a new MIDI event.
    pub var MIDI_InsertEvt: *fn (take: *MediaItem_Take, selected: bool, muted: bool, ppqpos: f64, bytestr: [*:0]const u8, bytestr_sz: c_int) callconv(.C) bool = undefined;

    /// MIDI_InsertNote
    /// Insert a new MIDI note. Set noSort if inserting multiple events, then call MIDI_Sort when done.
    pub var MIDI_InsertNote: *fn (take: *MediaItem_Take, selected: bool, muted: bool, startppqpos: f64, endppqpos: f64, chan: c_int, pitch: c_int, vel: c_int, noSortInOptional: *const bool) callconv(.C) bool = undefined;

    /// MIDI_InsertTextSysexEvt
    /// Insert a new MIDI text or sysex event. Allowable types are -1:sysex (msg should not include bounding F0..F7), 1-14:MIDI text event types, 15=REAPER notation event.
    pub var MIDI_InsertTextSysexEvt: *fn (take: *MediaItem_Take, selected: bool, muted: bool, ppqpos: f64, type: c_int, bytestr: [*:0]const u8, bytestr_sz: c_int) callconv(.C) bool = undefined;

    /// midi_reinit
    /// Reset (close and re-open) all MIDI devices
    pub var midi_reinit: *fn () callconv(.C) void = undefined;

    /// MIDI_SelectAll
    /// Select or deselect all MIDI content.
    pub var MIDI_SelectAll: *fn (take: *MediaItem_Take, select: bool) callconv(.C) void = undefined;

    /// MIDI_SetAllEvts
    /// Set all MIDI data. MIDI buffer is passed in as a list of { c_int offset, c_char flag, c_int msglen, unsigned c_char msg[] }.
    /// offset: MIDI ticks from previous event
    /// flag: &1=selected &2=muted
    /// flag high 4 bits for CC shape: &16=linear, &32=slow start/end, &16|32=fast start, &64=fast end, &64|16=bezier
    /// msg: the MIDI message.
    /// A meta-event of type 0xF followed by 'CCBZ ' and 5 more bytes represents bezier curve data for the previous MIDI event: 1 byte for the bezier type (usually 0) and 4 bytes for the bezier tension as a f32.
    /// For tick intervals longer than a 32 bit word can represent, zero-length meta events may be placed between valid events.
    /// See MIDI_GetAllEvts.
    pub var MIDI_SetAllEvts: *fn (take: *MediaItem_Take, buf: [*:0]const u8, buf_sz: c_int) callconv(.C) bool = undefined;

    /// MIDI_SetCC
    /// Set MIDI CC event properties. Properties passed as NULL will not be set. set noSort if setting multiple events, then call MIDI_Sort when done.
    pub var MIDI_SetCC: *fn (take: *MediaItem_Take, ccidx: c_int, selectedInOptional: *const bool, mutedInOptional: *const bool, ppqposInOptional: *const f64, chanmsgInOptional: *const c_int, chanInOptional: *const c_int, msg2InOptional: *const c_int, msg3InOptional: *const c_int, noSortInOptional: *const bool) callconv(.C) bool = undefined;

    /// MIDI_SetCCShape
    /// Set CC shape and bezier tension. set noSort if setting multiple events, then call MIDI_Sort when done. See MIDI_SetCC, MIDI_GetCCShape
    pub var MIDI_SetCCShape: *fn (take: *MediaItem_Take, ccidx: c_int, shape: c_int, beztension: f64, noSortInOptional: *const bool) callconv(.C) bool = undefined;

    /// MIDI_SetEvt
    /// Set MIDI event properties. Properties passed as NULL will not be set.  set noSort if setting multiple events, then call MIDI_Sort when done.
    pub var MIDI_SetEvt: *fn (take: *MediaItem_Take, evtidx: c_int, selectedInOptional: *const bool, mutedInOptional: *const bool, ppqposInOptional: *const f64, msgOptional: [*:0]const u8, msgOptional_sz: c_int, noSortInOptional: *const bool) callconv(.C) bool = undefined;

    /// MIDI_SetItemExtents
    /// Set the start/end positions of a media item that contains a MIDI take.
    pub var MIDI_SetItemExtents: *fn (item: *MediaItem, startQN: f64, endQN: f64) callconv(.C) bool = undefined;

    /// MIDI_SetNote
    /// Set MIDI note properties. Properties passed as NULL (or negative values) will not be set. Set noSort if setting multiple events, then call MIDI_Sort when done. Setting multiple note start positions at once is done more safely by deleting and re-inserting the notes.
    pub var MIDI_SetNote: *fn (take: *MediaItem_Take, noteidx: c_int, selectedInOptional: *const bool, mutedInOptional: *const bool, startppqposInOptional: *const f64, endppqposInOptional: *const f64, chanInOptional: *const c_int, pitchInOptional: *const c_int, velInOptional: *const c_int, noSortInOptional: *const bool) callconv(.C) bool = undefined;

    /// MIDI_SetTextSysexEvt
    /// Set MIDI text or sysex event properties. Properties passed as NULL will not be set. Allowable types are -1:sysex (msg should not include bounding F0..F7), 1-14:MIDI text event types, 15=REAPER notation event. set noSort if setting multiple events, then call MIDI_Sort when done.
    pub var MIDI_SetTextSysexEvt: *fn (take: *MediaItem_Take, textsyxevtidx: c_int, selectedInOptional: *const bool, mutedInOptional: *const bool, ppqposInOptional: *const f64, typeInOptional: *const c_int, msgOptional: [*:0]const u8, msgOptional_sz: c_int, noSortInOptional: *const bool) callconv(.C) bool = undefined;

    /// MIDI_Sort
    /// Sort MIDI events after multiple calls to MIDI_SetNote, MIDI_SetCC, etc.
    pub var MIDI_Sort: *fn (take: *MediaItem_Take) callconv(.C) void = undefined;

    /// MIDIEditor_EnumTakes
    /// list the takes that are currently being edited in this MIDI editor, starting with the active take. See MIDIEditor_GetTake
    pub var MIDIEditor_EnumTakes: *fn (midieditor: HWND, takeindex: c_int, editable_only: bool) callconv(.C) *MediaItem_Take = undefined;

    /// MIDIEditor_GetActive
    /// get a pointer to the focused MIDI editor window
    /// see MIDIEditor_GetMode, MIDIEditor_OnCommand
    pub var MIDIEditor_GetActive: *fn () callconv(.C) HWND = undefined;

    /// MIDIEditor_GetMode
    /// get the mode of a MIDI editor (0=piano roll, 1=event list, -1=invalid editor)
    /// see MIDIEditor_GetActive, MIDIEditor_OnCommand
    pub var MIDIEditor_GetMode: *fn (midieditor: HWND) callconv(.C) c_int = undefined;

    /// MIDIEditor_GetSetting_int
    /// Get settings from a MIDI editor. setting_desc can be:
    /// snap_enabled: returns 0 or 1
    /// active_note_row: returns 0-127
    /// last_clicked_cc_lane: returns 0-127=CC, 0x100|(0-31)=14-bit CC, 0x200=velocity, 0x201=pitch, 0x202=program, 0x203=channel pressure, 0x204=bank/program select, 0x205=text, 0x206=sysex, 0x207=off velocity, 0x208=notation events, 0x210=media item lane
    /// default_note_vel: returns 0-127
    /// default_note_chan: returns 0-15
    /// default_note_len: returns default length in MIDI ticks
    /// scale_enabled: returns 0-1
    /// scale_root: returns 0-12 (0=C)
    /// list_cnt: if viewing list view, returns event count
    /// if setting_desc is unsupported, the function returns -1.
    /// See MIDIEditor_SetSetting_int, MIDIEditor_GetActive, MIDIEditor_GetSetting_str
    ///
    pub var MIDIEditor_GetSetting_int: *fn (midieditor: HWND, setting_desc: [*:0]const u8) callconv(.C) c_int = undefined;

    /// MIDIEditor_GetSetting_str
    /// Get settings from a MIDI editor. setting_desc can be:
    /// last_clicked_cc_lane: returns text description ("velocity", "pitch", etc)
    /// scale: returns the scale record, for example "102034050607" for a major scale
    /// list_X: if viewing list view, returns string describing event at row X (0-based). String will have a list of key=value pairs, e.g. 'pos=4.0 len=4.0 offvel=127 msg=90317F'. pos/len times are in QN, len/offvel may not be present if event is not a note. other keys which may be present include pos_pq/len_pq, sel, mute, ccval14, ccshape, ccbeztension.
    /// if setting_desc is unsupported, the function returns false.
    /// See MIDIEditor_GetActive, MIDIEditor_GetSetting_int
    ///
    pub var MIDIEditor_GetSetting_str: *fn (midieditor: HWND, setting_desc: [*:0]const u8, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// MIDIEditor_GetTake
    /// get the take that is currently being edited in this MIDI editor. see MIDIEditor_EnumTakes
    pub var MIDIEditor_GetTake: *fn (midieditor: HWND) callconv(.C) *MediaItem_Take = undefined;

    /// MIDIEditor_LastFocused_OnCommand
    /// Send an action command to the last focused MIDI editor. Returns false if there is no MIDI editor open, or if the view mode (piano roll or event list) does not match the input.
    /// see MIDIEditor_OnCommand
    pub var MIDIEditor_LastFocused_OnCommand: *fn (command_id: c_int, islistviewcommand: bool) callconv(.C) bool = undefined;

    /// MIDIEditor_OnCommand
    /// Send an action command to a MIDI editor. Returns false if the supplied MIDI editor pointer is not valid (not an open MIDI editor).
    /// see MIDIEditor_GetActive, MIDIEditor_LastFocused_OnCommand
    pub var MIDIEditor_OnCommand: *fn (midieditor: HWND, command_id: c_int) callconv(.C) bool = undefined;

    /// MIDIEditor_SetSetting_int
    /// Set settings for a MIDI editor. setting_desc can be:
    /// active_note_row: 0-127
    /// See MIDIEditor_GetSetting_int
    ///
    pub var MIDIEditor_SetSetting_int: *fn (midieditor: HWND, setting_desc: [*:0]const u8, setting: c_int) callconv(.C) bool = undefined;

    /// MIDIEditorFlagsForTrack
    /// Get or set MIDI editor settings for this track. pitchwheelrange: semitones up or down. flags &1: snap pitch lane edits to semitones if pitchwheel range is defined.
    pub var MIDIEditorFlagsForTrack: *fn (track: *MediaTrack, pitchwheelrangeInOut: *c_int, flagsInOut: *c_int, is_set: bool) callconv(.C) void = undefined;

    /// mkpanstr
    pub var mkpanstr: *fn (strNeed64: *c_char, pan: f64) callconv(.C) void = undefined;

    /// mkvolpanstr
    pub var mkvolpanstr: *fn (strNeed64: *c_char, vol: f64, pan: f64) callconv(.C) void = undefined;

    /// mkvolstr
    pub var mkvolstr: *fn (strNeed64: *c_char, vol: f64) callconv(.C) void = undefined;

    /// MoveEditCursor
    pub var MoveEditCursor: *fn (adjamt: f64, dosel: bool) callconv(.C) void = undefined;

    /// MoveMediaItemToTrack
    /// returns TRUE if move succeeded
    pub var MoveMediaItemToTrack: *fn (item: *MediaItem, desttr: *MediaTrack) callconv(.C) bool = undefined;

    /// MuteAllTracks
    pub var MuteAllTracks: *fn (mute: bool) callconv(.C) void = undefined;

    /// my_getViewport
    pub var my_getViewport: *fn (r: *RECT, sr: *const RECT, wantWorkArea: bool) callconv(.C) void = undefined;

    /// NamedCommandLookup
    /// Get the command ID number for named command that was registered by an extension such as "_SWS_ABOUT" or "_113088d11ae641c193a2b7ede3041ad5" for a ReaScript or a custom action.
    pub var NamedCommandLookup: *fn (command_name: [*:0]const u8) callconv(.C) c_int = undefined;

    /// OnPauseButton
    /// direct way to simulate pause button hit
    pub var OnPauseButton: *fn () callconv(.C) void = undefined;

    /// OnPauseButtonEx
    /// direct way to simulate pause button hit
    pub var OnPauseButtonEx: *fn (proj: *ReaProject) callconv(.C) void = undefined;

    /// OnPlayButton
    /// direct way to simulate play button hit
    pub var OnPlayButton: *fn () callconv(.C) void = undefined;

    /// OnPlayButtonEx
    /// direct way to simulate play button hit
    pub var OnPlayButtonEx: *fn (proj: *ReaProject) callconv(.C) void = undefined;

    /// OnStopButton
    /// direct way to simulate stop button hit
    pub var OnStopButton: *fn () callconv(.C) void = undefined;

    /// OnStopButtonEx
    /// direct way to simulate stop button hit
    pub var OnStopButtonEx: *fn (proj: *ReaProject) callconv(.C) void = undefined;

    /// OpenColorThemeFile
    pub var OpenColorThemeFile: *fn (fn_: [*:0]const u8) callconv(.C) bool = undefined;

    /// OpenMediaExplorer
    /// Opens mediafn in the Media Explorer, play=true will play the file immediately (or toggle playback if mediafn was already open), =false will just select it.
    pub var OpenMediaExplorer: *fn (mediafn: [*:0]const u8, play: bool) callconv(.C) HWND = undefined;

    /// OscLocalMessageToHost
    /// Send an OSC message directly to REAPER. The value argument may be NULL. The message will be matched against the default OSC patterns.
    pub var OscLocalMessageToHost: *fn (message: [*:0]const u8, valueInOptional: *const f64) callconv(.C) void = undefined;

    /// parse_timestr
    /// Parse hh:mm:ss.sss time string, return time in seconds (or 0.0 on error). See parse_timestr_pos, parse_timestr_len.
    pub var parse_timestr: *fn (buf: [*:0]const u8) callconv(.C) f64 = undefined;

    /// parse_timestr_len
    /// time formatting mode overrides: -1=proj default.
    /// 0=time
    /// 1=measures.beats + time
    /// 2=measures.beats
    /// 3=seconds
    /// 4=samples
    /// 5=h:m:s:f
    ///
    pub var parse_timestr_len: *fn (buf: [*:0]const u8, offset: f64, modeoverride: c_int) callconv(.C) f64 = undefined;

    /// parse_timestr_pos
    /// Parse time string, time formatting mode overrides: -1=proj default.
    /// 0=time
    /// 1=measures.beats + time
    /// 2=measures.beats
    /// 3=seconds
    /// 4=samples
    /// 5=h:m:s:f
    ///
    pub var parse_timestr_pos: *fn (buf: [*:0]const u8, modeoverride: c_int) callconv(.C) f64 = undefined;

    /// parsepanstr
    pub var parsepanstr: *fn (str: [*:0]const u8) callconv(.C) f64 = undefined;

    /// PCM_Sink_Create
    pub var PCM_Sink_Create: *fn (filename: [*:0]const u8, cfg: [*:0]const u8, cfg_sz: c_int, nch: c_int, srate: c_int, buildpeaks: bool) callconv(.C) *PCM_sink = undefined;

    /// PCM_Sink_CreateEx
    pub var PCM_Sink_CreateEx: *fn (proj: *ReaProject, filename: [*:0]const u8, cfg: [*:0]const u8, cfg_sz: c_int, nch: c_int, srate: c_int, buildpeaks: bool) callconv(.C) *PCM_sink = undefined;

    /// PCM_Sink_CreateMIDIFile
    pub var PCM_Sink_CreateMIDIFile: *fn (filename: [*:0]const u8, cfg: [*:0]const u8, cfg_sz: c_int, bpm: f64, div: c_int) callconv(.C) *PCM_sink = undefined;

    /// PCM_Sink_CreateMIDIFileEx
    pub var PCM_Sink_CreateMIDIFileEx: *fn (proj: *ReaProject, filename: [*:0]const u8, cfg: [*:0]const u8, cfg_sz: c_int, bpm: f64, div: c_int) callconv(.C) *PCM_sink = undefined;

    /// PCM_Sink_Enum
    pub var PCM_Sink_Enum: *fn (idx: c_int, descstrOut: [*:0]const u8) callconv(.C) c_uint = undefined;

    /// PCM_Sink_GetExtension
    pub var PCM_Sink_GetExtension: *fn (data: [*:0]const u8, data_sz: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// PCM_Sink_ShowConfig
    pub var PCM_Sink_ShowConfig: *fn (cfg: [*:0]const u8, cfg_sz: c_int, hwndParent: HWND) callconv(.C) HWND = undefined;

    /// PCM_Source_BuildPeaks
    /// Calls and returns PCM_source::PeaksBuild_Begin() if mode=0, PeaksBuild_Run() if mode=1, and PeaksBuild_Finish() if mode=2. Normal use is to call PCM_Source_BuildPeaks(src,0), and if that returns nonzero, call PCM_Source_BuildPeaks(src,1) periodically until it returns zero (it returns the percentage of the file remaining), then call PCM_Source_BuildPeaks(src,2) to finalize. If PCM_Source_BuildPeaks(src,0) returns zero, then no further action is necessary.
    pub var PCM_Source_BuildPeaks: *fn (src: *PCM_source, mode: c_int) callconv(.C) c_int = undefined;

    /// PCM_Source_CreateFromFile
    /// See PCM_Source_CreateFromFileEx.
    pub var PCM_Source_CreateFromFile: *fn (filename: [*:0]const u8) callconv(.C) *PCM_source = undefined;

    /// PCM_Source_CreateFromFileEx
    /// Create a PCM_source from filename, and override pref of MIDI files being imported as in-project MIDI events.
    pub var PCM_Source_CreateFromFileEx: *fn (filename: [*:0]const u8, forcenoMidiImp: bool) callconv(.C) *PCM_source = undefined;

    /// PCM_Source_CreateFromSimple
    /// Creates a PCM_source from a ISimpleMediaDecoder
    /// (if fn is non-null, it will open the file in dec)
    pub var PCM_Source_CreateFromSimple: *fn (dec: *ISimpleMediaDecoder, fn_: [*:0]const u8) callconv(.C) *PCM_source = undefined;

    /// PCM_Source_CreateFromType
    /// Create a PCM_source from a "type" (use this if you're going to load its state via LoadState/ProjectStateContext).
    /// Valid types include "WAVE", "MIDI", or whatever plug-ins define as well.
    pub var PCM_Source_CreateFromType: *fn (sourcetype: [*:0]const u8) callconv(.C) *PCM_source = undefined;

    /// PCM_Source_Destroy
    /// Deletes a PCM_source -- be sure that you remove any project reference before deleting a source
    pub var PCM_Source_Destroy: *fn (src: *PCM_source) callconv(.C) void = undefined;

    /// PCM_Source_GetPeaks
    /// Gets block of peak samples to buf. Note that the peak samples are interleaved, but in two or three blocks (maximums, then minimums, then extra). Return value has 20 bits of returned sample count, then 4 bits of output_mode (0xf00000), then a bit to signify whether extra_type was available (0x1000000). extra_type can be 115 ('s') for spectral information, which will return peak samples as integers with the low 15 bits frequency, next 14 bits tonality.
    pub var PCM_Source_GetPeaks: *fn (src: *PCM_source, peakrate: f64, starttime: f64, numchannels: c_int, numsamplesperchannel: c_int, want_extra_type: c_int, buf: *f64) callconv(.C) c_int = undefined;

    /// PCM_Source_GetSectionInfo
    /// If a section/reverse block, retrieves offset/len/reverse. return true if success
    pub var PCM_Source_GetSectionInfo: *fn (src: *PCM_source, offsOut: *f64, lenOut: *f64, revOut: *bool) callconv(.C) bool = undefined;

    /// PeakBuild_Create
    pub var PeakBuild_Create: *fn (src: *PCM_source, fn_: [*:0]const u8, srate: c_int, nch: c_int) callconv(.C) *REAPER_PeakBuild_Interface = undefined;

    /// PeakBuild_CreateEx
    /// flags&1 for FP support
    pub var PeakBuild_CreateEx: *fn (src: *PCM_source, fn_: [*:0]const u8, srate: c_int, nch: c_int, flags: c_int) callconv(.C) *REAPER_PeakBuild_Interface = undefined;

    /// PeakGet_Create
    pub var PeakGet_Create: *fn (fn_: [*:0]const u8, srate: c_int, nch: c_int) callconv(.C) *REAPER_PeakGet_Interface = undefined;

    /// PitchShiftSubModeMenu
    /// menu to select/modify pitch shifter submode, returns new value (or old value if no item selected)
    pub var PitchShiftSubModeMenu: *fn (hwnd: HWND, x: c_int, y: c_int, mode: c_int, submode_sel: c_int) callconv(.C) c_int = undefined;

    /// PlayPreview
    /// return nonzero on success
    pub var PlayPreview: *fn (preview: *preview_register_t) callconv(.C) c_int = undefined;

    /// PlayPreviewEx
    /// return nonzero on success. bufflags &1=buffer source, &2=treat length changes in source as varispeed and adjust internal state accordingly if buffering. measure_align<0=play immediately, >0=align playback with measure start
    pub var PlayPreviewEx: *fn (preview: *preview_register_t, bufflags: c_int, measure_align: f64) callconv(.C) c_int = undefined;

    /// PlayTrackPreview
    /// return nonzero on success,in these,m_out_chan is a track index (0-n)
    pub var PlayTrackPreview: *fn (preview: *preview_register_t) callconv(.C) c_int = undefined;

    /// PlayTrackPreview2
    /// return nonzero on success,in these,m_out_chan is a track index (0-n)
    pub var PlayTrackPreview2: *fn (proj: *ReaProject, preview: *preview_register_t) callconv(.C) c_int = undefined;

    /// PlayTrackPreview2Ex
    /// return nonzero on success,in these,m_out_chan is a track index (0-n). see PlayPreviewEx
    pub var PlayTrackPreview2Ex: *fn (proj: *ReaProject, preview: *preview_register_t, flags: c_int, measure_align: f64) callconv(.C) c_int = undefined;

    /// plugin_getapi
    // pub var plugin_getapi: *fn (name: [*:0]const u8) callconv(.C) *void = undefined;

    /// plugin_getFilterList
    /// Returns a f64-NULL terminated list of importable media files, suitable for passing to GetOpenFileName() etc. Includes *.* (All files).
    pub var plugin_getFilterList: *fn () callconv(.C) [*:0]const u8 = undefined;

    /// plugin_getImportableProjectFilterList
    /// Returns a f64-NULL terminated list of importable project files, suitable for passing to GetOpenFileName() etc. Includes *.* (All files).
    pub var plugin_getImportableProjectFilterList: *fn () callconv(.C) [*:0]const u8 = undefined;

    /// plugin_register
    /// Alias for reaper_plugin_info_t::Register, see reaper_plugin.h for documented uses.
    // pub var plugin_register: *fn (name: [*:0]const u8, infostruct: *void) callconv(.C) c_int = undefined;

    /// PluginWantsAlwaysRunFx
    pub var PluginWantsAlwaysRunFx: *fn (amt: c_int) callconv(.C) void = undefined;

    /// PreventUIRefresh
    /// adds prevent_count to the UI refresh prevention state; always add then remove the same amount, or major disfunction will occur
    pub var PreventUIRefresh: *fn (prevent_count: c_int) callconv(.C) void = undefined;

    /// projectconfig_var_addr
    pub var projectconfig_var_addr: *fn (proj: *ReaProject, idx: c_int) callconv(.C) *void = undefined;

    /// projectconfig_var_getoffs
    /// returns offset to pass to projectconfig_var_addr() to get project-config var of name. szout gets size of object. can also query "__metronome_ptr" query project metronome *PCM_source* offset
    pub var projectconfig_var_getoffs: *fn (name: [*:0]const u8, szOut: *c_int) callconv(.C) c_int = undefined;

    /// PromptForAction
    /// Uses the action list to choose an action. Call with session_mode=1 to create a session (init_id will be the initial action to select, or 0), then poll with session_mode=0, checking return value for user-selected action (will return 0 if no action selected yet, or -1 if the action window is no longer available). When finished, call with session_mode=-1.
    pub var PromptForAction: *fn (session_mode: c_int, init_id: c_int, section_id: c_int) callconv(.C) c_int = undefined;

    /// realloc_cmd_clear
    /// clears a buffer/buffer-size registration added with realloc_cmd_register_buf, and clears any later registrations, frees any allocated buffers. call after values are read from any registered pointers etc.
    pub var realloc_cmd_clear: *fn (tok: c_int) callconv(.C) void = undefined;

    /// realloc_cmd_ptr
    /// special use for NeedBig script API functions - reallocates a NeedBig buffer and updates its size, returns false on error
    pub var realloc_cmd_ptr: *fn (ptr: *c_char, ptr_size: *c_int, new_size: c_int) callconv(.C) bool = undefined;

    /// realloc_cmd_register_buf
    /// registers a buffer/buffer-size which may be reallocated by an API (ptr/ptr_size will be updated to the new values). returns a token which should be passed to realloc_cmd_clear after API call and values are read.
    pub var realloc_cmd_register_buf: *fn (ptr: *c_char, ptr_size: *c_int) callconv(.C) c_int = undefined;

    /// ReaperGetPitchShiftAPI
    /// version must be REAPER_PITCHSHIFT_API_VER
    pub var ReaperGetPitchShiftAPI: *fn (version: c_int) callconv(.C) *IReaperPitchShift = undefined;

    /// ReaScriptError
    /// Causes REAPER to display the error message after the current ReaScript finishes. If called within a Lua context and errmsg has a ! prefix, script execution will be terminated.
    pub var ReaScriptError: *fn (errmsg: [*:0]const u8) callconv(.C) void = undefined;

    /// RecursiveCreateDirectory
    /// returns positive value on success, 0 on failure.
    pub var RecursiveCreateDirectory: *fn (path: [*:0]const u8, ignored: size_t) callconv(.C) c_int = undefined;

    /// reduce_open_files
    /// garbage-collects extra open files and closes them. if flags has 1 set, this is done incrementally (call this from a regular timer, if desired). if flags has 2 set, files are aggressively closed (they may need to be re-opened very soon). returns number of files closed by this call.
    pub var reduce_open_files: *fn (flags: c_int) callconv(.C) c_int = undefined;

    /// RefreshToolbar
    /// See RefreshToolbar2.
    pub var RefreshToolbar: *fn (command_id: c_int) callconv(.C) void = undefined;

    /// RefreshToolbar2
    /// Refresh the toolbar button states of a toggle action.
    pub var RefreshToolbar2: *fn (section_id: c_int, command_id: c_int) callconv(.C) void = undefined;

    /// relative_fn
    /// Makes a filename "in" relative to the current project, if any.
    pub var relative_fn: *fn (in: [*:0]const u8, out: *c_char, out_sz: c_int) callconv(.C) void = undefined;

    /// RemoveTrackSend
    /// Remove a send/receive/hardware output, return true on success. category is <0 for receives, 0=sends, >0 for hardware outputs. See CreateTrackSend, GetSetTrackSendInfo, GetTrackSendInfo_Value, SetTrackSendInfo_Value, GetTrackNumSends.
    pub var RemoveTrackSend: *fn (tr: *MediaTrack, category: c_int, sendidx: c_int) callconv(.C) bool = undefined;

    /// RenderFileSection
    /// Not available while playing back.
    pub var RenderFileSection: *fn (source_filename: [*:0]const u8, target_filename: [*:0]const u8, start_percent: f64, end_percent: f64, playrate: f64) callconv(.C) bool = undefined;

    /// ReorderSelectedTracks
    /// Moves all selected tracks to immediately above track specified by index beforeTrackIdx, returns false if no tracks were selected. makePrevFolder=0 for normal, 1 = as child of track preceding track specified by beforeTrackIdx, 2 = if track preceding track specified by beforeTrackIdx is last track in folder, extend folder
    pub var ReorderSelectedTracks: *fn (beforeTrackIdx: c_int, makePrevFolder: c_int) callconv(.C) bool = undefined;

    /// Resample_EnumModes
    pub var Resample_EnumModes: *fn (mode: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// Resampler_Create
    pub var Resampler_Create: *fn () callconv(.C) *REAPER_Resample_Interface = undefined;

    /// resolve_fn
    /// See resolve_fn2.
    pub var resolve_fn: *fn (in: [*:0]const u8, out: *c_char, out_sz: c_int) callconv(.C) void = undefined;

    /// resolve_fn2
    /// Resolves a filename "in" by using project settings etc. If no file found, out will be a copy of in.
    pub var resolve_fn2: *fn (in: [*:0]const u8, out: *c_char, out_sz: c_int, checkSubDirOptional: [*:0]const u8) callconv(.C) void = undefined;

    /// ResolveRenderPattern
    /// Resolve a wildcard pattern into a set of nul-separated, f64-nul terminated render target filenames. Returns the length of the string buffer needed for the returned file list. Call with path=NULL to suppress filtering out illegal pathnames, call with targets=NULL to get just the string buffer length.
    pub var ResolveRenderPattern: *fn (project: *ReaProject, path: [*:0]const u8, pattern: [*:0]const u8, targets: *c_char, targets_sz: c_int) callconv(.C) c_int = undefined;

    /// ReverseNamedCommandLookup
    /// Get the named command for the given command ID. The returned string will not start with '_' (e.g. it will return "SWS_ABOUT"), it will be NULL if command_id is a native action.
    pub var ReverseNamedCommandLookup: *fn (command_id: c_int) callconv(.C) [*:0]const u8 = undefined;

    /// ScaleFromEnvelopeMode
    /// See GetEnvelopeScalingMode.
    pub var ScaleFromEnvelopeMode: *fn (scaling_mode: c_int, val: f64) callconv(.C) f64 = undefined;

    /// ScaleToEnvelopeMode
    /// See GetEnvelopeScalingMode.
    pub var ScaleToEnvelopeMode: *fn (scaling_mode: c_int, val: f64) callconv(.C) f64 = undefined;

    /// screenset_register
    pub var screenset_register: *fn (id: *c_char, callbackFunc: *void, param: *void) callconv(.C) void = undefined;

    /// screenset_registerNew
    pub var screenset_registerNew: *fn (id: *c_char, callbackFunc: screensetNewCallbackFunc, param: *void) callconv(.C) void = undefined;

    /// screenset_unregister
    pub var screenset_unregister: *fn (id: *c_char) callconv(.C) void = undefined;

    /// screenset_unregisterByParam
    pub var screenset_unregisterByParam: *fn (param: *void) callconv(.C) void = undefined;

    /// screenset_updateLastFocus
    pub var screenset_updateLastFocus: *fn (prevWin: HWND) callconv(.C) void = undefined;

    /// SectionFromUniqueID
    pub var SectionFromUniqueID: *fn (uniqueID: c_int) callconv(.C) *KbdSectionInfo = undefined;

    /// SelectAllMediaItems
    pub var SelectAllMediaItems: *fn (proj: *ReaProject, selected: bool) callconv(.C) void = undefined;

    /// SelectProjectInstance
    pub var SelectProjectInstance: *fn (proj: *ReaProject) callconv(.C) void = undefined;

    /// SendLocalOscMessage
    /// Send an OSC message to REAPER. See CreateLocalOscHandler, DestroyLocalOscHandler.
    pub var SendLocalOscMessage: *fn (local_osc_handler: *void, msg: [*:0]const u8, msglen: c_int) callconv(.C) void = undefined;

    /// SendMIDIMessageToHardware
    /// Sends a MIDI message to output device specified by output. Message is sent in immediate mode. Lua example of how to pack the message string:
    /// sysex = { 0xF0, 0x00, 0xF7 }
    /// msg = ""
    /// for i=1, #sysex do msg = msg .. string.c_char(sysex[i]) end
    pub var SendMIDIMessageToHardware: *fn (output: c_int, msg: [*:0]const u8, msg_sz: c_int) callconv(.C) void = undefined;

    /// SetActiveTake
    /// set this take active in this media item
    pub var SetActiveTake: *fn (take: *MediaItem_Take) callconv(.C) void = undefined;

    /// SetAutomationMode
    /// sets all or selected tracks to mode.
    pub var SetAutomationMode: *fn (mode: c_int, onlySel: bool) callconv(.C) void = undefined;

    /// SetCurrentBPM
    /// set current BPM in project, set wantUndo=true to add undo point
    pub var SetCurrentBPM: *fn (__proj: *ReaProject, bpm: f64, wantUndo: bool) callconv(.C) void = undefined;

    /// SetCursorContext
    /// You must use this to change the focus programmatically. mode=0 to focus track panels, 1 to focus the arrange window, 2 to focus the arrange window and select env (or env==NULL to clear the current track/take envelope selection)
    pub var SetCursorContext: *fn (mode: c_int, envInOptional: *TrackEnvelope) callconv(.C) void = undefined;

    /// SetEditCurPos
    pub var SetEditCurPos: *fn (time: f64, moveview: bool, seekplay: bool) callconv(.C) void = undefined;

    /// SetEditCurPos2
    pub var SetEditCurPos2: *fn (proj: *ReaProject, time: f64, moveview: bool, seekplay: bool) callconv(.C) void = undefined;

    /// SetEnvelopePoint
    /// Set attributes of an envelope point. Values that are not supplied will be ignored. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done. See SetEnvelopePointEx.
    pub var SetEnvelopePoint: *fn (envelope: *TrackEnvelope, ptidx: c_int, timeInOptional: *f64, valueInOptional: *f64, shapeInOptional: *c_int, tensionInOptional: *f64, selectedInOptional: *bool, noSortInOptional: *bool) callconv(.C) bool = undefined;

    /// SetEnvelopePointEx
    /// Set attributes of an envelope point. Values that are not supplied will be ignored. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done.
    /// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
    /// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
    /// even if the automation item is trimmed so that not all points are visible.
    /// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
    /// See CountEnvelopePointsEx, GetEnvelopePointEx, InsertEnvelopePointEx, DeleteEnvelopePointEx.
    pub var SetEnvelopePointEx: *fn (envelope: *TrackEnvelope, autoitem_idx: c_int, ptidx: c_int, timeInOptional: *f64, valueInOptional: *f64, shapeInOptional: *c_int, tensionInOptional: *f64, selectedInOptional: *bool, noSortInOptional: *bool) callconv(.C) bool = undefined;

    /// SetEnvelopeStateChunk
    /// Sets the RPPXML state of an envelope, returns true if successful. Undo flag is a performance/caching hint.
    pub var SetEnvelopeStateChunk: *fn (env: *TrackEnvelope, str: [*:0]const u8, isundoOptional: bool) callconv(.C) bool = undefined;

    /// SetExtState
    /// Set the extended state value for a specific section and key. persist=true means the value should be stored and reloaded the next time REAPER is opened. See GetExtState, DeleteExtState, HasExtState.
    pub var SetExtState: *fn (section: [*:0]const u8, key: [*:0]const u8, value: [*:0]const u8, persist: bool) callconv(.C) void = undefined;

    /// SetGlobalAutomationOverride
    /// mode: see GetGlobalAutomationOverride
    pub var SetGlobalAutomationOverride: *fn (mode: c_int) callconv(.C) void = undefined;

    /// SetItemStateChunk
    /// Sets the RPPXML state of an item, returns true if successful. Undo flag is a performance/caching hint.
    pub var SetItemStateChunk: *fn (item: *MediaItem, str: [*:0]const u8, isundoOptional: bool) callconv(.C) bool = undefined;

    /// SetMasterTrackVisibility
    /// set &1 to show the master track in the TCP, &2 to HIDE in the mixer. Returns the previous visibility state. See GetMasterTrackVisibility.
    pub var SetMasterTrackVisibility: *fn (flag: c_int) callconv(.C) c_int = undefined;

    /// SetMediaItemInfo_Value
    /// Set media item numerical-value attributes.
    /// B_MUTE : bool * : muted (item solo overrides). setting this value will clear C_MUTE_SOLO.
    /// B_MUTE_ACTUAL : bool * : muted (ignores solo). setting this value will not affect C_MUTE_SOLO.
    /// C_LANEPLAYS : c_char * : in fixed lane tracks, 0=this item lane does not play, 1=this item lane plays exclusively, 2=this item lane plays and other lanes also play, -1=this item is on a non-visible, non-playing lane on a non-fixed-lane track (read-only)
    /// C_MUTE_SOLO : c_char * : solo override (-1=soloed, 0=no override, 1=unsoloed). note that this API does not automatically unsolo other items when soloing (nor clear the unsolos when clearing the last soloed item), it must be done by the caller via action or via this API.
    /// B_LOOPSRC : bool * : loop source
    /// B_ALLTAKESPLAY : bool * : all takes play
    /// B_UISEL : bool * : selected in arrange view
    /// C_BEATATTACHMODE : c_char * : item timebase, -1=track or project default, 1=beats (position, length, rate), 2=beats (position only). for auto-stretch timebase: C_BEATATTACHMODE=1, C_AUTOSTRETCH=1
    /// C_AUTOSTRETCH: : c_char * : auto-stretch at project tempo changes, 1=enabled, requires C_BEATATTACHMODE=1
    /// C_LOCK : c_char * : locked, &1=locked
    /// D_VOL : f64 * : item volume,  0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
    /// D_POSITION : f64 * : item position in seconds
    /// D_LENGTH : f64 * : item length in seconds
    /// D_SNAPOFFSET : f64 * : item snap offset in seconds
    /// D_FADEINLEN : f64 * : item manual fadein length in seconds
    /// D_FADEOUTLEN : f64 * : item manual fadeout length in seconds
    /// D_FADEINDIR : f64 * : item fadein curvature, -1..1
    /// D_FADEOUTDIR : f64 * : item fadeout curvature, -1..1
    /// D_FADEINLEN_AUTO : f64 * : item auto-fadein length in seconds, -1=no auto-fadein
    /// D_FADEOUTLEN_AUTO : f64 * : item auto-fadeout length in seconds, -1=no auto-fadeout
    /// C_FADEINSHAPE : c_int * : fadein shape, 0..6, 0=linear
    /// C_FADEOUTSHAPE : c_int * : fadeout shape, 0..6, 0=linear
    /// I_GROUPID : c_int * : group ID, 0=no group
    /// I_LASTY : c_int * : Y-position (relative to top of track) in pixels (read-only)
    /// I_LASTH : c_int * : height in pixels (read-only)
    /// I_CUSTOMCOLOR : c_int * : custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
    /// I_CURTAKE : c_int * : active take number
    /// IP_ITEMNUMBER : c_int : item number on this track (read-only, returns the item number directly)
    /// F_FREEMODE_Y : f32 * : free item positioning or fixed lane Y-position. 0=top of track, 1.0=bottom of track
    /// F_FREEMODE_H : f32 * : free item positioning or fixed lane height. 0.5=half the track height, 1.0=full track height
    /// I_FIXEDLANE : c_int * : fixed lane of item (fine to call with setNewValue, but returned value is read-only)
    /// B_FIXEDLANE_HIDDEN : bool * : true if displaying only one fixed lane and this item is in a different lane (read-only)
    ///
    pub var SetMediaItemInfo_Value: *fn (item: *MediaItem, parmname: [*:0]const u8, newvalue: f64) callconv(.C) bool = undefined;

    /// SetMediaItemLength
    /// Redraws the screen only if refreshUI == true.
    /// See UpdateArrange().
    pub var SetMediaItemLength: *fn (item: *MediaItem, length: f64, refreshUI: bool) callconv(.C) bool = undefined;

    /// SetMediaItemPosition
    /// Redraws the screen only if refreshUI == true.
    /// See UpdateArrange().
    pub var SetMediaItemPosition: *fn (item: *MediaItem, position: f64, refreshUI: bool) callconv(.C) bool = undefined;

    /// SetMediaItemSelected
    pub var SetMediaItemSelected: *fn (item: *MediaItem, selected: bool) callconv(.C) void = undefined;

    /// SetMediaItemTake_Source
    /// Set media source of media item take. The old source will not be destroyed, it is the caller's responsibility to retrieve it and destroy it after. If source already exists in any project, it will be duplicated before being set. C/C++ code should not use this and instead use GetSetMediaItemTakeInfo() with P_SOURCE to manage ownership directly.
    pub var SetMediaItemTake_Source: *fn (take: *MediaItem_Take, source: *PCM_source) callconv(.C) bool = undefined;

    /// SetMediaItemTakeInfo_Value
    /// Set media item take numerical-value attributes.
    /// D_STARTOFFS : f64 * : start offset in source media, in seconds
    /// D_VOL : f64 * : take volume, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc, negative if take polarity is flipped
    /// D_PAN : f64 * : take pan, -1..1
    /// D_PANLAW : f64 * : take pan law, -1=default, 0.5=-6dB, 1.0=+0dB, etc
    /// D_PLAYRATE : f64 * : take playback rate, 0.5=half speed, 1=normal, 2=f64 speed, etc
    /// D_PITCH : f64 * : take pitch adjustment in semitones, -12=one octave down, 0=normal, +12=one octave up, etc
    /// B_PPITCH : bool * : preserve pitch when changing playback rate
    /// I_LASTY : c_int * : Y-position (relative to top of track) in pixels (read-only)
    /// I_LASTH : c_int * : height in pixels (read-only)
    /// I_CHANMODE : c_int * : channel mode, 0=normal, 1=reverse stereo, 2=downmix, 3=left, 4=right
    /// I_PITCHMODE : c_int * : pitch shifter mode, -1=project default, otherwise high 2 bytes=shifter, low 2 bytes=parameter
    /// I_STRETCHFLAGS : c_int * : stretch marker flags (&7 mask for mode override: 0=default, 1=balanced, 2/3/6=tonal, 4=transient, 5=no pre-echo)
    /// F_STRETCHFADESIZE : f32 * : stretch marker fade size in seconds (0.0025 default)
    /// I_RECPASSID : c_int * : record pass ID
    /// I_TAKEFX_NCH : c_int * : number of internal audio channels for per-take FX to use (OK to call with setNewValue, but the returned value is read-only)
    /// I_CUSTOMCOLOR : c_int * : custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
    /// IP_TAKENUMBER : c_int : take number (read-only, returns the take number directly)
    ///
    pub var SetMediaItemTakeInfo_Value: *fn (take: *MediaItem_Take, parmname: [*:0]const u8, newvalue: f64) callconv(.C) bool = undefined;

    /// SetMediaTrackInfo_Value
    /// Set track numerical-value attributes.
    /// B_MUTE : bool * : muted
    /// B_PHASE : bool * : track phase inverted
    /// B_RECMON_IN_EFFECT : bool * : record monitoring in effect (current audio-thread playback state, read-only)
    /// IP_TRACKNUMBER : c_int : track number 1-based, 0=not found, -1=master track (read-only, returns the c_int directly)
    /// I_SOLO : c_int * : soloed, 0=not soloed, 1=soloed, 2=soloed in place, 5=safe soloed, 6=safe soloed in place
    /// B_SOLO_DEFEAT : bool * : when set, if anything else is soloed and this track is not muted, this track acts soloed
    /// I_FXEN : c_int * : fx enabled, 0=bypassed, !0=fx active
    /// I_RECARM : c_int * : record armed, 0=not record armed, 1=record armed
    /// I_RECINPUT : c_int * : record input, <0=no input. if 4096 set, input is MIDI and low 5 bits represent channel (0=all, 1-16=only chan), next 6 bits represent physical input (63=all, 62=VKB). If 4096 is not set, low 10 bits (0..1023) are input start channel (ReaRoute/Loopback start at 512). If 2048 is set, input is multichannel input (using track channel count), or if 1024 is set, input is stereo input, otherwise input is mono.
    /// I_RECMODE : c_int * : record mode, 0=input, 1=stereo out, 2=none, 3=stereo out w/latency compensation, 4=midi output, 5=mono out, 6=mono out w/ latency compensation, 7=midi overdub, 8=midi replace
    /// I_RECMODE_FLAGS : c_int * : record mode flags, &3=output recording mode (0=post fader, 1=pre-fx, 2=post-fx/pre-fader)
    /// I_RECMON : c_int * : record monitoring, 0=off, 1=normal, 2=not when playing (tape style)
    /// I_RECMONITEMS : c_int * : monitor items while recording, 0=off, 1=on
    /// B_AUTO_RECARM : bool * : automatically set record arm when selected (does not immediately affect recarm state, script should set directly if desired)
    /// I_VUMODE : c_int * : track vu mode, &1:disabled, &30==0:stereo peaks, &30==2:multichannel peaks, &30==4:stereo RMS, &30==8:combined RMS, &30==12:LUFS-M, &30==16:LUFS-S (readout=max), &30==20:LUFS-S (readout=current), &32:LUFS calculation on channels 1+2 only
    /// I_AUTOMODE : c_int * : track automation mode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
    /// I_NCHAN : c_int * : number of track channels, 2-128, even numbers only
    /// I_SELECTED : c_int * : track selected, 0=unselected, 1=selected
    /// I_WNDH : c_int * : current TCP window height in pixels including envelopes (read-only)
    /// I_TCPH : c_int * : current TCP window height in pixels not including envelopes (read-only)
    /// I_TCPY : c_int * : current TCP window Y-position in pixels relative to top of arrange view (read-only)
    /// I_MCPX : c_int * : current MCP X-position in pixels relative to mixer container (read-only)
    /// I_MCPY : c_int * : current MCP Y-position in pixels relative to mixer container (read-only)
    /// I_MCPW : c_int * : current MCP width in pixels (read-only)
    /// I_MCPH : c_int * : current MCP height in pixels (read-only)
    /// I_FOLDERDEPTH : c_int * : folder depth change, 0=normal, 1=track is a folder parent, -1=track is the last in the innermost folder, -2=track is the last in the innermost and next-innermost folders, etc
    /// I_FOLDERCOMPACT : c_int * : folder collapsed state (only valid on folders), 0=normal, 1=collapsed, 2=fully collapsed
    /// I_MIDIHWOUT : c_int * : track midi hardware output index, <0=disabled, low 5 bits are which channels (0=all, 1-16), next 5 bits are output device index (0-31)
    /// I_MIDI_INPUT_CHANMAP : c_int * : -1 maps to source channel, otherwise 1-16 to map to MIDI channel
    /// I_MIDI_CTL_CHAN : c_int * : -1 no link, 0-15 link to MIDI volume/pan on channel, 16 link to MIDI volume/pan on all channels
    /// I_MIDI_TRACKSEL_FLAG : c_int * : MIDI editor track list options: &1=expand media items, &2=exclude from list, &4=auto-pruned
    /// I_PERFFLAGS : c_int * : track performance flags, &1=no media buffering, &2=no anticipative FX
    /// I_CUSTOMCOLOR : c_int * : custom color, OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). If you do not |0x1000000, then it will not be used, but will store the color
    /// I_HEIGHTOVERRIDE : c_int * : custom height override for TCP window, 0 for none, otherwise size in pixels
    /// I_SPACER : c_int * : 1=TCP track spacer above this trackB_HEIGHTLOCK : bool * : track height lock (must set I_HEIGHTOVERRIDE before locking)
    /// D_VOL : f64 * : trim volume of track, 0=-inf, 0.5=-6dB, 1=+0dB, 2=+6dB, etc
    /// D_PAN : f64 * : trim pan of track, -1..1
    /// D_WIDTH : f64 * : width of track, -1..1
    /// D_DUALPANL : f64 * : dualpan position 1, -1..1, only if I_PANMODE==6
    /// D_DUALPANR : f64 * : dualpan position 2, -1..1, only if I_PANMODE==6
    /// I_PANMODE : c_int * : pan mode, 0=classic 3.x, 3=new balance, 5=stereo pan, 6=dual pan
    /// D_PANLAW : f64 * : pan law of track, <0=project default, 0.5=-6dB, 0.707..=-3dB, 1=+0dB, 1.414..=-3dB with gain compensation, 2=-6dB with gain compensation, etc
    /// I_PANLAW_FLAGS : c_int * : pan law flags, 0=sine taper, 1=hybrid taper with deprecated behavior when gain compensation enabled, 2=linear taper, 3=hybrid taper
    /// P_ENV:<envchunkname or P_ENV:GUID... : TrackEnvelope * : (read-only) chunkname can be <VOLENV, <PANENV, etc; GUID is the stringified envelope GUID.
    /// B_SHOWINMIXER : bool * : track control panel visible in mixer (do not use on master track)
    /// B_SHOWINTCP : bool * : track control panel visible in arrange view (do not use on master track)
    /// B_MAINSEND : bool * : track sends audio to parent
    /// C_MAINSEND_OFFS : c_char * : channel offset of track send to parent
    /// C_MAINSEND_NCH : c_char * : channel count of track send to parent (0=use all child track channels, 1=use one channel only)
    /// I_FREEMODE : c_int * : 1=track free item positioning enabled, 2=track fixed lanes enabled (call UpdateTimeline() after changing)
    /// I_NUMFIXEDLANES : c_int * : number of track fixed lanes (fine to call with setNewValue, but returned value is read-only)
    /// C_LANESCOLLAPSED : c_char * : fixed lane collapse state (1=lanes collapsed, 2=track displays as non-fixed-lanes but hidden lanes exist)
    /// C_LANESETTINGS : c_char * : fixed lane settings (&1=auto-remove empty lanes at bottom, &2=do not auto-comp new recording, &4=newly recorded lanes play exclusively (else add lanes in layers), &8=big lanes (else small lanes), &16=add new recording at bottom (else record into first available lane), &32=hide lane buttons
    /// C_LANEPLAYS:N : c_char * :  on fixed lane tracks, 0=lane N does not play, 1=lane N plays exclusively, 2=lane N plays and other lanes also play (fine to call with setNewValue, but returned value is read-only)
    /// C_ALLLANESPLAY : c_char * : on fixed lane tracks, 0=no lanes play, 1=all lanes play, 2=some lanes play (fine to call with setNewValue 0 or 1, but returned value is read-only)
    /// C_BEATATTACHMODE : c_char * : track timebase, -1=project default, 0=time, 1=beats (position, length, rate), 2=beats (position only)
    /// F_MCP_FXSEND_SCALE : f32 * : scale of fx+send area in MCP (0=minimum allowed, 1=maximum allowed)
    /// F_MCP_FXPARM_SCALE : f32 * : scale of fx parameter area in MCP (0=minimum allowed, 1=maximum allowed)
    /// F_MCP_SENDRGN_SCALE : f32 * : scale of send area as proportion of the fx+send total area (0=minimum allowed, 1=maximum allowed)
    /// F_TCP_FXPARM_SCALE : f32 * : scale of TCP parameter area when TCP FX are embedded (0=min allowed, default, 1=max allowed)
    /// I_PLAY_OFFSET_FLAG : c_int * : track media playback offset state, &1=bypassed, &2=offset value is measured in samples (otherwise measured in seconds)
    /// D_PLAY_OFFSET : f64 * : track media playback offset, units depend on I_PLAY_OFFSET_FLAG
    ///
    pub var SetMediaTrackInfo_Value: *fn (tr: MediaTrack, parmname: [*:0]const u8, newvalue: f64) callconv(.C) bool = undefined;

    /// SetMIDIEditorGrid
    /// Set the MIDI editor grid division. 0.25=quarter note, 1.0/3.0=half note tripet, etc.
    pub var SetMIDIEditorGrid: *fn (project: *ReaProject, division: f64) callconv(.C) void = undefined;

    /// SetMixerScroll
    /// Scroll the mixer so that leftmosttrack is the leftmost visible track. Returns the leftmost track after scrolling, which may be different from the passed-in track if there are not enough tracks to its right.
    pub var SetMixerScroll: *fn (leftmosttrack: *MediaTrack) callconv(.C) *MediaTrack = undefined;

    /// SetMouseModifier
    /// Set the mouse modifier assignment for a specific modifier key assignment, in a specific context.
    /// Context is a string like "MM_CTX_ITEM" (see reaper-mouse.ini) or "Media item left drag" (unlocalized).
    /// Modifier flag is a number from 0 to 15: add 1 for shift, 2 for control, 4 for alt, 8 for win.
    /// (macOS: add 1 for shift, 2 for command, 4 for opt, 8 for control.)
    /// For left-click and f64-click contexts, the action can be any built-in command ID number
    /// or any custom action ID string. Find built-in command IDs in the REAPER actions window
    /// (enable "show command IDs" in the context menu), and find custom action ID strings in reaper-kb.ini.
    /// The action string may be a mouse modifier ID (see reaper-mouse.ini) with " m" appended to it,
    /// or (for click/f64-click contexts) a command ID with " c" appended to it,
    /// or the text that appears in the mouse modifiers preferences dialog, like "Move item" (unlocalized).
    /// For example, SetMouseModifier("MM_CTX_ITEM", 0, "1 m") and SetMouseModifier("Media item left drag", 0, "Move item") are equivalent.
    /// SetMouseModifier(context, modifier_flag, -1) will reset that mouse modifier to default.
    /// SetMouseModifier(context, -1, -1) will reset the entire context to default.
    /// SetMouseModifier(-1, -1, -1) will reset all contexts to default.
    /// See GetMouseModifier.
    ///
    pub var SetMouseModifier: *fn (context: [*:0]const u8, modifier_flag: c_int, action: [*:0]const u8) callconv(.C) void = undefined;

    /// SetOnlyTrackSelected
    /// Set exactly one track selected, deselect all others
    pub var SetOnlyTrackSelected: *fn (track: *MediaTrack) callconv(.C) void = undefined;

    /// SetProjectGrid
    /// Set the arrange view grid division. 0.25=quarter note, 1.0/3.0=half note triplet, etc.
    pub var SetProjectGrid: *fn (project: *ReaProject, division: f64) callconv(.C) void = undefined;

    /// SetProjectMarker
    /// Note: this function can't clear a marker's name (an empty string will leave the name unchanged), see SetProjectMarker4.
    pub var SetProjectMarker: *fn (markrgnindexnumber: c_int, isrgn: bool, pos: f64, rgnend: f64, name: [*:0]const u8) callconv(.C) bool = undefined;

    /// SetProjectMarker2
    /// Note: this function can't clear a marker's name (an empty string will leave the name unchanged), see SetProjectMarker4.
    pub var SetProjectMarker2: *fn (proj: *ReaProject, markrgnindexnumber: c_int, isrgn: bool, pos: f64, rgnend: f64, name: [*:0]const u8) callconv(.C) bool = undefined;

    /// SetProjectMarker3
    /// Note: this function can't clear a marker's name (an empty string will leave the name unchanged), see SetProjectMarker4.
    pub var SetProjectMarker3: *fn (proj: *ReaProject, markrgnindexnumber: c_int, isrgn: bool, pos: f64, rgnend: f64, name: [*:0]const u8, color: c_int) callconv(.C) bool = undefined;

    /// SetProjectMarker4
    /// color should be 0 to not change, or ColorToNative(r,g,b)|0x1000000, flags&1 to clear name
    pub var SetProjectMarker4: *fn (proj: *ReaProject, markrgnindexnumber: c_int, isrgn: bool, pos: f64, rgnend: f64, name: [*:0]const u8, color: c_int, flags: c_int) callconv(.C) bool = undefined;

    /// SetProjectMarkerByIndex
    /// See SetProjectMarkerByIndex2.
    pub var SetProjectMarkerByIndex: *fn (proj: *ReaProject, markrgnidx: c_int, isrgn: bool, pos: f64, rgnend: f64, IDnumber: c_int, name: [*:0]const u8, color: c_int) callconv(.C) bool = undefined;

    /// SetProjectMarkerByIndex2
    /// Differs from SetProjectMarker4 in that markrgnidx is 0 for the first marker/region, 1 for the next, etc (see EnumProjectMarkers3), rather than representing the displayed marker/region ID number (see SetProjectMarker3). Function will fail if attempting to set a duplicate ID number for a region (duplicate ID numbers for markers are OK). , flags&1 to clear name. If flags&2, markers will not be re-sorted, and after making updates, you MUST call SetProjectMarkerByIndex2 with markrgnidx=-1 and flags&2 to force re-sort/UI updates.
    pub var SetProjectMarkerByIndex2: *fn (proj: *ReaProject, markrgnidx: c_int, isrgn: bool, pos: f64, rgnend: f64, IDnumber: c_int, name: [*:0]const u8, color: c_int, flags: c_int) callconv(.C) bool = undefined;

    /// SetProjExtState
    /// Save a key/value pair for a specific extension, to be restored the next time this specific project is loaded. Typically extname will be the name of a reascript or extension section. If key is NULL or "", all extended data for that extname will be deleted.  If val is NULL or "", the data previously associated with that key will be deleted. Returns the size of the state for this extname. See GetProjExtState, EnumProjExtState.
    pub var SetProjExtState: *fn (proj: *ReaProject, extname: [*:0]const u8, key: [*:0]const u8, value: [*:0]const u8) callconv(.C) c_int = undefined;

    /// SetRegionRenderMatrix
    /// Add (flag > 0) or remove (flag < 0) a track from this region when using the region render matrix. If adding, flag==2 means force mono, flag==4 means force stereo, flag==N means force N/2 channels.
    pub var SetRegionRenderMatrix: *fn (proj: *ReaProject, regionindex: c_int, track: *MediaTrack, flag: c_int) callconv(.C) void = undefined;

    /// SetRenderLastError
    /// Used by pcmsink objects to set an error to display while creating the pcmsink object.
    pub var SetRenderLastError: *fn (errorstr: [*:0]const u8) callconv(.C) void = undefined;

    /// SetTakeMarker
    /// Inserts or updates a take marker. If idx<0, a take marker will be added, otherwise an existing take marker will be updated. Returns the index of the new or updated take marker (which may change if srcPos is updated). See GetNumTakeMarkers, GetTakeMarker, DeleteTakeMarker
    pub var SetTakeMarker: *fn (take: *MediaItem_Take, idx: c_int, nameIn: [*:0]const u8, srcposInOptional: *f64, colorInOptional: *c_int) callconv(.C) c_int = undefined;

    /// SetTakeStretchMarker
    /// Adds or updates a stretch marker. If idx<0, stretch marker will be added. If idx>=0, stretch marker will be updated. When adding, if srcposInOptional is omitted, source position will be auto-calculated. When updating a stretch marker, if srcposInOptional is omitted, srcpos will not be modified. Position/srcposition values will be constrained to nearby stretch markers. Returns index of stretch marker, or -1 if did not insert (or marker already existed at time).
    pub var SetTakeStretchMarker: *fn (take: *MediaItem_Take, idx: c_int, pos: f64, srcposInOptional: *const f64) callconv(.C) c_int = undefined;

    /// SetTakeStretchMarkerSlope
    /// See GetTakeStretchMarkerSlope
    pub var SetTakeStretchMarkerSlope: *fn (take: *MediaItem_Take, idx: c_int, slope: f64) callconv(.C) bool = undefined;

    /// SetTempoTimeSigMarker
    /// Set parameters of a tempo/time signature marker. Provide either timepos (with measurepos=-1, beatpos=-1), or measurepos and beatpos (with timepos=-1). If timesig_num and timesig_denom are zero, the previous time signature will be used. ptidx=-1 will insert a new tempo/time signature marker. See CountTempoTimeSigMarkers, GetTempoTimeSigMarker, AddTempoTimeSigMarker.
    pub var SetTempoTimeSigMarker: *fn (proj: *ReaProject, ptidx: c_int, timepos: f64, measurepos: c_int, beatpos: f64, bpm: f64, timesig_num: c_int, timesig_denom: c_int, lineartempo: bool) callconv(.C) bool = undefined;

    /// SetThemeColor
    /// Temporarily updates the theme color to the color specified (or the theme default color if -1 is specified). Returns -1 on failure, otherwise returns the color (or transformed-color). Note that the UI is not updated by this, the caller should call UpdateArrange() etc as necessary. If the low bit of flags is set, any color transformations are bypassed. To read a value see GetThemeColor.
    pub var SetThemeColor: *fn (ini_key: [*:0]const u8, color: c_int, flagsOptional: c_int) callconv(.C) c_int = undefined;

    /// SetToggleCommandState
    /// Updates the toggle state of an action, returns true if succeeded. Only ReaScripts can have their toggle states changed programmatically. See RefreshToolbar2.
    pub var SetToggleCommandState: *fn (section_id: c_int, command_id: c_int, state: c_int) callconv(.C) bool = undefined;

    /// SetTrackAutomationMode
    pub var SetTrackAutomationMode: *fn (tr: *MediaTrack, mode: c_int) callconv(.C) void = undefined;

    /// SetTrackColor
    /// Set the custom track color, color is OS dependent (i.e. ColorToNative(r,g,b). To unset the track color, see SetMediaTrackInfo_Value I_CUSTOMCOLOR
    pub var SetTrackColor: *fn (track: *MediaTrack, color: c_int) callconv(.C) void = undefined;

    /// SetTrackMIDILyrics
    /// Set all MIDI lyrics on the track. Lyrics will be stuffed into any MIDI items found in range. Flag is unused at present. str is passed in as beat position, tab, text, tab (example with flag=2: "1.1.2\tLyric for measure 1 beat 2\t2.1.1\tLyric for measure 2 beat 1	"). See GetTrackMIDILyrics
    pub var SetTrackMIDILyrics: *fn (track: *MediaTrack, flag: c_int, str: [*:0]const u8) callconv(.C) bool = undefined;

    /// SetTrackMIDINoteName
    /// channel < 0 assigns these note names to all channels.
    pub var SetTrackMIDINoteName: *fn (track: c_int, pitch: c_int, chan: c_int, name: [*:0]const u8) callconv(.C) bool = undefined;

    /// SetTrackMIDINoteNameEx
    /// channel < 0 assigns note name to all channels. pitch 128 assigns name for CC0, pitch 129 for CC1, etc.
    pub var SetTrackMIDINoteNameEx: *fn (proj: *ReaProject, track: *MediaTrack, pitch: c_int, chan: c_int, name: [*:0]const u8) callconv(.C) bool = undefined;

    /// SetTrackSelected
    pub var SetTrackSelected: *fn (track: *MediaTrack, selected: bool) callconv(.C) void = undefined;

    /// SetTrackSendInfo_Value
    /// Set send/receive/hardware output numerical-value attributes, return true on success.
    /// category is <0 for receives, 0=sends, >0 for hardware outputs
    /// parameter names:
    /// B_MUTE : bool *
    /// B_PHASE : bool * : true to flip phase
    /// B_MONO : bool *
    /// D_VOL : f64 * : 1.0 = +0dB etc
    /// D_PAN : f64 * : -1..+1
    /// D_PANLAW : f64 * : 1.0=+0.0db, 0.5=-6dB, -1.0 = projdef etc
    /// I_SENDMODE : c_int * : 0=post-fader, 1=pre-fx, 2=post-fx (deprecated), 3=post-fx
    /// I_AUTOMODE : c_int * : automation mode (-1=use track automode, 0=trim/off, 1=read, 2=touch, 3=write, 4=latch)
    /// I_SRCCHAN : c_int * : -1 for no audio send. Low 10 bits specify channel offset, and higher bits specify channel count. (srcchan>>10) == 0 for stereo, 1 for mono, 2 for 4 channel, 3 for 6 channel, etc.
    /// I_DSTCHAN : c_int * : low 10 bits are destination index, &1024 set to mix to mono.
    /// I_MIDIFLAGS : c_int * : low 5 bits=source channel 0=all, 1-16, 31=MIDI send disabled, next 5 bits=dest channel, 0=orig, 1-16=chan. &1024 for faders-send MIDI vol/pan. (>>14)&255 = src bus (0 for all, 1 for normal, 2+). (>>22)&255=destination bus (0 for all, 1 for normal, 2+)
    /// See CreateTrackSend, RemoveTrackSend, GetTrackNumSends.
    pub var SetTrackSendInfo_Value: *fn (tr: *MediaTrack, category: c_int, sendidx: c_int, parmname: [*:0]const u8, newvalue: f64) callconv(.C) bool = undefined;

    /// SetTrackSendUIPan
    /// send_idx<0 for receives, >=0 for hw ouputs, >=nb_of_hw_ouputs for sends. isend=1 for end of edit, -1 for an instant edit (such as reset), 0 for normal tweak.
    pub var SetTrackSendUIPan: *fn (track: *MediaTrack, send_idx: c_int, pan: f64, isend: c_int) callconv(.C) bool = undefined;

    /// SetTrackSendUIVol
    /// send_idx<0 for receives, >=0 for hw ouputs, >=nb_of_hw_ouputs for sends. isend=1 for end of edit, -1 for an instant edit (such as reset), 0 for normal tweak.
    pub var SetTrackSendUIVol: *fn (track: *MediaTrack, send_idx: c_int, vol: f64, isend: c_int) callconv(.C) bool = undefined;

    /// SetTrackStateChunk
    /// Sets the RPPXML state of a track, returns true if successful. Undo flag is a performance/caching hint.
    pub var SetTrackStateChunk: *fn (track: *MediaTrack, str: [*:0]const u8, isundoOptional: bool) callconv(.C) bool = undefined;

    /// SetTrackUIInputMonitor
    /// monitor: 0=no monitoring, 1=monitoring, 2=auto-monitoring. returns new value or -1 if error. igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
    pub var SetTrackUIInputMonitor: *fn (track: *MediaTrack, monitor: c_int, igngroupflags: c_int) callconv(.C) c_int = undefined;

    /// SetTrackUIMute
    /// mute: <0 toggles, >0 sets mute, 0=unsets mute. returns new value or -1 if error. igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
    pub var SetTrackUIMute: *fn (track: *MediaTrack, mute: c_int, igngroupflags: c_int) callconv(.C) c_int = undefined;

    /// SetTrackUIPan
    /// igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
    pub var SetTrackUIPan: *fn (track: *MediaTrack, pan: f64, relative: bool, done: bool, igngroupflags: c_int) callconv(.C) f64 = undefined;

    /// SetTrackUIPolarity
    /// polarity (AKA phase): <0 toggles, 0=normal, >0=inverted. returns new value or -1 if error.igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
    pub var SetTrackUIPolarity: *fn (track: *MediaTrack, polarity: c_int, igngroupflags: c_int) callconv(.C) c_int = undefined;

    /// SetTrackUIRecArm
    /// recarm: <0 toggles, >0 sets recarm, 0=unsets recarm. returns new value or -1 if error. igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
    pub var SetTrackUIRecArm: *fn (track: *MediaTrack, recarm: c_int, igngroupflags: c_int) callconv(.C) c_int = undefined;

    /// SetTrackUISolo
    /// solo: <0 toggles, 1 sets solo (default mode), 0=unsets solo, 2 sets solo (non-SIP), 4 sets solo (SIP). returns new value or -1 if error. igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
    pub var SetTrackUISolo: *fn (track: *MediaTrack, solo: c_int, igngroupflags: c_int) callconv(.C) c_int = undefined;

    /// SetTrackUIVolume
    /// igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
    pub var SetTrackUIVolume: *fn (track: *MediaTrack, volume: f64, relative: bool, done: bool, igngroupflags: c_int) callconv(.C) f64 = undefined;

    /// SetTrackUIWidth
    /// igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
    pub var SetTrackUIWidth: *fn (track: *MediaTrack, width: f64, relative: bool, done: bool, igngroupflags: c_int) callconv(.C) f64 = undefined;

    /// ShowActionList
    pub var ShowActionList: *fn (section: *KbdSectionInfo, callerWnd: HWND) callconv(.C) void = undefined;

    /// ShowConsoleMsg
    /// Show a message to the user (also useful for debugging). Send "\n" for newline, "" to clear the console. Prefix string with "!SHOW:" and text will be added to console without opening the window. See ClearConsole
    pub var ShowConsoleMsg: *fn (msg: [*:0]const u8) callconv(.C) void = undefined;

    /// ShowMessageBox
    /// type 0=OK,1=OKCANCEL,2=ABORTRETRYIGNORE,3=YESNOCANCEL,4=YESNO,5=RETRYCANCEL : ret 1=OK,2=CANCEL,3=ABORT,4=RETRY,5=IGNORE,6=YES,7=NO
    pub var ShowMessageBox: *fn (msg: [*:0]const u8, title: [*:0]const u8, type: c_int) callconv(.C) c_int = undefined;

    /// ShowPopupMenu
    /// shows a context menu, valid names include: track_input, track_panel, track_area, track_routing, item, ruler, envelope, envelope_point, envelope_item. ctxOptional can be a track pointer for *track_, item pointer for *item (but is optional). for envelope_point, ctx2Optional has point index, ctx3Optional has item index (0=main envelope, 1=first AI). for envelope_item, ctx2Optional has AI index (1=first AI)
    pub var ShowPopupMenu: *fn (name: [*:0]const u8, x: c_int, y: c_int, hwndParentOptional: HWND, ctxOptional: *void, ctx2Optional: c_int, ctx3Optional: c_int) callconv(.C) void = undefined;

    /// SLIDER2DB
    pub var SLIDER2DB: *fn (y: f64) callconv(.C) f64 = undefined;

    /// SnapToGrid
    pub var SnapToGrid: *fn (project: *ReaProject, time_pos: f64) callconv(.C) f64 = undefined;

    /// SoloAllTracks
    /// solo=2 for SIP
    pub var SoloAllTracks: *fn (solo: c_int) callconv(.C) void = undefined;

    /// Splash_GetWnd
    /// gets the splash window, in case you want to display a message over it. Returns NULL when the splash window is not displayed.
    pub var Splash_GetWnd: *fn () callconv(.C) HWND = undefined;

    /// SplitMediaItem
    /// the original item becomes the left-hand split, the function returns the right-hand split (or NULL if the split failed)
    pub var SplitMediaItem: *fn (item: *MediaItem, position: f64) callconv(.C) *MediaItem = undefined;

    /// StopPreview
    /// return nonzero on success
    pub var StopPreview: *fn (preview: *preview_register_t) callconv(.C) c_int = undefined;

    /// StopTrackPreview
    /// return nonzero on success
    pub var StopTrackPreview: *fn (preview: *preview_register_t) callconv(.C) c_int = undefined;

    /// StopTrackPreview2
    /// return nonzero on success
    pub var StopTrackPreview2: *fn (proj: *ReaProject, preview: *preview_register_t) callconv(.C) c_int = undefined;

    /// stringToGuid
    pub var stringToGuid: *fn (str: [*:0]const u8, g: *GUID) callconv(.C) void = undefined;

    /// StuffMIDIMessage
    /// Stuffs a 3 byte MIDI message into either the Virtual MIDI Keyboard queue, or the MIDI-as-control input queue, or sends to a MIDI hardware output. mode=0 for VKB, 1 for control (actions map etc), 2 for VKB-on-current-channel; 16 for external MIDI device 0, 17 for external MIDI device 1, etc; see GetNumMIDIOutputs, GetMIDIOutputName.
    pub var StuffMIDIMessage: *fn (mode: c_int, msg1: c_int, msg2: c_int, msg3: c_int) callconv(.C) void = undefined;

    /// TakeFX_AddByName
    /// Adds or queries the position of a named FX in a take. See TrackFX_AddByName() for information on fxname and instantiate. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_AddByName: *fn (take: *MediaItem_Take, fxname: [*:0]const u8, instantiate: c_int) callconv(.C) c_int = undefined;

    /// TakeFX_CopyToTake
    /// Copies (or moves) FX from src_take to dest_take. Can be used with src_take=dest_take to reorder. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_CopyToTake: *fn (src_take: *MediaItem_Take, src_fx: c_int, dest_take: *MediaItem_Take, dest_fx: c_int, is_move: bool) callconv(.C) void = undefined;

    /// TakeFX_CopyToTrack
    /// Copies (or moves) FX from src_take to dest_track. dest_fx can have 0x1000000 set to reference input FX. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_CopyToTrack: *fn (src_take: *MediaItem_Take, src_fx: c_int, dest_track: *MediaTrack, dest_fx: c_int, is_move: bool) callconv(.C) void = undefined;

    /// TakeFX_Delete
    /// Remove a FX from take chain (returns true on success) FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_Delete: *fn (take: *MediaItem_Take, fx: c_int) callconv(.C) bool = undefined;

    /// TakeFX_EndParamEdit
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_EndParamEdit: *fn (take: *MediaItem_Take, fx: c_int, param: c_int) callconv(.C) bool = undefined;

    /// TakeFX_FormatParamValue
    /// Note: only works with FX that support Cockos VST extensions. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_FormatParamValue: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, val: f64, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TakeFX_FormatParamValueNormalized
    /// Note: only works with FX that support Cockos VST extensions. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_FormatParamValueNormalized: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, value: f64, buf: *c_char, buf_sz: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetChainVisible
    /// returns index of effect visible in chain, or -1 for chain hidden, or -2 for chain visible but no effect selected
    pub var TakeFX_GetChainVisible: *fn (take: *MediaItem_Take) callconv(.C) c_int = undefined;

    /// TakeFX_GetCount
    pub var TakeFX_GetCount: *fn (take: *MediaItem_Take) callconv(.C) c_int = undefined;

    /// TakeFX_GetEnabled
    /// See TakeFX_SetEnabled FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetEnabled: *fn (take: *MediaItem_Take, fx: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetEnvelope
    /// Returns the FX parameter envelope. If the envelope does not exist and create=true, the envelope will be created. If the envelope already exists and is bypassed and create=true, then the envelope will be unbypassed. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetEnvelope: *fn (take: *MediaItem_Take, fxindex: c_int, parameterindex: c_int, create: bool) callconv(.C) *TrackEnvelope = undefined;

    /// TakeFX_GetFloatingWindow
    /// returns HWND of f32ing window for effect index, if any FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetFloatingWindow: *fn (take: *MediaItem_Take, index: c_int) callconv(.C) HWND = undefined;

    /// TakeFX_GetFormattedParamValue
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetFormattedParamValue: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetFXGUID
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetFXGUID: *fn (take: *MediaItem_Take, fx: c_int) callconv(.C) *GUID = undefined;

    /// TakeFX_GetFXName
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetFXName: *fn (take: *MediaItem_Take, fx: c_int, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetIOSize
    /// Gets the number of input/output pins for FX if available, returns plug-in type or -1 on error FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetIOSize: *fn (take: *MediaItem_Take, fx: c_int, inputPinsOut: *c_int, outputPinsOut: *c_int) callconv(.C) c_int = undefined;

    /// TakeFX_GetNamedConfigParm
    /// gets plug-in specific named configuration value (returns true on success). see TrackFX_GetNamedConfigParm FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetNamedConfigParm: *fn (take: *MediaItem_Take, fx: c_int, parmname: [*:0]const u8, bufOutNeedBig: *c_char, bufOutNeedBig_sz: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetNumParams
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetNumParams: *fn (take: *MediaItem_Take, fx: c_int) callconv(.C) c_int = undefined;

    /// TakeFX_GetOffline
    /// See TakeFX_SetOffline FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetOffline: *fn (take: *MediaItem_Take, fx: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetOpen
    /// Returns true if this FX UI is open in the FX chain window or a f32ing window. See TakeFX_SetOpen FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetOpen: *fn (take: *MediaItem_Take, fx: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetParam
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetParam: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, minvalOut: *f64, maxvalOut: *f64) callconv(.C) f64 = undefined;

    /// TakeFX_GetParameterStepSizes
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetParameterStepSizes: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, stepOut: *f64, smallstepOut: *f64, largestepOut: *f64, istoggleOut: *bool) callconv(.C) bool = undefined;

    /// TakeFX_GetParamEx
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetParamEx: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, minvalOut: *f64, maxvalOut: *f64, midvalOut: *f64) callconv(.C) f64 = undefined;

    /// TakeFX_GetParamFromIdent
    /// gets the parameter index from an identifying string (:wet, :bypass, or a string returned from GetParamIdent), or -1 if unknown. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetParamFromIdent: *fn (take: *MediaItem_Take, fx: c_int, ident_str: [*:0]const u8) callconv(.C) c_int = undefined;

    /// TakeFX_GetParamIdent
    /// gets an identifying string for the parameter FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetParamIdent: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetParamName
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetParamName: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetParamNormalized
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetParamNormalized: *fn (take: *MediaItem_Take, fx: c_int, param: c_int) callconv(.C) f64 = undefined;

    /// TakeFX_GetPinMappings
    /// gets the effective channel mapping bitmask for a particular pin. high32Out will be set to the high 32 bits. Add 0x1000000 to pin index in order to access the second 64 bits of mappings independent of the first 64 bits. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetPinMappings: *fn (take: *MediaItem_Take, fx: c_int, isoutput: c_int, pin: c_int, high32Out: *c_int) callconv(.C) c_int = undefined;

    /// TakeFX_GetPreset
    /// Get the name of the preset currently showing in the REAPER dropdown, or the full path to a factory preset file for VST3 plug-ins (.vstpreset). See TakeFX_SetPreset. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetPreset: *fn (take: *MediaItem_Take, fx: c_int, presetnameOut: *c_char, presetnameOut_sz: c_int) callconv(.C) bool = undefined;

    /// TakeFX_GetPresetIndex
    /// Returns current preset index, or -1 if error. numberOfPresetsOut will be set to total number of presets available. See TakeFX_SetPresetByIndex FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetPresetIndex: *fn (take: *MediaItem_Take, fx: c_int, numberOfPresetsOut: *c_int) callconv(.C) c_int = undefined;

    /// TakeFX_GetUserPresetFilename
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_GetUserPresetFilename: *fn (take: *MediaItem_Take, fx: c_int, fnOut: *c_char, fnOut_sz: c_int) callconv(.C) void = undefined;

    /// TakeFX_NavigatePresets
    /// presetmove==1 activates the next preset, presetmove==-1 activates the previous preset, etc. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_NavigatePresets: *fn (take: *MediaItem_Take, fx: c_int, presetmove: c_int) callconv(.C) bool = undefined;

    /// TakeFX_SetEnabled
    /// See TakeFX_GetEnabled FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_SetEnabled: *fn (take: *MediaItem_Take, fx: c_int, enabled: bool) callconv(.C) void = undefined;

    /// TakeFX_SetNamedConfigParm
    /// gets plug-in specific named configuration value (returns true on success). see TrackFX_SetNamedConfigParm FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_SetNamedConfigParm: *fn (take: *MediaItem_Take, fx: c_int, parmname: [*:0]const u8, value: [*:0]const u8) callconv(.C) bool = undefined;

    /// TakeFX_SetOffline
    /// See TakeFX_GetOffline FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_SetOffline: *fn (take: *MediaItem_Take, fx: c_int, offline: bool) callconv(.C) void = undefined;

    /// TakeFX_SetOpen
    /// Open this FX UI. See TakeFX_GetOpen FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_SetOpen: *fn (take: *MediaItem_Take, fx: c_int, open: bool) callconv(.C) void = undefined;

    /// TakeFX_SetParam
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_SetParam: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, val: f64) callconv(.C) bool = undefined;

    /// TakeFX_SetParamNormalized
    ///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_SetParamNormalized: *fn (take: *MediaItem_Take, fx: c_int, param: c_int, value: f64) callconv(.C) bool = undefined;

    /// TakeFX_SetPinMappings
    /// sets the channel mapping bitmask for a particular pin. returns false if unsupported (not all types of plug-ins support this capability). Add 0x1000000 to pin index in order to access the second 64 bits of mappings independent of the first 64 bits. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_SetPinMappings: *fn (take: *MediaItem_Take, fx: c_int, isoutput: c_int, pin: c_int, low32bits: c_int, hi32bits: c_int) callconv(.C) bool = undefined;

    /// TakeFX_SetPreset
    /// Activate a preset with the name shown in the REAPER dropdown. Full paths to .vstpreset files are also supported for VST3 plug-ins. See TakeFX_GetPreset. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_SetPreset: *fn (take: *MediaItem_Take, fx: c_int, presetname: [*:0]const u8) callconv(.C) bool = undefined;

    /// TakeFX_SetPresetByIndex
    /// Sets the preset idx, or the factory preset (idx==-2), or the default user preset (idx==-1). Returns true on success. See TakeFX_GetPresetIndex. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_SetPresetByIndex: *fn (take: *MediaItem_Take, fx: c_int, idx: c_int) callconv(.C) bool = undefined;

    /// TakeFX_Show
    /// showflag=0 for hidechain, =1 for show chain(index valid), =2 for hide f32ing window(index valid), =3 for show f32ing window (index valid) FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TakeFX_Show: *fn (take: *MediaItem_Take, index: c_int, showFlag: c_int) callconv(.C) void = undefined;

    /// TakeIsMIDI
    /// Returns true if the active take contains MIDI.
    pub var TakeIsMIDI: *fn (take: *MediaItem_Take) callconv(.C) bool = undefined;

    /// ThemeLayout_GetLayout
    /// Gets theme layout information. section can be 'global' for global layout override, 'seclist' to enumerate a list of layout sections, otherwise a layout section such as 'mcp', 'tcp', 'trans', etc. idx can be -1 to query the current value, -2 to get the description of the section (if not global), -3 will return the current context DPI-scaling (256=normal, 512=retina, etc), or 0..x. returns false if failed.
    pub var ThemeLayout_GetLayout: *fn (section: [*:0]const u8, idx: c_int, nameOut: *c_char, nameOut_sz: c_int) callconv(.C) bool = undefined;

    /// ThemeLayout_GetParameter
    /// returns theme layout parameter. return value is cfg-name, or nil/empty if out of range.
    pub var ThemeLayout_GetParameter: *fn (wp: c_int, descOutOptional: [*:0]const u8, valueOutOptional: *c_int, defValueOutOptional: *c_int, minValueOutOptional: *c_int, maxValueOutOptional: *c_int) callconv(.C) [*:0]const u8 = undefined;

    /// ThemeLayout_RefreshAll
    /// Refreshes all layouts
    pub var ThemeLayout_RefreshAll: *fn () callconv(.C) void = undefined;

    /// ThemeLayout_SetLayout
    /// Sets theme layout override for a particular section -- section can be 'global' or 'mcp' etc. If setting global layout, prefix a ! to the layout string to clear any per-layout overrides. Returns false if failed.
    pub var ThemeLayout_SetLayout: *fn (section: [*:0]const u8, layout: [*:0]const u8) callconv(.C) bool = undefined;

    /// ThemeLayout_SetParameter
    /// sets theme layout parameter to value. persist=true in order to have change loaded on next theme load. note that the caller should update layouts via ??? to make changes visible.
    pub var ThemeLayout_SetParameter: *fn (wp: c_int, value: c_int, persist: bool) callconv(.C) bool = undefined;

    /// time_precise
    /// Gets a precise system timestamp in seconds
    pub var time_precise: *fn () callconv(.C) f64 = undefined;

    /// TimeMap2_beatsToTime
    /// convert a beat position (or optionally a beats+measures if measures is non-NULL) to time.
    pub var TimeMap2_beatsToTime: *fn (proj: *ReaProject, tpos: f64, measuresInOptional: *const c_int) callconv(.C) f64 = undefined;

    /// TimeMap2_GetDividedBpmAtTime
    /// get the effective BPM at the time (seconds) position (i.e. 2x in /8 signatures)
    pub var TimeMap2_GetDividedBpmAtTime: *fn (proj: *ReaProject, time: f64) callconv(.C) f64 = undefined;

    /// TimeMap2_GetNextChangeTime
    /// when does the next time map (tempo or time sig) change occur
    pub var TimeMap2_GetNextChangeTime: *fn (proj: *ReaProject, time: f64) callconv(.C) f64 = undefined;

    /// TimeMap2_QNToTime
    /// converts project QN position to time.
    pub var TimeMap2_QNToTime: *fn (proj: *ReaProject, qn: f64) callconv(.C) f64 = undefined;

    /// TimeMap2_timeToBeats
    /// convert a time into beats.
    /// if measures is non-NULL, measures will be set to the measure count, return value will be beats since measure.
    /// if cml is non-NULL, will be set to current measure length in beats (i.e. time signature numerator)
    /// if fullbeats is non-NULL, and measures is non-NULL, fullbeats will get the full beat count (same value returned if measures is NULL).
    /// if cdenom is non-NULL, will be set to the current time signature denominator.
    pub var TimeMap2_timeToBeats: *fn (proj: *ReaProject, tpos: f64, measuresOutOptional: *c_int, cmlOutOptional: *c_int, fullbeatsOutOptional: *f64, cdenomOutOptional: *c_int) callconv(.C) f64 = undefined;

    /// TimeMap2_timeToQN
    /// converts project time position to QN position.
    pub var TimeMap2_timeToQN: *fn (proj: *ReaProject, tpos: f64) callconv(.C) f64 = undefined;

    /// TimeMap_curFrameRate
    /// Gets project framerate, and optionally whether it is drop-frame timecode
    pub var TimeMap_curFrameRate: *fn (proj: *ReaProject, dropFrameOut: *bool) callconv(.C) f64 = undefined;

    /// TimeMap_GetDividedBpmAtTime
    /// get the effective BPM at the time (seconds) position (i.e. 2x in /8 signatures)
    pub var TimeMap_GetDividedBpmAtTime: *fn (time: f64) callconv(.C) f64 = undefined;

    /// TimeMap_GetMeasureInfo
    /// Get the QN position and time signature information for the start of a measure. Return the time in seconds of the measure start.
    pub var TimeMap_GetMeasureInfo: *fn (proj: *ReaProject, measure: c_int, qn_startOut: *f64, qn_endOut: *f64, timesig_numOut: *c_int, timesig_denomOut: *c_int, tempoOut: *f64) callconv(.C) f64 = undefined;

    /// TimeMap_GetMetronomePattern
    /// Fills in a string representing the active metronome pattern. For example, in a 7/8 measure divided 3+4, the pattern might be "1221222". The length of the string is the time signature numerator, and the function returns the time signature denominator.
    pub var TimeMap_GetMetronomePattern: *fn (proj: *ReaProject, time: f64, pattern: *c_char, pattern_sz: c_int) callconv(.C) c_int = undefined;

    /// TimeMap_GetTimeSigAtTime
    /// get the effective time signature and tempo
    pub var TimeMap_GetTimeSigAtTime: *fn (proj: *ReaProject, time: f64, timesig_numOut: *c_int, timesig_denomOut: *c_int, tempoOut: *f64) callconv(.C) void = undefined;

    /// TimeMap_QNToMeasures
    /// Find which measure the given QN position falls in.
    pub var TimeMap_QNToMeasures: *fn (proj: *ReaProject, qn: f64, qnMeasureStartOutOptional: *f64, qnMeasureEndOutOptional: *f64) callconv(.C) c_int = undefined;

    /// TimeMap_QNToTime
    /// converts project QN position to time.
    pub var TimeMap_QNToTime: *fn (qn: f64) callconv(.C) f64 = undefined;

    /// TimeMap_QNToTime_abs
    /// Converts project quarter note count (QN) to time. QN is counted from the start of the project, regardless of any partial measures. See TimeMap2_QNToTime
    pub var TimeMap_QNToTime_abs: *fn (proj: *ReaProject, qn: f64) callconv(.C) f64 = undefined;

    /// TimeMap_timeToQN
    /// converts project QN position to time.
    pub var TimeMap_timeToQN: *fn (tpos: f64) callconv(.C) f64 = undefined;

    /// TimeMap_timeToQN_abs
    /// Converts project time position to quarter note count (QN). QN is counted from the start of the project, regardless of any partial measures. See TimeMap2_timeToQN
    pub var TimeMap_timeToQN_abs: *fn (proj: *ReaProject, tpos: f64) callconv(.C) f64 = undefined;

    /// ToggleTrackSendUIMute
    /// send_idx<0 for receives, >=0 for hw ouputs, >=nb_of_hw_ouputs for sends.
    pub var ToggleTrackSendUIMute: *fn (track: *MediaTrack, send_idx: c_int) callconv(.C) bool = undefined;

    /// Track_GetPeakHoldDB
    /// Returns meter hold state, in *dB0.01 (0 = +0dB, -0.01 = -1dB, 0.02 = +2dB, etc). If clear is set, clears the meter hold. If channel==1024 or channel==1025, returns loudness values if this is the master track or this track's VU meters are set to display loudness.
    pub var Track_GetPeakHoldDB: *fn (track: *MediaTrack, channel: c_int, clear: bool) callconv(.C) f64 = undefined;

    /// Track_GetPeakInfo
    /// Returns peak meter value (1.0=+0dB, 0.0=-inf) for channel. If channel==1024 or channel==1025, returns loudness values if this is the master track or this track's VU meters are set to display loudness.
    pub var Track_GetPeakInfo: *fn (track: MediaTrack, channel: c_int) callconv(.C) f64 = undefined;

    /// TrackCtl_SetToolTip
    /// displays tooltip at location, or removes if empty string
    pub var TrackCtl_SetToolTip: *fn (fmt: [*:0]const u8, xpos: c_int, ypos: c_int, topmost: bool) callconv(.C) void = undefined;

    /// TrackFX_AddByName
    /// Adds or queries the position of a named FX from the track FX chain (recFX=false) or record input FX/monitoring FX (recFX=true, monitoring FX are on master track). Specify a negative value for instantiate to always create a new effect, 0 to only query the first instance of an effect, or a positive value to add an instance if one is not found. If instantiate is <= -1000, it is used for the insertion position (-1000 is first item in chain, -1001 is second, etc). fxname can have prefix to specify type: VST3:,VST2:,VST:,AU:,JS:, or DX:, or FXADD: which adds selected items from the currently-open FX browser, FXADD:2 to limit to 2 FX added, or FXADD:2e to only succeed if exactly 2 FX are selected. Returns -1 on failure or the new position in chain on success. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_AddByName: *fn (track: MediaTrack, fxname: [*:0]const u8, recFX: bool, instantiate: c_int) callconv(.C) c_int = undefined;

    /// TrackFX_CopyToTake
    /// Copies (or moves) FX from src_track to dest_take. src_fx can have 0x1000000 set to reference input FX. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_CopyToTake: *fn (src_track: *MediaTrack, src_fx: c_int, dest_take: *MediaItem_Take, dest_fx: c_int, is_move: bool) callconv(.C) void = undefined;

    /// TrackFX_CopyToTrack
    /// Copies (or moves) FX from src_track to dest_track. Can be used with src_track=dest_track to reorder, FX indices have 0x1000000 set to reference input FX. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_CopyToTrack: *fn (src_track: MediaTrack, src_fx: c_int, dest_track: MediaTrack, dest_fx: c_int, is_move: bool) callconv(.C) void = undefined;

    /// TrackFX_Delete
    /// Remove a FX from track chain (returns true on success) FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_Delete: *fn (track: MediaTrack, fx: c_int) callconv(.C) bool = undefined;

    /// TrackFX_EndParamEdit
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_EndParamEdit: *fn (track: *MediaTrack, fx: c_int, param: c_int) callconv(.C) bool = undefined;

    /// TrackFX_FormatParamValue
    /// Note: only works with FX that support Cockos VST extensions. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_FormatParamValue: *fn (track: *MediaTrack, fx: c_int, param: c_int, val: f64, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TrackFX_FormatParamValueNormalized
    /// Note: only works with FX that support Cockos VST extensions. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_FormatParamValueNormalized: *fn (track: *MediaTrack, fx: c_int, param: c_int, value: f64, buf: *c_char, buf_sz: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetByName
    /// Get the index of the first track FX insert that matches fxname. If the FX is not in the chain and instantiate is true, it will be inserted. See TrackFX_GetInstrument, TrackFX_GetEQ. Deprecated in favor of TrackFX_AddByName.
    pub var TrackFX_GetByName: *fn (track: MediaTrack, fxname: [*:0]const u8, instantiate: bool) callconv(.C) c_int = undefined;

    /// TrackFX_GetChainVisible
    /// returns index of effect visible in chain, or -1 for chain hidden, or -2 for chain visible but no effect selected
    pub var TrackFX_GetChainVisible: *fn (track: *MediaTrack) callconv(.C) c_int = undefined;

    /// TrackFX_GetCount
    pub var TrackFX_GetCount: *fn (track: MediaTrack) callconv(.C) c_int = undefined;

    /// TrackFX_GetEnabled
    /// See TrackFX_SetEnabled FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetEnabled: *fn (track: *MediaTrack, fx: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetEQ
    /// Get the index of ReaEQ in the track FX chain. If ReaEQ is not in the chain and instantiate is true, it will be inserted. See TrackFX_GetInstrument, TrackFX_GetByName.
    pub var TrackFX_GetEQ: *fn (track: *MediaTrack, instantiate: bool) callconv(.C) c_int = undefined;

    /// TrackFX_GetEQBandEnabled
    /// Returns true if the EQ band is enabled.
    /// Returns false if the band is disabled, or if track/fxidx is not ReaEQ.
    /// Bandtype: -1=master gain, 0=hipass, 1=loshelf, 2=band, 3=notch, 4=hishelf, 5=lopass, 6=bandpass, 7=parallel bandpass.
    /// Bandidx (ignored for master gain): 0=target first band matching bandtype, 1=target 2nd band matching bandtype, etc.
    ///
    /// See TrackFX_GetEQ, TrackFX_GetEQParam, TrackFX_SetEQParam, TrackFX_SetEQBandEnabled. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetEQBandEnabled: *fn (track: *MediaTrack, fxidx: c_int, bandtype: c_int, bandidx: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetEQParam
    /// Returns false if track/fxidx is not ReaEQ.
    /// Bandtype: -1=master gain, 0=hipass, 1=loshelf, 2=band, 3=notch, 4=hishelf, 5=lopass, 6=bandpass, 7=parallel bandpass.
    /// Bandidx (ignored for master gain): 0=target first band matching bandtype, 1=target 2nd band matching bandtype, etc.
    /// Paramtype (ignored for master gain): 0=freq, 1=gain, 2=Q.
    /// See TrackFX_GetEQ, TrackFX_SetEQParam, TrackFX_GetEQBandEnabled, TrackFX_SetEQBandEnabled. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetEQParam: *fn (track: *MediaTrack, fxidx: c_int, paramidx: c_int, bandtypeOut: *c_int, bandidxOut: *c_int, paramtypeOut: *c_int, normvalOut: *f64) callconv(.C) bool = undefined;

    /// TrackFX_GetFormattedParamValue
    /// returns HWND of f32ing window for effect index, if any FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetFloatingWindow: *fn (track: *MediaTrack, index: c_int) callconv(.C) HWND = undefined;

    /// TrackFX_GetFormattedParamValue
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetFormattedParamValue: *fn (track: *MediaTrack, fx: c_int, param: c_int, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetFXGUID
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetFXGUID: *fn (track: *MediaTrack, fx: c_int) callconv(.C) *GUID = undefined;

    /// TrackFX_GetFXName
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetFXName: *fn (track: MediaTrack, fx: c_int, bufOut: [*:0]u8, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetInstrument
    /// Get the index of the first track FX insert that is a virtual instrument, or -1 if none. See TrackFX_GetEQ, TrackFX_GetByName.
    pub var TrackFX_GetInstrument: *fn (track: *MediaTrack) callconv(.C) c_int = undefined;

    /// TrackFX_GetIOSize
    /// Gets the number of input/output pins for FX if available, returns plug-in type or -1 on error FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetIOSize: *fn (track: *MediaTrack, fx: c_int, inputPinsOut: *c_int, outputPinsOut: *c_int) callconv(.C) c_int = undefined;

    /// TrackFX_GetNamedConfigParm
    /// gets plug-in specific named configuration value (returns true on success).
    ///
    /// Supported values for read:
    /// pdc : PDC latency
    /// in_pin_X : name of input pin X
    /// out_pin_X : name of output pin X
    /// fx_type : type string
    /// fx_ident : type-specific identifier
    /// fx_name : name of FX (also supported as original_name)
    /// GainReduction_dB : [ReaComp + other supported compressors]
    /// parent_container : FX ID of parent container, if any (v7.06+)
    /// container_count : [Container] number of FX in container
    /// container_item.X : FX ID of item in container (first item is container_item.0) (v7.06+)
    /// param.X.container_map.hint_id : unique ID of mapping (preserved if mapping order changes)
    /// param.X.container_map.delete : read this value in order to remove the mapping for this parameter
    /// container_map.add : read from this value to add a new container parameter mapping -- will return new parameter index (accessed via param.X.container_map.*)
    /// container_map.add.FXID.PARMIDX : read from this value to add/get container parameter mapping for FXID/PARMIDX -- will return the parameter index (accessed via param.X.container_map.*). FXID can be a full address (must be a child of the container) or a 0-based sub-index (v7.06+).
    /// container_map.get.FXID.PARMIDX : read from this value to get container parameter mapping for FXID/PARMIDX -- will return the parameter index (accessed via param.X.container_map.*). FXID can be a full address (must be a child of the container) or a 0-based sub-index (v7.06+).
    ///
    ///
    /// Supported values for read/write:
    /// vst_chunk[_program] : base64-encoded VST-specific chunk.
    /// clap_chunk : base64-encoded CLAP-specific chunk.
    /// param.X.lfo.[active,dir,phase,speed,strength,temposync,free,shape] : parameter moduation LFO state
    /// param.X.acs.[active,dir,strength,attack,release,dblo,dbhi,chan,stereo,x2,y2] : parameter modulation ACS state
    /// param.X.plink.[active,scale,offset,effect,param,midi_bus,midi_chan,midi_msg,midi_msg2] : parameter link/MIDI link: set effect=-100 to support *midi_
    /// param.X.mod.[active,baseline,visible] : parameter module global settings
    /// param.X.learn.[midi1,midi2,osc] : first two bytes of MIDI message, or OSC string if set
    /// param.X.learn.mode : absolution/relative mode flag (0: Absolute, 1: 127=-1,1=+1, 2: 63=-1, 65=+1, 3: 65=-1, 1=+1, 4: toggle if nonzero)
    /// param.X.learn.flags : &1=selected track only, &2=soft takeover, &4=focused FX only, &8=LFO retrigger, &16=visible FX only
    /// param.X.container_map.fx_index : index of FX contained in container
    /// param.X.container_map.fx_parm : parameter index of parameter of FX contained in container
    /// param.X.container_map.aliased_name : name of parameter (if user-renamed, otherwise fails)
    /// BANDTYPEx, BANDENABLEDx : band configuration [ReaEQ]
    /// THRESHOLD, CEILING, TRUEPEAK : [ReaLimit]
    /// NUMCHANNELS, NUMSPEAKERS, RESETCHANNELS : [ReaSurroundPan]
    /// ITEMx : [ReaVerb] state configuration line, when writing should be followed by a write of DONE
    /// FILE, FILEx, -FILEx, +FILEx, -*FILE : [RS5k] file list, -/+ prefixes are write-only, when writing any, should be followed by a write of DONE
    /// MODE, RSMODE : [RS5k] general mode, resample mode
    /// VIDEO_CODE : [video processor] code
    /// force_auto_bypass : 0 or 1 - force auto-bypass plug-in on silence
    /// parallel : 0, 1 or 2 - 1=process plug-in in parallel with previous, 2=process plug-in parallel and merge MIDI
    /// instance_oversample_shift : instance oversampling shift amount, 0=none, 1=~96k, 2=~192k, etc. When setting requires playback stop/start to take effect
    /// chain_oversample_shift : chain oversampling shift amount, 0=none, 1=~96k, 2=~192k, etc. When setting requires playback stop/start to take effect
    /// chain_pdc_mode : chain PDC mode (0=classic, 1=new-default, 2=ignore PDC, 3=hwcomp-master)
    /// chain_sel : selected/visible FX in chain
    /// renamed_name : renamed FX instance name (empty string = not renamed)
    /// container_nch : number of internal channels for container
    /// container_nch_in : number of input pins for container
    /// container_nch_out : number of output pints for container
    /// container_nch_feedback : number of internal feedback channels enabled in container
    /// focused : reading returns 1 if focused. Writing a positive value to this sets the FX UI as "last focused."
    /// last_touched : reading returns two integers, one indicates whether FX is the last-touched FX, the second indicates which parameter was last touched. Writing a negative value ensures this plug-in is not set as last touched, otherwise the FX is set "last touched," and last touched parameter index is set to the value in the string (if valid).
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetNamedConfigParm: *fn (track: MediaTrack, fx: c_int, parmname: [*:0]const u8, bufOutNeedBig: [*:0]u8, bufOutNeedBig_sz: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetNumParams
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetNumParams: *fn (track: *MediaTrack, fx: c_int) callconv(.C) c_int = undefined;

    /// TrackFX_GetOffline
    /// See TrackFX_SetOffline FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetOffline: *fn (track: *MediaTrack, fx: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetOpen
    /// Returns true if this FX UI is open in the FX chain window or a f32ing window. See TrackFX_SetOpen FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetOpen: *fn (track: *MediaTrack, fx: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetParam
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetParam: *fn (track: *MediaTrack, fx: c_int, param: c_int, minvalOut: *f64, maxvalOut: *f64) callconv(.C) f64 = undefined;

    /// TrackFX_GetParameterStepSizes
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetParameterStepSizes: *fn (track: *MediaTrack, fx: c_int, param: c_int, stepOut: *f64, smallstepOut: *f64, largestepOut: *f64, istoggleOut: *bool) callconv(.C) bool = undefined;

    /// TrackFX_GetParamEx
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetParamEx: *fn (track: *MediaTrack, fx: c_int, param: c_int, minvalOut: *f64, maxvalOut: *f64, midvalOut: *f64) callconv(.C) f64 = undefined;

    /// TrackFX_GetParamFromIdent
    /// gets the parameter index from an identifying string (:wet, :bypass, :delta, or a string returned from GetParamIdent), or -1 if unknown. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetParamFromIdent: *fn (track: *MediaTrack, fx: c_int, ident_str: [*:0]const u8) callconv(.C) c_int = undefined;

    /// TrackFX_GetParamIdent
    /// gets an identifying string for the parameter FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetParamIdent: *fn (track: *MediaTrack, fx: c_int, param: c_int, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetParamName
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetParamName: *fn (track: *MediaTrack, fx: c_int, param: c_int, bufOut: *c_char, bufOut_sz: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetParamNormalized
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetParamNormalized: *fn (track: *MediaTrack, fx: c_int, param: c_int) callconv(.C) f64 = undefined;

    /// TrackFX_GetPinMappings
    /// gets the effective channel mapping bitmask for a particular pin. high32Out will be set to the high 32 bits. Add 0x1000000 to pin index in order to access the second 64 bits of mappings independent of the first 64 bits. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetPinMappings: *fn (tr: *MediaTrack, fx: c_int, isoutput: c_int, pin: c_int, high32Out: *c_int) callconv(.C) c_int = undefined;

    /// TrackFX_GetPreset
    /// Get the name of the preset currently showing in the REAPER dropdown, or the full path to a factory preset file for VST3 plug-ins (.vstpreset). See TrackFX_SetPreset. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetPreset: *fn (track: *MediaTrack, fx: c_int, presetnameOut: *c_char, presetnameOut_sz: c_int) callconv(.C) bool = undefined;

    /// TrackFX_GetPresetIndex
    /// Returns current preset index, or -1 if error. numberOfPresetsOut will be set to total number of presets available. See TrackFX_SetPresetByIndex FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetPresetIndex: *fn (track: *MediaTrack, fx: c_int, numberOfPresetsOut: *c_int) callconv(.C) c_int = undefined;

    /// TrackFX_GetRecChainVisible
    /// returns index of effect visible in record input chain, or -1 for chain hidden, or -2 for chain visible but no effect selected
    pub var TrackFX_GetRecChainVisible: *fn (track: *MediaTrack) callconv(.C) c_int = undefined;

    /// TrackFX_GetRecCount
    /// returns count of record input FX. To access record input FX, use a FX indices [0x1000000..0x1000000+n). On the master track, this accesses monitoring FX rather than record input FX.
    pub var TrackFX_GetRecCount: *fn (track: *MediaTrack) callconv(.C) c_int = undefined;

    /// TrackFX_GetUserPresetFilename
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_GetUserPresetFilename: *fn (track: *MediaTrack, fx: c_int, fnOut: *c_char, fnOut_sz: c_int) callconv(.C) void = undefined;

    /// TrackFX_NavigatePresets
    /// presetmove==1 activates the next preset, presetmove==-1 activates the previous preset, etc. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_NavigatePresets: *fn (track: *MediaTrack, fx: c_int, presetmove: c_int) callconv(.C) bool = undefined;

    /// TrackFX_SetEnabled
    /// See TrackFX_GetEnabled FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetEnabled: *fn (track: *MediaTrack, fx: c_int, enabled: bool) callconv(.C) void = undefined;

    /// TrackFX_SetEQBandEnabled
    /// Enable or disable a ReaEQ band.
    /// Returns false if track/fxidx is not ReaEQ.
    /// Bandtype: -1=master gain, 0=hipass, 1=loshelf, 2=band, 3=notch, 4=hishelf, 5=lopass, 6=bandpass, 7=parallel bandpass.
    /// Bandidx (ignored for master gain): 0=target first band matching bandtype, 1=target 2nd band matching bandtype, etc.
    ///
    /// See TrackFX_GetEQ, TrackFX_GetEQParam, TrackFX_SetEQParam, TrackFX_GetEQBandEnabled. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetEQBandEnabled: *fn (track: *MediaTrack, fxidx: c_int, bandtype: c_int, bandidx: c_int, enable: bool) callconv(.C) bool = undefined;

    /// TrackFX_SetEQParam
    /// Returns false if track/fxidx is not ReaEQ. Targets a band matching bandtype.
    /// Bandtype: -1=master gain, 0=hipass, 1=loshelf, 2=band, 3=notch, 4=hishelf, 5=lopass, 6=bandpass, 7=parallel bandpass.
    /// Bandidx (ignored for master gain): 0=target first band matching bandtype, 1=target 2nd band matching bandtype, etc.
    /// Paramtype (ignored for master gain): 0=freq, 1=gain, 2=Q.
    /// See TrackFX_GetEQ, TrackFX_GetEQParam, TrackFX_GetEQBandEnabled, TrackFX_SetEQBandEnabled. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetEQParam: *fn (track: *MediaTrack, fxidx: c_int, bandtype: c_int, bandidx: c_int, paramtype: c_int, val: f64, isnorm: bool) callconv(.C) bool = undefined;

    /// TrackFX_SetNamedConfigParm
    /// sets plug-in specific named configuration value (returns true on success).
    ///
    /// Support values for write:
    /// vst_chunk[_program] : base64-encoded VST-specific chunk.
    /// clap_chunk : base64-encoded CLAP-specific chunk.
    /// param.X.lfo.[active,dir,phase,speed,strength,temposync,free,shape] : parameter moduation LFO state
    /// param.X.acs.[active,dir,strength,attack,release,dblo,dbhi,chan,stereo,x2,y2] : parameter modulation ACS state
    /// param.X.plink.[active,scale,offset,effect,param,midi_bus,midi_chan,midi_msg,midi_msg2] : parameter link/MIDI link: set effect=-100 to support *midi_
    /// param.X.mod.[active,baseline,visible] : parameter module global settings
    /// param.X.learn.[midi1,midi2,osc] : first two bytes of MIDI message, or OSC string if set
    /// param.X.learn.mode : absolution/relative mode flag (0: Absolute, 1: 127=-1,1=+1, 2: 63=-1, 65=+1, 3: 65=-1, 1=+1, 4: toggle if nonzero)
    /// param.X.learn.flags : &1=selected track only, &2=soft takeover, &4=focused FX only, &8=LFO retrigger, &16=visible FX only
    /// param.X.container_map.fx_index : index of FX contained in container
    /// param.X.container_map.fx_parm : parameter index of parameter of FX contained in container
    /// param.X.container_map.aliased_name : name of parameter (if user-renamed, otherwise fails)
    /// BANDTYPEx, BANDENABLEDx : band configuration [ReaEQ]
    /// THRESHOLD, CEILING, TRUEPEAK : [ReaLimit]
    /// NUMCHANNELS, NUMSPEAKERS, RESETCHANNELS : [ReaSurroundPan]
    /// ITEMx : [ReaVerb] state configuration line, when writing should be followed by a write of DONE
    /// FILE, FILEx, -FILEx, +FILEx, -*FILE : [RS5k] file list, -/+ prefixes are write-only, when writing any, should be followed by a write of DONE
    /// MODE, RSMODE : [RS5k] general mode, resample mode
    /// VIDEO_CODE : [video processor] code
    /// force_auto_bypass : 0 or 1 - force auto-bypass plug-in on silence
    /// parallel : 0, 1 or 2 - 1=process plug-in in parallel with previous, 2=process plug-in parallel and merge MIDI
    /// instance_oversample_shift : instance oversampling shift amount, 0=none, 1=~96k, 2=~192k, etc. When setting requires playback stop/start to take effect
    /// chain_oversample_shift : chain oversampling shift amount, 0=none, 1=~96k, 2=~192k, etc. When setting requires playback stop/start to take effect
    /// chain_pdc_mode : chain PDC mode (0=classic, 1=new-default, 2=ignore PDC, 3=hwcomp-master)
    /// chain_sel : selected/visible FX in chain
    /// renamed_name : renamed FX instance name (empty string = not renamed)
    /// container_nch : number of internal channels for container
    /// container_nch_in : number of input pins for container
    /// container_nch_out : number of output pints for container
    /// container_nch_feedback : number of internal feedback channels enabled in container
    /// focused : reading returns 1 if focused. Writing a positive value to this sets the FX UI as "last focused."
    /// last_touched : reading returns two integers, one indicates whether FX is the last-touched FX, the second indicates which parameter was last touched. Writing a negative value ensures this plug-in is not set as last touched, otherwise the FX is set "last touched," and last touched parameter index is set to the value in the string (if valid).
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetNamedConfigParm: *fn (track: MediaTrack, fx: c_int, parmname: [*:0]const u8, value: [*:0]const u8) callconv(.C) bool = undefined;

    /// TrackFX_SetOffline
    /// See TrackFX_GetOffline FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetOffline: *fn (track: *MediaTrack, fx: c_int, offline: bool) callconv(.C) void = undefined;

    /// TrackFX_SetOpen
    /// Open this FX UI. See TrackFX_GetOpen FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetOpen: *fn (track: *MediaTrack, fx: c_int, open: bool) callconv(.C) void = undefined;

    /// TrackFX_SetParam
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetParam: *fn (track: *MediaTrack, fx: c_int, param: c_int, val: f64) callconv(.C) bool = undefined;

    /// TrackFX_SetParamNormalized
    ///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetParamNormalized: *fn (track: MediaTrack, fx: c_int, param: c_int, value: f64) callconv(.C) bool = undefined;

    /// TrackFX_SetPinMappings
    /// sets the channel mapping bitmask for a particular pin. returns false if unsupported (not all types of plug-ins support this capability). Add 0x1000000 to pin index in order to access the second 64 bits of mappings independent of the first 64 bits. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetPinMappings: *fn (tr: *MediaTrack, fx: c_int, isoutput: c_int, pin: c_int, low32bits: c_int, hi32bits: c_int) callconv(.C) bool = undefined;

    /// TrackFX_SetPreset
    /// Activate a preset with the name shown in the REAPER dropdown. Full paths to .vstpreset files are also supported for VST3 plug-ins. See TrackFX_GetPreset. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetPreset: *fn (track: *MediaTrack, fx: c_int, presetname: [*:0]const u8) callconv(.C) bool = undefined;

    /// TrackFX_SetPresetByIndex
    /// Sets the preset idx, or the factory preset (idx==-2), or the default user preset (idx==-1). Returns true on success. See TrackFX_GetPresetIndex. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_SetPresetByIndex: *fn (track: *MediaTrack, fx: c_int, idx: c_int) callconv(.C) bool = undefined;

    /// TrackFX_Show
    /// showflag=0 for hidechain, =1 for show chain(index valid), =2 for hide f32ing window(index valid), =3 for show f32ing window (index valid) FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
    pub var TrackFX_Show: *fn (track: *MediaTrack, index: c_int, showFlag: c_int) callconv(.C) void = undefined;

    /// TrackList_AdjustWindows
    pub var TrackList_AdjustWindows: *fn (isMinor: bool) callconv(.C) void = undefined;

    /// TrackList_UpdateAllExternalSurfaces
    pub var TrackList_UpdateAllExternalSurfaces: *fn () callconv(.C) void = undefined;

    /// Undo_BeginBlock
    /// call to start a new block
    pub var Undo_BeginBlock: *fn () callconv(.C) void = undefined;

    /// Undo_BeginBlock2
    /// call to start a new block
    pub var Undo_BeginBlock2: *fn (proj: *ReaProject) callconv(.C) void = undefined;

    /// Undo_CanRedo2
    /// returns string of next action,if able,NULL if not
    pub var Undo_CanRedo2: *fn (proj: *ReaProject) callconv(.C) [*:0]const u8 = undefined;

    /// Undo_CanUndo2
    /// returns string of last action,if able,NULL if not
    pub var Undo_CanUndo2: *fn (proj: *ReaProject) callconv(.C) [*:0]const u8 = undefined;

    /// Undo_DoRedo2
    /// nonzero if success
    pub var Undo_DoRedo2: *fn (proj: *ReaProject) callconv(.C) c_int = undefined;

    /// Undo_DoUndo2
    /// nonzero if success
    pub var Undo_DoUndo2: *fn (proj: *ReaProject) callconv(.C) c_int = undefined;

    /// Undo_EndBlock
    /// call to end the block,with extra flags if any,and a description
    pub var Undo_EndBlock: *fn (descchange: [*:0]const u8, extraflags: c_int) callconv(.C) void = undefined;

    /// Undo_EndBlock2
    /// call to end the block,with extra flags if any,and a description
    pub var Undo_EndBlock2: *fn (proj: *ReaProject, descchange: [*:0]const u8, extraflags: c_int) callconv(.C) void = undefined;

    /// Undo_OnStateChange
    /// limited state change to items
    pub var Undo_OnStateChange: *fn (descchange: [*:0]const u8) callconv(.C) void = undefined;

    /// Undo_OnStateChange2
    /// limited state change to items
    pub var Undo_OnStateChange2: *fn (proj: *ReaProject, descchange: [*:0]const u8) callconv(.C) void = undefined;

    /// Undo_OnStateChange_Item
    pub var Undo_OnStateChange_Item: *fn (proj: *ReaProject, name: [*:0]const u8, item: *MediaItem) callconv(.C) void = undefined;

    /// Undo_OnStateChangeEx
    /// trackparm=-1 by default,or if updating one fx chain,you can specify track index
    pub var Undo_OnStateChangeEx: *fn (descchange: [*:0]const u8, whichStates: c_int, trackparm: c_int) callconv(.C) void = undefined;

    /// Undo_OnStateChangeEx2
    /// trackparm=-1 by default,or if updating one fx chain,you can specify track index
    pub var Undo_OnStateChangeEx2: *fn (proj: *ReaProject, descchange: [*:0]const u8, whichStates: c_int, trackparm: c_int) callconv(.C) void = undefined;

    /// update_disk_counters
    /// Updates disk I/O statistics with bytes transferred since last call. notify REAPER of a write error by calling with readamt=0, writeamt=-101010110 for unknown or -101010111 for disk full
    pub var update_disk_counters: *fn (readamt: c_int, writeamt: c_int) callconv(.C) void = undefined;

    /// UpdateArrange
    /// Redraw the arrange view
    pub var UpdateArrange: *fn () callconv(.C) void = undefined;

    /// UpdateItemInProject
    pub var UpdateItemInProject: *fn (item: *MediaItem) callconv(.C) void = undefined;

    /// UpdateItemLanes
    /// Recalculate lane arrangement for fixed lane tracks, including auto-removing empty lanes at the bottom of the track
    pub var UpdateItemLanes: *fn (proj: *ReaProject) callconv(.C) bool = undefined;

    /// UpdateTimeline
    /// Redraw the arrange view and ruler
    pub var UpdateTimeline: *fn () callconv(.C) void = undefined;

    /// ValidatePtr
    /// see ValidatePtr2
    pub var ValidatePtr: *fn (pointer: *void, ctypename: [*:0]const u8) callconv(.C) bool = undefined;

    /// ValidatePtr2
    /// Return true if the pointer is a valid object of the right type in proj (proj is ignored if pointer is itself a project). Supported types are: *ReaProject, *MediaTrack, *MediaItem, *MediaItem_Take, *TrackEnvelope and *PCM_source.
    pub var ValidatePtr2: *fn (proj: *ReaProject, pointer: *void, ctypename: [*:0]const u8) callconv(.C) bool = undefined;

    /// ViewPrefs
    /// Opens the prefs to a page, use pageByName if page is 0.
    pub var ViewPrefs: *fn (page: c_int, pageByName: [*:0]const u8) callconv(.C) void = undefined;

    /// WDL_VirtualWnd_ScaledBlitBG
    pub var WDL_VirtualWnd_ScaledBlitBG: *fn (dest: *LICE_IBitmap, src: *WDL_VirtualWnd_BGCfg, destx: c_int, desty: c_int, destw: c_int, desth: c_int, clipx: c_int, clipy: c_int, clipw: c_int, cliph: c_int, alpha: f32, mode: c_int) callconv(.C) bool = undefined;
};

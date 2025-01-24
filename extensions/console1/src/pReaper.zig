const std = @import("std");

const reaper = @import("reaper.zig").reaper;
const ACCEL = reaper.ACCEL;
const AudioAccessor = reaper.AudioAccessor;
const AudioWriter = reaper.AudioWriter;
const BR_Envelope = reaper.BR_Envelope;
const CF_Preview = reaper.CF_Preview;
const FxChain = reaper.FxChain;
const GUID = reaper.GUID;
const HDC = reaper.HDC;
const HFONT = reaper.HFONT;
const HINSTANCE = reaper.HINSTANCE;
const HMENU = reaper.HMENU;
const HWND = reaper.HWND;
const INT_PTR = reaper.INT_PTR;
const IReaperControlSurface = reaper.IReaperControlSurface;
const IReaperPitchShift = reaper.IReaperPitchShift;
const ISimpleMediaDecoder = reaper.ISimpleMediaDecoder;
const KbdSectionInfo = reaper.KbdSectionInfo;
const LICE_IBitmap = reaper.LICE_IBitmap;
const LICE_IFont = reaper.LICE_IFont;
const LICE_pixel = reaper.LICE_pixel;
const LICE_pixel_chan = reaper.LICE_pixel_chan;
// pub const MIDI_event_t = *opaque {};

const MIDI_event_t = reaper.MIDI_event_t;
const MIDI_eventlist = reaper.MIDI_eventlist;
const MSG = reaper.MSG;
const MediaItem = reaper.MediaItem;
const MediaItem_Take = reaper.MediaItem_Take;
const MediaTrack = reaper.MediaTrack;
const PCM_sink = reaper.PCM_sink;
const PCM_source = reaper.PCM_source;
const PCM_source_peaktransfer_t = reaper.PCM_source_peaktransfer_t;
const PCM_source_transfer_t = reaper.PCM_source_transfer_t;
const PLUGIN_VERSION = reaper.PLUGIN_VERSION;
const REAPER_PeakBuild_Interface = reaper.REAPER_PeakBuild_Interface;
const REAPER_PeakGet_Interface = reaper.REAPER_PeakGet_Interface;
const REAPER_Resample_Interface = reaper.REAPER_Resample_Interface;
const RECT = reaper.RECT;
const ReaProject = reaper.ReaProject;
const RprMidiNote = reaper.RprMidiNote;
const RprMidiTake = reaper.RprMidiTake;
const TrackEnvelope = reaper.TrackEnvelope;
const UINT = reaper.UINT;
const WDL_FastString = reaper.WDL_FastString;
const WDL_VirtualWnd_BGCfg = reaper.WDL_VirtualWnd_BGCfg;
const audio_hook_register_t = reaper.audio_hook_register_t;
const gfx = reaper.gfx;
const joystick_device = reaper.joystick_device;
const midi_Input = reaper.midi_Input;
const midi_Output = reaper.midi_Output;
const preview_register_t = reaper.preview_register_t;
const screensetNewCallbackFunc = reaper.screensetNewCallbackFunc;
const size_t = reaper.size_t;
const takename = reaper.takename;
const plugin_info_t = reaper.plugin_info_t;

/// AddCustomizableMenu
/// menuidstr is some unique identifying string
/// menuname is for main menus only (displayed in a menu bar somewhere), NULL otherwise
/// kbdsecname is the name of the KbdSectionInfo registered by this plugin, or NULL for the main actions section
///-- @param menuidstr [*:0]const u8
///-- @param menuname [*:0]const u8
///-- @param kbdsecname [*:0]const u8
///-- @param addtomainmenu bool
pub const AddCustomizableMenu = function(&reaper.AddCustomizableMenu, 4, &.{ [*:0]const u8, [*:0]const u8, [*:0]const u8, bool });

/// AddExtensionsMainMenu
/// Add an Extensions main menu, which the extension can populate/modify with plugin_register("hookcustommenu")
pub const AddExtensionsMainMenu = function(&reaper.AddExtensionsMainMenu, 0, &.{});

/// AddMediaItemToTrack
/// creates a new media item.
///-- @param tr *MediaTrack
pub const AddMediaItemToTrack = function(&reaper.AddMediaItemToTrack, 1, &.{*MediaTrack});

/// AddProjectMarker
/// Returns the index of the created marker/region, or -1 on failure. Supply wantidx>=0 if you want a particular index number, but you'll get a different index number a region and wantidx is already in use.
///-- @param proj *ReaProject
///-- @param isrgn bool
///-- @param pos f64
///-- @param rgnend f64
///-- @param name [*:0]const u8
///-- @param wantidx c_int
pub const AddProjectMarker = function(&reaper.AddProjectMarker, 6, &.{ *ReaProject, bool, f64, f64, [*:0]const u8, c_int });

/// AddProjectMarker2
/// Returns the index of the created marker/region, or -1 on failure. Supply wantidx>=0 if you want a particular index number, but you'll get a different index number a region and wantidx is already in use. color should be 0 (default color), or ColorToNative(r,g,b)|0x1000000
///-- @param proj *ReaProject
///-- @param isrgn bool
///-- @param pos f64
///-- @param rgnend f64
///-- @param name [*:0]const u8
///-- @param wantidx c_int
///-- @param color c_int
pub const AddProjectMarker2 = function(&reaper.AddProjectMarker2, 7, &.{ *ReaProject, bool, f64, f64, [*:0]const u8, c_int, c_int });

/// AddRemoveReaScript
/// Add a ReaScript (return the new command ID, or 0 if failed) or remove a ReaScript (return >0 on success). Use commit==true when adding/removing a single script. When bulk adding/removing n scripts, you can optimize the n-1 first calls with commit==false and commit==true for the last call.
///-- @param add bool
///-- @param sectionID c_int
///-- @param scriptfn [*:0]const u8
///-- @param commit bool
pub const AddRemoveReaScript = function(&reaper.AddRemoveReaScript, 4, &.{ bool, c_int, [*:0]const u8, bool });

/// AddTakeToMediaItem
/// creates a new take in an item
///-- @param item *MediaItem
pub const AddTakeToMediaItem = function(&reaper.AddTakeToMediaItem, 1, &.{*MediaItem});

/// AddTempoTimeSigMarker
/// Deprecated. Use SetTempoTimeSigMarker with ptidx=-1.
///-- @param proj *ReaProject
///-- @param timepos f64
///-- @param bpm f64
///-- @param num c_int
///-- @param denom c_int
///-- @param lineartempochange bool
pub const AddTempoTimeSigMarker = function(&reaper.AddTempoTimeSigMarker, 6, &.{ *ReaProject, f64, f64, c_int, c_int, bool });

/// adjustZoom
/// forceset=0,doupd=true,centermode=-1 for default
///-- @param amt f64
///-- @param forceset c_int
///-- @param doupd bool
///-- @param centermode c_int
pub const adjustZoom = function(&reaper.adjustZoom, 4, &.{ f64, c_int, bool, c_int });

/// AnyTrackSolo
///-- @param proj *ReaProject
pub const AnyTrackSolo = function(&reaper.AnyTrackSolo, 1, &.{*ReaProject});

/// APIExists
/// Returns true if function_name exists in the REAPER API
///-- @param name [*:0]const u8
pub const APIExists = function(&reaper.APIExists, 1, &.{[*:0]const u8});

/// APITest
/// Displays a message window if the API was successfully called.
pub const APITest = function(&reaper.APITest, 0, &.{});

/// ApplyNudge
/// nudgeflag: &1=set to value (otherwise nudge by value), &2=snap
/// nudgewhat: 0=position, 1=left trim, 2=left edge, 3=right edge, 4=contents, 5=duplicate, 6=edit cursor
/// nudgeunit: 0=ms, 1=seconds, 2=grid, 3=256th notes, ..., 15=whole notes, 16=measures.beats (1.15 = 1 measure + 1.5 beats), 17=samples, 18=frames, 19=pixels, 20=item lengths, 21=item selections
/// value: amount to nudge by, or value to set to
/// reverse: in nudge mode, nudges left (otherwise ignored)
/// copies: in nudge duplicate mode, number of copies (otherwise ignored)
///-- @param project *ReaProject
///-- @param nudgeflag c_int
///-- @param nudgewhat c_int
///-- @param nudgeunits c_int
///-- @param value f64
///-- @param reverse bool
///-- @param copies c_int
pub const ApplyNudge = function(&reaper.ApplyNudge, 7, &.{ *ReaProject, c_int, c_int, c_int, f64, bool, c_int });

/// ArmCommand
/// arms a command (or disarms if 0 passed) in section sectionname (empty string for main)
///-- @param cmd c_int
///-- @param sectionname [*:0]const u8
pub const ArmCommand = function(&reaper.ArmCommand, 2, &.{ c_int, [*:0]const u8 });

/// Audio_Init
/// open all audio and MIDI devices, if not open
pub const Audio_Init = function(&reaper.Audio_Init, 0, &.{});

/// Audio_IsPreBuffer
/// is in pre-buffer? threadsafe
pub const Audio_IsPreBuffer = function(&reaper.Audio_IsPreBuffer, 0, &.{});

/// Audio_IsRunning
/// is audio running at all? threadsafe
pub const Audio_IsRunning = function(&reaper.Audio_IsRunning, 0, &.{});

/// Audio_Quit
/// close all audio and MIDI devices, if open
pub const Audio_Quit = function(&reaper.Audio_Quit, 0, &.{});

/// Audio_RegHardwareHook
/// return >0 on success
///-- @param isAdd bool
///-- @param reg *audio_hook_register_t
pub const Audio_RegHardwareHook = function(&reaper.Audio_RegHardwareHook, 2, &.{ bool, *audio_hook_register_t });

/// AudioAccessorStateChanged
/// Returns true if the underlying samples (track or media item take) have changed, but does not update the audio accessor, so the user can selectively call AudioAccessorValidateState only when needed. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, DestroyAudioAccessor, GetAudioAccessorEndTime, GetAudioAccessorSamples.
///-- @param accessor *AudioAccessor
pub const AudioAccessorStateChanged = function(&reaper.AudioAccessorStateChanged, 1, &.{*AudioAccessor});

/// AudioAccessorUpdate
/// Force the accessor to reload its state from the underlying track or media item take. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorEndTime, GetAudioAccessorSamples.
///-- @param accessor *AudioAccessor
pub const AudioAccessorUpdate = function(&reaper.AudioAccessorUpdate, 1, &.{*AudioAccessor});

/// AudioAccessorValidateState
/// Validates the current state of the audio accessor -- must ONLY call this from the main thread. Returns true if the state changed.
///-- @param accessor *AudioAccessor
pub const AudioAccessorValidateState = function(&reaper.AudioAccessorValidateState, 1, &.{*AudioAccessor});

/// BypassFxAllTracks
/// -1 = bypass all if not all bypassed,otherwise unbypass all
///-- @param bypass c_int
pub const BypassFxAllTracks = function(&reaper.BypassFxAllTracks, 1, &.{c_int});

/// CalcMediaSrcLoudness
/// Calculates loudness statistics of media via dry run render. Statistics will be displayed to the user; call GetSetProjectInfo_String("RENDER_STATS") to retrieve via API. Returns 1 if loudness was calculated successfully, -1 if user canceled the dry run render.
///-- @param mediasource *PCM_source
pub const CalcMediaSrcLoudness = function(&reaper.CalcMediaSrcLoudness, 1, &.{*PCM_source});

/// CalculateNormalization
/// Calculate normalize adjustment for source media. normalizeTo: 0=LUFS-I, 1=RMS-I, 2=peak, 3=true peak, 4=LUFS-M max, 5=LUFS-S max. normalizeTarget: dBFS or LUFS value. normalizeStart, normalizeEnd: time bounds within source media for normalization calculation. If normalizationStart=0 and normalizationEnd=0, the full duration of the media will be used for the calculation.
///-- @param source *PCM_source
///-- @param normalizeTo c_int
///-- @param normalizeTarget f64
///-- @param normalizeStart f64
///-- @param normalizeEnd f64
pub const CalculateNormalization = function(&reaper.CalculateNormalization, 5, &.{ *PCM_source, c_int, f64, f64, f64 });

/// CalculatePeaks
///-- @param srcBlock *PCM_source_transfer_t
///-- @param pksBlock *PCM_source_peaktransfer_t
pub const CalculatePeaks = function(&reaper.CalculatePeaks, 2, &.{ *PCM_source_transfer_t, *PCM_source_peaktransfer_t });

/// CalculatePeaksFloatSrcPtr
/// NOTE: source samples field is a pointer to f32s instead
///-- @param srcBlock *PCM_source_transfer_t
///-- @param pksBlock *PCM_source_peaktransfer_t
pub const CalculatePeaksFloatSrcPtr = function(&reaper.CalculatePeaksFloatSrcPtr, 2, &.{ *PCM_source_transfer_t, *PCM_source_peaktransfer_t });

/// ClearAllRecArmed
pub const ClearAllRecArmed = function(&reaper.ClearAllRecArmed, 0, &.{});

/// ClearConsole
/// Clear the ReaScript console. See ShowConsoleMsg
pub const ClearConsole = function(&reaper.ClearConsole, 0, &.{});

/// ClearPeakCache
/// resets the global peak caches
pub const ClearPeakCache = function(&reaper.ClearPeakCache, 0, &.{});

/// ColorFromNative
/// Extract RGB values from an OS dependent color. See ColorToNative.
///-- @param col c_int
///-- @param rOut *c_int
///-- @param gOut *c_int
///-- @param bOut *c_int
pub const ColorFromNative = function(&reaper.ColorFromNative, 4, &.{ c_int, *c_int, *c_int, *c_int });

/// ColorToNative
/// Make an OS dependent color from RGB values (e.g. RGB() macro on Windows). r,g and b are in [0..255]. See ColorFromNative.
///-- @param r c_int
///-- @param g c_int
///-- @param b c_int
pub const ColorToNative = function(&reaper.ColorToNative, 3, &.{ c_int, c_int, c_int });

/// CountActionShortcuts
/// Returns the number of shortcuts that exist for the given command ID.
/// see GetActionShortcutDesc, DeleteActionShortcut, DoActionShortcutDialog.
///-- @param section *KbdSectionInfo
///-- @param cmdID c_int
pub const CountActionShortcuts = function(&reaper.CountActionShortcuts, 2, &.{ *KbdSectionInfo, c_int });

/// CountAutomationItems
/// Returns the number of automation items on this envelope. See GetSetAutomationItemInfo
///-- @param env *TrackEnvelope
pub const CountAutomationItems = function(&reaper.CountAutomationItems, 1, &.{*TrackEnvelope});

/// CountEnvelopePoints
/// Returns the number of points in the envelope. See CountEnvelopePointsEx.
///-- @param envelope *TrackEnvelope
pub const CountEnvelopePoints = function(&reaper.CountEnvelopePoints, 1, &.{*TrackEnvelope});

/// CountEnvelopePointsEx
/// Returns the number of points in the envelope.
/// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
/// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
/// even if the automation item is trimmed so that not all points are visible.
/// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
/// See GetEnvelopePointEx, SetEnvelopePointEx, InsertEnvelopePointEx, DeleteEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param idx c_int
pub const CountEnvelopePointsEx = function(&reaper.CountEnvelopePointsEx, 2, &.{ *TrackEnvelope, c_int });

/// CountMediaItems
/// count the number of items in the project (proj=0 for active project)
///-- @param proj *ReaProject
pub const CountMediaItems = function(&reaper.CountMediaItems, 1, &.{*ReaProject});

/// CountProjectMarkers
/// num_markersOut and num_regionsOut may be NULL.
///-- @param proj *ReaProject
///-- @param markersOut *c_int
///-- @param regionsOut *c_int
pub const CountProjectMarkers = function(&reaper.CountProjectMarkers, 3, &.{ *ReaProject, *c_int, *c_int });

/// CountSelectedMediaItems
/// count the number of selected items in the project (proj=0 for active project)
///-- @param proj *ReaProject
pub const CountSelectedMediaItems = function(&reaper.CountSelectedMediaItems, 1, &.{*ReaProject});

/// CountSelectedTracks
/// Count the number of selected tracks in the project (proj=0 for active project). This function ignores the master track, see CountSelectedTracks2.
///-- @param proj ReaProject
pub const CountSelectedTracks = function(&reaper.CountSelectedTracks, 1, &.{ReaProject});

/// CountSelectedTracks2
/// Count the number of selected tracks in the project (proj=0 for active project).
///-- @param proj *ReaProject
///-- @param wantmaster bool
pub const CountSelectedTracks2 = function(&reaper.CountSelectedTracks2, 2, &.{ *ReaProject, bool });

/// CountTakeEnvelopes
/// See GetTakeEnvelope
///-- @param take *MediaItem_Take
pub const CountTakeEnvelopes = function(&reaper.CountTakeEnvelopes, 1, &.{*MediaItem_Take});

/// CountTakes
/// count the number of takes in the item
///-- @param item *MediaItem
pub const CountTakes = function(&reaper.CountTakes, 1, &.{*MediaItem});

/// CountTCPFXParms
/// Count the number of FX parameter knobs displayed on the track control panel.
///-- @param project *ReaProject
///-- @param track MediaTrack
pub const CountTCPFXParms = function(&reaper.CountTCPFXParms, 2, &.{ *ReaProject, MediaTrack });

/// CountTempoTimeSigMarkers
/// Count the number of tempo/time signature markers in the project. See GetTempoTimeSigMarker, SetTempoTimeSigMarker, AddTempoTimeSigMarker.
///-- @param proj *ReaProject
pub const CountTempoTimeSigMarkers = function(&reaper.CountTempoTimeSigMarkers, 1, &.{*ReaProject});

/// CountTrackEnvelopes
/// see GetTrackEnvelope
///-- @param track MediaTrack
pub const CountTrackEnvelopes = function(&reaper.CountTrackEnvelopes, 1, &.{MediaTrack});

/// CountTrackMediaItems
/// count the number of items in the track
///-- @param track MediaTrack
pub const CountTrackMediaItems = function(&reaper.CountTrackMediaItems, 1, &.{MediaTrack});

/// CountTracks
/// count the number of tracks in the project (proj=0 for active project)
///-- @param projOptional ReaProject
pub const CountTracks = function(&reaper.CountTracks, 1, &.{ReaProject});

/// CreateLocalOscHandler
/// callback is a function pointer: void (*callback)(*void obj, [*:0]const u8 msg, c_int msglen), which handles OSC messages sent from REAPER. The function return is a local osc handler. See SendLocalOscMessage, DestroyOscHandler.
///-- @param obj *void
///-- @param callback *void
pub const CreateLocalOscHandler = function(&reaper.CreateLocalOscHandler, 2, &.{ *void, *void });

/// CreateMIDIInput
/// Can only reliably create midi access for devices not already opened in prefs/MIDI, suitable for control surfaces etc.
///-- @param dev c_int
pub const CreateMIDIInput = function(&reaper.CreateMIDIInput, 1, &.{c_int});

/// CreateMIDIOutput
/// Can only reliably create midi access for devices not already opened in prefs/MIDI, suitable for control surfaces etc. If streamMode is set, msoffset100 points to a persistent variable that can change and reflects added delay to output in 100ths of a millisecond.
///-- @param dev c_int
///-- @param streamMode bool
///-- @param msoffset100 ?*c_int
pub const CreateMIDIOutput = function(&reaper.CreateMIDIOutput, 3, &.{ c_int, bool, ?*c_int });

/// CreateNewMIDIItemInProj
/// Create a new MIDI media item, containing no MIDI events. Time is in seconds unless qn is set.
///-- @param track MediaTrack
///-- @param starttime f64
///-- @param endtime f64
///-- @param qnInOptional *const bool
pub const CreateNewMIDIItemInProj = function(&reaper.CreateNewMIDIItemInProj, 4, &.{ MediaTrack, f64, f64, *const bool });

/// CreateTakeAudioAccessor
/// Create an audio accessor object for this take. Must only call from the main thread. See CreateTrackAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorEndTime, GetAudioAccessorSamples.
///-- @param take *MediaItem_Take
pub const CreateTakeAudioAccessor = function(&reaper.CreateTakeAudioAccessor, 1, &.{*MediaItem_Take});

/// CreateTrackAudioAccessor
/// Create an audio accessor object for this track. Must only call from the main thread. See CreateTakeAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorEndTime, GetAudioAccessorSamples.
///-- @param track MediaTrack
pub const CreateTrackAudioAccessor = function(&reaper.CreateTrackAudioAccessor, 1, &.{MediaTrack});

/// CreateTrackSend
/// Create a send/receive (desttrInOptional!=NULL), or a hardware output (desttrInOptional==NULL) with default properties, return >=0 on success (== new send/receive index). See RemoveTrackSend, GetSetTrackSendInfo, GetTrackSendInfo_Value, SetTrackSendInfo_Value.
///-- @param tr *MediaTrack
///-- @param desttrInOptional *MediaTrack
pub const CreateTrackSend = function(&reaper.CreateTrackSend, 2, &.{ *MediaTrack, *MediaTrack });

/// CSurf_FlushUndo
/// call this to force flushing of the undo states after using *CSurf_OnChange()
///-- @param force bool
pub const CSurf_FlushUndo = function(&reaper.CSurf_FlushUndo, 1, &.{bool});

/// CSurf_GetTouchState
///-- @param trackid *MediaTrack
///-- @param isPan c_int
pub const CSurf_GetTouchState = function(&reaper.CSurf_GetTouchState, 2, &.{ *MediaTrack, c_int });

/// CSurf_GoEnd
pub const CSurf_GoEnd = function(&reaper.CSurf_GoEnd, 0, &.{});

/// CSurf_GoStart
pub const CSurf_GoStart = function(&reaper.CSurf_GoStart, 0, &.{});

/// CSurf_NumTracks
/// track count
///-- @param mcpView bool
pub const CSurf_NumTracks = function(&reaper.CSurf_NumTracks, 1, &.{bool});

/// CSurf_OnArrow
///-- @param whichdir c_int
///-- @param wantzoom bool
pub const CSurf_OnArrow = function(&reaper.CSurf_OnArrow, 2, &.{ c_int, bool });

/// CSurf_OnFwd
///-- @param seekplay c_int
pub const CSurf_OnFwd = function(&reaper.CSurf_OnFwd, 1, &.{c_int});

/// CSurf_OnFXChange
/// toggle fx chain
/// en = 0 for inactive, 1 for active
///-- @param trackid MediaTrack
///-- @param en c_int
pub const CSurf_OnFXChange = function(&reaper.CSurf_OnFXChange, 2, &.{ MediaTrack, c_int });

/// CSurf_OnInputMonitorChange
///-- @param trackid MediaTrack
///-- @param monitor c_int
pub const CSurf_OnInputMonitorChange = function(&reaper.CSurf_OnInputMonitorChange, 2, &.{ MediaTrack, c_int });

/// CSurf_OnInputMonitorChangeEx
///-- @param trackid MediaTrack
///-- @param monitor c_int
///-- @param allowgang bool
pub const CSurf_OnInputMonitorChangeEx = function(&reaper.CSurf_OnInputMonitorChangeEx, 3, &.{ MediaTrack, c_int, bool });

/// CSurf_OnMuteChange
///-- @param trackid MediaTrack
///-- @param mute c_int
pub const CSurf_OnMuteChange = function(&reaper.CSurf_OnMuteChange, 2, &.{ MediaTrack, c_int });

/// CSurf_OnMuteChangeEx
///-- @param trackid MediaTrack
///-- @param mute c_int
///-- @param allowgang bool
pub const CSurf_OnMuteChangeEx = function(&reaper.CSurf_OnMuteChangeEx, 3, &.{ MediaTrack, c_int, bool });

/// CSurf_OnOscControlMessage
///-- @param msg [*:0]const u8
///-- @param arg *const f32
pub const CSurf_OnOscControlMessage = function(&reaper.CSurf_OnOscControlMessage, 2, &.{ [*:0]const u8, *const f32 });

/// CSurf_OnOscControlMessage2
///-- @param msg [*:0]const u8
///-- @param arg *const f32
///-- @param argstr [*:0]const u8
pub const CSurf_OnOscControlMessage2 = function(&reaper.CSurf_OnOscControlMessage2, 3, &.{ [*:0]const u8, *const f32, [*:0]const u8 });

/// CSurf_OnPanChange
///-- @param trackid MediaTrack
///-- @param pan f64
///-- @param relative bool
pub const CSurf_OnPanChange = function(&reaper.CSurf_OnPanChange, 3, &.{ MediaTrack, f64, bool });

/// CSurf_OnPanChangeEx
///-- @param trackid MediaTrack
///-- @param pan f64
///-- @param relative bool
///-- @param allowGang bool
pub const CSurf_OnPanChangeEx = function(&reaper.CSurf_OnPanChangeEx, 4, &.{ MediaTrack, f64, bool, bool });

/// CSurf_OnPause
pub const CSurf_OnPause = function(&reaper.CSurf_OnPause, 0, &.{});

/// CSurf_OnPlay
pub const CSurf_OnPlay = function(&reaper.CSurf_OnPlay, 0, &.{});

/// CSurf_OnPlayRateChange
///-- @param playrate f64
pub const CSurf_OnPlayRateChange = function(&reaper.CSurf_OnPlayRateChange, 1, &.{f64});

/// CSurf_OnRecArmChange
///-- @param trackid MediaTrack
///-- @param recarm c_int
pub const CSurf_OnRecArmChange = function(&reaper.CSurf_OnRecArmChange, 2, &.{ MediaTrack, c_int });

/// CSurf_OnRecArmChangeEx
///-- @param trackid MediaTrack
///-- @param recarm c_int
///-- @param allowgang bool
pub const CSurf_OnRecArmChangeEx = function(&reaper.CSurf_OnRecArmChangeEx, 3, &.{ MediaTrack, c_int, bool });

/// CSurf_OnRecord
pub const CSurf_OnRecord = function(&reaper.CSurf_OnRecord, 0, &.{});

/// CSurf_OnRecvPanChange
///-- @param trackid MediaTrack
///-- @param index c_int
///-- @param pan f64
///-- @param relative bool
pub const CSurf_OnRecvPanChange = function(&reaper.CSurf_OnRecvPanChange, 4, &.{ MediaTrack, c_int, f64, bool });

/// CSurf_OnRecvVolumeChange
///-- @param trackid MediaTrack
///-- @param index c_int
///-- @param volume f64
///-- @param relative bool
pub const CSurf_OnRecvVolumeChange = function(&reaper.CSurf_OnRecvVolumeChange, 4, &.{ MediaTrack, c_int, f64, bool });

/// CSurf_OnRew
///-- @param seekplay c_int
pub const CSurf_OnRew = function(&reaper.CSurf_OnRew, 1, &.{c_int});

/// CSurf_OnRewFwd
///-- @param seekplay c_int
///-- @param dir c_int
pub const CSurf_OnRewFwd = function(&reaper.CSurf_OnRewFwd, 2, &.{ c_int, c_int });

/// CSurf_OnScroll
///-- @param xdir c_int
///-- @param ydir c_int
pub const CSurf_OnScroll = function(&reaper.CSurf_OnScroll, 2, &.{ c_int, c_int });

/// CSurf_OnSelectedChange
///-- @param trackid MediaTrack
///-- @param selected c_int
pub const CSurf_OnSelectedChange = function(&reaper.CSurf_OnSelectedChange, 2, &.{ MediaTrack, c_int });

/// CSurf_OnSendPanChange
///-- @param trackid MediaTrack
///-- @param index c_int
///-- @param pan f64
///-- @param relative bool
pub const CSurf_OnSendPanChange = function(&reaper.CSurf_OnSendPanChange, 4, &.{ MediaTrack, c_int, f64, bool });

/// CSurf_OnSendVolumeChange
///-- @param trackid MediaTrack
///-- @param index c_int
///-- @param volume f64
///-- @param relative bool
pub const CSurf_OnSendVolumeChange = function(&reaper.CSurf_OnSendVolumeChange, 4, &.{ MediaTrack, c_int, f64, bool });

/// CSurf_OnSoloChange
///-- @param trackid MediaTrack
///-- @param solo c_int
pub const CSurf_OnSoloChange = function(&reaper.CSurf_OnSoloChange, 2, &.{ MediaTrack, c_int });

/// CSurf_OnSoloChangeEx
///-- @param trackid MediaTrack
///-- @param solo c_int
///-- @param allowgang bool
pub const CSurf_OnSoloChangeEx = function(&reaper.CSurf_OnSoloChangeEx, 3, &.{ MediaTrack, c_int, bool });

/// CSurf_OnStop
pub const CSurf_OnStop = function(&reaper.CSurf_OnStop, 0, &.{});

/// CSurf_OnTempoChange
///-- @param bpm f64
pub const CSurf_OnTempoChange = function(&reaper.CSurf_OnTempoChange, 1, &.{f64});

/// CSurf_OnTrackSelection
///-- @param trackid MediaTrack
pub const CSurf_OnTrackSelection = function(&reaper.CSurf_OnTrackSelection, 1, &.{MediaTrack});

/// CSurf_OnVolumeChange
///-- @param trackid MediaTrack
///-- @param volume f64
///-- @param relative bool
pub const CSurf_OnVolumeChange = function(&reaper.CSurf_OnVolumeChange, 3, &.{ MediaTrack, f64, bool });

/// CSurf_OnVolumeChangeEx
///-- @param trackid MediaTrack
///-- @param volume f64
///-- @param relative bool
///-- @param allowGang bool
pub const CSurf_OnVolumeChangeEx = function(&reaper.CSurf_OnVolumeChangeEx, 4, &.{ MediaTrack, f64, bool, bool });

/// CSurf_OnWidthChange
///-- @param trackid MediaTrack
///-- @param width f64
///-- @param relative bool
pub const CSurf_OnWidthChange = function(&reaper.CSurf_OnWidthChange, 3, &.{ MediaTrack, f64, bool });

/// CSurf_OnWidthChangeEx
///-- @param trackid MediaTrack
///-- @param width f64
///-- @param relative bool
///-- @param allowGang bool
pub const CSurf_OnWidthChangeEx = function(&reaper.CSurf_OnWidthChangeEx, 4, &.{ MediaTrack, f64, bool, bool });

/// CSurf_OnZoom
///-- @param xdir c_int
///-- @param ydir c_int
pub const CSurf_OnZoom = function(&reaper.CSurf_OnZoom, 2, &.{ c_int, c_int });

/// CSurf_ResetAllCachedVolPanStates
pub const CSurf_ResetAllCachedVolPanStates = function(&reaper.CSurf_ResetAllCachedVolPanStates, 0, &.{});

/// CSurf_ScrubAmt
///-- @param amt f64
pub const CSurf_ScrubAmt = function(&reaper.CSurf_ScrubAmt, 1, &.{f64});

/// CSurf_SetAutoMode
///-- @param mode c_int
///-- @param ignoresurf *IReaperControlSurface
pub const CSurf_SetAutoMode = function(&reaper.CSurf_SetAutoMode, 2, &.{ c_int, *IReaperControlSurface });

/// CSurf_SetPlayState
///-- @param play bool
///-- @param pause bool
///-- @param rec bool
///-- @param ignoresurf *IReaperControlSurface
pub const CSurf_SetPlayState = function(&reaper.CSurf_SetPlayState, 4, &.{ bool, bool, bool, *IReaperControlSurface });

/// CSurf_SetRepeatState
///-- @param rep bool
///-- @param ignoresurf *IReaperControlSurface
pub const CSurf_SetRepeatState = function(&reaper.CSurf_SetRepeatState, 2, &.{ bool, *IReaperControlSurface });

/// CSurf_SetSurfaceMute
///-- @param trackid MediaTrack
///-- @param mute bool
///-- @param ignoresurf ?IReaperControlSurface
pub const CSurf_SetSurfaceMute = function(&reaper.CSurf_SetSurfaceMute, 3, &.{ MediaTrack, bool, ?IReaperControlSurface });

/// CSurf_SetSurfacePan
///-- @param trackid MediaTrack
///-- @param pan f64
///-- @param ignoresurf ?IReaperControlSurface
pub const CSurf_SetSurfacePan = function(&reaper.CSurf_SetSurfacePan, 3, &.{ MediaTrack, f64, ?IReaperControlSurface });

/// CSurf_SetSurfaceRecArm
///-- @param trackid MediaTrack
///-- @param recarm bool
///-- @param ignoresurf ?IReaperControlSurface
pub const CSurf_SetSurfaceRecArm = function(&reaper.CSurf_SetSurfaceRecArm, 3, &.{ MediaTrack, bool, ?IReaperControlSurface });

/// CSurf_SetSurfaceSelected
///-- @param trackid MediaTrack
///-- @param selected bool
///-- @param ignoresurf IReaperControlSurface
pub const CSurf_SetSurfaceSelected = function(&reaper.CSurf_SetSurfaceSelected, 3, &.{ MediaTrack, bool, IReaperControlSurface });

/// CSurf_SetSurfaceSolo
///-- @param trackid MediaTrack
///-- @param solo bool
///-- @param ignoresurf ?IReaperControlSurface
pub const CSurf_SetSurfaceSolo = function(&reaper.CSurf_SetSurfaceSolo, 3, &.{ MediaTrack, bool, ?IReaperControlSurface });

/// CSurf_SetSurfaceVolume
///-- @param trackid MediaTrack
///-- @param volume f64
///-- @param ignoresurf ?IReaperControlSurface
pub const CSurf_SetSurfaceVolume = function(&reaper.CSurf_SetSurfaceVolume, 3, &.{ MediaTrack, f64, ?IReaperControlSurface });

/// CSurf_SetTrackListChange
pub const CSurf_SetTrackListChange = function(&reaper.CSurf_SetTrackListChange, 0, &.{});

/// CSurf_TrackFromID
///-- @param idx c_int
///-- @param mcpView bool
pub const CSurf_TrackFromID = function(&reaper.CSurf_TrackFromID, 2, &.{ c_int, bool });

/// CSurf_TrackToID
///-- @param track MediaTrack
///-- @param mcpView bool
pub const CSurf_TrackToID = function(&reaper.CSurf_TrackToID, 2, &.{ MediaTrack, bool });

/// DB2SLIDER
///-- @param x f64
pub const DB2SLIDER = function(&reaper.DB2SLIDER, 1, &.{f64});

/// DeleteActionShortcut
/// Delete the specific shortcut for the given command ID.
/// See CountActionShortcuts, GetActionShortcutDesc, DoActionShortcutDialog.
///-- @param section *KbdSectionInfo
///-- @param cmdID c_int
///-- @param shortcutidx c_int
pub const DeleteActionShortcut = function(&reaper.DeleteActionShortcut, 3, &.{ *KbdSectionInfo, c_int, c_int });

/// DeleteEnvelopePointEx
/// Delete an envelope point. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done.
/// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
/// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
/// even if the automation item is trimmed so that not all points are visible.
/// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
/// See CountEnvelopePointsEx, GetEnvelopePointEx, SetEnvelopePointEx, InsertEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param idx c_int
///-- @param ptidx c_int
pub const DeleteEnvelopePointEx = function(&reaper.DeleteEnvelopePointEx, 3, &.{ *TrackEnvelope, c_int, c_int });

/// DeleteEnvelopePointRange
/// Delete a range of envelope points. See DeleteEnvelopePointRangeEx, DeleteEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param start f64
///-- @param end f64
pub const DeleteEnvelopePointRange = function(&reaper.DeleteEnvelopePointRange, 3, &.{ *TrackEnvelope, f64, f64 });

/// DeleteEnvelopePointRangeEx
/// Delete a range of envelope points. autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
///-- @param envelope *TrackEnvelope
///-- @param idx c_int
///-- @param start f64
///-- @param end f64
pub const DeleteEnvelopePointRangeEx = function(&reaper.DeleteEnvelopePointRangeEx, 4, &.{ *TrackEnvelope, c_int, f64, f64 });

/// DeleteExtState
/// Delete the extended state value for a specific section and key. persist=true means the value should remain deleted the next time REAPER is opened. See SetExtState, GetExtState, HasExtState.
///-- @param section [*:0]const u8
///-- @param key [*:0]const u8
///-- @param persist bool
pub const DeleteExtState = function(&reaper.DeleteExtState, 3, &.{ [*:0]const u8, [*:0]const u8, bool });

/// DeleteProjectMarker
/// Delete a marker.  proj==NULL for the active project.
///-- @param proj *ReaProject
///-- @param markrgnindexnumber c_int
///-- @param isrgn bool
pub const DeleteProjectMarker = function(&reaper.DeleteProjectMarker, 3, &.{ *ReaProject, c_int, bool });

/// DeleteProjectMarkerByIndex
/// Differs from DeleteProjectMarker only in that markrgnidx is 0 for the first marker/region, 1 for the next, etc (see EnumProjectMarkers3), rather than representing the displayed marker/region ID number (see SetProjectMarker4).
///-- @param proj *ReaProject
///-- @param markrgnidx c_int
pub const DeleteProjectMarkerByIndex = function(&reaper.DeleteProjectMarkerByIndex, 2, &.{ *ReaProject, c_int });

/// DeleteTakeMarker
/// Delete a take marker. Note that idx will change for all following take markers. See GetNumTakeMarkers, GetTakeMarker, SetTakeMarker
///-- @param take *MediaItem_Take
///-- @param idx c_int
pub const DeleteTakeMarker = function(&reaper.DeleteTakeMarker, 2, &.{ *MediaItem_Take, c_int });

/// DeleteTakeStretchMarkers
/// Deletes one or more stretch markers. Returns number of stretch markers deleted.
///-- @param take *MediaItem_Take
///-- @param idx c_int
///-- @param countInOptional *const c_int
pub const DeleteTakeStretchMarkers = function(&reaper.DeleteTakeStretchMarkers, 3, &.{ *MediaItem_Take, c_int, *const c_int });

/// DeleteTempoTimeSigMarker
/// Delete a tempo/time signature marker.
///-- @param project *ReaProject
///-- @param markerindex c_int
pub const DeleteTempoTimeSigMarker = function(&reaper.DeleteTempoTimeSigMarker, 2, &.{ *ReaProject, c_int });

/// DeleteTrack
/// deletes a track
///-- @param tr MediaTrack
pub const DeleteTrack = function(&reaper.DeleteTrack, 1, &.{MediaTrack});

/// DeleteTrackMediaItem
///-- @param tr *MediaTrack
///-- @param it *MediaItem
pub const DeleteTrackMediaItem = function(&reaper.DeleteTrackMediaItem, 2, &.{ *MediaTrack, *MediaItem });

/// DestroyAudioAccessor
/// Destroy an audio accessor. Must only call from the main thread. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorEndTime, GetAudioAccessorSamples.
///-- @param accessor *AudioAccessor
pub const DestroyAudioAccessor = function(&reaper.DestroyAudioAccessor, 1, &.{*AudioAccessor});

/// DestroyLocalOscHandler
/// See CreateLocalOscHandler, SendLocalOscMessage.
///-- @param handler *void
pub const DestroyLocalOscHandler = function(&reaper.DestroyLocalOscHandler, 1, &.{*void});

/// DoActionShortcutDialog
/// Open the action shortcut dialog to edit or add a shortcut for the given command ID. If (shortcutidx >= 0 && shortcutidx < CountActionShortcuts()), that specific shortcut will be replaced, otherwise a new shortcut will be added.
/// See CountActionShortcuts, GetActionShortcutDesc, DeleteActionShortcut.
///-- @param hwnd HWND
///-- @param section *KbdSectionInfo
///-- @param cmdID c_int
///-- @param shortcutidx c_int
pub const DoActionShortcutDialog = function(&reaper.DoActionShortcutDialog, 4, &.{ HWND, *KbdSectionInfo, c_int, c_int });

/// Dock_UpdateDockID
/// updates preference for docker window ident_str to be in dock whichDock on next open
///-- @param str [*:0]const u8
///-- @param whichDock c_int
pub const Dock_UpdateDockID = function(&reaper.Dock_UpdateDockID, 2, &.{ [*:0]const u8, c_int });

/// DockGetPosition
/// -1=not found, 0=bottom, 1=left, 2=top, 3=right, 4=f32ing
///-- @param whichDock c_int
pub const DockGetPosition = function(&reaper.DockGetPosition, 1, &.{c_int});

/// DockIsChildOfDock
/// returns dock index that contains hwnd, or -1
///-- @param hwnd HWND
///-- @param isFloatingDockerOut *bool
pub const DockIsChildOfDock = function(&reaper.DockIsChildOfDock, 2, &.{ HWND, *bool });

/// DockWindowActivate
///-- @param hwnd HWND
pub const DockWindowActivate = function(&reaper.DockWindowActivate, 1, &.{HWND});

/// DockWindowAdd
///-- @param hwnd HWND
///-- @param name [*:0]const u8
///-- @param pos c_int
///-- @param allowShow bool
pub const DockWindowAdd = function(&reaper.DockWindowAdd, 4, &.{ HWND, [*:0]const u8, c_int, bool });

/// DockWindowAddEx
///-- @param hwnd HWND
///-- @param name [*:0]const u8
///-- @param identstr [*:0]const u8
///-- @param allowShow bool
pub const DockWindowAddEx = function(&reaper.DockWindowAddEx, 4, &.{ HWND, [*:0]const u8, [*:0]const u8, bool });

/// DockWindowRefresh
pub const DockWindowRefresh = function(&reaper.DockWindowRefresh, 0, &.{});

/// DockWindowRefreshForHWND
///-- @param hwnd HWND
pub const DockWindowRefreshForHWND = function(&reaper.DockWindowRefreshForHWND, 1, &.{HWND});

/// DockWindowRemove
///-- @param hwnd HWND
pub const DockWindowRemove = function(&reaper.DockWindowRemove, 1, &.{HWND});

/// DuplicateCustomizableMenu
/// Populate destmenu with all the entries and submenus found in srcmenu
///-- @param srcmenu *void
///-- @param destmenu *void
pub const DuplicateCustomizableMenu = function(&reaper.DuplicateCustomizableMenu, 2, &.{ *void, *void });

/// EditTempoTimeSigMarker
/// Open the tempo/time signature marker editor dialog.
///-- @param project *ReaProject
///-- @param markerindex c_int
pub const EditTempoTimeSigMarker = function(&reaper.EditTempoTimeSigMarker, 2, &.{ *ReaProject, c_int });

/// EnsureNotCompletelyOffscreen
/// call with a saved window rect for your window and it'll correct any positioning info.
///-- @param rInOut *RECT
pub const EnsureNotCompletelyOffscreen = function(&reaper.EnsureNotCompletelyOffscreen, 1, &.{*RECT});

/// EnumerateFiles
/// List the files in the "path" directory. Returns NULL/nil when all files have been listed. Use fileindex = -1 to force re-read of directory (invalidate cache). See EnumerateSubdirectories
///-- @param path [*:0]const u8
///-- @param fileindex c_int
pub const EnumerateFiles = function(&reaper.EnumerateFiles, 2, &.{ [*:0]const u8, c_int });

/// EnumerateSubdirectories
/// List the subdirectories in the "path" directory. Use subdirindex = -1 to force re-read of directory (invalidate cache). Returns NULL/nil when all subdirectories have been listed. See EnumerateFiles
///-- @param path [*:0]const u8
///-- @param subdirindex c_int
pub const EnumerateSubdirectories = function(&reaper.EnumerateSubdirectories, 2, &.{ [*:0]const u8, c_int });

/// EnumInstalledFX
/// Enumerates installed FX. Returns true if successful, sets nameOut and identOut to name and ident of FX at index.
///-- @param index c_int
///-- @param nameOut *[*:0]const u8
///-- @param identOut *[*:0]const u8
pub const EnumInstalledFX = function(&reaper.EnumInstalledFX, 3, &.{ c_int, *[*:0]const u8, *[*:0]const u8 });

/// EnumPitchShiftModes
/// Start querying modes at 0, returns FALSE when no more modes possible, sets strOut to NULL if a mode is currently unsupported
///-- @param mode c_int
///-- @param strOut [*:0]const u8
pub const EnumPitchShiftModes = function(&reaper.EnumPitchShiftModes, 2, &.{ c_int, [*:0]const u8 });

/// EnumPitchShiftSubModes
/// Returns submode name, or NULL
///-- @param mode c_int
///-- @param submode c_int
pub const EnumPitchShiftSubModes = function(&reaper.EnumPitchShiftSubModes, 2, &.{ c_int, c_int });

/// EnumProjectMarkers
///-- @param idx c_int
///-- @param isrgnOut *bool
///-- @param posOut *f64
///-- @param rgnendOut *f64
///-- @param nameOut [*:0]const u8
///-- @param markrgnindexnumberOut *c_int
pub const EnumProjectMarkers = function(&reaper.EnumProjectMarkers, 6, &.{ c_int, *bool, *f64, *f64, [*:0]const u8, *c_int });

/// EnumProjectMarkers2
///-- @param proj *ReaProject
///-- @param idx c_int
///-- @param isrgnOut *bool
///-- @param posOut *f64
///-- @param rgnendOut *f64
///-- @param nameOut [*:0]const u8
///-- @param markrgnindexnumberOut *c_int
pub const EnumProjectMarkers2 = function(&reaper.EnumProjectMarkers2, 7, &.{ *ReaProject, c_int, *bool, *f64, *f64, [*:0]const u8, *c_int });

/// EnumProjectMarkers3
///-- @param proj *ReaProject
///-- @param idx c_int
///-- @param isrgnOut *bool
///-- @param posOut *f64
///-- @param rgnendOut *f64
///-- @param nameOut [*:0]const u8
///-- @param markrgnindexnumberOut *c_int
///-- @param colorOut *c_int
pub const EnumProjectMarkers3 = function(&reaper.EnumProjectMarkers3, 8, &.{ *ReaProject, c_int, *bool, *f64, *f64, [*:0]const u8, *c_int, *c_int });

/// EnumProjects
/// idx=-1 for current project,projfn can be NULL if not interested in filename. use idx 0x40000000 for currently rendering project, if any.
///-- @param idx c_int
///-- @param projfnOutOptional ?*c_char
pub const EnumProjects = function(&reaper.EnumProjects, 2, &.{ c_int, ?*c_char });

/// EnumProjExtState
/// Enumerate the data stored with the project for a specific extname. Returns false when there is no more data. See SetProjExtState, GetProjExtState.
///-- @param proj *ReaProject
///-- @param extname [*:0]const u8
///-- @param idx c_int
///-- @param keyOutOptional *c_char
///-- @param sz c_int
///-- @param valOutOptional *c_char
///-- @param sz c_int
pub const EnumProjExtState = function(&reaper.EnumProjExtState, 7, &.{ *ReaProject, [*:0]const u8, c_int, *c_char, c_int, *c_char, c_int });

/// EnumRegionRenderMatrix
/// Enumerate which tracks will be rendered within this region when using the region render matrix. When called with rendertrack==0, the function returns the first track that will be rendered (which may be the master track); rendertrack==1 will return the next track rendered, and so on. The function returns NULL when there are no more tracks that will be rendered within this region.
///-- @param proj *ReaProject
///-- @param regionindex c_int
///-- @param rendertrack c_int
pub const EnumRegionRenderMatrix = function(&reaper.EnumRegionRenderMatrix, 3, &.{ *ReaProject, c_int, c_int });

/// EnumTrackMIDIProgramNames
/// returns false if there are no plugins on the track that support MIDI programs,or if all programs have been enumerated
///-- @param track c_int
///-- @param programNumber c_int
///-- @param programName *c_char
///-- @param sz c_int
pub const EnumTrackMIDIProgramNames = function(&reaper.EnumTrackMIDIProgramNames, 4, &.{ c_int, c_int, *c_char, c_int });

/// EnumTrackMIDIProgramNamesEx
/// returns false if there are no plugins on the track that support MIDI programs,or if all programs have been enumerated
///-- @param proj *ReaProject
///-- @param track MediaTrack
///-- @param programNumber c_int
///-- @param programName *c_char
///-- @param sz c_int
pub const EnumTrackMIDIProgramNamesEx = function(&reaper.EnumTrackMIDIProgramNamesEx, 5, &.{ *ReaProject, MediaTrack, c_int, *c_char, c_int });

/// Envelope_Evaluate
/// Get the effective envelope value at a given time position. samplesRequested is how long the caller expects until the next call to Envelope_Evaluate (often, the buffer block size). The return value is how many samples beyond that time position that the returned values are valid. dVdS is the change in value per sample (first derivative), ddVdS is the second derivative, dddVdS is the third derivative. See GetEnvelopeScalingMode.
///-- @param envelope *TrackEnvelope
///-- @param time f64
///-- @param samplerate f64
///-- @param samplesRequested c_int
///-- @param valueOut *f64
///-- @param dVdSOut *f64
///-- @param ddVdSOut *f64
///-- @param dddVdSOut *f64
pub const Envelope_Evaluate = function(&reaper.Envelope_Evaluate, 8, &.{ *TrackEnvelope, f64, f64, c_int, *f64, *f64, *f64, *f64 });

/// Envelope_FormatValue
/// Formats the value of an envelope to a user-readable form
///-- @param env *TrackEnvelope
///-- @param value f64
///-- @param bufOut *c_char
///-- @param sz c_int
pub const Envelope_FormatValue = function(&reaper.Envelope_FormatValue, 4, &.{ *TrackEnvelope, f64, *c_char, c_int });

/// Envelope_GetParentTake
/// If take envelope, gets the take from the envelope. If FX, indexOut set to FX index, index2Out set to parameter index, otherwise -1.
///-- @param env *TrackEnvelope
///-- @param indexOut *c_int
///-- @param index2Out *c_int
pub const Envelope_GetParentTake = function(&reaper.Envelope_GetParentTake, 3, &.{ *TrackEnvelope, *c_int, *c_int });

/// Envelope_GetParentTrack
/// If track envelope, gets the track from the envelope. If FX, indexOut set to FX index, index2Out set to parameter index, otherwise -1.
///-- @param env *TrackEnvelope
///-- @param indexOut *c_int
///-- @param index2Out *c_int
pub const Envelope_GetParentTrack = function(&reaper.Envelope_GetParentTrack, 3, &.{ *TrackEnvelope, *c_int, *c_int });

/// Envelope_SortPoints
/// Sort envelope points by time. See SetEnvelopePoint, InsertEnvelopePoint.
///-- @param envelope *TrackEnvelope
pub const Envelope_SortPoints = function(&reaper.Envelope_SortPoints, 1, &.{*TrackEnvelope});

/// Envelope_SortPointsEx
/// Sort envelope points by time. autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc. See SetEnvelopePoint, InsertEnvelopePoint.
///-- @param envelope *TrackEnvelope
///-- @param idx c_int
pub const Envelope_SortPointsEx = function(&reaper.Envelope_SortPointsEx, 2, &.{ *TrackEnvelope, c_int });

/// ExecProcess
/// Executes command line, returns NULL on total failure, otherwise the return value, a newline, and then the output of the command. If timeoutmsec is 0, command will be allowed to run indefinitely (recommended for large amounts of returned output). timeoutmsec is -1 for no wait/terminate, -2 for no wait and minimize
///-- @param cmdline [*:0]const u8
///-- @param timeoutmsec c_int
pub const ExecProcess = function(&reaper.ExecProcess, 2, &.{ [*:0]const u8, c_int });

/// file_exists
/// returns true if path points to a valid, readable file
///-- @param path [*:0]const u8
pub const file_exists = function(&reaper.file_exists, 1, &.{[*:0]const u8});

/// FindTempoTimeSigMarker
/// Find the tempo/time signature marker that falls at or before this time position (the marker that is in effect as of this time position).
///-- @param project *ReaProject
///-- @param time f64
pub const FindTempoTimeSigMarker = function(&reaper.FindTempoTimeSigMarker, 2, &.{ *ReaProject, f64 });

/// format_timestr
/// Format tpos (which is time in seconds) as hh:mm:ss.sss. See format_timestr_pos, format_timestr_len.
///-- @param tpos f64
///-- @param buf *c_char
///-- @param sz c_int
pub const format_timestr = function(&reaper.format_timestr, 3, &.{ f64, *c_char, c_int });

/// format_timestr_len
/// time formatting mode overrides: -1=proj default.
/// 0=time
/// 1=measures.beats + time
/// 2=measures.beats
/// 3=seconds
/// 4=samples
/// 5=h:m:s:f
/// offset is start of where the length will be calculated from
///-- @param tpos f64
///-- @param buf *c_char
///-- @param sz c_int
///-- @param offset f64
///-- @param modeoverride c_int
pub const format_timestr_len = function(&reaper.format_timestr_len, 5, &.{ f64, *c_char, c_int, f64, c_int });

/// format_timestr_pos
/// time formatting mode overrides: -1=proj default.
/// 0=time
/// 1=measures.beats + time
/// 2=measures.beats
/// 3=seconds
/// 4=samples
/// 5=h:m:s:f
///
///-- @param tpos f64
///-- @param buf *c_char
///-- @param sz c_int
///-- @param modeoverride c_int
pub const format_timestr_pos = function(&reaper.format_timestr_pos, 4, &.{ f64, *c_char, c_int, c_int });

/// FreeHeapPtr
/// free heap memory returned from a Reaper API function
///-- @param ptr *void
pub const FreeHeapPtr = function(&reaper.FreeHeapPtr, 1, &.{*void});

/// genGuid
///-- @param g *GUID
pub const genGuid = function(&reaper.genGuid, 1, &.{*GUID});

/// get_config_var
/// gets ini configuration variable by name, raw, returns size of variable in szOut and pointer to variable. special values queryable are also:
///   __numcpu (c_int) cpu count.
///   __fx_loadstate_ctx (c_char): 0 if unknown, or during FX state loading: 'u' (instantiating via undo), 'U' (updating via undo), 'P' (loading preset).
///-- @param name [*:0]const u8
///-- @param szOut *c_int
pub const get_config_var = function(&reaper.get_config_var, 2, &.{ [*:0]const u8, *c_int });

/// get_config_var_string
/// gets ini configuration variable value as string
///-- @param name [*:0]const u8
///-- @param bufOut *c_char
///-- @param sz c_int
pub const get_config_var_string = function(&reaper.get_config_var_string, 3, &.{ [*:0]const u8, *c_char, c_int });

/// get_ini_file
/// Get reaper.ini full filename.
pub const get_ini_file = function(&reaper.get_ini_file, 0, &.{});

/// get_midi_config_var
/// Deprecated.
///-- @param name [*:0]const u8
///-- @param szOut *c_int
pub const get_midi_config_var = function(&reaper.get_midi_config_var, 2, &.{ [*:0]const u8, *c_int });

/// GetActionShortcutDesc
/// Get the text description of a specific shortcut for the given command ID.
/// See CountActionShortcuts,DeleteActionShortcut,DoActionShortcutDialog.
///-- @param section *KbdSectionInfo
///-- @param cmdID c_int
///-- @param shortcutidx c_int
///-- @param descOut *c_char
///-- @param sz c_int
pub const GetActionShortcutDesc = function(&reaper.GetActionShortcutDesc, 5, &.{ *KbdSectionInfo, c_int, c_int, *c_char, c_int });

/// GetActiveTake
/// get the active take in this item
///-- @param item *MediaItem
pub const GetActiveTake = function(&reaper.GetActiveTake, 1, &.{*MediaItem});

/// GetAllProjectPlayStates
/// returns the bitwise OR of all project play states (1=playing, 2=pause, 4=recording)
///-- @param ignoreProject *ReaProject
pub const GetAllProjectPlayStates = function(&reaper.GetAllProjectPlayStates, 1, &.{*ReaProject});

/// GetAppVersion
/// Returns app version which may include an OS/arch signifier, such as: "6.17" (windows 32-bit), "6.17/x64" (windows 64-bit), "6.17/OSX64" (macOS 64-bit Intel), "6.17/OSX" (macOS 32-bit), "6.17/macOS-arm64", "6.17/linux-x86_64", "6.17/linux-i686", "6.17/linux-aarch64", "6.17/linux-armv7l", etc
pub const GetAppVersion = function(&reaper.GetAppVersion, 0, &.{});

/// GetArmedCommand
/// gets the currently armed command and section name (returns 0 if nothing armed). section name is empty-string for main section.
///-- @param secOut *c_char
///-- @param sz c_int
pub const GetArmedCommand = function(&reaper.GetArmedCommand, 2, &.{ *c_char, c_int });

/// GetAudioAccessorEndTime
/// Get the end time of the audio that can be returned from this accessor. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorStartTime, GetAudioAccessorSamples.
///-- @param accessor *AudioAccessor
pub const GetAudioAccessorEndTime = function(&reaper.GetAudioAccessorEndTime, 1, &.{*AudioAccessor});

/// GetAudioAccessorHash
/// Deprecated. See AudioAccessorStateChanged instead.
///-- @param accessor *AudioAccessor
///-- @param hashNeed128 *c_char
pub const GetAudioAccessorHash = function(&reaper.GetAudioAccessorHash, 2, &.{ *AudioAccessor, *c_char });

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
///-- @param accessor *AudioAccessor
///-- @param samplerate c_int
///-- @param numchannels c_int
///-- @param sec f64
///-- @param numsamplesperchannel c_int
///-- @param samplebuffer *f64
pub const GetAudioAccessorSamples = function(&reaper.GetAudioAccessorSamples, 6, &.{ *AudioAccessor, c_int, c_int, f64, c_int, *f64 });

/// GetAudioAccessorStartTime
/// Get the start time of the audio that can be returned from this accessor. See CreateTakeAudioAccessor, CreateTrackAudioAccessor, DestroyAudioAccessor, AudioAccessorStateChanged, GetAudioAccessorEndTime, GetAudioAccessorSamples.
///-- @param accessor *AudioAccessor
pub const GetAudioAccessorStartTime = function(&reaper.GetAudioAccessorStartTime, 1, &.{*AudioAccessor});

/// GetAudioDeviceInfo
/// get information about the currently open audio device. attribute can be MODE, IDENT_IN, IDENT_OUT, BSIZE, SRATE, BPS. returns false if unknown attribute or device not open.
///-- @param attribute [*:0]const u8
///-- @param descOut *c_char
///-- @param sz c_int
pub const GetAudioDeviceInfo = function(&reaper.GetAudioDeviceInfo, 3, &.{ [*:0]const u8, *c_char, c_int });

/// GetColorTheme
/// Deprecated, see GetColorThemeStruct.
// GetColorTheme: *fn(idx: c_int, defval:  c_int) callconv(.C) c_int_PTR ,

/// GetColorThemeStruct
/// returns the whole color theme (icontheme.h) and the size
///-- @param szOut *c_int
pub const GetColorThemeStruct = function(&reaper.GetColorThemeStruct, 1, &.{*c_int});

/// GetConfigWantsDock
/// gets the dock ID desired by ident_str, if any
///-- @param str [*:0]const u8
pub const GetConfigWantsDock = function(&reaper.GetConfigWantsDock, 1, &.{[*:0]const u8});

/// GetContextMenu
/// gets context menus. submenu 0:trackctl, 1:mediaitems, 2:ruler, 3:empty track area
///-- @param idx c_int
pub const GetContextMenu = function(&reaper.GetContextMenu, 1, &.{c_int});

/// GetCurrentProjectInLoadSave
/// returns current project if in load/save (usually only used from project_config_extension_t)
pub const GetCurrentProjectInLoadSave = function(&reaper.GetCurrentProjectInLoadSave, 0, &.{});

/// GetCursorContext
/// return the current cursor context: 0 if track panels, 1 if items, 2 if envelopes, otherwise unknown
pub const GetCursorContext = function(&reaper.GetCursorContext, 0, &.{});

/// GetCursorContext2
/// 0 if track panels, 1 if items, 2 if envelopes, otherwise unknown (unlikely when want_last_valid is true)
///-- @param valid bool
pub const GetCursorContext2 = function(&reaper.GetCursorContext2, 1, &.{bool});

/// GetCursorPosition
/// edit cursor position
pub const GetCursorPosition = function(&reaper.GetCursorPosition, 0, &.{});

/// GetCursorPositionEx
/// edit cursor position
///-- @param proj *ReaProject
pub const GetCursorPositionEx = function(&reaper.GetCursorPositionEx, 1, &.{*ReaProject});

/// GetDisplayedMediaItemColor
/// see GetDisplayedMediaItemColor2.
///-- @param item *MediaItem
pub const GetDisplayedMediaItemColor = function(&reaper.GetDisplayedMediaItemColor, 1, &.{*MediaItem});

/// GetDisplayedMediaItemColor2
/// Returns the custom take, item, or track color that is used (according to the user preference) to color the media item. The returned color is OS dependent|0x01000000 (i.e. ColorToNative(r,g,b)|0x01000000), so a return of zero means "no color", not black.
///-- @param item *MediaItem
///-- @param take *MediaItem_Take
pub const GetDisplayedMediaItemColor2 = function(&reaper.GetDisplayedMediaItemColor2, 2, &.{ *MediaItem, *MediaItem_Take });

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
///-- @param env *TrackEnvelope
///-- @param parmname [*:0]const u8
pub const GetEnvelopeInfo_Value = function(&reaper.GetEnvelopeInfo_Value, 2, &.{ *TrackEnvelope, [*:0]const u8 });

/// GetEnvelopeName
///-- @param env *TrackEnvelope
///-- @param bufOut *c_char
///-- @param sz c_int
pub const GetEnvelopeName = function(&reaper.GetEnvelopeName, 3, &.{ *TrackEnvelope, *c_char, c_int });

/// GetEnvelopePoint
/// Get the attributes of an envelope point. See GetEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param ptidx c_int
///-- @param timeOut *f64
///-- @param valueOut *f64
///-- @param shapeOut *c_int
///-- @param tensionOut *f64
///-- @param selectedOut *bool
pub const GetEnvelopePoint = function(&reaper.GetEnvelopePoint, 7, &.{ *TrackEnvelope, c_int, *f64, *f64, *c_int, *f64, *bool });

/// GetEnvelopePointByTime
/// Returns the envelope point at or immediately prior to the given time position. See GetEnvelopePointByTimeEx.
///-- @param envelope *TrackEnvelope
///-- @param time f64
pub const GetEnvelopePointByTime = function(&reaper.GetEnvelopePointByTime, 2, &.{ *TrackEnvelope, f64 });

/// GetEnvelopePointByTimeEx
/// Returns the envelope point at or immediately prior to the given time position.
/// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
/// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
/// even if the automation item is trimmed so that not all points are visible.
/// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
/// See GetEnvelopePointEx, SetEnvelopePointEx, InsertEnvelopePointEx, DeleteEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param idx c_int
///-- @param time f64
pub const GetEnvelopePointByTimeEx = function(&reaper.GetEnvelopePointByTimeEx, 3, &.{ *TrackEnvelope, c_int, f64 });

/// GetEnvelopePointEx
/// Get the attributes of an envelope point.
/// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
/// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
/// even if the automation item is trimmed so that not all points are visible.
/// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
/// See CountEnvelopePointsEx, SetEnvelopePointEx, InsertEnvelopePointEx, DeleteEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param idx c_int
///-- @param ptidx c_int
///-- @param timeOut *f64
///-- @param valueOut *f64
///-- @param shapeOut *c_int
///-- @param tensionOut *f64
///-- @param selectedOut *bool
pub const GetEnvelopePointEx = function(&reaper.GetEnvelopePointEx, 8, &.{ *TrackEnvelope, c_int, c_int, *f64, *f64, *c_int, *f64, *bool });

/// GetEnvelopeScalingMode
/// Returns the envelope scaling mode: 0=no scaling, 1=fader scaling. All API functions deal with raw envelope point values, to convert raw from/to scaled values see ScaleFromEnvelopeMode, ScaleToEnvelopeMode.
///-- @param env *TrackEnvelope
pub const GetEnvelopeScalingMode = function(&reaper.GetEnvelopeScalingMode, 1, &.{*TrackEnvelope});

/// GetEnvelopeStateChunk
/// Gets the RPPXML state of an envelope, returns true if successful. Undo flag is a performance/caching hint.
///-- @param env *TrackEnvelope
///-- @param strNeedBig *c_char
///-- @param sz c_int
///-- @param isundoOptional bool
pub const GetEnvelopeStateChunk = function(&reaper.GetEnvelopeStateChunk, 4, &.{ *TrackEnvelope, *c_char, c_int, bool });

/// GetEnvelopeUIState
/// gets information on the UI state of an envelope: returns &1 if automation/modulation is playing back, &2 if automation is being actively written, &4 if the envelope recently had an effective automation mode change
///-- @param env *TrackEnvelope
pub const GetEnvelopeUIState = function(&reaper.GetEnvelopeUIState, 1, &.{*TrackEnvelope});

/// GetExePath
/// returns path of REAPER.exe (not including EXE), i.e. C:\Program Files\REAPER
pub const GetExePath = function(&reaper.GetExePath, 0, &.{});

/// GetExtState
/// Get the extended state value for a specific section and key. See SetExtState, DeleteExtState, HasExtState.
///-- @param section [*:0]const u8
///-- @param key [*:0]const u8
pub const GetExtState = function(&reaper.GetExtState, 2, &.{ [*:0]const u8, [*:0]const u8 });

/// GetFocusedFX
/// This function is deprecated (returns GetFocusedFX2()&3), see GetTouchedOrFocusedFX.
///-- @param tracknumberOut *c_int
///-- @param itemnumberOut *c_int
///-- @param fxnumberOut *c_int
pub const GetFocusedFX = function(&reaper.GetFocusedFX, 3, &.{ *c_int, *c_int, *c_int });

/// GetFocusedFX2
/// Return value has 1 set if track FX, 2 if take/item FX, 4 set if FX is no longer focused but still open. tracknumber==0 means the master track, 1 means track 1, etc. itemnumber is zero-based (or -1 if not an item). For interpretation of fxnumber, see GetLastTouchedFX. Deprecated, see GetTouchedOrFocusedFX
///-- @param tracknumberOut *c_int
///-- @param itemnumberOut *c_int
///-- @param fxnumberOut *c_int
pub const GetFocusedFX2 = function(&reaper.GetFocusedFX2, 3, &.{ *c_int, *c_int, *c_int });

/// GetFreeDiskSpaceForRecordPath
/// returns free disk space in megabytes, pathIdx 0 for normal, 1 for alternate.
///-- @param proj *ReaProject
///-- @param pathidx c_int
pub const GetFreeDiskSpaceForRecordPath = function(&reaper.GetFreeDiskSpaceForRecordPath, 2, &.{ *ReaProject, c_int });

/// GetFXEnvelope
/// Returns the FX parameter envelope. If the envelope does not exist and create=true, the envelope will be created. If the envelope already exists and is bypassed and create=true, then the envelope will be unbypassed.
///-- @param track MediaTrack
///-- @param fxindex c_int
///-- @param parameterindex c_int
///-- @param create bool
pub const GetFXEnvelope = function(&reaper.GetFXEnvelope, 4, &.{ MediaTrack, c_int, c_int, bool });

/// GetGlobalAutomationOverride
/// return -1=no override, 0=trim/read, 1=read, 2=touch, 3=write, 4=latch, 5=bypass
pub const GetGlobalAutomationOverride = function(&reaper.GetGlobalAutomationOverride, 0, &.{});

/// GetHZoomLevel
/// returns pixels/second
pub const GetHZoomLevel = function(&reaper.GetHZoomLevel, 0, &.{});

/// GetIconThemePointer
/// returns a named icontheme entry
///-- @param name [*:0]const u8
pub const GetIconThemePointer = function(&reaper.GetIconThemePointer, 1, &.{[*:0]const u8});

/// GetIconThemePointerForDPI
/// returns a named icontheme entry for a given DPI-scaling (256=1:1). Note: the return value should not be stored, it should be queried at each paint! Querying name=NULL returns the start of the structure
///-- @param name [*:0]const u8
///-- @param dpisc c_int
pub const GetIconThemePointerForDPI = function(&reaper.GetIconThemePointerForDPI, 2, &.{ [*:0]const u8, c_int });

/// GetIconThemeStruct
/// returns a pointer to the icon theme (icontheme.h) and the size of that struct
///-- @param szOut *c_int
pub const GetIconThemeStruct = function(&reaper.GetIconThemeStruct, 1, &.{*c_int});

/// GetInputActivityLevel
/// returns approximate input level if available, 0-511 mono inputs, |1024 for stereo pairs, 4096+*devidx32 for MIDI devices
///-- @param id c_int
pub const GetInputActivityLevel = function(&reaper.GetInputActivityLevel, 1, &.{c_int});

/// GetInputChannelName
///-- @param channelIndex c_int
pub const GetInputChannelName = function(&reaper.GetInputChannelName, 1, &.{c_int});

/// GetInputOutputLatency
/// Gets the audio device input/output latency in samples
///-- @param inputlatencyOut *c_int
///-- @param outputLatencyOut *c_int
pub const GetInputOutputLatency = function(&reaper.GetInputOutputLatency, 2, &.{ *c_int, *c_int });

/// GetItemEditingTime2
/// returns time of relevant edit, set which_item to the pcm_source (if applicable), flags (if specified) will be set to 1 for edge resizing, 2 for fade change, 4 for item move, 8 for item slip edit (edit cursor time or start of item)
///-- @param itemOut *PCM_source
///-- @param flagsOut *c_int
pub const GetItemEditingTime2 = function(&reaper.GetItemEditingTime2, 2, &.{ *PCM_source, *c_int });

/// GetItemFromPoint
/// Returns the first item at the screen coordinates specified. If allow_locked is false, locked items are ignored. If takeOutOptional specified, returns the take hit. See GetThingFromPoint.
///-- @param x c_int
///-- @param y c_int
///-- @param locked bool
///-- @param takeOutOptional *MediaItem_Take
pub const GetItemFromPoint = function(&reaper.GetItemFromPoint, 4, &.{ c_int, c_int, bool, *MediaItem_Take });

/// GetItemProjectContext
///-- @param item *MediaItem
pub const GetItemProjectContext = function(&reaper.GetItemProjectContext, 1, &.{*MediaItem});

/// GetItemStateChunk
/// Gets the RPPXML state of an item, returns true if successful. Undo flag is a performance/caching hint.
///-- @param item *MediaItem
///-- @param strNeedBig *c_char
///-- @param sz c_int
///-- @param isundoOptional bool
pub const GetItemStateChunk = function(&reaper.GetItemStateChunk, 4, &.{ *MediaItem, *c_char, c_int, bool });

/// GetLastColorThemeFile
pub const GetLastColorThemeFile = function(&reaper.GetLastColorThemeFile, 0, &.{});

/// GetLastMarkerAndCurRegion
/// Get the last project marker before time, and/or the project region that includes time. markeridx and regionidx are returned not necessarily as the displayed marker/region index, but as the index that can be passed to EnumProjectMarkers. Either or both of markeridx and regionidx may be NULL. See EnumProjectMarkers.
///-- @param proj *ReaProject
///-- @param time f64
///-- @param markeridxOut *c_int
///-- @param regionidxOut *c_int
pub const GetLastMarkerAndCurRegion = function(&reaper.GetLastMarkerAndCurRegion, 4, &.{ *ReaProject, f64, *c_int, *c_int });

/// GetLastTouchedFX
/// Returns true if the last touched FX parameter is valid, false otherwise. The low word of tracknumber is the 1-based track index -- 0 means the master track, 1 means track 1, etc. If the high word of tracknumber is nonzero, it refers to the 1-based item index (1 is the first item on the track, etc). For track FX, the low 24 bits of fxnumber refer to the FX index in the chain, and if the next 8 bits are 01, then the FX is record FX. For item FX, the low word defines the FX index in the chain, and the high word defines the take number. Deprecated, see GetTouchedOrFocusedFX.
///-- @param tracknumberOut *c_int
///-- @param fxnumberOut *c_int
///-- @param paramnumberOut *c_int
pub const GetLastTouchedFX = function(&reaper.GetLastTouchedFX, 3, &.{ *c_int, *c_int, *c_int });

/// GetLastTouchedTrack
pub const GetLastTouchedTrack = function(&reaper.GetLastTouchedTrack, 0, &.{});

/// GetMainHwnd
pub const GetMainHwnd = function(&reaper.GetMainHwnd, 0, &.{});

/// GetMasterMuteSoloFlags
/// &1=master mute,&2=master solo. This is deprecated as you can just query the master track as well.
pub const GetMasterMuteSoloFlags = function(&reaper.GetMasterMuteSoloFlags, 0, &.{});

/// GetMasterTrack
///-- @param proj *ReaProject
pub const GetMasterTrack = function(&reaper.GetMasterTrack, 1, &.{*ReaProject});

/// GetMasterTrackVisibility
/// returns &1 if the master track is visible in the TCP, &2 if NOT visible in the mixer. See SetMasterTrackVisibility.
pub const GetMasterTrackVisibility = function(&reaper.GetMasterTrackVisibility, 0, &.{});

/// GetMaxMidiInputs
/// returns max dev for midi inputs/outputs
pub const GetMaxMidiInputs = function(&reaper.GetMaxMidiInputs, 0, &.{});

/// GetMaxMidiOutputs
pub const GetMaxMidiOutputs = function(&reaper.GetMaxMidiOutputs, 0, &.{});

/// GetMediaFileMetadata
/// Get text-based metadata from a media file for a given identifier. Call with identifier="" to list all identifiers contained in the file, separated by newlines. May return "[Binary data]" for metadata that REAPER doesn't handle.
///-- @param mediaSource *PCM_source
///-- @param identifier [*:0]const u8
///-- @param bufOutNeedBig *c_char
///-- @param sz c_int
pub const GetMediaFileMetadata = function(&reaper.GetMediaFileMetadata, 4, &.{ *PCM_source, [*:0]const u8, *c_char, c_int });

/// GetMediaItem
/// get an item from a project by item count (zero-based) (proj=0 for active project)
///-- @param proj *ReaProject
///-- @param itemidx c_int
pub const GetMediaItem = function(&reaper.GetMediaItem, 2, &.{ *ReaProject, c_int });

/// GetMediaItem_Track
/// Get parent track of media item
///-- @param item *MediaItem
pub const GetMediaItem_Track = function(&reaper.GetMediaItem_Track, 1, &.{*MediaItem});

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
///-- @param item *MediaItem
///-- @param parmname [*:0]const u8
pub const GetMediaItemInfo_Value = function(&reaper.GetMediaItemInfo_Value, 2, &.{ *MediaItem, [*:0]const u8 });

/// GetMediaItemNumTakes
///-- @param item *MediaItem
pub const GetMediaItemNumTakes = function(&reaper.GetMediaItemNumTakes, 1, &.{*MediaItem});

/// GetMediaItemTake
///-- @param item *MediaItem
///-- @param tk c_int
pub const GetMediaItemTake = function(&reaper.GetMediaItemTake, 2, &.{ *MediaItem, c_int });

/// GetMediaItemTake_Item
/// Get parent item of media item take
///-- @param take *MediaItem_Take
pub const GetMediaItemTake_Item = function(&reaper.GetMediaItemTake_Item, 1, &.{*MediaItem_Take});

/// GetMediaItemTake_Peaks
/// Gets block of peak samples to buf. Note that the peak samples are interleaved, but in two or three blocks (maximums, then minimums, then extra). Return value has 20 bits of returned sample count, then 4 bits of output_mode (0xf00000), then a bit to signify whether extra_type was available (0x1000000). extra_type can be 115 ('s') for spectral information, which will return peak samples as integers with the low 15 bits frequency, next 14 bits tonality.
///-- @param take *MediaItem_Take
///-- @param peakrate f64
///-- @param starttime f64
///-- @param numchannels c_int
///-- @param numsamplesperchannel c_int
///-- @param type c_int
///-- @param buf *f64
pub const GetMediaItemTake_Peaks = function(&reaper.GetMediaItemTake_Peaks, 7, &.{ *MediaItem_Take, f64, f64, c_int, c_int, c_int, *f64 });

/// GetMediaItemTake_Source
/// Get media source of media item take
///-- @param take *MediaItem_Take
pub const GetMediaItemTake_Source = function(&reaper.GetMediaItemTake_Source, 1, &.{*MediaItem_Take});

/// GetMediaItemTake_Track
/// Get parent track of media item take
///-- @param take *MediaItem_Take
pub const GetMediaItemTake_Track = function(&reaper.GetMediaItemTake_Track, 1, &.{*MediaItem_Take});

/// GetMediaItemTakeByGUID
///-- @param project *ReaProject
///-- @param guid *const GUID
pub const GetMediaItemTakeByGUID = function(&reaper.GetMediaItemTakeByGUID, 2, &.{ *ReaProject, *const GUID });

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
///-- @param take *MediaItem_Take
///-- @param parmname [*:0]const u8
pub const GetMediaItemTakeInfo_Value = function(&reaper.GetMediaItemTakeInfo_Value, 2, &.{ *MediaItem_Take, [*:0]const u8 });

/// GetMediaItemTrack
///-- @param item *MediaItem
pub const GetMediaItemTrack = function(&reaper.GetMediaItemTrack, 1, &.{*MediaItem});

/// GetMediaSourceFileName
/// Copies the media source filename to filenamebuf. Note that in-project MIDI media sources have no associated filename. See GetMediaSourceParent.
///-- @param source *PCM_source
///-- @param filenamebufOut *c_char
///-- @param sz c_int
pub const GetMediaSourceFileName = function(&reaper.GetMediaSourceFileName, 3, &.{ *PCM_source, *c_char, c_int });

/// GetMediaSourceLength
/// Returns the length of the source media. If the media source is beat-based, the length will be in quarter notes, otherwise it will be in seconds.
///-- @param source *PCM_source
///-- @param lengthIsQNOut *bool
pub const GetMediaSourceLength = function(&reaper.GetMediaSourceLength, 2, &.{ *PCM_source, *bool });

/// GetMediaSourceNumChannels
/// Returns the number of channels in the source media.
///-- @param source *PCM_source
pub const GetMediaSourceNumChannels = function(&reaper.GetMediaSourceNumChannels, 1, &.{*PCM_source});

/// GetMediaSourceParent
/// Returns the parent source, or NULL if src is the root source. This can be used to retrieve the parent properties of sections or reversed sources for example.
///-- @param src *PCM_source
pub const GetMediaSourceParent = function(&reaper.GetMediaSourceParent, 1, &.{*PCM_source});

/// GetMediaSourceSampleRate
/// Returns the sample rate. MIDI source media will return zero.
///-- @param source *PCM_source
pub const GetMediaSourceSampleRate = function(&reaper.GetMediaSourceSampleRate, 1, &.{*PCM_source});

/// GetMediaSourceType
/// copies the media source type ("WAV", "MIDI", etc) to typebuf
///-- @param source *PCM_source
///-- @param typebufOut *c_char
///-- @param sz c_int
pub const GetMediaSourceType = function(&reaper.GetMediaSourceType, 3, &.{ *PCM_source, *c_char, c_int });

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
///-- @param tr MediaTrack
///-- @param parmname [*:0]const u8
pub const GetMediaTrackInfo_Value = function(&reaper.GetMediaTrackInfo_Value, 2, &.{ MediaTrack, [*:0]const u8 });

/// GetMIDIInputName
/// returns true if device present
///-- @param dev c_int
///-- @param nameout [*]c_char
///-- @param sz c_int
pub const GetMIDIInputName = function(&reaper.GetMIDIInputName, 3, &.{ c_int, [*]c_char, c_int });

/// GetMIDIOutputName
/// returns true if device present
///-- @param dev c_int
///-- @param nameout [*]c_char
///-- @param sz c_int
pub const GetMIDIOutputName = function(&reaper.GetMIDIOutputName, 3, &.{ c_int, [*]c_char, c_int });

/// GetMixerScroll
/// Get the leftmost track visible in the mixer
pub const GetMixerScroll = function(&reaper.GetMixerScroll, 0, &.{});

/// GetMouseModifier
/// Get the current mouse modifier assignment for a specific modifier key assignment, in a specific context.
/// action will be filled in with the command ID number for a built-in mouse modifier
/// or built-in REAPER command ID, or the custom action ID string.
/// Note: the action string may have a space and 'c' or 'm' appended to it to specify command ID vs mouse modifier ID.
/// See SetMouseModifier for more information.
///
///-- @param context [*:0]const u8
///-- @param flag c_int
///-- @param actionOut *c_char
///-- @param sz c_int
pub const GetMouseModifier = function(&reaper.GetMouseModifier, 4, &.{ [*:0]const u8, c_int, *c_char, c_int });

/// GetMousePosition
/// get mouse position in screen coordinates
///-- @param xOut *c_int
///-- @param yOut *c_int
pub const GetMousePosition = function(&reaper.GetMousePosition, 2, &.{ *c_int, *c_int });

/// GetNumAudioInputs
/// Return number of normal audio hardware inputs available
pub const GetNumAudioInputs = function(&reaper.GetNumAudioInputs, 0, &.{});

/// GetNumAudioOutputs
/// Return number of normal audio hardware outputs available
pub const GetNumAudioOutputs = function(&reaper.GetNumAudioOutputs, 0, &.{});

/// GetNumMIDIInputs
/// returns max number of real midi hardware inputs
pub const GetNumMIDIInputs = function(&reaper.GetNumMIDIInputs, 0, &.{});

/// GetNumMIDIOutputs
/// returns max number of real midi hardware outputs
pub const GetNumMIDIOutputs = function(&reaper.GetNumMIDIOutputs, 0, &.{});

/// GetNumTakeMarkers
/// Returns number of take markers. See GetTakeMarker, SetTakeMarker, DeleteTakeMarker
///-- @param take *MediaItem_Take
pub const GetNumTakeMarkers = function(&reaper.GetNumTakeMarkers, 1, &.{*MediaItem_Take});

/// GetNumTracks
pub const GetNumTracks = function(&reaper.GetNumTracks, 0, &.{});

/// GetOS
/// Returns "Win32", "Win64", "OSX32", "OSX64", "macOS-arm64", or "Other".
pub const GetOS = function(&reaper.GetOS, 0, &.{});

/// GetOutputChannelName
///-- @param channelIndex c_int
pub const GetOutputChannelName = function(&reaper.GetOutputChannelName, 1, &.{c_int});

/// GetOutputLatency
/// returns output latency in seconds
pub const GetOutputLatency = function(&reaper.GetOutputLatency, 0, &.{});

/// GetParentTrack
///-- @param track MediaTrack
pub const GetParentTrack = function(&reaper.GetParentTrack, 1, &.{MediaTrack});

/// GetPeakFileName
/// get the peak file name for a given file (can be either filename.reapeaks,or a hashed filename in another path)
///-- @param bufOut *c_char
///-- @param sz c_int
pub const GetPeakFileName = function(&reaper.GetPeakFileName, 2, &.{ *c_char, c_int });

/// GetPeakFileNameEx
/// get the peak file name for a given file (can be either filename.reapeaks,or a hashed filename in another path)
///-- @param buf *c_char
///-- @param sz c_int
///-- @param forWrite bool
pub const GetPeakFileNameEx = function(&reaper.GetPeakFileNameEx, 3, &.{ *c_char, c_int, bool });

/// GetPeakFileNameEx2
/// Like GetPeakFileNameEx, but you can specify peaksfileextension such as ".reapeaks"
///-- @param buf *c_char
///-- @param sz c_int
///-- @param forWrite bool
///-- @param peaksfileextension [*:0]const u8
pub const GetPeakFileNameEx2 = function(&reaper.GetPeakFileNameEx2, 4, &.{ *c_char, c_int, bool, [*:0]const u8 });

/// GetPeaksBitmap
/// see note in reaper_plugin.h about PCM_source_peaktransfer_t::samplerate
///-- @param pks *PCM_source_peaktransfer_t
///-- @param maxamp f64
///-- @param w c_int
///-- @param h c_int
///-- @param bmp *LICE_IBitmap
pub const GetPeaksBitmap = function(&reaper.GetPeaksBitmap, 5, &.{ *PCM_source_peaktransfer_t, f64, c_int, c_int, *LICE_IBitmap });

/// GetPlayPosition
/// returns latency-compensated actual-what-you-hear position
pub const GetPlayPosition = function(&reaper.GetPlayPosition, 0, &.{});

/// GetPlayPosition2
/// returns position of next audio block being processed
pub const GetPlayPosition2 = function(&reaper.GetPlayPosition2, 0, &.{});

/// GetPlayPosition2Ex
/// returns position of next audio block being processed
///-- @param proj *ReaProject
pub const GetPlayPosition2Ex = function(&reaper.GetPlayPosition2Ex, 1, &.{*ReaProject});

/// GetPlayPositionEx
/// returns latency-compensated actual-what-you-hear position
///-- @param proj *ReaProject
pub const GetPlayPositionEx = function(&reaper.GetPlayPositionEx, 1, &.{*ReaProject});

/// GetPlayState
/// &1=playing, &2=paused, &4=is recording
pub const GetPlayState = function(&reaper.GetPlayState, 0, &.{});

/// GetPlayStateEx
/// &1=playing, &2=paused, &4=is recording
///-- @param proj *ReaProject
pub const GetPlayStateEx = function(&reaper.GetPlayStateEx, 1, &.{*ReaProject});

/// GetPreferredDiskReadMode
/// Gets user configured preferred disk read mode. mode/nb/bs are all parameters that should be passed to WDL_FileRead, see for more information.
///-- @param mode *c_int
///-- @param nb *c_int
///-- @param bs *c_int
pub const GetPreferredDiskReadMode = function(&reaper.GetPreferredDiskReadMode, 3, &.{ *c_int, *c_int, *c_int });

/// GetPreferredDiskReadModePeak
/// Gets user configured preferred disk read mode for use when building peaks. mode/nb/bs are all parameters that should be passed to WDL_FileRead, see for more information.
///-- @param mode *c_int
///-- @param nb *c_int
///-- @param bs *c_int
pub const GetPreferredDiskReadModePeak = function(&reaper.GetPreferredDiskReadModePeak, 3, &.{ *c_int, *c_int, *c_int });

/// GetPreferredDiskWriteMode
/// Gets user configured preferred disk write mode. nb will receive two values, the initial and maximum write buffer counts. mode/nb/bs are all parameters that should be passed to WDL_FileWrite, see for more information.
///-- @param mode *c_int
///-- @param nb *c_int
///-- @param bs *c_int
pub const GetPreferredDiskWriteMode = function(&reaper.GetPreferredDiskWriteMode, 3, &.{ *c_int, *c_int, *c_int });

/// GetProjectLength
/// returns length of project (maximum of end of media item, markers, end of regions, tempo map
///-- @param proj *ReaProject
pub const GetProjectLength = function(&reaper.GetProjectLength, 1, &.{*ReaProject});

/// GetProjectName
///-- @param proj *ReaProject
///-- @param bufOut *c_char
///-- @param sz c_int
pub const GetProjectName = function(&reaper.GetProjectName, 3, &.{ *ReaProject, *c_char, c_int });

/// GetProjectPath
/// Get the project recording path.
///-- @param bufOut *c_char
///-- @param sz c_int
pub const GetProjectPath = function(&reaper.GetProjectPath, 2, &.{ *c_char, c_int });

/// GetProjectPathEx
/// Get the project recording path.
///-- @param proj *ReaProject
///-- @param bufOut *c_char
///-- @param sz c_int
pub const GetProjectPathEx = function(&reaper.GetProjectPathEx, 3, &.{ *ReaProject, *c_char, c_int });

/// GetProjectStateChangeCount
/// returns an integer that changes when the project state changes
///-- @param proj *ReaProject
pub const GetProjectStateChangeCount = function(&reaper.GetProjectStateChangeCount, 1, &.{*ReaProject});

/// GetProjectTimeOffset
/// Gets project time offset in seconds (project settings - project start time). If rndframe is true, the offset is rounded to a multiple of the project frame size.
///-- @param proj *ReaProject
///-- @param rndframe bool
pub const GetProjectTimeOffset = function(&reaper.GetProjectTimeOffset, 2, &.{ *ReaProject, bool });

/// GetProjectTimeSignature
/// deprecated
///-- @param bpmOut *f64
///-- @param bpiOut *f64
pub const GetProjectTimeSignature = function(&reaper.GetProjectTimeSignature, 2, &.{ *f64, *f64 });

/// GetProjectTimeSignature2
/// Gets basic time signature (beats per minute, numerator of time signature in bpi)
/// this does not reflect tempo envelopes but is purely what is set in the project settings.
///-- @param proj *ReaProject
///-- @param bpmOut *f64
///-- @param bpiOut *f64
pub const GetProjectTimeSignature2 = function(&reaper.GetProjectTimeSignature2, 3, &.{ *ReaProject, *f64, *f64 });

/// GetProjExtState
/// Get the value previously associated with this extname and key, the last time the project was saved. See SetProjExtState, EnumProjExtState.
///-- @param proj *ReaProject
///-- @param extname [*:0]const u8
///-- @param key [*:0]const u8
///-- @param valOutNeedBig *c_char
///-- @param sz c_int
pub const GetProjExtState = function(&reaper.GetProjExtState, 5, &.{ *ReaProject, [*:0]const u8, [*:0]const u8, *c_char, c_int });

/// GetResourcePath
/// returns path where ini files are stored, other things are in subdirectories.
pub const GetResourcePath = function(&reaper.GetResourcePath, 0, &.{});

/// GetSelectedEnvelope
/// get the currently selected envelope, returns NULL/nil if no envelope is selected
///-- @param proj *ReaProject
pub const GetSelectedEnvelope = function(&reaper.GetSelectedEnvelope, 1, &.{*ReaProject});

/// GetSelectedMediaItem
/// get a selected item by selected item count (zero-based) (proj=0 for active project)
///-- @param proj *ReaProject
///-- @param selitem c_int
pub const GetSelectedMediaItem = function(&reaper.GetSelectedMediaItem, 2, &.{ *ReaProject, c_int });

/// GetSelectedTrack
/// Get a selected track from a project (proj=0 for active project) by selected track count (zero-based). This function ignores the master track, see GetSelectedTrack2.
///-- @param proj ReaProject
///-- @param seltrackidx c_int
pub const GetSelectedTrack = function(&reaper.GetSelectedTrack, 2, &.{ ReaProject, c_int });

/// GetSelectedTrack2
/// Get a selected track from a project (proj=0 for active project) by selected track count (zero-based).
///-- @param proj ReaProject
///-- @param seltrackidx c_int
///-- @param wantmaster bool
pub const GetSelectedTrack2 = function(&reaper.GetSelectedTrack2, 3, &.{ ReaProject, c_int, bool });

/// GetSelectedTrackEnvelope
/// get the currently selected track envelope, returns NULL/nil if no envelope is selected
///-- @param proj *ReaProject
pub const GetSelectedTrackEnvelope = function(&reaper.GetSelectedTrackEnvelope, 1, &.{*ReaProject});

/// GetSet_ArrangeView2
/// Gets or sets the arrange view start/end time for screen coordinates. use screen_x_start=screen_x_end=0 to use the full arrange view's start/end time
///-- @param proj *ReaProject
///-- @param isSet bool
///-- @param start c_int
///-- @param end c_int
///-- @param timeInOut *f64
///-- @param timeInOut *f64
pub const GetSet_ArrangeView2 = function(&reaper.GetSet_ArrangeView2, 6, &.{ *ReaProject, bool, c_int, c_int, *f64, *f64 });

/// GetSet_LoopTimeRange
///-- @param isSet bool
///-- @param isLoop bool
///-- @param startOut *f64
///-- @param endOut *f64
///-- @param allowautoseek bool
pub const GetSet_LoopTimeRange = function(&reaper.GetSet_LoopTimeRange, 5, &.{ bool, bool, *f64, *f64, bool });

/// GetSet_LoopTimeRange2
///-- @param proj *ReaProject
///-- @param isSet bool
///-- @param isLoop bool
///-- @param startOut *f64
///-- @param endOut *f64
///-- @param allowautoseek bool
pub const GetSet_LoopTimeRange2 = function(&reaper.GetSet_LoopTimeRange2, 6, &.{ *ReaProject, bool, bool, *f64, *f64, bool });

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
///-- @param env *TrackEnvelope
///-- @param idx c_int
///-- @param desc [*:0]const u8
///-- @param value f64
///-- @param set bool
pub const GetSetAutomationItemInfo = function(&reaper.GetSetAutomationItemInfo, 5, &.{ *TrackEnvelope, c_int, [*:0]const u8, f64, bool });

/// GetSetAutomationItemInfo_String
/// Get or set automation item information. autoitem_idx=0 for the first automation item on an envelope, 1 for the second item, etc. returns true on success. desc can be any of the following:
/// P_POOL_NAME : c_char * : name of the underlying automation item pool
/// P_POOL_EXT:xyz : c_char * : extension-specific persistent data
///
///-- @param env *TrackEnvelope
///-- @param idx c_int
///-- @param desc [*:0]const u8
///-- @param valuestrNeedBig *c_char
///-- @param set bool
pub const GetSetAutomationItemInfo_String = function(&reaper.GetSetAutomationItemInfo_String, 5, &.{ *TrackEnvelope, c_int, [*:0]const u8, *c_char, bool });

/// GetSetEnvelopeInfo_String
/// Gets/sets an attribute string:
/// P_EXT:xyz : c_char * : extension-specific persistent data
/// GUID : GUID * : 16-byte GUID, can query only, not set. If using a _String() function, GUID is a string {xyz-...}.
///
///-- @param env *TrackEnvelope
///-- @param parmname [*:0]const u8
///-- @param stringNeedBig *c_char
///-- @param setNewValue bool
pub const GetSetEnvelopeInfo_String = function(&reaper.GetSetEnvelopeInfo_String, 4, &.{ *TrackEnvelope, [*:0]const u8, *c_char, bool });

/// GetSetEnvelopeState
/// deprecated -- see SetEnvelopeStateChunk, GetEnvelopeStateChunk
///-- @param env *TrackEnvelope
///-- @param str *c_char
///-- @param sz c_int
pub const GetSetEnvelopeState = function(&reaper.GetSetEnvelopeState, 3, &.{ *TrackEnvelope, *c_char, c_int });

/// GetSetEnvelopeState2
/// deprecated -- see SetEnvelopeStateChunk, GetEnvelopeStateChunk
///-- @param env *TrackEnvelope
///-- @param str *c_char
///-- @param sz c_int
///-- @param isundo bool
pub const GetSetEnvelopeState2 = function(&reaper.GetSetEnvelopeState2, 4, &.{ *TrackEnvelope, *c_char, c_int, bool });

/// GetSetItemState
/// deprecated -- see SetItemStateChunk, GetItemStateChunk
///-- @param item *MediaItem
///-- @param str *c_char
///-- @param sz c_int
pub const GetSetItemState = function(&reaper.GetSetItemState, 3, &.{ *MediaItem, *c_char, c_int });

/// GetSetItemState2
/// deprecated -- see SetItemStateChunk, GetItemStateChunk
///-- @param item *MediaItem
///-- @param str *c_char
///-- @param sz c_int
///-- @param isundo bool
pub const GetSetItemState2 = function(&reaper.GetSetItemState2, 4, &.{ *MediaItem, *c_char, c_int, bool });

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
///-- @param item *MediaItem
///-- @param parmname [*:0]const u8
///-- @param setNewValue *void
pub const GetSetMediaItemInfo = function(&reaper.GetSetMediaItemInfo, 3, &.{ *MediaItem, [*:0]const u8, *void });

/// GetSetMediaItemInfo_String
/// Gets/sets an item attribute string:
/// P_NOTES : c_char * : item note text (do not write to returned pointer, use setNewValue to update)
/// P_EXT:xyz : c_char * : extension-specific persistent data
/// GUID : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
///
///-- @param item *MediaItem
///-- @param parmname [*:0]const u8
///-- @param stringNeedBig *c_char
///-- @param setNewValue bool
pub const GetSetMediaItemInfo_String = function(&reaper.GetSetMediaItemInfo_String, 4, &.{ *MediaItem, [*:0]const u8, *c_char, bool });

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
///-- @param tk *MediaItem_Take
///-- @param parmname [*:0]const u8
///-- @param setNewValue *void
pub const GetSetMediaItemTakeInfo = function(&reaper.GetSetMediaItemTakeInfo, 3, &.{ *MediaItem_Take, [*:0]const u8, *void });

/// GetSetMediaItemTakeInfo_String
/// Gets/sets a take attribute string:
/// P_NAME : c_char * : take name
/// P_EXT:xyz : c_char * : extension-specific persistent data
/// GUID : GUID * : 16-byte GUID, can query or update. If using a _String() function, GUID is a string {xyz-...}.
///
///-- @param tk *MediaItem_Take
///-- @param parmname [*:0]const u8
///-- @param stringNeedBig *c_char
///-- @param setNewValue bool
pub const GetSetMediaItemTakeInfo_String = function(&reaper.GetSetMediaItemTakeInfo_String, 4, &.{ *MediaItem_Take, [*:0]const u8, *c_char, bool });

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
///-- @param tr MediaTrack
///-- @param parmname [*:0]const u8
///-- @param setNewValue *u8
pub const GetSetMediaTrackInfo = function(&reaper.GetSetMediaTrackInfo, 3, &.{ MediaTrack, [*:0]const u8, *u8 });

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
///-- @param tr *MediaTrack
///-- @param parmname [*:0]const u8
///-- @param stringNeedBig *c_char
///-- @param setNewValue bool
pub const GetSetMediaTrackInfo_String = function(&reaper.GetSetMediaTrackInfo_String, 4, &.{ *MediaTrack, [*:0]const u8, *c_char, bool });

/// GetSetObjectState
/// get or set the state of a {track,item,envelope} as an RPPXML chunk
/// str="" to get the chunk string returned (must call FreeHeapPtr when done)
/// supply str to set the state (returns zero)
///-- @param obj *void
///-- @param str [*:0]const u8
pub const GetSetObjectState = function(&reaper.GetSetObjectState, 2, &.{ *void, [*:0]const u8 });

/// GetSetObjectState2
/// get or set the state of a {track,item,envelope} as an RPPXML chunk
/// str="" to get the chunk string returned (must call FreeHeapPtr when done)
/// supply str to set the state (returns zero)
/// set isundo if the state will be used for undo purposes (which may allow REAPER to get the state more efficiently
///-- @param obj *void
///-- @param str [*:0]const u8
///-- @param isundo bool
pub const GetSetObjectState2 = function(&reaper.GetSetObjectState2, 3, &.{ *void, [*:0]const u8, bool });

/// GetSetProjectAuthor
/// deprecated, see GetSetProjectInfo_String with desc="PROJECT_AUTHOR"
///-- @param proj *ReaProject
///-- @param set bool
///-- @param author *c_char
///-- @param sz c_int
pub const GetSetProjectAuthor = function(&reaper.GetSetProjectAuthor, 4, &.{ *ReaProject, bool, *c_char, c_int });

/// GetSetProjectGrid
/// Get or set the arrange view grid division. 0.25=quarter note, 1.0/3.0=half note triplet, etc. swingmode can be 1 for swing enabled, swingamt is -1..1. swingmode can be 3 for measure-grid. Returns grid configuration flags
///-- @param project *ReaProject
///-- @param set bool
///-- @param divisionInOutOptional *f64
///-- @param swingmodeInOutOptional *c_int
///-- @param swingamtInOutOptional *f64
pub const GetSetProjectGrid = function(&reaper.GetSetProjectGrid, 5, &.{ *ReaProject, bool, *f64, *c_int, *f64 });

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
///-- @param project *ReaProject
///-- @param desc [*:0]const u8
///-- @param value f64
///-- @param set bool
pub const GetSetProjectInfo = function(&reaper.GetSetProjectInfo, 4, &.{ *ReaProject, [*:0]const u8, f64, bool });

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
///-- @param project *ReaProject
///-- @param desc [*:0]const u8
///-- @param valuestrNeedBig *c_char
///-- @param set bool
pub const GetSetProjectInfo_String = function(&reaper.GetSetProjectInfo_String, 4, &.{ *ReaProject, [*:0]const u8, *c_char, bool });

/// GetSetProjectNotes
/// gets or sets project notes, notesNeedBig_sz is ignored when setting
///-- @param proj *ReaProject
///-- @param set bool
///-- @param notesNeedBig *c_char
///-- @param sz c_int
pub const GetSetProjectNotes = function(&reaper.GetSetProjectNotes, 4, &.{ *ReaProject, bool, *c_char, c_int });

/// GetSetRepeat
/// -1 == query,0=clear,1=set,>1=toggle . returns new value
///-- @param val c_int
pub const GetSetRepeat = function(&reaper.GetSetRepeat, 1, &.{c_int});

/// GetSetRepeatEx
/// -1 == query,0=clear,1=set,>1=toggle . returns new value
///-- @param proj *ReaProject
///-- @param val c_int
pub const GetSetRepeatEx = function(&reaper.GetSetRepeatEx, 2, &.{ *ReaProject, c_int });

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
///-- @param tr *MediaTrack
///-- @param groupname [*:0]const u8
///-- @param setmask c_uint
///-- @param setvalue c_uint
pub const GetSetTrackGroupMembership = function(&reaper.GetSetTrackGroupMembership, 4, &.{ *MediaTrack, [*:0]const u8, c_uint, c_uint });

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
///-- @param tr *MediaTrack
///-- @param groupname [*:0]const u8
///-- @param setmask c_uint
///-- @param setvalue c_uint
pub const GetSetTrackGroupMembershipHigh = function(&reaper.GetSetTrackGroupMembershipHigh, 4, &.{ *MediaTrack, [*:0]const u8, c_uint, c_uint });

/// GetSetTrackMIDISupportFile
/// Get or set the filename for storage of various track MIDI c_characteristics. 0=MIDI colormap image file, 1 or 2=MIDI bank/program select file (2=set new default). If fn != NULL, a new track MIDI storage file will be set; otherwise the existing track MIDI storage file will be returned.
///-- @param proj *ReaProject
///-- @param track MediaTrack
///-- @param which c_int
///-- @param filename [*:0]const u8
pub const GetSetTrackMIDISupportFile = function(&reaper.GetSetTrackMIDISupportFile, 4, &.{ *ReaProject, MediaTrack, c_int, [*:0]const u8 });

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
///-- @param tr *MediaTrack
///-- @param category c_int
///-- @param sendidx c_int
///-- @param parmname [*:0]const u8
///-- @param setNewValue *void
pub const GetSetTrackSendInfo = function(&reaper.GetSetTrackSendInfo, 5, &.{ *MediaTrack, c_int, c_int, [*:0]const u8, *void });

/// GetSetTrackSendInfo_String
/// Gets/sets a send attribute string:
/// P_EXT:xyz : c_char * : extension-specific persistent data
///
///-- @param tr *MediaTrack
///-- @param category c_int
///-- @param sendidx c_int
///-- @param parmname [*:0]const u8
///-- @param stringNeedBig *c_char
///-- @param setNewValue bool
pub const GetSetTrackSendInfo_String = function(&reaper.GetSetTrackSendInfo_String, 6, &.{ *MediaTrack, c_int, c_int, [*:0]const u8, *c_char, bool });

/// GetSetTrackState
/// deprecated -- see SetTrackStateChunk, GetTrackStateChunk
///-- @param track MediaTrack
///-- @param str *c_char
///-- @param sz c_int
pub const GetSetTrackState = function(&reaper.GetSetTrackState, 3, &.{ MediaTrack, *c_char, c_int });

/// GetSetTrackState2
/// deprecated -- see SetTrackStateChunk, GetTrackStateChunk
///-- @param track MediaTrack
///-- @param str *c_char
///-- @param sz c_int
///-- @param isundo bool
pub const GetSetTrackState2 = function(&reaper.GetSetTrackState2, 4, &.{ MediaTrack, *c_char, c_int, bool });

/// GetSubProjectFromSource
///-- @param src *PCM_source
pub const GetSubProjectFromSource = function(&reaper.GetSubProjectFromSource, 1, &.{*PCM_source});

/// GetTake
/// get a take from an item by take count (zero-based)
///-- @param item *MediaItem
///-- @param takeidx c_int
pub const GetTake = function(&reaper.GetTake, 2, &.{ *MediaItem, c_int });

/// GetTakeEnvelope
///-- @param take *MediaItem_Take
///-- @param envidx c_int
pub const GetTakeEnvelope = function(&reaper.GetTakeEnvelope, 2, &.{ *MediaItem_Take, c_int });

/// GetTakeEnvelopeByName
///-- @param take *MediaItem_Take
///-- @param envname [*:0]const u8
pub const GetTakeEnvelopeByName = function(&reaper.GetTakeEnvelopeByName, 2, &.{ *MediaItem_Take, [*:0]const u8 });

/// GetTakeMarker
/// Get information about a take marker. Returns the position in media item source time, or -1 if the take marker does not exist. See GetNumTakeMarkers, SetTakeMarker, DeleteTakeMarker
///-- @param take *MediaItem_Take
///-- @param idx c_int
///-- @param nameOut *c_char
///-- @param sz c_int
///-- @param colorOutOptional *c_int
pub const GetTakeMarker = function(&reaper.GetTakeMarker, 5, &.{ *MediaItem_Take, c_int, *c_char, c_int, *c_int });

/// GetTakeName
/// returns NULL if the take is not valid
///-- @param take *MediaItem_Take
pub const GetTakeName = function(&reaper.GetTakeName, 1, &.{*MediaItem_Take});

/// GetTakeNumStretchMarkers
/// Returns number of stretch markers in take
///-- @param take *MediaItem_Take
pub const GetTakeNumStretchMarkers = function(&reaper.GetTakeNumStretchMarkers, 1, &.{*MediaItem_Take});

/// GetTakeStretchMarker
/// Gets information on a stretch marker, idx is 0..n. Returns -1 if stretch marker not valid. posOut will be set to position in item, srcposOutOptional will be set to source media position. Returns index. if input index is -1, the following marker is found using position (or source position if position is -1). If position/source position are used to find marker position, their values are not updated.
///-- @param take *MediaItem_Take
///-- @param idx c_int
///-- @param posOut *f64
///-- @param srcposOutOptional *f64
pub const GetTakeStretchMarker = function(&reaper.GetTakeStretchMarker, 4, &.{ *MediaItem_Take, c_int, *f64, *f64 });

/// GetTakeStretchMarkerSlope
/// See SetTakeStretchMarkerSlope
///-- @param take *MediaItem_Take
///-- @param idx c_int
pub const GetTakeStretchMarkerSlope = function(&reaper.GetTakeStretchMarkerSlope, 2, &.{ *MediaItem_Take, c_int });

/// GetTCPFXParm
/// Get information about a specific FX parameter knob (see CountTCPFXParms).
///-- @param project *ReaProject
///-- @param track MediaTrack
///-- @param index c_int
///-- @param fxindexOut *c_int
///-- @param parmidxOut *c_int
pub const GetTCPFXParm = function(&reaper.GetTCPFXParm, 5, &.{ *ReaProject, MediaTrack, c_int, *c_int, *c_int });

/// GetTempoMatchPlayRate
/// finds the playrate and target length to insert this item stretched to a round power-of-2 number of bars, between 1/8 and 256
///-- @param source *PCM_source
///-- @param srcscale f64
///-- @param position f64
///-- @param mult f64
///-- @param rateOut *f64
///-- @param targetlenOut *f64
pub const GetTempoMatchPlayRate = function(&reaper.GetTempoMatchPlayRate, 6, &.{ *PCM_source, f64, f64, f64, *f64, *f64 });

/// GetTempoTimeSigMarker
/// Get information about a tempo/time signature marker. See CountTempoTimeSigMarkers, SetTempoTimeSigMarker, AddTempoTimeSigMarker.
///-- @param proj *ReaProject
///-- @param ptidx c_int
///-- @param timeposOut *f64
///-- @param measureposOut *c_int
///-- @param beatposOut *f64
///-- @param bpmOut *f64
///-- @param numOut *c_int
///-- @param denomOut *c_int
///-- @param lineartempoOut *bool
pub const GetTempoTimeSigMarker = function(&reaper.GetTempoTimeSigMarker, 9, &.{ *ReaProject, c_int, *f64, *c_int, *f64, *f64, *c_int, *c_int, *bool });

/// GetThemeColor
/// Returns the theme color specified, or -1 on failure. If the low bit of flags is set, the color as originally specified by the theme (before any transformations) is returned, otherwise the current (possibly transformed and modified) color is returned. See SetThemeColor for a list of valid ini_key.
///-- @param key [*:0]const u8
///-- @param flagsOptional c_int
pub const GetThemeColor = function(&reaper.GetThemeColor, 2, &.{ [*:0]const u8, c_int });

/// GetThingFromPoint
/// Hit tests a point in screen coordinates. Updates infoOut with information such as "arrange", "fx_chain", "fx_0" (first FX in chain, f32ing), "spacer_0" (spacer before first track). If a track panel is hit, string will begin with "tcp" or "mcp" or "tcp.mute" etc (future versions may append additional information). May return NULL with valid info string to indicate non-track thing.
///-- @param x c_int
///-- @param y c_int
///-- @param infoOut *c_char
///-- @param sz c_int
pub const GetThingFromPoint = function(&reaper.GetThingFromPoint, 4, &.{ c_int, c_int, *c_char, c_int });

/// GetToggleCommandState
/// See GetToggleCommandStateEx.
///-- @param id c_int
pub const GetToggleCommandState = function(&reaper.GetToggleCommandState, 1, &.{c_int});

/// GetToggleCommandState2
/// See GetToggleCommandStateEx.
///-- @param section *KbdSectionInfo
///-- @param id c_int
pub const GetToggleCommandState2 = function(&reaper.GetToggleCommandState2, 2, &.{ *KbdSectionInfo, c_int });

/// GetToggleCommandStateEx
/// For the main action context, the MIDI editor, or the media explorer, returns the toggle state of the action. 0=off, 1=on, -1=NA because the action does not have on/off states. For the MIDI editor, the action state for the most recently focused window will be returned.
///-- @param id c_int
///-- @param id c_int
pub const GetToggleCommandStateEx = function(&reaper.GetToggleCommandStateEx, 2, &.{ c_int, c_int });

/// GetToggleCommandStateThroughHooks
/// Returns the state of an action via extension plugins' hooks.
///-- @param section *KbdSectionInfo
///-- @param id c_int
pub const GetToggleCommandStateThroughHooks = function(&reaper.GetToggleCommandStateThroughHooks, 2, &.{ *KbdSectionInfo, c_int });

/// GetTooltipWindow
/// gets a tooltip window,in case you want to ask it for font information. Can return NULL.
pub const GetTooltipWindow = function(&reaper.GetTooltipWindow, 0, &.{});

/// GetTouchedOrFocusedFX
/// mode can be 0 to query last touched parameter, or 1 to query currently focused FX. Returns false if failed. If successful, trackIdxOut will be track index (-1 is master track, 0 is first track). itemidxOut will be 0-based item index if an item, or -1 if not an item. takeidxOut will be 0-based take index. fxidxOut will be FX index, potentially with 0x2000000 set to signify container-addressing, or with 0x1000000 set to signify record-input FX. parmOut will be set to the parameter index if querying last-touched. parmOut will have 1 set if querying focused state and FX is no longer focused but still open.
///-- @param mode c_int
///-- @param trackidxOut *c_int
///-- @param itemidxOut *c_int
///-- @param takeidxOut *c_int
///-- @param fxidxOut *c_int
///-- @param parmOut *c_int
pub const GetTouchedOrFocusedFX = function(&reaper.GetTouchedOrFocusedFX, 6, &.{ c_int, *c_int, *c_int, *c_int, *c_int, *c_int });

/// GetTrack
/// get a track from a project by track count (zero-based) (proj=0 for active project)
///-- @param proj ReaProject
///-- @param trackidx c_int
pub const GetTrack = function(&reaper.GetTrack, 2, &.{ ReaProject, c_int });

/// GetTrackAutomationMode
/// return the track mode, regardless of global override
///-- @param tr MediaTrack
pub const GetTrackAutomationMode = function(&reaper.GetTrackAutomationMode, 1, &.{MediaTrack});

/// GetTrackColor
/// Returns the track custom color as OS dependent color|0x1000000 (i.e. ColorToNative(r,g,b)|0x1000000). Black is returned as 0x1000000, no color setting is returned as 0.
///-- @param track MediaTrack
pub const GetTrackColor = function(&reaper.GetTrackColor, 1, &.{MediaTrack});

/// GetTrackDepth
///-- @param track MediaTrack
pub const GetTrackDepth = function(&reaper.GetTrackDepth, 1, &.{MediaTrack});

/// GetTrackEnvelope
///-- @param track MediaTrack
///-- @param envidx c_int
pub const GetTrackEnvelope = function(&reaper.GetTrackEnvelope, 2, &.{ MediaTrack, c_int });

/// GetTrackEnvelopeByChunkName
/// Gets a built-in track envelope by configuration chunk name, like "<VOLENV", or GUID string, like "{B577250D-146F-B544-9B34-F24FBE488F1F}".
///
///-- @param tr *MediaTrack
///-- @param guid [*:0]const u8
pub const GetTrackEnvelopeByChunkName = function(&reaper.GetTrackEnvelopeByChunkName, 2, &.{ *MediaTrack, [*:0]const u8 });

/// GetTrackEnvelopeByName
///-- @param track MediaTrack
///-- @param envname [*:0]const u8
pub const GetTrackEnvelopeByName = function(&reaper.GetTrackEnvelopeByName, 2, &.{ MediaTrack, [*:0]const u8 });

/// GetTrackFromPoint
/// Returns the track from the screen coordinates specified. If the screen coordinates refer to a window associated to the track (such as FX), the track will be returned. infoOutOptional will be set to 1 if it is likely an envelope, 2 if it is likely a track FX. For a free item positioning or fixed lane track, the second byte of infoOutOptional will be set to the (approximate, for fipm tracks) item lane underneath the mouse. See GetThingFromPoint.
///-- @param x c_int
///-- @param y c_int
///-- @param infoOutOptional *c_int
pub const GetTrackFromPoint = function(&reaper.GetTrackFromPoint, 3, &.{ c_int, c_int, *c_int });

/// GetTrackGUID
///-- @param tr *MediaTrack
pub const GetTrackGUID = function(&reaper.GetTrackGUID, 1, &.{*MediaTrack});

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
///-- @param track INT_PTR
///-- @param flags *c_int
pub const GetTrackInfo = function(&reaper.GetTrackInfo, 2, &.{ INT_PTR, *c_int });

/// GetTrackMediaItem
///-- @param tr *MediaTrack
///-- @param itemidx c_int
pub const GetTrackMediaItem = function(&reaper.GetTrackMediaItem, 2, &.{ *MediaTrack, c_int });

/// GetTrackMIDILyrics
/// Get all MIDI lyrics on the track. Lyrics will be returned as one string with tabs between each word. flag&1: f64 tabs at the end of each measure and triple tabs when skipping measures, flag&2: each lyric is preceded by its beat position in the project (example with flag=2: "1.1.2\tLyric for measure 1 beat 2\t2.1.1\tLyric for measure 2 beat 1	"). See SetTrackMIDILyrics
///-- @param track MediaTrack
///-- @param flag c_int
///-- @param bufOutWantNeedBig *c_char
///-- @param sz *c_int
pub const GetTrackMIDILyrics = function(&reaper.GetTrackMIDILyrics, 4, &.{ MediaTrack, c_int, *c_char, *c_int });

/// GetTrackMIDINoteName
/// see GetTrackMIDINoteNameEx
///-- @param track c_int
///-- @param pitch c_int
///-- @param chan c_int
pub const GetTrackMIDINoteName = function(&reaper.GetTrackMIDINoteName, 3, &.{ c_int, c_int, c_int });

/// GetTrackMIDINoteNameEx
/// Get note/CC name. pitch 128 for CC0 name, 129 for CC1 name, etc. See SetTrackMIDINoteNameEx
///-- @param proj *ReaProject
///-- @param track MediaTrack
///-- @param pitch c_int
///-- @param chan c_int
pub const GetTrackMIDINoteNameEx = function(&reaper.GetTrackMIDINoteNameEx, 4, &.{ *ReaProject, MediaTrack, c_int, c_int });

/// GetTrackMIDINoteRange
///-- @param proj *ReaProject
///-- @param track MediaTrack
///-- @param loOut *c_int
///-- @param hiOut *c_int
pub const GetTrackMIDINoteRange = function(&reaper.GetTrackMIDINoteRange, 4, &.{ *ReaProject, MediaTrack, *c_int, *c_int });

/// GetTrackName
/// Returns "MASTER" for master track, "Track N" if track has no name.
///-- @param track MediaTrack
///-- @param bufOut [*:0]const u8
///-- @param sz c_int
pub const GetTrackName = function(&reaper.GetTrackName, 3, &.{ MediaTrack, [*:0]const u8, c_int });

/// GetTrackNumMediaItems
///-- @param tr *MediaTrack
pub const GetTrackNumMediaItems = function(&reaper.GetTrackNumMediaItems, 1, &.{*MediaTrack});

/// GetTrackNumSends
/// returns number of sends/receives/hardware outputs - category is <0 for receives, 0=sends, >0 for hardware outputs
///-- @param tr *MediaTrack
///-- @param category c_int
pub const GetTrackNumSends = function(&reaper.GetTrackNumSends, 2, &.{ *MediaTrack, c_int });

/// GetTrackReceiveName
/// See GetTrackSendName.
///-- @param track MediaTrack
///-- @param index c_int
///-- @param bufOut *c_char
///-- @param sz c_int
pub const GetTrackReceiveName = function(&reaper.GetTrackReceiveName, 4, &.{ MediaTrack, c_int, *c_char, c_int });

/// GetTrackReceiveUIMute
/// See GetTrackSendUIMute.
///-- @param track MediaTrack
///-- @param index c_int
///-- @param muteOut *bool
pub const GetTrackReceiveUIMute = function(&reaper.GetTrackReceiveUIMute, 3, &.{ MediaTrack, c_int, *bool });

/// GetTrackReceiveUIVolPan
/// See GetTrackSendUIVolPan.
///-- @param track MediaTrack
///-- @param index c_int
///-- @param volumeOut *f64
///-- @param panOut *f64
pub const GetTrackReceiveUIVolPan = function(&reaper.GetTrackReceiveUIVolPan, 4, &.{ MediaTrack, c_int, *f64, *f64 });

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
///-- @param tr *MediaTrack
///-- @param category c_int
///-- @param sendidx c_int
///-- @param parmname [*:0]const u8
pub const GetTrackSendInfo_Value = function(&reaper.GetTrackSendInfo_Value, 4, &.{ *MediaTrack, c_int, c_int, [*:0]const u8 });

/// GetTrackSendName
/// send_idx>=0 for hw ouputs, >=nb_of_hw_ouputs for sends. See GetTrackReceiveName.
///-- @param track MediaTrack
///-- @param index c_int
///-- @param bufOut *c_char
///-- @param sz c_int
pub const GetTrackSendName = function(&reaper.GetTrackSendName, 4, &.{ MediaTrack, c_int, *c_char, c_int });

/// GetTrackSendUIMute
/// send_idx>=0 for hw ouputs, >=nb_of_hw_ouputs for sends. See GetTrackReceiveUIMute.
///-- @param track MediaTrack
///-- @param index c_int
///-- @param muteOut *bool
pub const GetTrackSendUIMute = function(&reaper.GetTrackSendUIMute, 3, &.{ MediaTrack, c_int, *bool });

/// GetTrackSendUIVolPan
/// send_idx>=0 for hw ouputs, >=nb_of_hw_ouputs for sends. See GetTrackReceiveUIVolPan.
///-- @param track MediaTrack
///-- @param index c_int
///-- @param volumeOut *f64
///-- @param panOut *f64
pub const GetTrackSendUIVolPan = function(&reaper.GetTrackSendUIVolPan, 4, &.{ MediaTrack, c_int, *f64, *f64 });

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
///-- @param track MediaTrack
///-- @param flagsOut *c_int
pub const GetTrackState = function(&reaper.GetTrackState, 2, &.{ MediaTrack, *c_int });

/// GetTrackStateChunk
/// Gets the RPPXML state of a track, returns true if successful. Undo flag is a performance/caching hint.
///-- @param track MediaTrack
///-- @param strNeedBig *c_char
///-- @param sz c_int
///-- @param isundoOptional bool
pub const GetTrackStateChunk = function(&reaper.GetTrackStateChunk, 4, &.{ MediaTrack, *c_char, c_int, bool });

/// GetTrackUIMute
///-- @param track MediaTrack
///-- @param muteOut *bool
pub const GetTrackUIMute = function(&reaper.GetTrackUIMute, 2, &.{ MediaTrack, *bool });

/// GetTrackUIPan
///-- @param track MediaTrack
///-- @param pan1Out *f64
///-- @param pan2Out *f64
///-- @param panmodeOut *c_int
pub const GetTrackUIPan = function(&reaper.GetTrackUIPan, 4, &.{ MediaTrack, *f64, *f64, *c_int });

/// GetTrackUIVolPan
///-- @param track MediaTrack
///-- @param volumeOut *f64
///-- @param panOut *f64
pub const GetTrackUIVolPan = function(&reaper.GetTrackUIVolPan, 3, &.{ MediaTrack, *f64, *f64 });

/// GetUnderrunTime
/// retrieves the last timestamps of audio xrun (yellow-flash, if available), media xrun (red-flash), and the current time stamp (all milliseconds)
///-- @param xrunOut *c_uint
///-- @param xrunOut *c_uint
///-- @param curtimeOut *c_uint
pub const GetUnderrunTime = function(&reaper.GetUnderrunTime, 3, &.{ *c_uint, *c_uint, *c_uint });

/// GetUserFileNameForRead
/// returns true if the user selected a valid file, false if the user canceled the dialog
///-- @param filenameNeed4096 *c_char
///-- @param title [*:0]const u8
///-- @param defext [*:0]const u8
pub const GetUserFileNameForRead = function(&reaper.GetUserFileNameForRead, 3, &.{ *c_char, [*:0]const u8, [*:0]const u8 });

/// GetUserInputs
/// Get values from the user.
/// If a caption begins with *, for example "*password", the edit field will not display the input text.
/// Maximum fields is 16. Values are returned as a comma-separated string. Returns false if the user canceled the dialog. You can supply special extra information via additional caption fields: extrawidth=XXX to increase text field width, separator=X to use a different separator for returned fields.
///-- @param title [*:0]const u8
///-- @param inputs c_int
///-- @param csv [*:0]const u8
///-- @param csv *c_char
///-- @param sz c_int
pub const GetUserInputs = function(&reaper.GetUserInputs, 5, &.{ [*:0]const u8, c_int, [*:0]const u8, *c_char, c_int });

/// GoToMarker
/// Go to marker. If use_timeline_order==true, marker_index 1 refers to the first marker on the timeline.  If use_timeline_order==false, marker_index 1 refers to the first marker with the user-editable index of 1.
///-- @param proj *ReaProject
///-- @param index c_int
///-- @param order bool
pub const GoToMarker = function(&reaper.GoToMarker, 3, &.{ *ReaProject, c_int, bool });

/// GoToRegion
/// Seek to region after current region finishes playing (smooth seek). If use_timeline_order==true, region_index 1 refers to the first region on the timeline.  If use_timeline_order==false, region_index 1 refers to the first region with the user-editable index of 1.
///-- @param proj *ReaProject
///-- @param index c_int
///-- @param order bool
pub const GoToRegion = function(&reaper.GoToRegion, 3, &.{ *ReaProject, c_int, bool });

/// GR_SelectColor
/// Runs the system color chooser dialog.  Returns 0 if the user cancels the dialog.
///-- @param hwnd HWND
///-- @param colorOut *c_int
pub const GR_SelectColor = function(&reaper.GR_SelectColor, 2, &.{ HWND, *c_int });

/// GSC_mainwnd
/// this is just like win32 GetSysColor() but can have overrides.
///-- @param t c_int
pub const GSC_mainwnd = function(&reaper.GSC_mainwnd, 1, &.{c_int});

/// guidToString
/// dest should be at least 64 c_chars long to be safe
///-- @param g *const GUID
///-- @param destNeed64 *c_char
pub const guidToString = function(&reaper.guidToString, 2, &.{ *const GUID, *c_char });

/// HasExtState
/// Returns true if there exists an extended state value for a specific section and key. See SetExtState, GetExtState, DeleteExtState.
///-- @param section [*:0]const u8
///-- @param key [*:0]const u8
pub const HasExtState = function(&reaper.HasExtState, 2, &.{ [*:0]const u8, [*:0]const u8 });

/// HasTrackMIDIPrograms
/// returns name of track plugin that is supplying MIDI programs,or NULL if there is none
///-- @param track c_int
pub const HasTrackMIDIPrograms = function(&reaper.HasTrackMIDIPrograms, 1, &.{c_int});

/// HasTrackMIDIProgramsEx
/// returns name of track plugin that is supplying MIDI programs,or NULL if there is none
///-- @param proj *ReaProject
///-- @param track MediaTrack
pub const HasTrackMIDIProgramsEx = function(&reaper.HasTrackMIDIProgramsEx, 2, &.{ *ReaProject, MediaTrack });

/// Help_Set
///-- @param helpstring [*:0]const u8
///-- @param help bool
pub const Help_Set = function(&reaper.Help_Set, 2, &.{ [*:0]const u8, bool });

/// HiresPeaksFromSource
///-- @param src *PCM_source
///-- @param block *PCM_source_peaktransfer_t
pub const HiresPeaksFromSource = function(&reaper.HiresPeaksFromSource, 2, &.{ *PCM_source, *PCM_source_peaktransfer_t });

/// image_resolve_fn
///-- @param in [*:0]const u8
///-- @param out *c_char
///-- @param sz c_int
pub const image_resolve_fn = function(&reaper.image_resolve_fn, 3, &.{ [*:0]const u8, *c_char, c_int });

/// InsertAutomationItem
/// Insert a new automation item. pool_id < 0 collects existing envelope points into the automation item; if pool_id is >= 0 the automation item will be a new instance of that pool (which will be created as an empty instance if it does not exist). Returns the index of the item, suitable for passing to other automation item API functions. See GetSetAutomationItemInfo.
///-- @param env *TrackEnvelope
///-- @param id c_int
///-- @param position f64
///-- @param length f64
pub const InsertAutomationItem = function(&reaper.InsertAutomationItem, 4, &.{ *TrackEnvelope, c_int, f64, f64 });

/// InsertEnvelopePoint
/// Insert an envelope point. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done. See InsertEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param time f64
///-- @param value f64
///-- @param shape c_int
///-- @param tension f64
///-- @param selected bool
///-- @param noSortInOptional *bool
pub const InsertEnvelopePoint = function(&reaper.InsertEnvelopePoint, 7, &.{ *TrackEnvelope, f64, f64, c_int, f64, bool, *bool });

/// InsertEnvelopePointEx
/// Insert an envelope point. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done.
/// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
/// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
/// even if the automation item is trimmed so that not all points are visible.
/// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
/// See CountEnvelopePointsEx, GetEnvelopePointEx, SetEnvelopePointEx, DeleteEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param idx c_int
///-- @param time f64
///-- @param value f64
///-- @param shape c_int
///-- @param tension f64
///-- @param selected bool
///-- @param noSortInOptional *bool
pub const InsertEnvelopePointEx = function(&reaper.InsertEnvelopePointEx, 8, &.{ *TrackEnvelope, c_int, f64, f64, c_int, f64, bool, *bool });

/// InsertMedia
/// mode: 0=add to current track, 1=add new track, 3=add to selected items as takes, &4=stretch/loop to fit time sel, &8=try to match tempo 1x, &16=try to match tempo 0.5x, &32=try to match tempo 2x, &64=don't preserve pitch when matching tempo, &128=no loop/section if startpct/endpct set, &256=force loop regardless of global preference for looping imported items, &512=use high word as absolute track index if mode&3==0 or mode&2048, &1024=insert into reasamplomatic on a new track (add 1 to insert on last selected track), &2048=insert into open reasamplomatic instance (add 512 to use high word as absolute track index), &4096=move to source preferred position (BWF start offset), &8192=reverse
///-- @param file [*:0]const u8
///-- @param mode c_int
pub const InsertMedia = function(&reaper.InsertMedia, 2, &.{ [*:0]const u8, c_int });

/// InsertMediaSection
/// See InsertMedia.
///-- @param file [*:0]const u8
///-- @param mode c_int
///-- @param startpct f64
///-- @param endpct f64
///-- @param pitchshift f64
pub const InsertMediaSection = function(&reaper.InsertMediaSection, 5, &.{ [*:0]const u8, c_int, f64, f64, f64 });

/// InsertTrackAtIndex
/// inserts a track at idx,of course this will be clamped to 0..GetNumTracks(). wantDefaults=TRUE for default envelopes/FX,otherwise no enabled fx/env
///-- @param idx c_int
///-- @param wantDefaults bool
pub const InsertTrackAtIndex = function(&reaper.InsertTrackAtIndex, 2, &.{ c_int, bool });

/// IsInRealTimeAudio
/// are we in a realtime audio thread (between OnAudioBuffer calls,not in some worker/anticipative FX thread)? threadsafe
pub const IsInRealTimeAudio = function(&reaper.IsInRealTimeAudio, 0, &.{});

/// IsItemTakeActiveForPlayback
/// get whether a take will be played (active take, unmuted, etc)
///-- @param item *MediaItem
///-- @param take *MediaItem_Take
pub const IsItemTakeActiveForPlayback = function(&reaper.IsItemTakeActiveForPlayback, 2, &.{ *MediaItem, *MediaItem_Take });

/// IsMediaExtension
/// Tests a file extension (i.e. "wav" or "mid") to see if it's a media extension.
/// If wantOthers is set, then "RPP", "TXT" and other project-type formats will also pass.
///-- @param ext [*:0]const u8
///-- @param wantOthers bool
pub const IsMediaExtension = function(&reaper.IsMediaExtension, 2, &.{ [*:0]const u8, bool });

/// IsMediaItemSelected
///-- @param item *MediaItem
pub const IsMediaItemSelected = function(&reaper.IsMediaItemSelected, 1, &.{*MediaItem});

/// IsProjectDirty
/// Is the project dirty (needing save)? Always returns 0 if 'undo/prompt to save' is disabled in preferences.
///-- @param proj *ReaProject
pub const IsProjectDirty = function(&reaper.IsProjectDirty, 1, &.{*ReaProject});

/// IsREAPER
/// Returns true if dealing with REAPER, returns false for ReaMote, etc
pub const IsREAPER = function(&reaper.IsREAPER, 0, &.{});

/// IsTrackSelected
///-- @param track MediaTrack
pub const IsTrackSelected = function(&reaper.IsTrackSelected, 1, &.{MediaTrack});

/// IsTrackVisible
/// If mixer==true, returns true if the track is visible in the mixer.  If mixer==false, returns true if the track is visible in the track control panel.
///-- @param track MediaTrack
///-- @param mixer bool
pub const IsTrackVisible = function(&reaper.IsTrackVisible, 2, &.{ MediaTrack, bool });

/// joystick_create
/// creates a joystick device
///-- @param guid *const GUID
pub const joystick_create = function(&reaper.joystick_create, 1, &.{*const GUID});

/// joystick_destroy
/// destroys a joystick device
///-- @param device *joystick_device
pub const joystick_destroy = function(&reaper.joystick_destroy, 1, &.{*joystick_device});

/// joystick_enum
/// enumerates installed devices, returns GUID as a string
///-- @param index c_int
///-- @param namestrOutOptional [*:0]const u8
pub const joystick_enum = function(&reaper.joystick_enum, 2, &.{ c_int, [*:0]const u8 });

/// joystick_getaxis
/// returns axis value (-1..1)
///-- @param dev *joystick_device
///-- @param axis c_int
pub const joystick_getaxis = function(&reaper.joystick_getaxis, 2, &.{ *joystick_device, c_int });

/// joystick_getbuttonmask
/// returns button pressed mask, 1=first button, 2=second...
///-- @param dev *joystick_device
pub const joystick_getbuttonmask = function(&reaper.joystick_getbuttonmask, 1, &.{*joystick_device});

/// joystick_getinfo
/// returns button count
///-- @param dev *joystick_device
///-- @param axesOutOptional *c_int
///-- @param povsOutOptional *c_int
pub const joystick_getinfo = function(&reaper.joystick_getinfo, 3, &.{ *joystick_device, *c_int, *c_int });

/// joystick_getpov
/// returns POV value (usually 0..655.35, or 655.35 on error)
///-- @param dev *joystick_device
///-- @param pov c_int
pub const joystick_getpov = function(&reaper.joystick_getpov, 2, &.{ *joystick_device, c_int });

/// joystick_update
/// Updates joystick state from hardware, returns true if successful (*joystick_get will not be valid until joystick_update() is called successfully)
///-- @param dev *joystick_device
pub const joystick_update = function(&reaper.joystick_update, 1, &.{*joystick_device});

/// kbd_enumerateActions
///-- @param section *KbdSectionInfo
///-- @param idx c_int
///-- @param nameOut [*:0]const u8
pub const kbd_enumerateActions = function(&reaper.kbd_enumerateActions, 3, &.{ *KbdSectionInfo, c_int, [*:0]const u8 });

/// kbd_formatKeyName
///-- @param ac *ACCEL
///-- @param s *c_char
pub const kbd_formatKeyName = function(&reaper.kbd_formatKeyName, 2, &.{ *ACCEL, *c_char });

/// kbd_getCommandName
/// Get the string of a key assigned to command "cmd" in a section.
/// This function is poorly named as it doesn't return the command's name, see kbd_getTextFromCmd.
///-- @param cmd c_int
///-- @param s *c_char
///-- @param section *KbdSectionInfo
pub const kbd_getCommandName = function(&reaper.kbd_getCommandName, 3, &.{ c_int, *c_char, *KbdSectionInfo });

/// kbd_getTextFromCmd
///-- @param cmd c_int
///-- @param section *KbdSectionInfo
pub const kbd_getTextFromCmd = function(&reaper.kbd_getTextFromCmd, 2, &.{ c_int, *KbdSectionInfo });

/// KBD_OnMainActionEx
/// val/valhw are used for midi stuff.
/// val=[0..127] and valhw=-1 (midi CC),
/// valhw >=0 (midi pitch (valhw | val<<7)),
/// relmode absolute (0) or 1/2/3 for relative adjust modes
///-- @param cmd c_int
///-- @param val c_int
///-- @param valhw c_int
///-- @param relmode c_int
///-- @param hwnd HWND
///-- @param proj *ReaProject
pub const KBD_OnMainActionEx = function(&reaper.KBD_OnMainActionEx, 6, &.{ c_int, c_int, c_int, c_int, HWND, *ReaProject });

/// kbd_OnMidiEvent
/// can be called from anywhere (threadsafe)
///-- @param evt *MIDI_event_t
///-- @param index c_int
pub const kbd_OnMidiEvent = function(&reaper.kbd_OnMidiEvent, 2, &.{ *MIDI_event_t, c_int });

/// kbd_OnMidiList
/// can be called from anywhere (threadsafe)
///-- @param list *MIDI_eventlist
///-- @param index c_int
pub const kbd_OnMidiList = function(&reaper.kbd_OnMidiList, 2, &.{ *MIDI_eventlist, c_int });

/// kbd_ProcessActionsMenu
///-- @param menu HMENU
///-- @param section *KbdSectionInfo
pub const kbd_ProcessActionsMenu = function(&reaper.kbd_ProcessActionsMenu, 2, &.{ HMENU, *KbdSectionInfo });

/// kbd_processMidiEventActionEx
///-- @param evt *MIDI_event_t
///-- @param section *KbdSectionInfo
///-- @param hwndCtx HWND
pub const kbd_processMidiEventActionEx = function(&reaper.kbd_processMidiEventActionEx, 3, &.{ *MIDI_event_t, *KbdSectionInfo, HWND });

/// kbd_reprocessMenu
/// Reprocess a menu recursively, setting key assignments to what their command IDs are mapped to.
///-- @param menu HMENU
///-- @param section *KbdSectionInfo
pub const kbd_reprocessMenu = function(&reaper.kbd_reprocessMenu, 2, &.{ HMENU, *KbdSectionInfo });

/// kbd_RunCommandThroughHooks
/// actioncommandID may get modified
///-- @param section *KbdSectionInfo
///-- @param actionCommandID *const c_int
///-- @param val *const c_int
///-- @param valhw *const c_int
///-- @param relmode *const c_int
///-- @param hwnd HWND
pub const kbd_RunCommandThroughHooks = function(&reaper.kbd_RunCommandThroughHooks, 6, &.{ *KbdSectionInfo, *const c_int, *const c_int, *const c_int, *const c_int, HWND });

/// kbd_translateAccelerator
/// Pass in the HWND to receive commands, a MSG of a key command,  and a valid section,
/// and kbd_translateAccelerator() will process it looking for any keys bound to it, and send the messages off.
/// Returns 1 if processed, 0 if no key binding found.
///-- @param hwnd HWND
///-- @param msg *MSG
///-- @param section *KbdSectionInfo
pub const kbd_translateAccelerator = function(&reaper.kbd_translateAccelerator, 3, &.{ HWND, *MSG, *KbdSectionInfo });

/// LICE__Destroy
///-- @param bm *LICE_IBitmap
pub const LICE__Destroy = function(&reaper.LICE__Destroy, 1, &.{*LICE_IBitmap});

/// LICE__DestroyFont
///-- @param font *LICE_IFont
pub const LICE__DestroyFont = function(&reaper.LICE__DestroyFont, 1, &.{*LICE_IFont});

/// LICE__DrawText
///-- @param font *LICE_IFont
///-- @param bm *LICE_IBitmap
///-- @param str [*:0]const u8
///-- @param strcnt c_int
///-- @param rect *RECT
///-- @param dtFlags UINT
pub const LICE__DrawText = function(&reaper.LICE__DrawText, 6, &.{ *LICE_IFont, *LICE_IBitmap, [*:0]const u8, c_int, *RECT, UINT });

/// LICE__GetBits
///-- @param bm *LICE_IBitmap
pub const LICE__GetBits = function(&reaper.LICE__GetBits, 1, &.{*LICE_IBitmap});

/// LICE__GetDC
///-- @param bm *LICE_IBitmap
pub const LICE__GetDC = function(&reaper.LICE__GetDC, 1, &.{*LICE_IBitmap});

/// LICE__GetHeight
///-- @param bm *LICE_IBitmap
pub const LICE__GetHeight = function(&reaper.LICE__GetHeight, 1, &.{*LICE_IBitmap});

/// LICE__GetRowSpan
///-- @param bm *LICE_IBitmap
pub const LICE__GetRowSpan = function(&reaper.LICE__GetRowSpan, 1, &.{*LICE_IBitmap});

/// LICE__GetWidth
///-- @param bm *LICE_IBitmap
pub const LICE__GetWidth = function(&reaper.LICE__GetWidth, 1, &.{*LICE_IBitmap});

/// LICE__IsFlipped
///-- @param bm *LICE_IBitmap
pub const LICE__IsFlipped = function(&reaper.LICE__IsFlipped, 1, &.{*LICE_IBitmap});

/// LICE__resize
///-- @param bm *LICE_IBitmap
///-- @param w c_int
///-- @param h c_int
pub const LICE__resize = function(&reaper.LICE__resize, 3, &.{ *LICE_IBitmap, c_int, c_int });

/// LICE__SetBkColor
///-- @param font *LICE_IFont
///-- @param color LICE_pixel
pub const LICE__SetBkColor = function(&reaper.LICE__SetBkColor, 2, &.{ *LICE_IFont, LICE_pixel });

/// LICE__SetFromHFont
/// font must REMAIN valid,unless LICE_FONT_FLAG_PRECALCALL is set
///-- @param font *LICE_IFont
///-- @param hfont HFONT
///-- @param flags c_int
pub const LICE__SetFromHFont = function(&reaper.LICE__SetFromHFont, 3, &.{ *LICE_IFont, HFONT, c_int });

/// LICE__SetTextColor
///-- @param font *LICE_IFont
///-- @param color LICE_pixel
pub const LICE__SetTextColor = function(&reaper.LICE__SetTextColor, 2, &.{ *LICE_IFont, LICE_pixel });

/// LICE__SetTextCombineMode
///-- @param ifont *LICE_IFont
///-- @param mode c_int
///-- @param alpha f32
pub const LICE__SetTextCombineMode = function(&reaper.LICE__SetTextCombineMode, 3, &.{ *LICE_IFont, c_int, f32 });

/// LICE_Arc
///-- @param dest *LICE_IBitmap
///-- @param cx f32
///-- @param cy f32
///-- @param r f32
///-- @param minAngle f32
///-- @param maxAngle f32
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
///-- @param aa bool
pub const LICE_Arc = function(&reaper.LICE_Arc, 10, &.{ *LICE_IBitmap, f32, f32, f32, f32, f32, LICE_pixel, f32, c_int, bool });

/// LICE_Blit
///-- @param dest *LICE_IBitmap
///-- @param src *LICE_IBitmap
///-- @param dstx c_int
///-- @param dsty c_int
///-- @param srcx c_int
///-- @param srcy c_int
///-- @param srcw c_int
///-- @param srch c_int
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_Blit = function(&reaper.LICE_Blit, 10, &.{ *LICE_IBitmap, *LICE_IBitmap, c_int, c_int, c_int, c_int, c_int, c_int, f32, c_int });

/// LICE_Blur
///-- @param dest *LICE_IBitmap
///-- @param src *LICE_IBitmap
///-- @param dstx c_int
///-- @param dsty c_int
///-- @param srcx c_int
///-- @param srcy c_int
///-- @param srcw c_int
///-- @param srch c_int
pub const LICE_Blur = function(&reaper.LICE_Blur, 8, &.{ *LICE_IBitmap, *LICE_IBitmap, c_int, c_int, c_int, c_int, c_int, c_int });

/// LICE_BorderedRect
///-- @param dest *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param w c_int
///-- @param h c_int
///-- @param bgcolor LICE_pixel
///-- @param fgcolor LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_BorderedRect = function(&reaper.LICE_BorderedRect, 9, &.{ *LICE_IBitmap, c_int, c_int, c_int, c_int, LICE_pixel, LICE_pixel, f32, c_int });

/// LICE_Circle
///-- @param dest *LICE_IBitmap
///-- @param cx f32
///-- @param cy f32
///-- @param r f32
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
///-- @param aa bool
pub const LICE_Circle = function(&reaper.LICE_Circle, 8, &.{ *LICE_IBitmap, f32, f32, f32, LICE_pixel, f32, c_int, bool });

/// LICE_Clear
///-- @param dest *LICE_IBitmap
///-- @param color LICE_pixel
pub const LICE_Clear = function(&reaper.LICE_Clear, 2, &.{ *LICE_IBitmap, LICE_pixel });

/// LICE_ClearRect
///-- @param dest *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param w c_int
///-- @param h c_int
///-- @param mask LICE_pixel
///-- @param orbits LICE_pixel
pub const LICE_ClearRect = function(&reaper.LICE_ClearRect, 7, &.{ *LICE_IBitmap, c_int, c_int, c_int, c_int, LICE_pixel, LICE_pixel });

/// LICE_ClipLine
/// Returns false if the line is entirely offscreen.
///-- @param pX1Out *c_int
///-- @param pY1Out *c_int
///-- @param pX2Out *c_int
///-- @param pY2Out *c_int
///-- @param xLo c_int
///-- @param yLo c_int
///-- @param xHi c_int
///-- @param yHi c_int
pub const LICE_ClipLine = function(&reaper.LICE_ClipLine, 8, &.{ *c_int, *c_int, *c_int, *c_int, c_int, c_int, c_int, c_int });

/// LICE_CombinePixels
///-- @param dest LICE_pixel
///-- @param src LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_CombinePixels = function(&reaper.LICE_CombinePixels, 4, &.{ LICE_pixel, LICE_pixel, f32, c_int });

/// LICE_Copy
///-- @param dest *LICE_IBitmap
///-- @param src *LICE_IBitmap
pub const LICE_Copy = function(&reaper.LICE_Copy, 2, &.{ *LICE_IBitmap, *LICE_IBitmap });

/// LICE_CreateBitmap
/// create a new bitmap. this is like calling new LICE_MemBitmap (mode=0) or new LICE_SysBitmap (mode=1).
///-- @param mode c_int
///-- @param w c_int
///-- @param h c_int
pub const LICE_CreateBitmap = function(&reaper.LICE_CreateBitmap, 3, &.{ c_int, c_int, c_int });

/// LICE_CreateFont
pub const LICE_CreateFont = function(&reaper.LICE_CreateFont, 0, &.{});

/// LICE_DrawCBezier
///-- @param dest *LICE_IBitmap
///-- @param xstart f64
///-- @param ystart f64
///-- @param xctl1 f64
///-- @param yctl1 f64
///-- @param xctl2 f64
///-- @param yctl2 f64
///-- @param xend f64
///-- @param yend f64
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
///-- @param aa bool
///-- @param tol f64
pub const LICE_DrawCBezier = function(&reaper.LICE_DrawCBezier, 14, &.{ *LICE_IBitmap, f64, f64, f64, f64, f64, f64, f64, f64, LICE_pixel, f32, c_int, bool, f64 });

/// LICE_DrawChar
///-- @param bm *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param c c_char
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_DrawChar = function(&reaper.LICE_DrawChar, 7, &.{ *LICE_IBitmap, c_int, c_int, c_char, LICE_pixel, f32, c_int });

/// LICE_DrawGlyph
///-- @param dest *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param color LICE_pixel
///-- @param alphas *LICE_pixel_chan
///-- @param w c_int
///-- @param h c_int
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_DrawGlyph = function(&reaper.LICE_DrawGlyph, 9, &.{ *LICE_IBitmap, c_int, c_int, LICE_pixel, *LICE_pixel_chan, c_int, c_int, f32, c_int });

/// LICE_DrawRect
///-- @param dest *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param w c_int
///-- @param h c_int
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_DrawRect = function(&reaper.LICE_DrawRect, 8, &.{ *LICE_IBitmap, c_int, c_int, c_int, c_int, LICE_pixel, f32, c_int });

/// LICE_DrawText
///-- @param bm *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param string [*:0]const u8
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_DrawText = function(&reaper.LICE_DrawText, 7, &.{ *LICE_IBitmap, c_int, c_int, [*:0]const u8, LICE_pixel, f32, c_int });

/// LICE_FillCBezier
///-- @param dest *LICE_IBitmap
///-- @param xstart f64
///-- @param ystart f64
///-- @param xctl1 f64
///-- @param yctl1 f64
///-- @param xctl2 f64
///-- @param yctl2 f64
///-- @param xend f64
///-- @param yend f64
///-- @param yfill c_int
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
///-- @param aa bool
///-- @param tol f64
pub const LICE_FillCBezier = function(&reaper.LICE_FillCBezier, 15, &.{ *LICE_IBitmap, f64, f64, f64, f64, f64, f64, f64, f64, c_int, LICE_pixel, f32, c_int, bool, f64 });

/// LICE_FillCircle
///-- @param dest *LICE_IBitmap
///-- @param cx f32
///-- @param cy f32
///-- @param r f32
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
///-- @param aa bool
pub const LICE_FillCircle = function(&reaper.LICE_FillCircle, 8, &.{ *LICE_IBitmap, f32, f32, f32, LICE_pixel, f32, c_int, bool });

/// LICE_FillConvexPolygon
///-- @param dest *LICE_IBitmap
///-- @param x *c_int
///-- @param y *c_int
///-- @param npoints c_int
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_FillConvexPolygon = function(&reaper.LICE_FillConvexPolygon, 7, &.{ *LICE_IBitmap, *c_int, *c_int, c_int, LICE_pixel, f32, c_int });

/// LICE_FillRect
///-- @param dest *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param w c_int
///-- @param h c_int
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_FillRect = function(&reaper.LICE_FillRect, 8, &.{ *LICE_IBitmap, c_int, c_int, c_int, c_int, LICE_pixel, f32, c_int });

/// LICE_FillTrapezoid
///-- @param dest *LICE_IBitmap
///-- @param x1a c_int
///-- @param x1b c_int
///-- @param y1 c_int
///-- @param x2a c_int
///-- @param x2b c_int
///-- @param y2 c_int
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_FillTrapezoid = function(&reaper.LICE_FillTrapezoid, 10, &.{ *LICE_IBitmap, c_int, c_int, c_int, c_int, c_int, c_int, LICE_pixel, f32, c_int });

/// LICE_FillTriangle
///-- @param dest *LICE_IBitmap
///-- @param x1 c_int
///-- @param y1 c_int
///-- @param x2 c_int
///-- @param y2 c_int
///-- @param x3 c_int
///-- @param y3 c_int
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_FillTriangle = function(&reaper.LICE_FillTriangle, 10, &.{ *LICE_IBitmap, c_int, c_int, c_int, c_int, c_int, c_int, LICE_pixel, f32, c_int });

/// LICE_GetPixel
///-- @param bm *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
pub const LICE_GetPixel = function(&reaper.LICE_GetPixel, 3, &.{ *LICE_IBitmap, c_int, c_int });

/// LICE_GradRect
///-- @param dest *LICE_IBitmap
///-- @param dstx c_int
///-- @param dsty c_int
///-- @param dstw c_int
///-- @param dsth c_int
///-- @param ir f32
///-- @param ig f32
///-- @param ib f32
///-- @param ia f32
///-- @param drdx f32
///-- @param dgdx f32
///-- @param dbdx f32
///-- @param dadx f32
///-- @param drdy f32
///-- @param dgdy f32
///-- @param dbdy f32
///-- @param dady f32
///-- @param mode c_int
pub const LICE_GradRect = function(&reaper.LICE_GradRect, 18, &.{ *LICE_IBitmap, c_int, c_int, c_int, c_int, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, c_int });

/// LICE_Line
///-- @param dest *LICE_IBitmap
///-- @param x1 f32
///-- @param y1 f32
///-- @param x2 f32
///-- @param y2 f32
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
///-- @param aa bool
pub const LICE_Line = function(&reaper.LICE_Line, 9, &.{ *LICE_IBitmap, f32, f32, f32, f32, LICE_pixel, f32, c_int, bool });

/// LICE_LineInt
///-- @param dest *LICE_IBitmap
///-- @param x1 c_int
///-- @param y1 c_int
///-- @param x2 c_int
///-- @param y2 c_int
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
///-- @param aa bool
pub const LICE_LineInt = function(&reaper.LICE_LineInt, 9, &.{ *LICE_IBitmap, c_int, c_int, c_int, c_int, LICE_pixel, f32, c_int, bool });

/// LICE_LoadPNG
///-- @param filename [*:0]const u8
///-- @param bmp *LICE_IBitmap
pub const LICE_LoadPNG = function(&reaper.LICE_LoadPNG, 2, &.{ [*:0]const u8, *LICE_IBitmap });

/// LICE_LoadPNGFromResource
///-- @param hInst HINSTANCE
///-- @param resid [*:0]const u8
///-- @param bmp *LICE_IBitmap
pub const LICE_LoadPNGFromResource = function(&reaper.LICE_LoadPNGFromResource, 3, &.{ HINSTANCE, [*:0]const u8, *LICE_IBitmap });

/// LICE_MeasureText
///-- @param string [*:0]const u8
///-- @param w *c_int
///-- @param h *c_int
pub const LICE_MeasureText = function(&reaper.LICE_MeasureText, 3, &.{ [*:0]const u8, *c_int, *c_int });

/// LICE_MultiplyAddRect
///-- @param dest *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param w c_int
///-- @param h c_int
///-- @param rsc f32
///-- @param gsc f32
///-- @param bsc f32
///-- @param asc f32
///-- @param radd f32
///-- @param gadd f32
///-- @param badd f32
///-- @param aadd f32
pub const LICE_MultiplyAddRect = function(&reaper.LICE_MultiplyAddRect, 13, &.{ *LICE_IBitmap, c_int, c_int, c_int, c_int, f32, f32, f32, f32, f32, f32, f32, f32 });

/// LICE_PutPixel
///-- @param bm *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_PutPixel = function(&reaper.LICE_PutPixel, 6, &.{ *LICE_IBitmap, c_int, c_int, LICE_pixel, f32, c_int });

/// LICE_RotatedBlit
/// these coordinates are offset from the center of the image,in source pixel coordinates
///-- @param dest *LICE_IBitmap
///-- @param src *LICE_IBitmap
///-- @param dstx c_int
///-- @param dsty c_int
///-- @param dstw c_int
///-- @param dsth c_int
///-- @param srcx f32
///-- @param srcy f32
///-- @param srcw f32
///-- @param srch f32
///-- @param angle f32
///-- @param cliptosourcerect bool
///-- @param alpha f32
///-- @param mode c_int
///-- @param rotxcent f32
///-- @param rotycent f32
pub const LICE_RotatedBlit = function(&reaper.LICE_RotatedBlit, 16, &.{ *LICE_IBitmap, *LICE_IBitmap, c_int, c_int, c_int, c_int, f32, f32, f32, f32, f32, bool, f32, c_int, f32, f32 });

/// LICE_RoundRect
///-- @param drawbm *LICE_IBitmap
///-- @param xpos f32
///-- @param ypos f32
///-- @param w f32
///-- @param h f32
///-- @param cornerradius c_int
///-- @param col LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
///-- @param aa bool
pub const LICE_RoundRect = function(&reaper.LICE_RoundRect, 10, &.{ *LICE_IBitmap, f32, f32, f32, f32, c_int, LICE_pixel, f32, c_int, bool });

/// LICE_ScaledBlit
///-- @param dest *LICE_IBitmap
///-- @param src *LICE_IBitmap
///-- @param dstx c_int
///-- @param dsty c_int
///-- @param dstw c_int
///-- @param dsth c_int
///-- @param srcx f32
///-- @param srcy f32
///-- @param srcw f32
///-- @param srch f32
///-- @param alpha f32
///-- @param mode c_int
pub const LICE_ScaledBlit = function(&reaper.LICE_ScaledBlit, 12, &.{ *LICE_IBitmap, *LICE_IBitmap, c_int, c_int, c_int, c_int, f32, f32, f32, f32, f32, c_int });

/// LICE_SimpleFill
///-- @param dest *LICE_IBitmap
///-- @param x c_int
///-- @param y c_int
///-- @param newcolor LICE_pixel
///-- @param comparemask LICE_pixel
///-- @param keepmask LICE_pixel
pub const LICE_SimpleFill = function(&reaper.LICE_SimpleFill, 6, &.{ *LICE_IBitmap, c_int, c_int, LICE_pixel, LICE_pixel, LICE_pixel });

/// LICE_ThickFLine
/// always AA. wid is not affected by scaling (1 is always normal line, 2 is always 2 physical pixels, etc)
///-- @param dest *LICE_IBitmap
///-- @param x1 f64
///-- @param y1 f64
///-- @param x2 f64
///-- @param y2 f64
///-- @param color LICE_pixel
///-- @param alpha f32
///-- @param mode c_int
///-- @param wid c_int
pub const LICE_ThickFLine = function(&reaper.LICE_ThickFLine, 9, &.{ *LICE_IBitmap, f64, f64, f64, f64, LICE_pixel, f32, c_int, c_int });

/// LocalizeString
/// Returns a localized version of src_string, in section section. flags can have 1 set to only localize if sprintf-style formatting matches the original.
///-- @param string [*:0]const u8
///-- @param section [*:0]const u8
///-- @param flagsOptional c_int
pub const LocalizeString = function(&reaper.LocalizeString, 3, &.{ [*:0]const u8, [*:0]const u8, c_int });

/// Loop_OnArrow
/// Move the loop selection left or right. Returns true if snap is enabled.
///-- @param project *ReaProject
///-- @param direction c_int
pub const Loop_OnArrow = function(&reaper.Loop_OnArrow, 2, &.{ *ReaProject, c_int });

/// Main_OnCommand
/// See Main_OnCommandEx.
///-- @param command c_int
///-- @param flag c_int
pub const Main_OnCommand = function(&reaper.Main_OnCommand, 2, &.{ c_int, c_int });

/// Main_OnCommandEx
/// Performs an action belonging to the main action section. To perform non-native actions (ReaScripts, custom or extension plugins' actions) safely, see NamedCommandLookup().
///-- @param command c_int
///-- @param flag c_int
///-- @param proj *ReaProject
pub const Main_OnCommandEx = function(&reaper.Main_OnCommandEx, 3, &.{ c_int, c_int, *ReaProject });

/// Main_openProject
/// opens a project. will prompt the user to save unless name is prefixed with 'noprompt:'. If name is prefixed with 'template:', project file will be loaded as a template.
/// If passed a .RTrackTemplate file, adds the template to the existing project.
///-- @param name [*:0]const u8
pub const Main_openProject = function(&reaper.Main_openProject, 1, &.{[*:0]const u8});

/// Main_SaveProject
/// Save the project.
///-- @param proj *ReaProject
///-- @param forceSaveAsInOptional bool
pub const Main_SaveProject = function(&reaper.Main_SaveProject, 2, &.{ *ReaProject, bool });

/// Main_SaveProjectEx
/// Save the project. options: &1=save selected tracks as track template, &2=include media with track template, &4=include envelopes with track template. See Main_openProject, Main_SaveProject.
///-- @param proj *ReaProject
///-- @param filename [*:0]const u8
///-- @param options c_int
pub const Main_SaveProjectEx = function(&reaper.Main_SaveProjectEx, 3, &.{ *ReaProject, [*:0]const u8, c_int });

/// Main_UpdateLoopInfo
///-- @param ignoremask c_int
pub const Main_UpdateLoopInfo = function(&reaper.Main_UpdateLoopInfo, 1, &.{c_int});

/// MarkProjectDirty
/// Marks project as dirty (needing save) if 'undo/prompt to save' is enabled in preferences.
///-- @param proj *ReaProject
pub const MarkProjectDirty = function(&reaper.MarkProjectDirty, 1, &.{*ReaProject});

/// MarkTrackItemsDirty
/// If track is supplied, item is ignored
///-- @param track MediaTrack
///-- @param item *MediaItem
pub const MarkTrackItemsDirty = function(&reaper.MarkTrackItemsDirty, 2, &.{ MediaTrack, *MediaItem });

/// Master_GetPlayRate
///-- @param project *ReaProject
pub const Master_GetPlayRate = function(&reaper.Master_GetPlayRate, 1, &.{*ReaProject});

/// Master_GetPlayRateAtTime
///-- @param s f64
///-- @param proj *ReaProject
pub const Master_GetPlayRateAtTime = function(&reaper.Master_GetPlayRateAtTime, 2, &.{ f64, *ReaProject });

/// Master_GetTempo
pub const Master_GetTempo = function(&reaper.Master_GetTempo, 0, &.{});

/// Master_NormalizePlayRate
/// Convert play rate to/from a value between 0 and 1, representing the position on the project playrate slider.
///-- @param playrate f64
///-- @param isnormalized bool
pub const Master_NormalizePlayRate = function(&reaper.Master_NormalizePlayRate, 2, &.{ f64, bool });

/// Master_NormalizeTempo
/// Convert the tempo to/from a value between 0 and 1, representing bpm in the range of 40-296 bpm.
///-- @param bpm f64
///-- @param isnormalized bool
pub const Master_NormalizeTempo = function(&reaper.Master_NormalizeTempo, 2, &.{ f64, bool });

/// MB
/// type 0=OK,1=OKCANCEL,2=ABORTRETRYIGNORE,3=YESNOCANCEL,4=YESNO,5=RETRYCANCEL : ret 1=OK,2=CANCEL,3=ABORT,4=RETRY,5=IGNORE,6=YES,7=NO
///-- @param msg [*:0]const u8
///-- @param title [*:0]const u8
///-- @param type c_int
pub const MB = function(&reaper.MB, 3, &.{ [*:0]const u8, [*:0]const u8, c_int });

/// MediaItemDescendsFromTrack
/// Returns 1 if the track holds the item, 2 if the track is a folder containing the track that holds the item, etc.
///-- @param item *MediaItem
///-- @param track MediaTrack
pub const MediaItemDescendsFromTrack = function(&reaper.MediaItemDescendsFromTrack, 2, &.{ *MediaItem, MediaTrack });

/// Menu_GetHash
/// Get a string that only changes when menu/toolbar entries are added or removed (not re-ordered). Can be used to determine if a customized menu/toolbar differs from the default, or if the default changed after a menu/toolbar was customized. flag==0: current default menu/toolbar; flag==1: current customized menu/toolbar; flag==2: default menu/toolbar at the time the current menu/toolbar was most recently customized, if it was customized in REAPER v7.08 or later.
///-- @param menuname [*:0]const u8
///-- @param flag c_int
///-- @param hashOut *c_char
///-- @param sz c_int
pub const Menu_GetHash = function(&reaper.Menu_GetHash, 4, &.{ [*:0]const u8, c_int, *c_char, c_int });

/// MIDI_CountEvts
/// Count the number of notes, CC events, and text/sysex events in a given MIDI item.
///-- @param take *MediaItem_Take
///-- @param notecntOut *c_int
///-- @param ccevtcntOut *c_int
///-- @param textsyxevtcntOut *c_int
pub const MIDI_CountEvts = function(&reaper.MIDI_CountEvts, 4, &.{ *MediaItem_Take, *c_int, *c_int, *c_int });

/// MIDI_DeleteCC
/// Delete a MIDI CC event.
///-- @param take *MediaItem_Take
///-- @param ccidx c_int
pub const MIDI_DeleteCC = function(&reaper.MIDI_DeleteCC, 2, &.{ *MediaItem_Take, c_int });

/// MIDI_DeleteEvt
/// Delete a MIDI event.
///-- @param take *MediaItem_Take
///-- @param evtidx c_int
pub const MIDI_DeleteEvt = function(&reaper.MIDI_DeleteEvt, 2, &.{ *MediaItem_Take, c_int });

/// MIDI_DeleteNote
/// Delete a MIDI note.
///-- @param take *MediaItem_Take
///-- @param noteidx c_int
pub const MIDI_DeleteNote = function(&reaper.MIDI_DeleteNote, 2, &.{ *MediaItem_Take, c_int });

/// MIDI_DeleteTextSysexEvt
/// Delete a MIDI text or sysex event.
///-- @param take *MediaItem_Take
///-- @param textsyxevtidx c_int
pub const MIDI_DeleteTextSysexEvt = function(&reaper.MIDI_DeleteTextSysexEvt, 2, &.{ *MediaItem_Take, c_int });

/// MIDI_DisableSort
/// Disable sorting for all MIDI insert, delete, get and set functions, until MIDI_Sort is called.
///-- @param take *MediaItem_Take
pub const MIDI_DisableSort = function(&reaper.MIDI_DisableSort, 1, &.{*MediaItem_Take});

/// MIDI_EnumSelCC
/// Returns the index of the next selected MIDI CC event after ccidx (-1 if there are no more selected events).
///-- @param take *MediaItem_Take
///-- @param ccidx c_int
pub const MIDI_EnumSelCC = function(&reaper.MIDI_EnumSelCC, 2, &.{ *MediaItem_Take, c_int });

/// MIDI_EnumSelEvts
/// Returns the index of the next selected MIDI event after evtidx (-1 if there are no more selected events).
///-- @param take *MediaItem_Take
///-- @param evtidx c_int
pub const MIDI_EnumSelEvts = function(&reaper.MIDI_EnumSelEvts, 2, &.{ *MediaItem_Take, c_int });

/// MIDI_EnumSelNotes
/// Returns the index of the next selected MIDI note after noteidx (-1 if there are no more selected events).
///-- @param take *MediaItem_Take
///-- @param noteidx c_int
pub const MIDI_EnumSelNotes = function(&reaper.MIDI_EnumSelNotes, 2, &.{ *MediaItem_Take, c_int });

/// MIDI_EnumSelTextSysexEvts
/// Returns the index of the next selected MIDI text/sysex event after textsyxidx (-1 if there are no more selected events).
///-- @param take *MediaItem_Take
///-- @param textsyxidx c_int
pub const MIDI_EnumSelTextSysexEvts = function(&reaper.MIDI_EnumSelTextSysexEvts, 2, &.{ *MediaItem_Take, c_int });

/// MIDI_eventlist_Create
/// Create a MIDI_eventlist object. The returned object must be deleted with MIDI_eventlist_destroy().
pub const MIDI_eventlist_Create = function(&reaper.MIDI_eventlist_Create, 0, &.{});

/// MIDI_eventlist_Destroy
/// Destroy a MIDI_eventlist object that was created using MIDI_eventlist_Create().
///-- @param evtlist *MIDI_eventlist
pub const MIDI_eventlist_Destroy = function(&reaper.MIDI_eventlist_Destroy, 1, &.{*MIDI_eventlist});

/// MIDI_GetAllEvts
/// Get all MIDI data. MIDI buffer is returned as a list of { c_int offset, c_char flag, c_int msglen, unsigned c_char msg[] }.
/// offset: MIDI ticks from previous event
/// flag: &1=selected &2=muted
/// flag high 4 bits for CC shape: &16=linear, &32=slow start/end, &16|32=fast start, &64=fast end, &64|16=bezier
/// msg: the MIDI message.
/// A meta-event of type 0xF followed by 'CCBZ ' and 5 more bytes represents bezier curve data for the previous MIDI event: 1 byte for the bezier type (usually 0) and 4 bytes for the bezier tension as a f32.
/// For tick intervals longer than a 32 bit word can represent, zero-length meta events may be placed between valid events.
/// See MIDI_SetAllEvts.
///-- @param take *MediaItem_Take
///-- @param bufOutNeedBig *c_char
///-- @param sz *c_int
pub const MIDI_GetAllEvts = function(&reaper.MIDI_GetAllEvts, 3, &.{ *MediaItem_Take, *c_char, *c_int });

/// MIDI_GetCC
/// Get MIDI CC event properties.
///-- @param take *MediaItem_Take
///-- @param ccidx c_int
///-- @param selectedOut *bool
///-- @param mutedOut *bool
///-- @param ppqposOut *f64
///-- @param chanmsgOut *c_int
///-- @param chanOut *c_int
///-- @param msg2Out *c_int
///-- @param msg3Out *c_int
pub const MIDI_GetCC = function(&reaper.MIDI_GetCC, 9, &.{ *MediaItem_Take, c_int, *bool, *bool, *f64, *c_int, *c_int, *c_int, *c_int });

/// MIDI_GetCCShape
/// Get CC shape and bezier tension. See MIDI_GetCC, MIDI_SetCCShape
///-- @param take *MediaItem_Take
///-- @param ccidx c_int
///-- @param shapeOut *c_int
///-- @param beztensionOut *f64
pub const MIDI_GetCCShape = function(&reaper.MIDI_GetCCShape, 4, &.{ *MediaItem_Take, c_int, *c_int, *f64 });

/// MIDI_GetEvt
/// Get MIDI event properties.
///-- @param take *MediaItem_Take
///-- @param evtidx c_int
///-- @param selectedOut *bool
///-- @param mutedOut *bool
///-- @param ppqposOut *f64
///-- @param msgOut *c_char
///-- @param sz *c_int
pub const MIDI_GetEvt = function(&reaper.MIDI_GetEvt, 7, &.{ *MediaItem_Take, c_int, *bool, *bool, *f64, *c_char, *c_int });

/// MIDI_GetGrid
/// Returns the most recent MIDI editor grid size for this MIDI take, in QN. Swing is between 0 and 1. Note length is 0 if it follows the grid size.
///-- @param take *MediaItem_Take
///-- @param swingOutOptional *f64
///-- @param noteLenOutOptional *f64
pub const MIDI_GetGrid = function(&reaper.MIDI_GetGrid, 3, &.{ *MediaItem_Take, *f64, *f64 });

/// MIDI_GetHash
/// Get a string that only changes when the MIDI data changes. If notesonly==true, then the string changes only when the MIDI notes change. See MIDI_GetTrackHash
///-- @param take *MediaItem_Take
///-- @param notesonly bool
///-- @param hashOut *c_char
///-- @param sz c_int
pub const MIDI_GetHash = function(&reaper.MIDI_GetHash, 4, &.{ *MediaItem_Take, bool, *c_char, c_int });

/// MIDI_GetNote
/// Get MIDI note properties.
///-- @param take *MediaItem_Take
///-- @param noteidx c_int
///-- @param selectedOut *bool
///-- @param mutedOut *bool
///-- @param startppqposOut *f64
///-- @param endppqposOut *f64
///-- @param chanOut *c_int
///-- @param pitchOut *c_int
///-- @param velOut *c_int
pub const MIDI_GetNote = function(&reaper.MIDI_GetNote, 9, &.{ *MediaItem_Take, c_int, *bool, *bool, *f64, *f64, *c_int, *c_int, *c_int });

/// MIDI_GetPPQPos_EndOfMeasure
/// Returns the MIDI tick (ppq) position corresponding to the end of the measure.
///-- @param take *MediaItem_Take
///-- @param ppqpos f64
pub const MIDI_GetPPQPos_EndOfMeasure = function(&reaper.MIDI_GetPPQPos_EndOfMeasure, 2, &.{ *MediaItem_Take, f64 });

/// MIDI_GetPPQPos_StartOfMeasure
/// Returns the MIDI tick (ppq) position corresponding to the start of the measure.
///-- @param take *MediaItem_Take
///-- @param ppqpos f64
pub const MIDI_GetPPQPos_StartOfMeasure = function(&reaper.MIDI_GetPPQPos_StartOfMeasure, 2, &.{ *MediaItem_Take, f64 });

/// MIDI_GetPPQPosFromProjQN
/// Returns the MIDI tick (ppq) position corresponding to a specific project time in quarter notes.
///-- @param take *MediaItem_Take
///-- @param projqn f64
pub const MIDI_GetPPQPosFromProjQN = function(&reaper.MIDI_GetPPQPosFromProjQN, 2, &.{ *MediaItem_Take, f64 });

/// MIDI_GetPPQPosFromProjTime
/// Returns the MIDI tick (ppq) position corresponding to a specific project time in seconds.
///-- @param take *MediaItem_Take
///-- @param projtime f64
pub const MIDI_GetPPQPosFromProjTime = function(&reaper.MIDI_GetPPQPosFromProjTime, 2, &.{ *MediaItem_Take, f64 });

/// MIDI_GetProjQNFromPPQPos
/// Returns the project time in quarter notes corresponding to a specific MIDI tick (ppq) position.
///-- @param take *MediaItem_Take
///-- @param ppqpos f64
pub const MIDI_GetProjQNFromPPQPos = function(&reaper.MIDI_GetProjQNFromPPQPos, 2, &.{ *MediaItem_Take, f64 });

/// MIDI_GetProjTimeFromPPQPos
/// Returns the project time in seconds corresponding to a specific MIDI tick (ppq) position.
///-- @param take *MediaItem_Take
///-- @param ppqpos f64
pub const MIDI_GetProjTimeFromPPQPos = function(&reaper.MIDI_GetProjTimeFromPPQPos, 2, &.{ *MediaItem_Take, f64 });

/// MIDI_GetRecentInputEvent
/// Gets a recent MIDI input event from the global history. idx=0 for the most recent event, which also latches to the latest MIDI event state (to get a more recent list, calling with idx=0 is necessary). idx=1 next most recent event, returns a non-zero sequence number for the event, or zero if no more events. tsOut will be set to the timestamp in samples relative to the current position (0 is current, -48000 is one second ago, etc). devIdxOut will have the low 16 bits set to the input device index, and 0x10000 will be set if device was enabled only for control. projPosOut will be set to project position in seconds if project was playing back at time of event, otherwise -1. Large SysEx events will not be included in this event list.
///-- @param idx c_int
///-- @param bufOut *c_char
///-- @param sz *c_int
///-- @param tsOut *c_int
///-- @param devIdxOut *c_int
///-- @param projPosOut *f64
///-- @param projLoopCntOut *c_int
pub const MIDI_GetRecentInputEvent = function(&reaper.MIDI_GetRecentInputEvent, 7, &.{ c_int, *c_char, *c_int, *c_int, *c_int, *f64, *c_int });

/// MIDI_GetScale
/// Get the active scale in the media source, if any. root 0=C, 1=C#, etc. scale &0x1=root, &0x2=minor 2nd, &0x4=major 2nd, &0x8=minor 3rd, &0xF=fourth, etc.
///-- @param take *MediaItem_Take
///-- @param rootOut *c_int
///-- @param scaleOut *c_int
///-- @param nameOut *c_char
///-- @param sz c_int
pub const MIDI_GetScale = function(&reaper.MIDI_GetScale, 5, &.{ *MediaItem_Take, *c_int, *c_int, *c_char, c_int });

/// MIDI_GetTextSysexEvt
/// Get MIDI meta-event properties. Allowable types are -1:sysex (msg should not include bounding F0..F7), 1-14:MIDI text event types, 15=REAPER notation event. For all other meta-messages, type is returned as -2 and msg returned as all zeroes. See MIDI_GetEvt.
///-- @param take *MediaItem_Take
///-- @param textsyxevtidx c_int
///-- @param selectedOutOptional *bool
///-- @param mutedOutOptional *bool
///-- @param ppqposOutOptional *f64
///-- @param typeOutOptional *c_int
///-- @param msgOptional *c_char
///-- @param sz *c_int
pub const MIDI_GetTextSysexEvt = function(&reaper.MIDI_GetTextSysexEvt, 8, &.{ *MediaItem_Take, c_int, *bool, *bool, *f64, *c_int, *c_char, *c_int });

/// MIDI_GetTrackHash
/// Get a string that only changes when the MIDI data changes. If notesonly==true, then the string changes only when the MIDI notes change. See MIDI_GetHash
///-- @param track MediaTrack
///-- @param notesonly bool
///-- @param hashOut *c_char
///-- @param sz c_int
pub const MIDI_GetTrackHash = function(&reaper.MIDI_GetTrackHash, 4, &.{ MediaTrack, bool, *c_char, c_int });

/// midi_init
/// Opens MIDI devices as configured in preferences. force_reinit_input and force_reinit_output force a particular device index to close/re-open (pass -1 to not force any devices to reopen).
///-- @param input c_int
///-- @param output c_int
pub const midi_init = function(&reaper.midi_init, 2, &.{ c_int, c_int });

/// MIDI_InsertCC
/// Insert a new MIDI CC event.
///-- @param take *MediaItem_Take
///-- @param selected bool
///-- @param muted bool
///-- @param ppqpos f64
///-- @param chanmsg c_int
///-- @param chan c_int
///-- @param msg2 c_int
///-- @param msg3 c_int
pub const MIDI_InsertCC = function(&reaper.MIDI_InsertCC, 8, &.{ *MediaItem_Take, bool, bool, f64, c_int, c_int, c_int, c_int });

/// MIDI_InsertEvt
/// Insert a new MIDI event.
///-- @param take *MediaItem_Take
///-- @param selected bool
///-- @param muted bool
///-- @param ppqpos f64
///-- @param bytestr [*:0]const u8
///-- @param sz c_int
pub const MIDI_InsertEvt = function(&reaper.MIDI_InsertEvt, 6, &.{ *MediaItem_Take, bool, bool, f64, [*:0]const u8, c_int });

/// MIDI_InsertNote
/// Insert a new MIDI note. Set noSort if inserting multiple events, then call MIDI_Sort when done.
///-- @param take *MediaItem_Take
///-- @param selected bool
///-- @param muted bool
///-- @param startppqpos f64
///-- @param endppqpos f64
///-- @param chan c_int
///-- @param pitch c_int
///-- @param vel c_int
///-- @param noSortInOptional *const bool
pub const MIDI_InsertNote = function(&reaper.MIDI_InsertNote, 9, &.{ *MediaItem_Take, bool, bool, f64, f64, c_int, c_int, c_int, *const bool });

/// MIDI_InsertTextSysexEvt
/// Insert a new MIDI text or sysex event. Allowable types are -1:sysex (msg should not include bounding F0..F7), 1-14:MIDI text event types, 15=REAPER notation event.
///-- @param take *MediaItem_Take
///-- @param selected bool
///-- @param muted bool
///-- @param ppqpos f64
///-- @param type c_int
///-- @param bytestr [*:0]const u8
///-- @param sz c_int
pub const MIDI_InsertTextSysexEvt = function(&reaper.MIDI_InsertTextSysexEvt, 7, &.{ *MediaItem_Take, bool, bool, f64, c_int, [*:0]const u8, c_int });

/// midi_reinit
/// Reset (close and re-open) all MIDI devices
pub const midi_reinit = function(&reaper.midi_reinit, 0, &.{});

/// MIDI_SelectAll
/// Select or deselect all MIDI content.
///-- @param take *MediaItem_Take
///-- @param select bool
pub const MIDI_SelectAll = function(&reaper.MIDI_SelectAll, 2, &.{ *MediaItem_Take, bool });

/// MIDI_SetAllEvts
/// Set all MIDI data. MIDI buffer is passed in as a list of { c_int offset, c_char flag, c_int msglen, unsigned c_char msg[] }.
/// offset: MIDI ticks from previous event
/// flag: &1=selected &2=muted
/// flag high 4 bits for CC shape: &16=linear, &32=slow start/end, &16|32=fast start, &64=fast end, &64|16=bezier
/// msg: the MIDI message.
/// A meta-event of type 0xF followed by 'CCBZ ' and 5 more bytes represents bezier curve data for the previous MIDI event: 1 byte for the bezier type (usually 0) and 4 bytes for the bezier tension as a f32.
/// For tick intervals longer than a 32 bit word can represent, zero-length meta events may be placed between valid events.
/// See MIDI_GetAllEvts.
///-- @param take *MediaItem_Take
///-- @param buf [*:0]const u8
///-- @param sz c_int
pub const MIDI_SetAllEvts = function(&reaper.MIDI_SetAllEvts, 3, &.{ *MediaItem_Take, [*:0]const u8, c_int });

/// MIDI_SetCC
/// Set MIDI CC event properties. Properties passed as NULL will not be set. set noSort if setting multiple events, then call MIDI_Sort when done.
///-- @param take *MediaItem_Take
///-- @param ccidx c_int
///-- @param selectedInOptional *const bool
///-- @param mutedInOptional *const bool
///-- @param ppqposInOptional *const f64
///-- @param chanmsgInOptional *const c_int
///-- @param chanInOptional *const c_int
///-- @param msg2InOptional *const c_int
///-- @param msg3InOptional *const c_int
///-- @param noSortInOptional *const bool
pub const MIDI_SetCC = function(&reaper.MIDI_SetCC, 10, &.{ *MediaItem_Take, c_int, *const bool, *const bool, *const f64, *const c_int, *const c_int, *const c_int, *const c_int, *const bool });

/// MIDI_SetCCShape
/// Set CC shape and bezier tension. set noSort if setting multiple events, then call MIDI_Sort when done. See MIDI_SetCC, MIDI_GetCCShape
///-- @param take *MediaItem_Take
///-- @param ccidx c_int
///-- @param shape c_int
///-- @param beztension f64
///-- @param noSortInOptional *const bool
pub const MIDI_SetCCShape = function(&reaper.MIDI_SetCCShape, 5, &.{ *MediaItem_Take, c_int, c_int, f64, *const bool });

/// MIDI_SetEvt
/// Set MIDI event properties. Properties passed as NULL will not be set.  set noSort if setting multiple events, then call MIDI_Sort when done.
///-- @param take *MediaItem_Take
///-- @param evtidx c_int
///-- @param selectedInOptional *const bool
///-- @param mutedInOptional *const bool
///-- @param ppqposInOptional *const f64
///-- @param msgOptional [*:0]const u8
///-- @param sz c_int
///-- @param noSortInOptional *const bool
pub const MIDI_SetEvt = function(&reaper.MIDI_SetEvt, 8, &.{ *MediaItem_Take, c_int, *const bool, *const bool, *const f64, [*:0]const u8, c_int, *const bool });

/// MIDI_SetItemExtents
/// Set the start/end positions of a media item that contains a MIDI take.
///-- @param item *MediaItem
///-- @param startQN f64
///-- @param endQN f64
pub const MIDI_SetItemExtents = function(&reaper.MIDI_SetItemExtents, 3, &.{ *MediaItem, f64, f64 });

/// MIDI_SetNote
/// Set MIDI note properties. Properties passed as NULL (or negative values) will not be set. Set noSort if setting multiple events, then call MIDI_Sort when done. Setting multiple note start positions at once is done more safely by deleting and re-inserting the notes.
///-- @param take *MediaItem_Take
///-- @param noteidx c_int
///-- @param selectedInOptional *const bool
///-- @param mutedInOptional *const bool
///-- @param startppqposInOptional *const f64
///-- @param endppqposInOptional *const f64
///-- @param chanInOptional *const c_int
///-- @param pitchInOptional *const c_int
///-- @param velInOptional *const c_int
///-- @param noSortInOptional *const bool
pub const MIDI_SetNote = function(&reaper.MIDI_SetNote, 10, &.{ *MediaItem_Take, c_int, *const bool, *const bool, *const f64, *const f64, *const c_int, *const c_int, *const c_int, *const bool });

/// MIDI_SetTextSysexEvt
/// Set MIDI text or sysex event properties. Properties passed as NULL will not be set. Allowable types are -1:sysex (msg should not include bounding F0..F7), 1-14:MIDI text event types, 15=REAPER notation event. set noSort if setting multiple events, then call MIDI_Sort when done.
///-- @param take *MediaItem_Take
///-- @param textsyxevtidx c_int
///-- @param selectedInOptional *const bool
///-- @param mutedInOptional *const bool
///-- @param ppqposInOptional *const f64
///-- @param typeInOptional *const c_int
///-- @param msgOptional [*:0]const u8
///-- @param sz c_int
///-- @param noSortInOptional *const bool
pub const MIDI_SetTextSysexEvt = function(&reaper.MIDI_SetTextSysexEvt, 9, &.{ *MediaItem_Take, c_int, *const bool, *const bool, *const f64, *const c_int, [*:0]const u8, c_int, *const bool });

/// MIDI_Sort
/// Sort MIDI events after multiple calls to MIDI_SetNote, MIDI_SetCC, etc.
///-- @param take *MediaItem_Take
pub const MIDI_Sort = function(&reaper.MIDI_Sort, 1, &.{*MediaItem_Take});

/// MIDIEditor_EnumTakes
/// list the takes that are currently being edited in this MIDI editor, starting with the active take. See MIDIEditor_GetTake
///-- @param midieditor HWND
///-- @param takeindex c_int
///-- @param only bool
pub const MIDIEditor_EnumTakes = function(&reaper.MIDIEditor_EnumTakes, 3, &.{ HWND, c_int, bool });

/// MIDIEditor_GetActive
/// get a pointer to the focused MIDI editor window
/// see MIDIEditor_GetMode, MIDIEditor_OnCommand
pub const MIDIEditor_GetActive = function(&reaper.MIDIEditor_GetActive, 0, &.{});

/// MIDIEditor_GetMode
/// get the mode of a MIDI editor (0=piano roll, 1=event list, -1=invalid editor)
/// see MIDIEditor_GetActive, MIDIEditor_OnCommand
///-- @param midieditor HWND
pub const MIDIEditor_GetMode = function(&reaper.MIDIEditor_GetMode, 1, &.{HWND});

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
///-- @param midieditor HWND
///-- @param desc [*:0]const u8
pub const MIDIEditor_GetSetting_int = function(&reaper.MIDIEditor_GetSetting_int, 2, &.{ HWND, [*:0]const u8 });

/// MIDIEditor_GetSetting_str
/// Get settings from a MIDI editor. setting_desc can be:
/// last_clicked_cc_lane: returns text description ("velocity", "pitch", etc)
/// scale: returns the scale record, for example "102034050607" for a major scale
/// list_X: if viewing list view, returns string describing event at row X (0-based). String will have a list of key=value pairs, e.g. 'pos=4.0 len=4.0 offvel=127 msg=90317F'. pos/len times are in QN, len/offvel may not be present if event is not a note. other keys which may be present include pos_pq/len_pq, sel, mute, ccval14, ccshape, ccbeztension.
/// if setting_desc is unsupported, the function returns false.
/// See MIDIEditor_GetActive, MIDIEditor_GetSetting_int
///
///-- @param midieditor HWND
///-- @param desc [*:0]const u8
///-- @param bufOut *c_char
///-- @param sz c_int
pub const MIDIEditor_GetSetting_str = function(&reaper.MIDIEditor_GetSetting_str, 4, &.{ HWND, [*:0]const u8, *c_char, c_int });

/// MIDIEditor_GetTake
/// get the take that is currently being edited in this MIDI editor. see MIDIEditor_EnumTakes
///-- @param midieditor HWND
pub const MIDIEditor_GetTake = function(&reaper.MIDIEditor_GetTake, 1, &.{HWND});

/// MIDIEditor_LastFocused_OnCommand
/// Send an action command to the last focused MIDI editor. Returns false if there is no MIDI editor open, or if the view mode (piano roll or event list) does not match the input.
/// see MIDIEditor_OnCommand
///-- @param id c_int
///-- @param islistviewcommand bool
pub const MIDIEditor_LastFocused_OnCommand = function(&reaper.MIDIEditor_LastFocused_OnCommand, 2, &.{ c_int, bool });

/// MIDIEditor_OnCommand
/// Send an action command to a MIDI editor. Returns false if the supplied MIDI editor pointer is not valid (not an open MIDI editor).
/// see MIDIEditor_GetActive, MIDIEditor_LastFocused_OnCommand
///-- @param midieditor HWND
///-- @param id c_int
pub const MIDIEditor_OnCommand = function(&reaper.MIDIEditor_OnCommand, 2, &.{ HWND, c_int });

/// MIDIEditor_SetSetting_int
/// Set settings for a MIDI editor. setting_desc can be:
/// active_note_row: 0-127
/// See MIDIEditor_GetSetting_int
///
///-- @param midieditor HWND
///-- @param desc [*:0]const u8
///-- @param setting c_int
pub const MIDIEditor_SetSetting_int = function(&reaper.MIDIEditor_SetSetting_int, 3, &.{ HWND, [*:0]const u8, c_int });

/// MIDIEditorFlagsForTrack
/// Get or set MIDI editor settings for this track. pitchwheelrange: semitones up or down. flags &1: snap pitch lane edits to semitones if pitchwheel range is defined.
///-- @param track MediaTrack
///-- @param pitchwheelrangeInOut *c_int
///-- @param flagsInOut *c_int
///-- @param set bool
pub const MIDIEditorFlagsForTrack = function(&reaper.MIDIEditorFlagsForTrack, 4, &.{ MediaTrack, *c_int, *c_int, bool });

/// mkpanstr
///-- @param strNeed64 *c_char
///-- @param pan f64
pub const mkpanstr = function(&reaper.mkpanstr, 2, &.{ *c_char, f64 });

/// mkvolpanstr
///-- @param strNeed64 *c_char
///-- @param vol f64
///-- @param pan f64
pub const mkvolpanstr = function(&reaper.mkvolpanstr, 3, &.{ *c_char, f64, f64 });

/// mkvolstr
///-- @param strNeed64 *c_char
///-- @param vol f64
pub const mkvolstr = function(&reaper.mkvolstr, 2, &.{ *c_char, f64 });

/// MoveEditCursor
///-- @param adjamt f64
///-- @param dosel bool
pub const MoveEditCursor = function(&reaper.MoveEditCursor, 2, &.{ f64, bool });

/// MoveMediaItemToTrack
/// returns TRUE if move succeeded
///-- @param item *MediaItem
///-- @param desttr *MediaTrack
pub const MoveMediaItemToTrack = function(&reaper.MoveMediaItemToTrack, 2, &.{ *MediaItem, *MediaTrack });

/// MuteAllTracks
///-- @param mute bool
pub const MuteAllTracks = function(&reaper.MuteAllTracks, 1, &.{bool});

/// my_getViewport
///-- @param r *RECT
///-- @param sr *const RECT
///-- @param wantWorkArea bool
pub const my_getViewport = function(&reaper.my_getViewport, 3, &.{ *RECT, *const RECT, bool });

/// NamedCommandLookup
/// Get the command ID number for named command that was registered by an extension such as "_SWS_ABOUT" or "_113088d11ae641c193a2b7ede3041ad5" for a ReaScript or a custom action.
///-- @param name [*:0]const u8
pub const NamedCommandLookup = function(&reaper.NamedCommandLookup, 1, &.{[*:0]const u8});

/// OnPauseButton
/// direct way to simulate pause button hit
pub const OnPauseButton = function(&reaper.OnPauseButton, 0, &.{});

/// OnPauseButtonEx
/// direct way to simulate pause button hit
///-- @param proj *ReaProject
pub const OnPauseButtonEx = function(&reaper.OnPauseButtonEx, 1, &.{*ReaProject});

/// OnPlayButton
/// direct way to simulate play button hit
pub const OnPlayButton = function(&reaper.OnPlayButton, 0, &.{});

/// OnPlayButtonEx
/// direct way to simulate play button hit
///-- @param proj *ReaProject
pub const OnPlayButtonEx = function(&reaper.OnPlayButtonEx, 1, &.{*ReaProject});

/// OnStopButton
/// direct way to simulate stop button hit
pub const OnStopButton = function(&reaper.OnStopButton, 0, &.{});

/// OnStopButtonEx
/// direct way to simulate stop button hit
///-- @param proj *ReaProject
pub const OnStopButtonEx = function(&reaper.OnStopButtonEx, 1, &.{*ReaProject});

/// OpenColorThemeFile
pub const OpenColorThemeFile = function(&reaper.OpenColorThemeFile, 0, &.{});

/// OpenMediaExplorer
/// Opens mediafn in the Media Explorer, play=true will play the file immediately (or toggle playback if mediafn was already open), =false will just select it.
///-- @param mediafn [*:0]const u8
///-- @param play bool
pub const OpenMediaExplorer = function(&reaper.OpenMediaExplorer, 2, &.{ [*:0]const u8, bool });

/// OscLocalMessageToHost
/// Send an OSC message directly to REAPER. The value argument may be NULL. The message will be matched against the default OSC patterns.
///-- @param message [*:0]const u8
///-- @param valueInOptional *const f64
pub const OscLocalMessageToHost = function(&reaper.OscLocalMessageToHost, 2, &.{ [*:0]const u8, *const f64 });

/// parse_timestr
/// Parse hh:mm:ss.sss time string, return time in seconds (or 0.0 on error). See parse_timestr_pos, parse_timestr_len.
///-- @param buf [*:0]const u8
pub const parse_timestr = function(&reaper.parse_timestr, 1, &.{[*:0]const u8});

/// parse_timestr_len
/// time formatting mode overrides: -1=proj default.
/// 0=time
/// 1=measures.beats + time
/// 2=measures.beats
/// 3=seconds
/// 4=samples
/// 5=h:m:s:f
///
///-- @param buf [*:0]const u8
///-- @param offset f64
///-- @param modeoverride c_int
pub const parse_timestr_len = function(&reaper.parse_timestr_len, 3, &.{ [*:0]const u8, f64, c_int });

/// parse_timestr_pos
/// Parse time string, time formatting mode overrides: -1=proj default.
/// 0=time
/// 1=measures.beats + time
/// 2=measures.beats
/// 3=seconds
/// 4=samples
/// 5=h:m:s:f
///
///-- @param buf [*:0]const u8
///-- @param modeoverride c_int
pub const parse_timestr_pos = function(&reaper.parse_timestr_pos, 2, &.{ [*:0]const u8, c_int });

/// parsepanstr
///-- @param str [*:0]const u8
pub const parsepanstr = function(&reaper.parsepanstr, 1, &.{[*:0]const u8});

/// PCM_Sink_Create
///-- @param filename [*:0]const u8
///-- @param cfg [*:0]const u8
///-- @param sz c_int
///-- @param nch c_int
///-- @param srate c_int
///-- @param buildpeaks bool
pub const PCM_Sink_Create = function(&reaper.PCM_Sink_Create, 6, &.{ [*:0]const u8, [*:0]const u8, c_int, c_int, c_int, bool });

/// PCM_Sink_CreateEx
///-- @param proj *ReaProject
///-- @param filename [*:0]const u8
///-- @param cfg [*:0]const u8
///-- @param sz c_int
///-- @param nch c_int
///-- @param srate c_int
///-- @param buildpeaks bool
pub const PCM_Sink_CreateEx = function(&reaper.PCM_Sink_CreateEx, 7, &.{ *ReaProject, [*:0]const u8, [*:0]const u8, c_int, c_int, c_int, bool });

/// PCM_Sink_CreateMIDIFile
///-- @param filename [*:0]const u8
///-- @param cfg [*:0]const u8
///-- @param sz c_int
///-- @param bpm f64
///-- @param div c_int
pub const PCM_Sink_CreateMIDIFile = function(&reaper.PCM_Sink_CreateMIDIFile, 5, &.{ [*:0]const u8, [*:0]const u8, c_int, f64, c_int });

/// PCM_Sink_CreateMIDIFileEx
///-- @param proj *ReaProject
///-- @param filename [*:0]const u8
///-- @param cfg [*:0]const u8
///-- @param sz c_int
///-- @param bpm f64
///-- @param div c_int
pub const PCM_Sink_CreateMIDIFileEx = function(&reaper.PCM_Sink_CreateMIDIFileEx, 6, &.{ *ReaProject, [*:0]const u8, [*:0]const u8, c_int, f64, c_int });

/// PCM_Sink_Enum
///-- @param idx c_int
///-- @param descstrOut [*:0]const u8
pub const PCM_Sink_Enum = function(&reaper.PCM_Sink_Enum, 2, &.{ c_int, [*:0]const u8 });

/// PCM_Sink_GetExtension
///-- @param data [*:0]const u8
///-- @param sz c_int
pub const PCM_Sink_GetExtension = function(&reaper.PCM_Sink_GetExtension, 2, &.{ [*:0]const u8, c_int });

/// PCM_Sink_ShowConfig
///-- @param cfg [*:0]const u8
///-- @param sz c_int
///-- @param hwndParent HWND
pub const PCM_Sink_ShowConfig = function(&reaper.PCM_Sink_ShowConfig, 3, &.{ [*:0]const u8, c_int, HWND });

/// PCM_Source_BuildPeaks
/// Calls and returns PCM_source::PeaksBuild_Begin() if mode=0, PeaksBuild_Run() if mode=1, and PeaksBuild_Finish() if mode=2. Normal use is to call PCM_Source_BuildPeaks(src,0), and if that returns nonzero, call PCM_Source_BuildPeaks(src,1) periodically until it returns zero (it returns the percentage of the file remaining), then call PCM_Source_BuildPeaks(src,2) to finalize. If PCM_Source_BuildPeaks(src,0) returns zero, then no further action is necessary.
///-- @param src *PCM_source
///-- @param mode c_int
pub const PCM_Source_BuildPeaks = function(&reaper.PCM_Source_BuildPeaks, 2, &.{ *PCM_source, c_int });

/// PCM_Source_CreateFromFile
/// See PCM_Source_CreateFromFileEx.
///-- @param filename [*:0]const u8
pub const PCM_Source_CreateFromFile = function(&reaper.PCM_Source_CreateFromFile, 1, &.{[*:0]const u8});

/// PCM_Source_CreateFromFileEx
/// Create a PCM_source from filename, and override pref of MIDI files being imported as in-project MIDI events.
///-- @param filename [*:0]const u8
///-- @param forcenoMidiImp bool
pub const PCM_Source_CreateFromFileEx = function(&reaper.PCM_Source_CreateFromFileEx, 2, &.{ [*:0]const u8, bool });

/// PCM_Source_CreateFromSimple
/// Creates a PCM_source from a ISimpleMediaDecoder
/// (if fn is non-null, it will open the file in dec)
///-- @param dec *ISimpleMediaDecoder
pub const PCM_Source_CreateFromSimple = function(&reaper.PCM_Source_CreateFromSimple, 1, &.{*ISimpleMediaDecoder});

/// PCM_Source_CreateFromType
/// Create a PCM_source from a "type" (use this if you're going to load its state via LoadState/ProjectStateContext).
/// Valid types include "WAVE", "MIDI", or whatever plug-ins define as well.
///-- @param sourcetype [*:0]const u8
pub const PCM_Source_CreateFromType = function(&reaper.PCM_Source_CreateFromType, 1, &.{[*:0]const u8});

/// PCM_Source_Destroy
/// Deletes a PCM_source -- be sure that you remove any project reference before deleting a source
///-- @param src *PCM_source
pub const PCM_Source_Destroy = function(&reaper.PCM_Source_Destroy, 1, &.{*PCM_source});

/// PCM_Source_GetPeaks
/// Gets block of peak samples to buf. Note that the peak samples are interleaved, but in two or three blocks (maximums, then minimums, then extra). Return value has 20 bits of returned sample count, then 4 bits of output_mode (0xf00000), then a bit to signify whether extra_type was available (0x1000000). extra_type can be 115 ('s') for spectral information, which will return peak samples as integers with the low 15 bits frequency, next 14 bits tonality.
///-- @param src *PCM_source
///-- @param peakrate f64
///-- @param starttime f64
///-- @param numchannels c_int
///-- @param numsamplesperchannel c_int
///-- @param type c_int
///-- @param buf *f64
pub const PCM_Source_GetPeaks = function(&reaper.PCM_Source_GetPeaks, 7, &.{ *PCM_source, f64, f64, c_int, c_int, c_int, *f64 });

/// PCM_Source_GetSectionInfo
/// If a section/reverse block, retrieves offset/len/reverse. return true if success
///-- @param src *PCM_source
///-- @param offsOut *f64
///-- @param lenOut *f64
///-- @param revOut *bool
pub const PCM_Source_GetSectionInfo = function(&reaper.PCM_Source_GetSectionInfo, 4, &.{ *PCM_source, *f64, *f64, *bool });

/// PeakBuild_Create
///-- @param src *PCM_source
///-- @param srate c_int
///-- @param nch c_int
pub const PeakBuild_Create = function(&reaper.PeakBuild_Create, 3, &.{ *PCM_source, c_int, c_int });

/// PeakBuild_CreateEx
/// flags&1 for FP support
///-- @param src *PCM_source
///-- @param srate c_int
///-- @param nch c_int
///-- @param flags c_int
pub const PeakBuild_CreateEx = function(&reaper.PeakBuild_CreateEx, 4, &.{ *PCM_source, c_int, c_int, c_int });

/// PeakGet_Create
///-- @param srate c_int
///-- @param nch c_int
pub const PeakGet_Create = function(&reaper.PeakGet_Create, 2, &.{ c_int, c_int });

/// PitchShiftSubModeMenu
/// menu to select/modify pitch shifter submode, returns new value (or old value if no item selected)
///-- @param hwnd HWND
///-- @param x c_int
///-- @param y c_int
///-- @param mode c_int
///-- @param sel c_int
pub const PitchShiftSubModeMenu = function(&reaper.PitchShiftSubModeMenu, 5, &.{ HWND, c_int, c_int, c_int, c_int });

/// PlayPreview
/// return nonzero on success
///-- @param preview *preview_register_t
pub const PlayPreview = function(&reaper.PlayPreview, 1, &.{*preview_register_t});

/// PlayPreviewEx
/// return nonzero on success. bufflags &1=buffer source, &2=treat length changes in source as varispeed and adjust internal state accordingly if buffering. measure_align<0=play immediately, >0=align playback with measure start
///-- @param preview *preview_register_t
///-- @param bufflags c_int
///-- @param align f64
pub const PlayPreviewEx = function(&reaper.PlayPreviewEx, 3, &.{ *preview_register_t, c_int, f64 });

/// PlayTrackPreview
/// return nonzero on success,in these,m_out_chan is a track index (0-n)
///-- @param preview *preview_register_t
pub const PlayTrackPreview = function(&reaper.PlayTrackPreview, 1, &.{*preview_register_t});

/// PlayTrackPreview2
/// return nonzero on success,in these,m_out_chan is a track index (0-n)
///-- @param proj *ReaProject
///-- @param preview *preview_register_t
pub const PlayTrackPreview2 = function(&reaper.PlayTrackPreview2, 2, &.{ *ReaProject, *preview_register_t });

/// PlayTrackPreview2Ex
/// return nonzero on success,in these,m_out_chan is a track index (0-n). see PlayPreviewEx
///-- @param proj *ReaProject
///-- @param preview *preview_register_t
///-- @param flags c_int
///-- @param align f64
pub const PlayTrackPreview2Ex = function(&reaper.PlayTrackPreview2Ex, 4, &.{ *ReaProject, *preview_register_t, c_int, f64 });

/// plugin_getapi
// pub var plugin_getapi: *fn (name: [*:0]const u8) callconv(.C) *void = undefined;

/// plugin_getFilterList
/// Returns a f64-NULL terminated list of importable media files, suitable for passing to GetOpenFileName() etc. Includes *.* (All files).
pub const plugin_getFilterList = function(&reaper.plugin_getFilterList, 0, &.{});

/// plugin_getImportableProjectFilterList
/// Returns a f64-NULL terminated list of importable project files, suitable for passing to GetOpenFileName() etc. Includes *.* (All files).
pub const plugin_getImportableProjectFilterList = function(&reaper.plugin_getImportableProjectFilterList, 0, &.{});

/// plugin_register
/// Alias for reaper_plugin_info_t::Register, see reaper_plugin.h for documented uses.
// pub var plugin_register: *fn (name: [*:0]const u8, infostruct: *void) callconv(.C) c_int = undefined;

/// PluginWantsAlwaysRunFx
///-- @param amt c_int
pub const PluginWantsAlwaysRunFx = function(&reaper.PluginWantsAlwaysRunFx, 1, &.{c_int});

/// PreventUIRefresh
/// adds prevent_count to the UI refresh prevention state; always add then remove the same amount, or major disfunction will occur
///-- @param count c_int
pub const PreventUIRefresh = function(&reaper.PreventUIRefresh, 1, &.{c_int});

/// projectconfig_var_addr
///-- @param proj *ReaProject
///-- @param idx c_int
pub const projectconfig_var_addr = function(&reaper.projectconfig_var_addr, 2, &.{ *ReaProject, c_int });

/// projectconfig_var_getoffs
/// returns offset to pass to projectconfig_var_addr() to get project-config var of name. szout gets size of object. can also query "__metronome_ptr" query project metronome *PCM_source* offset
///-- @param name [*:0]const u8
///-- @param szOut *c_int
pub const projectconfig_var_getoffs = function(&reaper.projectconfig_var_getoffs, 2, &.{ [*:0]const u8, *c_int });

/// PromptForAction
/// Uses the action list to choose an action. Call with session_mode=1 to create a session (init_id will be the initial action to select, or 0), then poll with session_mode=0, checking return value for user-selected action (will return 0 if no action selected yet, or -1 if the action window is no longer available). When finished, call with session_mode=-1.
///-- @param mode c_int
///-- @param id c_int
///-- @param id c_int
pub const PromptForAction = function(&reaper.PromptForAction, 3, &.{ c_int, c_int, c_int });

/// realloc_cmd_clear
/// clears a buffer/buffer-size registration added with realloc_cmd_register_buf, and clears any later registrations, frees any allocated buffers. call after values are read from any registered pointers etc.
///-- @param tok c_int
pub const realloc_cmd_clear = function(&reaper.realloc_cmd_clear, 1, &.{c_int});

/// realloc_cmd_ptr
/// special use for NeedBig script API functions - reallocates a NeedBig buffer and updates its size, returns false on error
///-- @param ptr *c_char
///-- @param size *c_int
///-- @param size c_int
pub const realloc_cmd_ptr = function(&reaper.realloc_cmd_ptr, 3, &.{ *c_char, *c_int, c_int });

/// realloc_cmd_register_buf
/// registers a buffer/buffer-size which may be reallocated by an API (ptr/ptr_size will be updated to the new values). returns a token which should be passed to realloc_cmd_clear after API call and values are read.
///-- @param ptr *[*]u8
///-- @param size *c_int
pub const realloc_cmd_register_buf = function(&reaper.realloc_cmd_register_buf, 2, &.{ *[*]u8, *c_int });

/// ReaperGetPitchShiftAPI
/// version must be REAPER_PITCHSHIFT_API_VER
///-- @param version c_int
pub const ReaperGetPitchShiftAPI = function(&reaper.ReaperGetPitchShiftAPI, 1, &.{c_int});

/// ReaScriptError
/// Causes REAPER to display the error message after the current ReaScript finishes. If called within a Lua context and errmsg has a ! prefix, script execution will be terminated.
///-- @param errmsg [*:0]const u8
pub const ReaScriptError = function(&reaper.ReaScriptError, 1, &.{[*:0]const u8});

/// RecursiveCreateDirectory
/// returns positive value on success, 0 on failure.
///-- @param path [*:0]const u8
///-- @param ignored size_t
pub const RecursiveCreateDirectory = function(&reaper.RecursiveCreateDirectory, 2, &.{ [*:0]const u8, size_t });

/// reduce_open_files
/// garbage-collects extra open files and closes them. if flags has 1 set, this is done incrementally (call this from a regular timer, if desired). if flags has 2 set, files are aggressively closed (they may need to be re-opened very soon). returns number of files closed by this call.
///-- @param flags c_int
pub const reduce_open_files = function(&reaper.reduce_open_files, 1, &.{c_int});

/// RefreshToolbar
/// See RefreshToolbar2.
///-- @param id c_int
pub const RefreshToolbar = function(&reaper.RefreshToolbar, 1, &.{c_int});

/// RefreshToolbar2
/// Refresh the toolbar button states of a toggle action.
///-- @param id c_int
///-- @param id c_int
pub const RefreshToolbar2 = function(&reaper.RefreshToolbar2, 2, &.{ c_int, c_int });

/// relative_fn
/// Makes a filename "in" relative to the current project, if any.
///-- @param in [*:0]const u8
///-- @param out *c_char
///-- @param sz c_int
pub const relative_fn = function(&reaper.relative_fn, 3, &.{ [*:0]const u8, *c_char, c_int });

/// RemoveTrackSend
/// Remove a send/receive/hardware output, return true on success. category is <0 for receives, 0=sends, >0 for hardware outputs. See CreateTrackSend, GetSetTrackSendInfo, GetTrackSendInfo_Value, SetTrackSendInfo_Value, GetTrackNumSends.
///-- @param tr *MediaTrack
///-- @param category c_int
///-- @param sendidx c_int
pub const RemoveTrackSend = function(&reaper.RemoveTrackSend, 3, &.{ *MediaTrack, c_int, c_int });

/// RenderFileSection
/// Not available while playing back.
///-- @param filename [*:0]const u8
///-- @param filename [*:0]const u8
///-- @param percent f64
///-- @param percent f64
///-- @param playrate f64
pub const RenderFileSection = function(&reaper.RenderFileSection, 5, &.{ [*:0]const u8, [*:0]const u8, f64, f64, f64 });

/// ReorderSelectedTracks
/// Moves all selected tracks to immediately above track specified by index beforeTrackIdx, returns false if no tracks were selected. makePrevFolder=0 for normal, 1 = as child of track preceding track specified by beforeTrackIdx, 2 = if track preceding track specified by beforeTrackIdx is last track in folder, extend folder
///-- @param beforeTrackIdx c_int
///-- @param makePrevFolder c_int
pub const ReorderSelectedTracks = function(&reaper.ReorderSelectedTracks, 2, &.{ c_int, c_int });

/// Resample_EnumModes
///-- @param mode c_int
pub const Resample_EnumModes = function(&reaper.Resample_EnumModes, 1, &.{c_int});

/// Resampler_Create
pub const Resampler_Create = function(&reaper.Resampler_Create, 0, &.{});

/// resolve_fn
/// See resolve_fn2.
///-- @param in [*:0]const u8
///-- @param out *c_char
///-- @param sz c_int
pub const resolve_fn = function(&reaper.resolve_fn, 3, &.{ [*:0]const u8, *c_char, c_int });

/// resolve_fn2
/// Resolves a filename "in" by using project settings etc. If no file found, out will be a copy of in.
///-- @param in [*:0]const u8
///-- @param out *c_char
///-- @param sz c_int
///-- @param checkSubDirOptional [*:0]const u8
pub const resolve_fn2 = function(&reaper.resolve_fn2, 4, &.{ [*:0]const u8, *c_char, c_int, [*:0]const u8 });

/// ResolveRenderPattern
/// Resolve a wildcard pattern into a set of nul-separated, f64-nul terminated render target filenames. Returns the length of the string buffer needed for the returned file list. Call with path=NULL to suppress filtering out illegal pathnames, call with targets=NULL to get just the string buffer length.
///-- @param project *ReaProject
///-- @param path [*:0]const u8
///-- @param pattern [*:0]const u8
///-- @param targets *c_char
///-- @param sz c_int
pub const ResolveRenderPattern = function(&reaper.ResolveRenderPattern, 5, &.{ *ReaProject, [*:0]const u8, [*:0]const u8, *c_char, c_int });

/// ReverseNamedCommandLookup
/// Get the named command for the given command ID. The returned string will not start with '_' (e.g. it will return "SWS_ABOUT"), it will be NULL if command_id is a native action.
///-- @param id c_int
pub const ReverseNamedCommandLookup = function(&reaper.ReverseNamedCommandLookup, 1, &.{c_int});

/// ScaleFromEnvelopeMode
/// See GetEnvelopeScalingMode.
///-- @param mode c_int
///-- @param val f64
pub const ScaleFromEnvelopeMode = function(&reaper.ScaleFromEnvelopeMode, 2, &.{ c_int, f64 });

/// ScaleToEnvelopeMode
/// See GetEnvelopeScalingMode.
///-- @param mode c_int
///-- @param val f64
pub const ScaleToEnvelopeMode = function(&reaper.ScaleToEnvelopeMode, 2, &.{ c_int, f64 });

/// screenset_register
///-- @param id *c_char
///-- @param callbackFunc *void
///-- @param param *void
pub const screenset_register = function(&reaper.screenset_register, 3, &.{ *c_char, *void, *void });

/// screenset_registerNew
///-- @param id *c_char
///-- @param callbackFunc screensetNewCallbackFunc
///-- @param param *void
pub const screenset_registerNew = function(&reaper.screenset_registerNew, 3, &.{ *c_char, screensetNewCallbackFunc, *void });

/// screenset_unregister
///-- @param id *c_char
pub const screenset_unregister = function(&reaper.screenset_unregister, 1, &.{*c_char});

/// screenset_unregisterByParam
///-- @param param *void
pub const screenset_unregisterByParam = function(&reaper.screenset_unregisterByParam, 1, &.{*void});

/// screenset_updateLastFocus
///-- @param prevWin HWND
pub const screenset_updateLastFocus = function(&reaper.screenset_updateLastFocus, 1, &.{HWND});

/// SectionFromUniqueID
///-- @param uniqueID c_int
pub const SectionFromUniqueID = function(&reaper.SectionFromUniqueID, 1, &.{c_int});

/// SelectAllMediaItems
///-- @param proj *ReaProject
///-- @param selected bool
pub const SelectAllMediaItems = function(&reaper.SelectAllMediaItems, 2, &.{ *ReaProject, bool });

/// SelectProjectInstance
///-- @param proj *ReaProject
pub const SelectProjectInstance = function(&reaper.SelectProjectInstance, 1, &.{*ReaProject});

/// SendLocalOscMessage
/// Send an OSC message to REAPER. See CreateLocalOscHandler, DestroyLocalOscHandler.
///-- @param handler *void
///-- @param msg [*:0]const u8
///-- @param msglen c_int
pub const SendLocalOscMessage = function(&reaper.SendLocalOscMessage, 3, &.{ *void, [*:0]const u8, c_int });

/// SendMIDIMessageToHardware
/// Sends a MIDI message to output device specified by output. Message is sent in immediate mode. Lua example of how to pack the message string:
/// sysex = { 0xF0, 0x00, 0xF7 }
/// msg = ""
/// for i=1, #sysex do msg = msg .. string.c_char(sysex[i]) end
///-- @param output c_int
///-- @param msg [*:0]const u8
///-- @param sz c_int
pub const SendMIDIMessageToHardware = function(&reaper.SendMIDIMessageToHardware, 3, &.{ c_int, [*:0]const u8, c_int });

/// SetActiveTake
/// set this take active in this media item
///-- @param take *MediaItem_Take
pub const SetActiveTake = function(&reaper.SetActiveTake, 1, &.{*MediaItem_Take});

/// SetAutomationMode
/// sets all or selected tracks to mode.
///-- @param mode c_int
///-- @param onlySel bool
pub const SetAutomationMode = function(&reaper.SetAutomationMode, 2, &.{ c_int, bool });

/// SetCurrentBPM
/// set current BPM in project, set wantUndo=true to add undo point
///-- @param proj *ReaProject
///-- @param bpm f64
///-- @param wantUndo bool
pub const SetCurrentBPM = function(&reaper.SetCurrentBPM, 3, &.{ *ReaProject, f64, bool });

/// SetCursorContext
/// You must use this to change the focus programmatically. mode=0 to focus track panels, 1 to focus the arrange window, 2 to focus the arrange window and select env (or env==NULL to clear the current track/take envelope selection)
///-- @param mode c_int
///-- @param envInOptional *TrackEnvelope
pub const SetCursorContext = function(&reaper.SetCursorContext, 2, &.{ c_int, *TrackEnvelope });

/// SetEditCurPos
///-- @param time f64
///-- @param moveview bool
///-- @param seekplay bool
pub const SetEditCurPos = function(&reaper.SetEditCurPos, 3, &.{ f64, bool, bool });

/// SetEditCurPos2
///-- @param proj *ReaProject
///-- @param time f64
///-- @param moveview bool
///-- @param seekplay bool
pub const SetEditCurPos2 = function(&reaper.SetEditCurPos2, 4, &.{ *ReaProject, f64, bool, bool });

/// SetEnvelopePoint
/// Set attributes of an envelope point. Values that are not supplied will be ignored. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done. See SetEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param ptidx c_int
///-- @param timeInOptional *f64
///-- @param valueInOptional *f64
///-- @param shapeInOptional *c_int
///-- @param tensionInOptional *f64
///-- @param selectedInOptional *bool
///-- @param noSortInOptional *bool
pub const SetEnvelopePoint = function(&reaper.SetEnvelopePoint, 8, &.{ *TrackEnvelope, c_int, *f64, *f64, *c_int, *f64, *bool, *bool });

/// SetEnvelopePointEx
/// Set attributes of an envelope point. Values that are not supplied will be ignored. If setting multiple points at once, set noSort=true, and call Envelope_SortPoints when done.
/// autoitem_idx=-1 for the underlying envelope, 0 for the first automation item on the envelope, etc.
/// For automation items, pass autoitem_idx|0x10000000 to base ptidx on the number of points in one full loop iteration,
/// even if the automation item is trimmed so that not all points are visible.
/// Otherwise, ptidx will be based on the number of visible points in the automation item, including all loop iterations.
/// See CountEnvelopePointsEx, GetEnvelopePointEx, InsertEnvelopePointEx, DeleteEnvelopePointEx.
///-- @param envelope *TrackEnvelope
///-- @param idx c_int
///-- @param ptidx c_int
///-- @param timeInOptional *f64
///-- @param valueInOptional *f64
///-- @param shapeInOptional *c_int
///-- @param tensionInOptional *f64
///-- @param selectedInOptional *bool
///-- @param noSortInOptional *bool
pub const SetEnvelopePointEx = function(&reaper.SetEnvelopePointEx, 9, &.{ *TrackEnvelope, c_int, c_int, *f64, *f64, *c_int, *f64, *bool, *bool });

/// SetEnvelopeStateChunk
/// Sets the RPPXML state of an envelope, returns true if successful. Undo flag is a performance/caching hint.
///-- @param env *TrackEnvelope
///-- @param str [*:0]const u8
///-- @param isundoOptional bool
pub const SetEnvelopeStateChunk = function(&reaper.SetEnvelopeStateChunk, 3, &.{ *TrackEnvelope, [*:0]const u8, bool });

/// SetExtState
/// Set the extended state value for a specific section and key. persist=true means the value should be stored and reloaded the next time REAPER is opened. See GetExtState, DeleteExtState, HasExtState.
///-- @param section [*:0]const u8
///-- @param key [*:0]const u8
///-- @param value [*:0]const u8
///-- @param persist bool
pub const SetExtState = function(&reaper.SetExtState, 4, &.{ [*:0]const u8, [*:0]const u8, [*:0]const u8, bool });

/// SetGlobalAutomationOverride
/// mode: see GetGlobalAutomationOverride
///-- @param mode c_int
pub const SetGlobalAutomationOverride = function(&reaper.SetGlobalAutomationOverride, 1, &.{c_int});

/// SetItemStateChunk
/// Sets the RPPXML state of an item, returns true if successful. Undo flag is a performance/caching hint.
///-- @param item *MediaItem
///-- @param str [*:0]const u8
///-- @param isundoOptional bool
pub const SetItemStateChunk = function(&reaper.SetItemStateChunk, 3, &.{ *MediaItem, [*:0]const u8, bool });

/// SetMasterTrackVisibility
/// set &1 to show the master track in the TCP, &2 to HIDE in the mixer. Returns the previous visibility state. See GetMasterTrackVisibility.
///-- @param flag c_int
pub const SetMasterTrackVisibility = function(&reaper.SetMasterTrackVisibility, 1, &.{c_int});

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
///-- @param item *MediaItem
///-- @param parmname [*:0]const u8
///-- @param newvalue f64
pub const SetMediaItemInfo_Value = function(&reaper.SetMediaItemInfo_Value, 3, &.{ *MediaItem, [*:0]const u8, f64 });

/// SetMediaItemLength
/// Redraws the screen only if refreshUI == true.
/// See UpdateArrange().
///-- @param item *MediaItem
///-- @param length f64
///-- @param refreshUI bool
pub const SetMediaItemLength = function(&reaper.SetMediaItemLength, 3, &.{ *MediaItem, f64, bool });

/// SetMediaItemPosition
/// Redraws the screen only if refreshUI == true.
/// See UpdateArrange().
///-- @param item *MediaItem
///-- @param position f64
///-- @param refreshUI bool
pub const SetMediaItemPosition = function(&reaper.SetMediaItemPosition, 3, &.{ *MediaItem, f64, bool });

/// SetMediaItemSelected
///-- @param item *MediaItem
///-- @param selected bool
pub const SetMediaItemSelected = function(&reaper.SetMediaItemSelected, 2, &.{ *MediaItem, bool });

/// SetMediaItemTake_Source
/// Set media source of media item take. The old source will not be destroyed, it is the caller's responsibility to retrieve it and destroy it after. If source already exists in any project, it will be duplicated before being set. C/C++ code should not use this and instead use GetSetMediaItemTakeInfo() with P_SOURCE to manage ownership directly.
///-- @param take *MediaItem_Take
///-- @param source *PCM_source
pub const SetMediaItemTake_Source = function(&reaper.SetMediaItemTake_Source, 2, &.{ *MediaItem_Take, *PCM_source });

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
///-- @param take *MediaItem_Take
///-- @param parmname [*:0]const u8
///-- @param newvalue f64
pub const SetMediaItemTakeInfo_Value = function(&reaper.SetMediaItemTakeInfo_Value, 3, &.{ *MediaItem_Take, [*:0]const u8, f64 });

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
///-- @param tr MediaTrack
///-- @param parmname [*:0]const u8
///-- @param newvalue f64
pub const SetMediaTrackInfo_Value = function(&reaper.SetMediaTrackInfo_Value, 3, &.{ MediaTrack, [*:0]const u8, f64 });

/// SetMIDIEditorGrid
/// Set the MIDI editor grid division. 0.25=quarter note, 1.0/3.0=half note tripet, etc.
///-- @param project *ReaProject
///-- @param division f64
pub const SetMIDIEditorGrid = function(&reaper.SetMIDIEditorGrid, 2, &.{ *ReaProject, f64 });

/// SetMixerScroll
/// Scroll the mixer so that leftmosttrack is the leftmost visible track. Returns the leftmost track after scrolling, which may be different from the passed-in track if there are not enough tracks to its right.
///-- @param leftmosttrack MediaTrack
pub const SetMixerScroll = function(&reaper.SetMixerScroll, 1, &.{MediaTrack});

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
///-- @param context [*:0]const u8
///-- @param flag c_int
///-- @param action [*:0]const u8
pub const SetMouseModifier = function(&reaper.SetMouseModifier, 3, &.{ [*:0]const u8, c_int, [*:0]const u8 });

/// SetOnlyTrackSelected
/// Set exactly one track selected, deselect all others
///-- @param track MediaTrack
pub const SetOnlyTrackSelected = function(&reaper.SetOnlyTrackSelected, 1, &.{MediaTrack});

/// SetProjectGrid
/// Set the arrange view grid division. 0.25=quarter note, 1.0/3.0=half note triplet, etc.
///-- @param project *ReaProject
///-- @param division f64
pub const SetProjectGrid = function(&reaper.SetProjectGrid, 2, &.{ *ReaProject, f64 });

/// SetProjectMarker
/// Note: this function can't clear a marker's name (an empty string will leave the name unchanged), see SetProjectMarker4.
///-- @param markrgnindexnumber c_int
///-- @param isrgn bool
///-- @param pos f64
///-- @param rgnend f64
///-- @param name [*:0]const u8
pub const SetProjectMarker = function(&reaper.SetProjectMarker, 5, &.{ c_int, bool, f64, f64, [*:0]const u8 });

/// SetProjectMarker2
/// Note: this function can't clear a marker's name (an empty string will leave the name unchanged), see SetProjectMarker4.
///-- @param proj *ReaProject
///-- @param markrgnindexnumber c_int
///-- @param isrgn bool
///-- @param pos f64
///-- @param rgnend f64
///-- @param name [*:0]const u8
pub const SetProjectMarker2 = function(&reaper.SetProjectMarker2, 6, &.{ *ReaProject, c_int, bool, f64, f64, [*:0]const u8 });

/// SetProjectMarker3
/// Note: this function can't clear a marker's name (an empty string will leave the name unchanged), see SetProjectMarker4.
///-- @param proj *ReaProject
///-- @param markrgnindexnumber c_int
///-- @param isrgn bool
///-- @param pos f64
///-- @param rgnend f64
///-- @param name [*:0]const u8
///-- @param color c_int
pub const SetProjectMarker3 = function(&reaper.SetProjectMarker3, 7, &.{ *ReaProject, c_int, bool, f64, f64, [*:0]const u8, c_int });

/// SetProjectMarker4
/// color should be 0 to not change, or ColorToNative(r,g,b)|0x1000000, flags&1 to clear name
///-- @param proj *ReaProject
///-- @param markrgnindexnumber c_int
///-- @param isrgn bool
///-- @param pos f64
///-- @param rgnend f64
///-- @param name [*:0]const u8
///-- @param color c_int
///-- @param flags c_int
pub const SetProjectMarker4 = function(&reaper.SetProjectMarker4, 8, &.{ *ReaProject, c_int, bool, f64, f64, [*:0]const u8, c_int, c_int });

/// SetProjectMarkerByIndex
/// See SetProjectMarkerByIndex2.
///-- @param proj *ReaProject
///-- @param markrgnidx c_int
///-- @param isrgn bool
///-- @param pos f64
///-- @param rgnend f64
///-- @param IDnumber c_int
///-- @param name [*:0]const u8
///-- @param color c_int
pub const SetProjectMarkerByIndex = function(&reaper.SetProjectMarkerByIndex, 8, &.{ *ReaProject, c_int, bool, f64, f64, c_int, [*:0]const u8, c_int });

/// SetProjectMarkerByIndex2
/// Differs from SetProjectMarker4 in that markrgnidx is 0 for the first marker/region, 1 for the next, etc (see EnumProjectMarkers3), rather than representing the displayed marker/region ID number (see SetProjectMarker3). Function will fail if attempting to set a duplicate ID number for a region (duplicate ID numbers for markers are OK). , flags&1 to clear name. If flags&2, markers will not be re-sorted, and after making updates, you MUST call SetProjectMarkerByIndex2 with markrgnidx=-1 and flags&2 to force re-sort/UI updates.
///-- @param proj *ReaProject
///-- @param markrgnidx c_int
///-- @param isrgn bool
///-- @param pos f64
///-- @param rgnend f64
///-- @param IDnumber c_int
///-- @param name [*:0]const u8
///-- @param color c_int
///-- @param flags c_int
pub const SetProjectMarkerByIndex2 = function(&reaper.SetProjectMarkerByIndex2, 9, &.{ *ReaProject, c_int, bool, f64, f64, c_int, [*:0]const u8, c_int, c_int });

/// SetProjExtState
/// Save a key/value pair for a specific extension, to be restored the next time this specific project is loaded. Typically extname will be the name of a reascript or extension section. If key is NULL or "", all extended data for that extname will be deleted.  If val is NULL or "", the data previously associated with that key will be deleted. Returns the size of the state for this extname. See GetProjExtState, EnumProjExtState.
///-- @param proj *ReaProject
///-- @param extname [*:0]const u8
///-- @param key [*:0]const u8
///-- @param value [*:0]const u8
pub const SetProjExtState = function(&reaper.SetProjExtState, 4, &.{ *ReaProject, [*:0]const u8, [*:0]const u8, [*:0]const u8 });

/// SetRegionRenderMatrix
/// Add (flag > 0) or remove (flag < 0) a track from this region when using the region render matrix. If adding, flag==2 means force mono, flag==4 means force stereo, flag==N means force N/2 channels.
///-- @param proj *ReaProject
///-- @param regionindex c_int
///-- @param track MediaTrack
///-- @param flag c_int
pub const SetRegionRenderMatrix = function(&reaper.SetRegionRenderMatrix, 4, &.{ *ReaProject, c_int, MediaTrack, c_int });

/// SetRenderLastError
/// Used by pcmsink objects to set an error to display while creating the pcmsink object.
///-- @param errorstr [*:0]const u8
pub const SetRenderLastError = function(&reaper.SetRenderLastError, 1, &.{[*:0]const u8});

/// SetTakeMarker
/// Inserts or updates a take marker. If idx<0, a take marker will be added, otherwise an existing take marker will be updated. Returns the index of the new or updated take marker (which may change if srcPos is updated). See GetNumTakeMarkers, GetTakeMarker, DeleteTakeMarker
///-- @param take *MediaItem_Take
///-- @param idx c_int
///-- @param nameIn [*:0]const u8
///-- @param srcposInOptional *f64
///-- @param colorInOptional *c_int
pub const SetTakeMarker = function(&reaper.SetTakeMarker, 5, &.{ *MediaItem_Take, c_int, [*:0]const u8, *f64, *c_int });

/// SetTakeStretchMarker
/// Adds or updates a stretch marker. If idx<0, stretch marker will be added. If idx>=0, stretch marker will be updated. When adding, if srcposInOptional is omitted, source position will be auto-calculated. When updating a stretch marker, if srcposInOptional is omitted, srcpos will not be modified. Position/srcposition values will be constrained to nearby stretch markers. Returns index of stretch marker, or -1 if did not insert (or marker already existed at time).
///-- @param take *MediaItem_Take
///-- @param idx c_int
///-- @param pos f64
///-- @param srcposInOptional *const f64
pub const SetTakeStretchMarker = function(&reaper.SetTakeStretchMarker, 4, &.{ *MediaItem_Take, c_int, f64, *const f64 });

/// SetTakeStretchMarkerSlope
/// See GetTakeStretchMarkerSlope
///-- @param take *MediaItem_Take
///-- @param idx c_int
///-- @param slope f64
pub const SetTakeStretchMarkerSlope = function(&reaper.SetTakeStretchMarkerSlope, 3, &.{ *MediaItem_Take, c_int, f64 });

/// SetTempoTimeSigMarker
/// Set parameters of a tempo/time signature marker. Provide either timepos (with measurepos=-1, beatpos=-1), or measurepos and beatpos (with timepos=-1). If timesig_num and timesig_denom are zero, the previous time signature will be used. ptidx=-1 will insert a new tempo/time signature marker. See CountTempoTimeSigMarkers, GetTempoTimeSigMarker, AddTempoTimeSigMarker.
///-- @param proj *ReaProject
///-- @param ptidx c_int
///-- @param timepos f64
///-- @param measurepos c_int
///-- @param beatpos f64
///-- @param bpm f64
///-- @param num c_int
///-- @param denom c_int
///-- @param lineartempo bool
pub const SetTempoTimeSigMarker = function(&reaper.SetTempoTimeSigMarker, 9, &.{ *ReaProject, c_int, f64, c_int, f64, f64, c_int, c_int, bool });

/// SetThemeColor
/// Temporarily updates the theme color to the color specified (or the theme default color if -1 is specified). Returns -1 on failure, otherwise returns the color (or transformed-color). Note that the UI is not updated by this, the caller should call UpdateArrange() etc as necessary. If the low bit of flags is set, any color transformations are bypassed. To read a value see GetThemeColor.
///-- @param key [*:0]const u8
///-- @param color c_int
///-- @param flagsOptional c_int
pub const SetThemeColor = function(&reaper.SetThemeColor, 3, &.{ [*:0]const u8, c_int, c_int });

/// SetToggleCommandState
/// Updates the toggle state of an action, returns true if succeeded. Only ReaScripts can have their toggle states changed programmatically. See RefreshToolbar2.
///-- @param id c_int
///-- @param id c_int
///-- @param state c_int
pub const SetToggleCommandState = function(&reaper.SetToggleCommandState, 3, &.{ c_int, c_int, c_int });

/// SetTrackAutomationMode
///-- @param tr MediaTrack
///-- @param mode c_int
pub const SetTrackAutomationMode = function(&reaper.SetTrackAutomationMode, 2, &.{ MediaTrack, c_int });

/// SetTrackColor
/// Set the custom track color, color is OS dependent (i.e. ColorToNative(r,g,b). To unset the track color, see SetMediaTrackInfo_Value I_CUSTOMCOLOR
///-- @param track MediaTrack
///-- @param color c_int
pub const SetTrackColor = function(&reaper.SetTrackColor, 2, &.{ MediaTrack, c_int });

/// SetTrackMIDILyrics
/// Set all MIDI lyrics on the track. Lyrics will be stuffed into any MIDI items found in range. Flag is unused at present. str is passed in as beat position, tab, text, tab (example with flag=2: "1.1.2\tLyric for measure 1 beat 2\t2.1.1\tLyric for measure 2 beat 1	"). See GetTrackMIDILyrics
///-- @param track MediaTrack
///-- @param flag c_int
///-- @param str [*:0]const u8
pub const SetTrackMIDILyrics = function(&reaper.SetTrackMIDILyrics, 3, &.{ MediaTrack, c_int, [*:0]const u8 });

/// SetTrackMIDINoteName
/// channel < 0 assigns these note names to all channels.
///-- @param track c_int
///-- @param pitch c_int
///-- @param chan c_int
///-- @param name [*:0]const u8
pub const SetTrackMIDINoteName = function(&reaper.SetTrackMIDINoteName, 4, &.{ c_int, c_int, c_int, [*:0]const u8 });

/// SetTrackMIDINoteNameEx
/// channel < 0 assigns note name to all channels. pitch 128 assigns name for CC0, pitch 129 for CC1, etc.
///-- @param proj *ReaProject
///-- @param track MediaTrack
///-- @param pitch c_int
///-- @param chan c_int
///-- @param name [*:0]const u8
pub const SetTrackMIDINoteNameEx = function(&reaper.SetTrackMIDINoteNameEx, 5, &.{ *ReaProject, MediaTrack, c_int, c_int, [*:0]const u8 });

/// SetTrackSelected
///-- @param track MediaTrack
///-- @param selected bool
pub const SetTrackSelected = function(&reaper.SetTrackSelected, 2, &.{ MediaTrack, bool });

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
///-- @param tr *MediaTrack
///-- @param category c_int
///-- @param sendidx c_int
///-- @param parmname [*:0]const u8
///-- @param newvalue f64
pub const SetTrackSendInfo_Value = function(&reaper.SetTrackSendInfo_Value, 5, &.{ *MediaTrack, c_int, c_int, [*:0]const u8, f64 });

/// SetTrackSendUIPan
/// send_idx<0 for receives, >=0 for hw ouputs, >=nb_of_hw_ouputs for sends. isend=1 for end of edit, -1 for an instant edit (such as reset), 0 for normal tweak.
///-- @param track MediaTrack
///-- @param idx c_int
///-- @param pan f64
///-- @param isend c_int
pub const SetTrackSendUIPan = function(&reaper.SetTrackSendUIPan, 4, &.{ MediaTrack, c_int, f64, c_int });

/// SetTrackSendUIVol
/// send_idx<0 for receives, >=0 for hw ouputs, >=nb_of_hw_ouputs for sends. isend=1 for end of edit, -1 for an instant edit (such as reset), 0 for normal tweak.
///-- @param track MediaTrack
///-- @param idx c_int
///-- @param vol f64
///-- @param isend c_int
pub const SetTrackSendUIVol = function(&reaper.SetTrackSendUIVol, 4, &.{ MediaTrack, c_int, f64, c_int });

/// SetTrackStateChunk
/// Sets the RPPXML state of a track, returns true if successful. Undo flag is a performance/caching hint.
///-- @param track MediaTrack
///-- @param str [*:0]const u8
///-- @param isundoOptional bool
pub const SetTrackStateChunk = function(&reaper.SetTrackStateChunk, 3, &.{ MediaTrack, [*:0]const u8, bool });

/// SetTrackUIInputMonitor
/// monitor: 0=no monitoring, 1=monitoring, 2=auto-monitoring. returns new value or -1 if error. igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
///-- @param track MediaTrack
///-- @param monitor c_int
///-- @param igngroupflags c_int
pub const SetTrackUIInputMonitor = function(&reaper.SetTrackUIInputMonitor, 3, &.{ MediaTrack, c_int, c_int });

/// SetTrackUIMute
/// mute: <0 toggles, >0 sets mute, 0=unsets mute. returns new value or -1 if error. igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
///-- @param track MediaTrack
///-- @param mute c_int
///-- @param igngroupflags c_int
pub const SetTrackUIMute = function(&reaper.SetTrackUIMute, 3, &.{ MediaTrack, c_int, c_int });

/// SetTrackUIPan
/// igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
///-- @param track MediaTrack
///-- @param pan f64
///-- @param relative bool
///-- @param done bool
///-- @param igngroupflags c_int
pub const SetTrackUIPan = function(&reaper.SetTrackUIPan, 5, &.{ MediaTrack, f64, bool, bool, c_int });

/// SetTrackUIPolarity
/// polarity (AKA phase): <0 toggles, 0=normal, >0=inverted. returns new value or -1 if error.igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
///-- @param track MediaTrack
///-- @param polarity c_int
///-- @param igngroupflags c_int
pub const SetTrackUIPolarity = function(&reaper.SetTrackUIPolarity, 3, &.{ MediaTrack, c_int, c_int });

/// SetTrackUIRecArm
/// recarm: <0 toggles, >0 sets recarm, 0=unsets recarm. returns new value or -1 if error. igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
///-- @param track MediaTrack
///-- @param recarm c_int
///-- @param igngroupflags c_int
pub const SetTrackUIRecArm = function(&reaper.SetTrackUIRecArm, 3, &.{ MediaTrack, c_int, c_int });

/// SetTrackUISolo
/// solo: <0 toggles, 1 sets solo (default mode), 0=unsets solo, 2 sets solo (non-SIP), 4 sets solo (SIP). returns new value or -1 if error. igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
///-- @param track MediaTrack
///-- @param solo c_int
///-- @param igngroupflags c_int
pub const SetTrackUISolo = function(&reaper.SetTrackUISolo, 3, &.{ MediaTrack, c_int, c_int });

/// SetTrackUIVolume
/// igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
///-- @param track MediaTrack
///-- @param volume f64
///-- @param relative bool
///-- @param done bool
///-- @param igngroupflags c_int
pub const SetTrackUIVolume = function(&reaper.SetTrackUIVolume, 5, &.{ MediaTrack, f64, bool, bool, c_int });

/// SetTrackUIWidth
/// igngroupflags: &1 to prevent track grouping, &2 to prevent selection ganging
///-- @param track MediaTrack
///-- @param width f64
///-- @param relative bool
///-- @param done bool
///-- @param igngroupflags c_int
pub const SetTrackUIWidth = function(&reaper.SetTrackUIWidth, 5, &.{ MediaTrack, f64, bool, bool, c_int });

/// ShowActionList
///-- @param section *KbdSectionInfo
///-- @param callerWnd HWND
pub const ShowActionList = function(&reaper.ShowActionList, 2, &.{ *KbdSectionInfo, HWND });

/// ShowConsoleMsg
/// Show a message to the user (also useful for debugging). Send "\n" for newline, "" to clear the console. Prefix string with "!SHOW:" and text will be added to console without opening the window. See ClearConsole
///-- @param msg [*:0]const u8
pub const ShowConsoleMsg = function(&reaper.ShowConsoleMsg, 1, &.{[*:0]const u8});

/// ShowMessageBox
/// type 0=OK,1=OKCANCEL,2=ABORTRETRYIGNORE,3=YESNOCANCEL,4=YESNO,5=RETRYCANCEL : ret 1=OK,2=CANCEL,3=ABORT,4=RETRY,5=IGNORE,6=YES,7=NO
///-- @param msg [*:0]const u8
///-- @param title [*:0]const u8
///-- @param type c_int
pub const ShowMessageBox = function(&reaper.ShowMessageBox, 3, &.{ [*:0]const u8, [*:0]const u8, c_int });

/// ShowPopupMenu
/// shows a context menu, valid names include: track_input, track_panel, track_area, track_routing, item, ruler, envelope, envelope_point, envelope_item. ctxOptional can be a track pointer for *track_, item pointer for *item (but is optional). for envelope_point, ctx2Optional has point index, ctx3Optional has item index (0=main envelope, 1=first AI). for envelope_item, ctx2Optional has AI index (1=first AI)
///-- @param name [*:0]const u8
///-- @param x c_int
///-- @param y c_int
///-- @param hwndParentOptional HWND
///-- @param ctxOptional *void
///-- @param ctx2Optional c_int
///-- @param ctx3Optional c_int
pub const ShowPopupMenu = function(&reaper.ShowPopupMenu, 7, &.{ [*:0]const u8, c_int, c_int, HWND, *void, c_int, c_int });

/// SLIDER2DB
///-- @param y f64
pub const SLIDER2DB = function(&reaper.SLIDER2DB, 1, &.{f64});

/// SnapToGrid
///-- @param project *ReaProject
///-- @param pos f64
pub const SnapToGrid = function(&reaper.SnapToGrid, 2, &.{ *ReaProject, f64 });

/// SoloAllTracks
/// solo=2 for SIP
///-- @param solo c_int
pub const SoloAllTracks = function(&reaper.SoloAllTracks, 1, &.{c_int});

/// Splash_GetWnd
/// gets the splash window, in case you want to display a message over it. Returns NULL when the splash window is not displayed.
pub const Splash_GetWnd = function(&reaper.Splash_GetWnd, 0, &.{});

/// SplitMediaItem
/// the original item becomes the left-hand split, the function returns the right-hand split (or NULL if the split failed)
///-- @param item *MediaItem
///-- @param position f64
pub const SplitMediaItem = function(&reaper.SplitMediaItem, 2, &.{ *MediaItem, f64 });

/// StopPreview
/// return nonzero on success
///-- @param preview *preview_register_t
pub const StopPreview = function(&reaper.StopPreview, 1, &.{*preview_register_t});

/// StopTrackPreview
/// return nonzero on success
///-- @param preview *preview_register_t
pub const StopTrackPreview = function(&reaper.StopTrackPreview, 1, &.{*preview_register_t});

/// StopTrackPreview2
/// return nonzero on success
///-- @param proj *ReaProject
///-- @param preview *preview_register_t
pub const StopTrackPreview2 = function(&reaper.StopTrackPreview2, 2, &.{ *ReaProject, *preview_register_t });

/// stringToGuid
///-- @param str [*:0]const u8
///-- @param g *GUID
pub const stringToGuid = function(&reaper.stringToGuid, 2, &.{ [*:0]const u8, *GUID });

/// StuffMIDIMessage
/// Stuffs a 3 byte MIDI message into either the Virtual MIDI Keyboard queue, or the MIDI-as-control input queue, or sends to a MIDI hardware output. mode=0 for VKB, 1 for control (actions map etc), 2 for VKB-on-current-channel; 16 for external MIDI device 0, 17 for external MIDI device 1, etc; see GetNumMIDIOutputs, GetMIDIOutputName.
///-- @param mode c_int
///-- @param msg1 c_int
///-- @param msg2 c_int
///-- @param msg3 c_int
pub const StuffMIDIMessage = function(&reaper.StuffMIDIMessage, 4, &.{ c_int, c_int, c_int, c_int });

/// TakeFX_AddByName
/// Adds or queries the position of a named FX in a take. See TrackFX_AddByName() for information on fxname and instantiate. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fxname [*:0]const u8
///-- @param instantiate c_int
pub const TakeFX_AddByName = function(&reaper.TakeFX_AddByName, 3, &.{ *MediaItem_Take, [*:0]const u8, c_int });

/// TakeFX_CopyToTake
/// Copies (or moves) FX from src_take to dest_take. Can be used with src_take=dest_take to reorder. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param move bool
pub const TakeFX_CopyToTake = function(&reaper.TakeFX_CopyToTake, 5, &.{ *MediaItem_Take, c_int, *MediaItem_Take, c_int, bool });

/// TakeFX_CopyToTrack
/// Copies (or moves) FX from src_take to dest_track. dest_fx can have 0x1000000 set to reference input FX. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param move bool
pub const TakeFX_CopyToTrack = function(&reaper.TakeFX_CopyToTrack, 5, &.{ *MediaItem_Take, c_int, MediaTrack, c_int, bool });

/// TakeFX_Delete
/// Remove a FX from take chain (returns true on success) FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
pub const TakeFX_Delete = function(&reaper.TakeFX_Delete, 2, &.{ *MediaItem_Take, c_int });

/// TakeFX_EndParamEdit
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
pub const TakeFX_EndParamEdit = function(&reaper.TakeFX_EndParamEdit, 3, &.{ *MediaItem_Take, c_int, c_int });

/// TakeFX_FormatParamValue
/// Note: only works with FX that support Cockos VST extensions. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param val f64
///-- @param bufOut *c_char
///-- @param sz c_int
pub const TakeFX_FormatParamValue = function(&reaper.TakeFX_FormatParamValue, 6, &.{ *MediaItem_Take, c_int, c_int, f64, *c_char, c_int });

/// TakeFX_FormatParamValueNormalized
/// Note: only works with FX that support Cockos VST extensions. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param value f64
///-- @param buf *c_char
///-- @param sz c_int
pub const TakeFX_FormatParamValueNormalized = function(&reaper.TakeFX_FormatParamValueNormalized, 6, &.{ *MediaItem_Take, c_int, c_int, f64, *c_char, c_int });

/// TakeFX_GetChainVisible
/// returns index of effect visible in chain, or -1 for chain hidden, or -2 for chain visible but no effect selected
///-- @param take *MediaItem_Take
pub const TakeFX_GetChainVisible = function(&reaper.TakeFX_GetChainVisible, 1, &.{*MediaItem_Take});

/// TakeFX_GetCount
///-- @param take *MediaItem_Take
pub const TakeFX_GetCount = function(&reaper.TakeFX_GetCount, 1, &.{*MediaItem_Take});

/// TakeFX_GetEnabled
/// See TakeFX_SetEnabled FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
pub const TakeFX_GetEnabled = function(&reaper.TakeFX_GetEnabled, 2, &.{ *MediaItem_Take, c_int });

/// TakeFX_GetEnvelope
/// Returns the FX parameter envelope. If the envelope does not exist and create=true, the envelope will be created. If the envelope already exists and is bypassed and create=true, then the envelope will be unbypassed. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fxindex c_int
///-- @param parameterindex c_int
///-- @param create bool
pub const TakeFX_GetEnvelope = function(&reaper.TakeFX_GetEnvelope, 4, &.{ *MediaItem_Take, c_int, c_int, bool });

/// TakeFX_GetFloatingWindow
/// returns HWND of f32ing window for effect index, if any FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param index c_int
pub const TakeFX_GetFloatingWindow = function(&reaper.TakeFX_GetFloatingWindow, 2, &.{ *MediaItem_Take, c_int });

/// TakeFX_GetFormattedParamValue
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param bufOut *c_char
///-- @param sz c_int
pub const TakeFX_GetFormattedParamValue = function(&reaper.TakeFX_GetFormattedParamValue, 5, &.{ *MediaItem_Take, c_int, c_int, *c_char, c_int });

/// TakeFX_GetFXGUID
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
pub const TakeFX_GetFXGUID = function(&reaper.TakeFX_GetFXGUID, 2, &.{ *MediaItem_Take, c_int });

/// TakeFX_GetFXName
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param bufOut *c_char
///-- @param sz c_int
pub const TakeFX_GetFXName = function(&reaper.TakeFX_GetFXName, 4, &.{ *MediaItem_Take, c_int, *c_char, c_int });

/// TakeFX_GetIOSize
/// Gets the number of input/output pins for FX if available, returns plug-in type or -1 on error FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param inputPinsOut *c_int
///-- @param outputPinsOut *c_int
pub const TakeFX_GetIOSize = function(&reaper.TakeFX_GetIOSize, 4, &.{ *MediaItem_Take, c_int, *c_int, *c_int });

/// TakeFX_GetNamedConfigParm
/// gets plug-in specific named configuration value (returns true on success). see TrackFX_GetNamedConfigParm FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param parmname [*:0]const u8
///-- @param bufOutNeedBig *c_char
///-- @param sz c_int
pub const TakeFX_GetNamedConfigParm = function(&reaper.TakeFX_GetNamedConfigParm, 5, &.{ *MediaItem_Take, c_int, [*:0]const u8, *c_char, c_int });

/// TakeFX_GetNumParams
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
pub const TakeFX_GetNumParams = function(&reaper.TakeFX_GetNumParams, 2, &.{ *MediaItem_Take, c_int });

/// TakeFX_GetOffline
/// See TakeFX_SetOffline FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
pub const TakeFX_GetOffline = function(&reaper.TakeFX_GetOffline, 2, &.{ *MediaItem_Take, c_int });

/// TakeFX_GetOpen
/// Returns true if this FX UI is open in the FX chain window or a f32ing window. See TakeFX_SetOpen FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
pub const TakeFX_GetOpen = function(&reaper.TakeFX_GetOpen, 2, &.{ *MediaItem_Take, c_int });

/// TakeFX_GetParam
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param minvalOut *f64
///-- @param maxvalOut *f64
pub const TakeFX_GetParam = function(&reaper.TakeFX_GetParam, 5, &.{ *MediaItem_Take, c_int, c_int, *f64, *f64 });

/// TakeFX_GetParameterStepSizes
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param stepOut *f64
///-- @param smallstepOut *f64
///-- @param largestepOut *f64
///-- @param istoggleOut *bool
pub const TakeFX_GetParameterStepSizes = function(&reaper.TakeFX_GetParameterStepSizes, 7, &.{ *MediaItem_Take, c_int, c_int, *f64, *f64, *f64, *bool });

/// TakeFX_GetParamEx
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param minvalOut *f64
///-- @param maxvalOut *f64
///-- @param midvalOut *f64
pub const TakeFX_GetParamEx = function(&reaper.TakeFX_GetParamEx, 6, &.{ *MediaItem_Take, c_int, c_int, *f64, *f64, *f64 });

/// TakeFX_GetParamFromIdent
/// gets the parameter index from an identifying string (:wet, :bypass, or a string returned from GetParamIdent), or -1 if unknown. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param str [*:0]const u8
pub const TakeFX_GetParamFromIdent = function(&reaper.TakeFX_GetParamFromIdent, 3, &.{ *MediaItem_Take, c_int, [*:0]const u8 });

/// TakeFX_GetParamIdent
/// gets an identifying string for the parameter FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param bufOut *c_char
///-- @param sz c_int
pub const TakeFX_GetParamIdent = function(&reaper.TakeFX_GetParamIdent, 5, &.{ *MediaItem_Take, c_int, c_int, *c_char, c_int });

/// TakeFX_GetParamName
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param bufOut *c_char
///-- @param sz c_int
pub const TakeFX_GetParamName = function(&reaper.TakeFX_GetParamName, 5, &.{ *MediaItem_Take, c_int, c_int, *c_char, c_int });

/// TakeFX_GetParamNormalized
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
pub const TakeFX_GetParamNormalized = function(&reaper.TakeFX_GetParamNormalized, 3, &.{ *MediaItem_Take, c_int, c_int });

/// TakeFX_GetPinMappings
/// gets the effective channel mapping bitmask for a particular pin. high32Out will be set to the high 32 bits. Add 0x1000000 to pin index in order to access the second 64 bits of mappings independent of the first 64 bits. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param isoutput c_int
///-- @param pin c_int
///-- @param high32Out *c_int
pub const TakeFX_GetPinMappings = function(&reaper.TakeFX_GetPinMappings, 5, &.{ *MediaItem_Take, c_int, c_int, c_int, *c_int });

/// TakeFX_GetPreset
/// Get the name of the preset currently showing in the REAPER dropdown, or the full path to a factory preset file for VST3 plug-ins (.vstpreset). See TakeFX_SetPreset. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param presetnameOut *c_char
///-- @param sz c_int
pub const TakeFX_GetPreset = function(&reaper.TakeFX_GetPreset, 4, &.{ *MediaItem_Take, c_int, *c_char, c_int });

/// TakeFX_GetPresetIndex
/// Returns current preset index, or -1 if error. numberOfPresetsOut will be set to total number of presets available. See TakeFX_SetPresetByIndex FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param numberOfPresetsOut *c_int
pub const TakeFX_GetPresetIndex = function(&reaper.TakeFX_GetPresetIndex, 3, &.{ *MediaItem_Take, c_int, *c_int });

/// TakeFX_GetUserPresetFilename
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param fnOut *c_char
///-- @param sz c_int
pub const TakeFX_GetUserPresetFilename = function(&reaper.TakeFX_GetUserPresetFilename, 4, &.{ *MediaItem_Take, c_int, *c_char, c_int });

/// TakeFX_NavigatePresets
/// presetmove==1 activates the next preset, presetmove==-1 activates the previous preset, etc. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param presetmove c_int
pub const TakeFX_NavigatePresets = function(&reaper.TakeFX_NavigatePresets, 3, &.{ *MediaItem_Take, c_int, c_int });

/// TakeFX_SetEnabled
/// See TakeFX_GetEnabled FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param enabled bool
pub const TakeFX_SetEnabled = function(&reaper.TakeFX_SetEnabled, 3, &.{ *MediaItem_Take, c_int, bool });

/// TakeFX_SetNamedConfigParm
/// gets plug-in specific named configuration value (returns true on success). see TrackFX_SetNamedConfigParm FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param parmname [*:0]const u8
///-- @param value [*:0]const u8
pub const TakeFX_SetNamedConfigParm = function(&reaper.TakeFX_SetNamedConfigParm, 4, &.{ *MediaItem_Take, c_int, [*:0]const u8, [*:0]const u8 });

/// TakeFX_SetOffline
/// See TakeFX_GetOffline FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param offline bool
pub const TakeFX_SetOffline = function(&reaper.TakeFX_SetOffline, 3, &.{ *MediaItem_Take, c_int, bool });

/// TakeFX_SetOpen
/// Open this FX UI. See TakeFX_GetOpen FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param open bool
pub const TakeFX_SetOpen = function(&reaper.TakeFX_SetOpen, 3, &.{ *MediaItem_Take, c_int, bool });

/// TakeFX_SetParam
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param val f64
pub const TakeFX_SetParam = function(&reaper.TakeFX_SetParam, 4, &.{ *MediaItem_Take, c_int, c_int, f64 });

/// TakeFX_SetParamNormalized
///  FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param param c_int
///-- @param value f64
pub const TakeFX_SetParamNormalized = function(&reaper.TakeFX_SetParamNormalized, 4, &.{ *MediaItem_Take, c_int, c_int, f64 });

/// TakeFX_SetPinMappings
/// sets the channel mapping bitmask for a particular pin. returns false if unsupported (not all types of plug-ins support this capability). Add 0x1000000 to pin index in order to access the second 64 bits of mappings independent of the first 64 bits. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param isoutput c_int
///-- @param pin c_int
///-- @param low32bits c_int
///-- @param hi32bits c_int
pub const TakeFX_SetPinMappings = function(&reaper.TakeFX_SetPinMappings, 6, &.{ *MediaItem_Take, c_int, c_int, c_int, c_int, c_int });

/// TakeFX_SetPreset
/// Activate a preset with the name shown in the REAPER dropdown. Full paths to .vstpreset files are also supported for VST3 plug-ins. See TakeFX_GetPreset. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param presetname [*:0]const u8
pub const TakeFX_SetPreset = function(&reaper.TakeFX_SetPreset, 3, &.{ *MediaItem_Take, c_int, [*:0]const u8 });

/// TakeFX_SetPresetByIndex
/// Sets the preset idx, or the factory preset (idx==-2), or the default user preset (idx==-1). Returns true on success. See TakeFX_GetPresetIndex. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param idx c_int
pub const TakeFX_SetPresetByIndex = function(&reaper.TakeFX_SetPresetByIndex, 3, &.{ *MediaItem_Take, c_int, c_int });

/// TakeFX_Show
/// showflag=0 for hidechain, =1 for show chain(index valid), =2 for hide f32ing window(index valid), =3 for show f32ing window (index valid) FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param take *MediaItem_Take
///-- @param index c_int
///-- @param showFlag c_int
pub const TakeFX_Show = function(&reaper.TakeFX_Show, 3, &.{ *MediaItem_Take, c_int, c_int });

/// TakeIsMIDI
/// Returns true if the active take contains MIDI.
///-- @param take *MediaItem_Take
pub const TakeIsMIDI = function(&reaper.TakeIsMIDI, 1, &.{*MediaItem_Take});

/// ThemeLayout_GetLayout
/// Gets theme layout information. section can be 'global' for global layout override, 'seclist' to enumerate a list of layout sections, otherwise a layout section such as 'mcp', 'tcp', 'trans', etc. idx can be -1 to query the current value, -2 to get the description of the section (if not global), -3 will return the current context DPI-scaling (256=normal, 512=retina, etc), or 0..x. returns false if failed.
///-- @param section [*:0]const u8
///-- @param idx c_int
///-- @param nameOut *c_char
///-- @param sz c_int
pub const ThemeLayout_GetLayout = function(&reaper.ThemeLayout_GetLayout, 4, &.{ [*:0]const u8, c_int, *c_char, c_int });

/// ThemeLayout_GetParameter
/// returns theme layout parameter. return value is cfg-name, or nil/empty if out of range.
///-- @param wp c_int
///-- @param descOutOptional [*:0]const u8
///-- @param valueOutOptional *c_int
///-- @param defValueOutOptional *c_int
///-- @param minValueOutOptional *c_int
///-- @param maxValueOutOptional *c_int
pub const ThemeLayout_GetParameter = function(&reaper.ThemeLayout_GetParameter, 6, &.{ c_int, [*:0]const u8, *c_int, *c_int, *c_int, *c_int });

/// ThemeLayout_RefreshAll
/// Refreshes all layouts
pub const ThemeLayout_RefreshAll = function(&reaper.ThemeLayout_RefreshAll, 0, &.{});

/// ThemeLayout_SetLayout
/// Sets theme layout override for a particular section -- section can be 'global' or 'mcp' etc. If setting global layout, prefix a ! to the layout string to clear any per-layout overrides. Returns false if failed.
///-- @param section [*:0]const u8
///-- @param layout [*:0]const u8
pub const ThemeLayout_SetLayout = function(&reaper.ThemeLayout_SetLayout, 2, &.{ [*:0]const u8, [*:0]const u8 });

/// ThemeLayout_SetParameter
/// sets theme layout parameter to value. persist=true in order to have change loaded on next theme load. note that the caller should update layouts via ??? to make changes visible.
///-- @param wp c_int
///-- @param value c_int
///-- @param persist bool
pub const ThemeLayout_SetParameter = function(&reaper.ThemeLayout_SetParameter, 3, &.{ c_int, c_int, bool });

/// time_precise
/// Gets a precise system timestamp in seconds
pub const time_precise = function(&reaper.time_precise, 0, &.{});

/// TimeMap2_beatsToTime
/// convert a beat position (or optionally a beats+measures if measures is non-NULL) to time.
///-- @param proj *ReaProject
///-- @param tpos f64
///-- @param measuresInOptional *const c_int
pub const TimeMap2_beatsToTime = function(&reaper.TimeMap2_beatsToTime, 3, &.{ *ReaProject, f64, *const c_int });

/// TimeMap2_GetDividedBpmAtTime
/// get the effective BPM at the time (seconds) position (i.e. 2x in /8 signatures)
///-- @param proj *ReaProject
///-- @param time f64
pub const TimeMap2_GetDividedBpmAtTime = function(&reaper.TimeMap2_GetDividedBpmAtTime, 2, &.{ *ReaProject, f64 });

/// TimeMap2_GetNextChangeTime
/// when does the next time map (tempo or time sig) change occur
///-- @param proj *ReaProject
///-- @param time f64
pub const TimeMap2_GetNextChangeTime = function(&reaper.TimeMap2_GetNextChangeTime, 2, &.{ *ReaProject, f64 });

/// TimeMap2_QNToTime
/// converts project QN position to time.
///-- @param proj *ReaProject
///-- @param qn f64
pub const TimeMap2_QNToTime = function(&reaper.TimeMap2_QNToTime, 2, &.{ *ReaProject, f64 });

/// TimeMap2_timeToBeats
/// convert a time into beats.
/// if measures is non-NULL, measures will be set to the measure count, return value will be beats since measure.
/// if cml is non-NULL, will be set to current measure length in beats (i.e. time signature numerator)
/// if fullbeats is non-NULL, and measures is non-NULL, fullbeats will get the full beat count (same value returned if measures is NULL).
/// if cdenom is non-NULL, will be set to the current time signature denominator.
///-- @param proj *ReaProject
///-- @param tpos f64
///-- @param measuresOutOptional *c_int
///-- @param cmlOutOptional *c_int
///-- @param fullbeatsOutOptional *f64
///-- @param cdenomOutOptional *c_int
pub const TimeMap2_timeToBeats = function(&reaper.TimeMap2_timeToBeats, 6, &.{ *ReaProject, f64, *c_int, *c_int, *f64, *c_int });

/// TimeMap2_timeToQN
/// converts project time position to QN position.
///-- @param proj *ReaProject
///-- @param tpos f64
pub const TimeMap2_timeToQN = function(&reaper.TimeMap2_timeToQN, 2, &.{ *ReaProject, f64 });

/// TimeMap_curFrameRate
/// Gets project framerate, and optionally whether it is drop-frame timecode
///-- @param proj *ReaProject
///-- @param dropFrameOut *bool
pub const TimeMap_curFrameRate = function(&reaper.TimeMap_curFrameRate, 2, &.{ *ReaProject, *bool });

/// TimeMap_GetDividedBpmAtTime
/// get the effective BPM at the time (seconds) position (i.e. 2x in /8 signatures)
///-- @param time f64
pub const TimeMap_GetDividedBpmAtTime = function(&reaper.TimeMap_GetDividedBpmAtTime, 1, &.{f64});

/// TimeMap_GetMeasureInfo
/// Get the QN position and time signature information for the start of a measure. Return the time in seconds of the measure start.
///-- @param proj *ReaProject
///-- @param measure c_int
///-- @param startOut *f64
///-- @param endOut *f64
///-- @param numOut *c_int
///-- @param denomOut *c_int
///-- @param tempoOut *f64
pub const TimeMap_GetMeasureInfo = function(&reaper.TimeMap_GetMeasureInfo, 7, &.{ *ReaProject, c_int, *f64, *f64, *c_int, *c_int, *f64 });

/// TimeMap_GetMetronomePattern
/// Fills in a string representing the active metronome pattern. For example, in a 7/8 measure divided 3+4, the pattern might be "1221222". The length of the string is the time signature numerator, and the function returns the time signature denominator.
///-- @param proj *ReaProject
///-- @param time f64
///-- @param pattern *c_char
///-- @param sz c_int
pub const TimeMap_GetMetronomePattern = function(&reaper.TimeMap_GetMetronomePattern, 4, &.{ *ReaProject, f64, *c_char, c_int });

/// TimeMap_GetTimeSigAtTime
/// get the effective time signature and tempo
///-- @param proj *ReaProject
///-- @param time f64
///-- @param numOut *c_int
///-- @param denomOut *c_int
///-- @param tempoOut *f64
pub const TimeMap_GetTimeSigAtTime = function(&reaper.TimeMap_GetTimeSigAtTime, 5, &.{ *ReaProject, f64, *c_int, *c_int, *f64 });

/// TimeMap_QNToMeasures
/// Find which measure the given QN position falls in.
///-- @param proj *ReaProject
///-- @param qn f64
///-- @param qnMeasureStartOutOptional *f64
///-- @param qnMeasureEndOutOptional *f64
pub const TimeMap_QNToMeasures = function(&reaper.TimeMap_QNToMeasures, 4, &.{ *ReaProject, f64, *f64, *f64 });

/// TimeMap_QNToTime
/// converts project QN position to time.
///-- @param qn f64
pub const TimeMap_QNToTime = function(&reaper.TimeMap_QNToTime, 1, &.{f64});

/// TimeMap_QNToTime_abs
/// Converts project quarter note count (QN) to time. QN is counted from the start of the project, regardless of any partial measures. See TimeMap2_QNToTime
///-- @param proj *ReaProject
///-- @param qn f64
pub const TimeMap_QNToTime_abs = function(&reaper.TimeMap_QNToTime_abs, 2, &.{ *ReaProject, f64 });

/// TimeMap_timeToQN
/// converts project QN position to time.
///-- @param tpos f64
pub const TimeMap_timeToQN = function(&reaper.TimeMap_timeToQN, 1, &.{f64});

/// TimeMap_timeToQN_abs
/// Converts project time position to quarter note count (QN). QN is counted from the start of the project, regardless of any partial measures. See TimeMap2_timeToQN
///-- @param proj *ReaProject
///-- @param tpos f64
pub const TimeMap_timeToQN_abs = function(&reaper.TimeMap_timeToQN_abs, 2, &.{ *ReaProject, f64 });

/// ToggleTrackSendUIMute
/// send_idx<0 for receives, >=0 for hw ouputs, >=nb_of_hw_ouputs for sends.
///-- @param track MediaTrack
///-- @param idx c_int
pub const ToggleTrackSendUIMute = function(&reaper.ToggleTrackSendUIMute, 2, &.{ MediaTrack, c_int });

/// Track_GetPeakHoldDB
/// Returns meter hold state, in *dB0.01 (0 = +0dB, -0.01 = -1dB, 0.02 = +2dB, etc). If clear is set, clears the meter hold. If channel==1024 or channel==1025, returns loudness values if this is the master track or this track's VU meters are set to display loudness.
///-- @param track MediaTrack
///-- @param channel c_int
///-- @param clear bool
pub const Track_GetPeakHoldDB = function(&reaper.Track_GetPeakHoldDB, 3, &.{ MediaTrack, c_int, bool });

/// Track_GetPeakInfo
/// Returns peak meter value (1.0=+0dB, 0.0=-inf) for channel. If channel==1024 or channel==1025, returns loudness values if this is the master track or this track's VU meters are set to display loudness.
///-- @param track MediaTrack
///-- @param channel c_int
pub const Track_GetPeakInfo = function(&reaper.Track_GetPeakInfo, 2, &.{ MediaTrack, c_int });

/// TrackCtl_SetToolTip
/// displays tooltip at location, or removes if empty string
///-- @param fmt [*:0]const u8
///-- @param xpos c_int
///-- @param ypos c_int
///-- @param topmost bool
pub const TrackCtl_SetToolTip = function(&reaper.TrackCtl_SetToolTip, 4, &.{ [*:0]const u8, c_int, c_int, bool });

/// TrackFX_AddByName
/// Adds or queries the position of a named FX from the track FX chain (recFX=false) or record input FX/monitoring FX (recFX=true, monitoring FX are on master track). Specify a negative value for instantiate to always create a new effect, 0 to only query the first instance of an effect, or a positive value to add an instance if one is not found. If instantiate is <= -1000, it is used for the insertion position (-1000 is first item in chain, -1001 is second, etc). fxname can have prefix to specify type: VST3:,VST2:,VST:,AU:,JS:, or DX:, or FXADD: which adds selected items from the currently-open FX browser, FXADD:2 to limit to 2 FX added, or FXADD:2e to only succeed if exactly 2 FX are selected. Returns -1 on failure or the new position in chain on success. FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fxname [*:0]const u8
///-- @param recFX bool
///-- @param instantiate c_int
pub const TrackFX_AddByName = function(&reaper.TrackFX_AddByName, 4, &.{ MediaTrack, [*:0]const u8, bool, c_int });

/// TrackFX_CopyToTake
/// Copies (or moves) FX from src_track to dest_take. src_fx can have 0x1000000 set to reference input FX. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param take *MediaItem_Take
///-- @param fx c_int
///-- @param move bool
pub const TrackFX_CopyToTake = function(&reaper.TrackFX_CopyToTake, 5, &.{ MediaTrack, c_int, *MediaItem_Take, c_int, bool });

/// TrackFX_CopyToTrack
/// Copies (or moves) FX from src_track to dest_track. Can be used with src_track=dest_track to reorder, FX indices have 0x1000000 set to reference input FX. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param move bool
pub const TrackFX_CopyToTrack = function(&reaper.TrackFX_CopyToTrack, 5, &.{ MediaTrack, c_int, MediaTrack, c_int, bool });

/// TrackFX_Delete
/// Remove a FX from track chain (returns true on success) FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
pub const TrackFX_Delete = function(&reaper.TrackFX_Delete, 2, &.{ MediaTrack, c_int });

/// TrackFX_EndParamEdit
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
pub const TrackFX_EndParamEdit = function(&reaper.TrackFX_EndParamEdit, 3, &.{ MediaTrack, c_int, c_int });

/// TrackFX_FormatParamValue
/// Note: only works with FX that support Cockos VST extensions. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param val f64
///-- @param bufOut *c_char
///-- @param sz c_int
pub const TrackFX_FormatParamValue = function(&reaper.TrackFX_FormatParamValue, 6, &.{ MediaTrack, c_int, c_int, f64, *c_char, c_int });

/// TrackFX_FormatParamValueNormalized
/// Note: only works with FX that support Cockos VST extensions. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param value f64
///-- @param buf *c_char
///-- @param sz c_int
pub const TrackFX_FormatParamValueNormalized = function(&reaper.TrackFX_FormatParamValueNormalized, 6, &.{ MediaTrack, c_int, c_int, f64, *c_char, c_int });

/// TrackFX_GetByName
/// Get the index of the first track FX insert that matches fxname. If the FX is not in the chain and instantiate is true, it will be inserted. See TrackFX_GetInstrument, TrackFX_GetEQ. Deprecated in favor of TrackFX_AddByName.
///-- @param track MediaTrack
///-- @param fxname [*:0]const u8
///-- @param instantiate bool
pub const TrackFX_GetByName = function(&reaper.TrackFX_GetByName, 3, &.{ MediaTrack, [*:0]const u8, bool });

/// TrackFX_GetChainVisible
/// returns index of effect visible in chain, or -1 for chain hidden, or -2 for chain visible but no effect selected
///-- @param track MediaTrack
pub const TrackFX_GetChainVisible = function(&reaper.TrackFX_GetChainVisible, 1, &.{MediaTrack});

/// TrackFX_GetCount
///-- @param track MediaTrack
pub const TrackFX_GetCount = function(&reaper.TrackFX_GetCount, 1, &.{MediaTrack});

/// TrackFX_GetEnabled
/// See TrackFX_SetEnabled FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
pub const TrackFX_GetEnabled = function(&reaper.TrackFX_GetEnabled, 2, &.{ MediaTrack, c_int });

/// TrackFX_GetEQ
/// Get the index of ReaEQ in the track FX chain. If ReaEQ is not in the chain and instantiate is true, it will be inserted. See TrackFX_GetInstrument, TrackFX_GetByName.
///-- @param track MediaTrack
///-- @param instantiate bool
pub const TrackFX_GetEQ = function(&reaper.TrackFX_GetEQ, 2, &.{ MediaTrack, bool });

/// TrackFX_GetEQBandEnabled
/// Returns true if the EQ band is enabled.
/// Returns false if the band is disabled, or if track/fxidx is not ReaEQ.
/// Bandtype: -1=master gain, 0=hipass, 1=loshelf, 2=band, 3=notch, 4=hishelf, 5=lopass, 6=bandpass, 7=parallel bandpass.
/// Bandidx (ignored for master gain): 0=target first band matching bandtype, 1=target 2nd band matching bandtype, etc.
///
/// See TrackFX_GetEQ, TrackFX_GetEQParam, TrackFX_SetEQParam, TrackFX_SetEQBandEnabled. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fxidx c_int
///-- @param bandtype c_int
///-- @param bandidx c_int
pub const TrackFX_GetEQBandEnabled = function(&reaper.TrackFX_GetEQBandEnabled, 4, &.{ MediaTrack, c_int, c_int, c_int });

/// TrackFX_GetEQParam
/// Returns false if track/fxidx is not ReaEQ.
/// Bandtype: -1=master gain, 0=hipass, 1=loshelf, 2=band, 3=notch, 4=hishelf, 5=lopass, 6=bandpass, 7=parallel bandpass.
/// Bandidx (ignored for master gain): 0=target first band matching bandtype, 1=target 2nd band matching bandtype, etc.
/// Paramtype (ignored for master gain): 0=freq, 1=gain, 2=Q.
/// See TrackFX_GetEQ, TrackFX_SetEQParam, TrackFX_GetEQBandEnabled, TrackFX_SetEQBandEnabled. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fxidx c_int
///-- @param paramidx c_int
///-- @param bandtypeOut *c_int
///-- @param bandidxOut *c_int
///-- @param paramtypeOut *c_int
///-- @param normvalOut *f64
pub const TrackFX_GetEQParam = function(&reaper.TrackFX_GetEQParam, 7, &.{ MediaTrack, c_int, c_int, *c_int, *c_int, *c_int, *f64 });

/// TrackFX_GetFormattedParamValue
/// returns HWND of f32ing window for effect index, if any FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param index c_int
pub const TrackFX_GetFloatingWindow = function(&reaper.TrackFX_GetFloatingWindow, 2, &.{ MediaTrack, c_int });

/// TrackFX_GetFormattedParamValue
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param bufOut [*:0]u8
///-- @param sz c_int
pub const TrackFX_GetFormattedParamValue = function(&reaper.TrackFX_GetFormattedParamValue, 5, &.{ MediaTrack, c_int, c_int, [*:0]u8, c_int });

/// TrackFX_GetFXGUID
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
pub const TrackFX_GetFXGUID = function(&reaper.TrackFX_GetFXGUID, 2, &.{ MediaTrack, c_int });

/// TrackFX_GetFXName
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param bufOut [*:0]u8
///-- @param sz c_int
pub const TrackFX_GetFXName = function(&reaper.TrackFX_GetFXName, 4, &.{ MediaTrack, c_int, [*:0]u8, c_int });

/// TrackFX_GetInstrument
/// Get the index of the first track FX insert that is a virtual instrument, or -1 if none. See TrackFX_GetEQ, TrackFX_GetByName.
///-- @param track MediaTrack
pub const TrackFX_GetInstrument = function(&reaper.TrackFX_GetInstrument, 1, &.{MediaTrack});

/// TrackFX_GetIOSize
/// Gets the number of input/output pins for FX if available, returns plug-in type or -1 on error FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param inputPinsOut *c_int
///-- @param outputPinsOut *c_int
pub const TrackFX_GetIOSize = function(&reaper.TrackFX_GetIOSize, 4, &.{ MediaTrack, c_int, *c_int, *c_int });

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
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param parmname [*:0]const u8
///-- @param bufOutNeedBig [*:0]u8
///-- @param sz c_int
pub const TrackFX_GetNamedConfigParm = function(&reaper.TrackFX_GetNamedConfigParm, 5, &.{ MediaTrack, c_int, [*:0]const u8, [*:0]u8, c_int });

/// TrackFX_GetNumParams
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
pub const TrackFX_GetNumParams = function(&reaper.TrackFX_GetNumParams, 2, &.{ MediaTrack, c_int });

/// TrackFX_GetOffline
/// See TrackFX_SetOffline FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
pub const TrackFX_GetOffline = function(&reaper.TrackFX_GetOffline, 2, &.{ MediaTrack, c_int });

/// TrackFX_GetOpen
/// Returns true if this FX UI is open in the FX chain window or a f32ing window. See TrackFX_SetOpen FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
pub const TrackFX_GetOpen = function(&reaper.TrackFX_GetOpen, 2, &.{ MediaTrack, c_int });

/// TrackFX_GetParam
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param minvalOut *f64
///-- @param maxvalOut *f64
pub const TrackFX_GetParam = function(&reaper.TrackFX_GetParam, 5, &.{ MediaTrack, c_int, c_int, *f64, *f64 });

/// TrackFX_GetParameterStepSizes
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param stepOut *f64
///-- @param smallstepOut *f64
///-- @param largestepOut *f64
///-- @param istoggleOut *bool
pub const TrackFX_GetParameterStepSizes = function(&reaper.TrackFX_GetParameterStepSizes, 7, &.{ MediaTrack, c_int, c_int, *f64, *f64, *f64, *bool });

/// TrackFX_GetParamEx
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param minvalOut *f64
///-- @param maxvalOut *f64
///-- @param midvalOut *f64
pub const TrackFX_GetParamEx = function(&reaper.TrackFX_GetParamEx, 6, &.{ MediaTrack, c_int, c_int, *f64, *f64, *f64 });

/// TrackFX_GetParamFromIdent
/// gets the parameter index from an identifying string (:wet, :bypass, :delta, or a string returned from GetParamIdent), or -1 if unknown. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param str [*:0]const u8
pub const TrackFX_GetParamFromIdent = function(&reaper.TrackFX_GetParamFromIdent, 3, &.{ MediaTrack, c_int, [*:0]const u8 });

/// TrackFX_GetParamIdent
/// gets an identifying string for the parameter FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param bufOut *c_char
///-- @param sz c_int
pub const TrackFX_GetParamIdent = function(&reaper.TrackFX_GetParamIdent, 5, &.{ MediaTrack, c_int, c_int, *c_char, c_int });

/// TrackFX_GetParamName
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param bufOut [*:0]const u8
///-- @param sz c_int
pub const TrackFX_GetParamName = function(&reaper.TrackFX_GetParamName, 5, &.{ MediaTrack, c_int, c_int, [*:0]const u8, c_int });

/// TrackFX_GetParamNormalized
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
pub const TrackFX_GetParamNormalized = function(&reaper.TrackFX_GetParamNormalized, 3, &.{ MediaTrack, c_int, c_int });

/// TrackFX_GetPinMappings
/// gets the effective channel mapping bitmask for a particular pin. high32Out will be set to the high 32 bits. Add 0x1000000 to pin index in order to access the second 64 bits of mappings independent of the first 64 bits. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param tr MediaTrack
///-- @param fx c_int
///-- @param isoutput c_int
///-- @param pin c_int
///-- @param high32Out *c_int
pub const TrackFX_GetPinMappings = function(&reaper.TrackFX_GetPinMappings, 5, &.{ MediaTrack, c_int, c_int, c_int, *c_int });

/// TrackFX_GetPreset
/// Get the name of the preset currently showing in the REAPER dropdown, or the full path to a factory preset file for VST3 plug-ins (.vstpreset). See TrackFX_SetPreset. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param presetnameOut [*:0]u8
///-- @param sz c_int
pub const TrackFX_GetPreset = function(&reaper.TrackFX_GetPreset, 4, &.{ MediaTrack, c_int, [*:0]u8, c_int });

/// TrackFX_GetPresetIndex
/// Returns current preset index, or -1 if error. numberOfPresetsOut will be set to total number of presets available. See TrackFX_SetPresetByIndex FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param numberOfPresetsOut *c_int
pub const TrackFX_GetPresetIndex = function(&reaper.TrackFX_GetPresetIndex, 3, &.{ MediaTrack, c_int, *c_int });

/// TrackFX_GetRecChainVisible
/// returns index of effect visible in record input chain, or -1 for chain hidden, or -2 for chain visible but no effect selected
///-- @param track MediaTrack
pub const TrackFX_GetRecChainVisible = function(&reaper.TrackFX_GetRecChainVisible, 1, &.{MediaTrack});

/// TrackFX_GetRecCount
/// returns count of record input FX. To access record input FX, use a FX indices [0x1000000..0x1000000+n). On the master track, this accesses monitoring FX rather than record input FX.
///-- @param track MediaTrack
pub const TrackFX_GetRecCount = function(&reaper.TrackFX_GetRecCount, 1, &.{MediaTrack});

/// TrackFX_GetUserPresetFilename
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param fnOut *c_char
///-- @param sz c_int
pub const TrackFX_GetUserPresetFilename = function(&reaper.TrackFX_GetUserPresetFilename, 4, &.{ MediaTrack, c_int, *c_char, c_int });

/// TrackFX_NavigatePresets
/// presetmove==1 activates the next preset, presetmove==-1 activates the previous preset, etc. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param presetmove c_int
pub const TrackFX_NavigatePresets = function(&reaper.TrackFX_NavigatePresets, 3, &.{ MediaTrack, c_int, c_int });

/// TrackFX_SetEnabled
/// See TrackFX_GetEnabled FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param enabled bool
pub const TrackFX_SetEnabled = function(&reaper.TrackFX_SetEnabled, 3, &.{ MediaTrack, c_int, bool });

/// TrackFX_SetEQBandEnabled
/// Enable or disable a ReaEQ band.
/// Returns false if track/fxidx is not ReaEQ.
/// Bandtype: -1=master gain, 0=hipass, 1=loshelf, 2=band, 3=notch, 4=hishelf, 5=lopass, 6=bandpass, 7=parallel bandpass.
/// Bandidx (ignored for master gain): 0=target first band matching bandtype, 1=target 2nd band matching bandtype, etc.
///
/// See TrackFX_GetEQ, TrackFX_GetEQParam, TrackFX_SetEQParam, TrackFX_GetEQBandEnabled. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fxidx c_int
///-- @param bandtype c_int
///-- @param bandidx c_int
///-- @param enable bool
pub const TrackFX_SetEQBandEnabled = function(&reaper.TrackFX_SetEQBandEnabled, 5, &.{ MediaTrack, c_int, c_int, c_int, bool });

/// TrackFX_SetEQParam
/// Returns false if track/fxidx is not ReaEQ. Targets a band matching bandtype.
/// Bandtype: -1=master gain, 0=hipass, 1=loshelf, 2=band, 3=notch, 4=hishelf, 5=lopass, 6=bandpass, 7=parallel bandpass.
/// Bandidx (ignored for master gain): 0=target first band matching bandtype, 1=target 2nd band matching bandtype, etc.
/// Paramtype (ignored for master gain): 0=freq, 1=gain, 2=Q.
/// See TrackFX_GetEQ, TrackFX_GetEQParam, TrackFX_GetEQBandEnabled, TrackFX_SetEQBandEnabled. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fxidx c_int
///-- @param bandtype c_int
///-- @param bandidx c_int
///-- @param paramtype c_int
///-- @param val f64
///-- @param isnorm bool
pub const TrackFX_SetEQParam = function(&reaper.TrackFX_SetEQParam, 7, &.{ MediaTrack, c_int, c_int, c_int, c_int, f64, bool });

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
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param parmname [*:0]const u8
///-- @param value [*:0]const u8
pub const TrackFX_SetNamedConfigParm = function(&reaper.TrackFX_SetNamedConfigParm, 4, &.{ MediaTrack, c_int, [*:0]const u8, [*:0]const u8 });

/// TrackFX_SetOffline
/// See TrackFX_GetOffline FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param offline bool
pub const TrackFX_SetOffline = function(&reaper.TrackFX_SetOffline, 3, &.{ MediaTrack, c_int, bool });

/// TrackFX_SetOpen
/// Open this FX UI. See TrackFX_GetOpen FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param open bool
pub const TrackFX_SetOpen = function(&reaper.TrackFX_SetOpen, 3, &.{ MediaTrack, c_int, bool });

/// TrackFX_SetParam
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param val f64
pub const TrackFX_SetParam = function(&reaper.TrackFX_SetParam, 4, &.{ MediaTrack, c_int, c_int, f64 });

/// TrackFX_SetParamNormalized
///  FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param param c_int
///-- @param value f64
pub const TrackFX_SetParamNormalized = function(&reaper.TrackFX_SetParamNormalized, 4, &.{ MediaTrack, c_int, c_int, f64 });

/// TrackFX_SetPinMappings
/// sets the channel mapping bitmask for a particular pin. returns false if unsupported (not all types of plug-ins support this capability). Add 0x1000000 to pin index in order to access the second 64 bits of mappings independent of the first 64 bits. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param tr MediaTrack
///-- @param fx c_int
///-- @param isoutput c_int
///-- @param pin c_int
///-- @param low32bits c_int
///-- @param hi32bits c_int
pub const TrackFX_SetPinMappings = function(&reaper.TrackFX_SetPinMappings, 6, &.{ MediaTrack, c_int, c_int, c_int, c_int, c_int });

/// TrackFX_SetPreset
/// Activate a preset with the name shown in the REAPER dropdown. Full paths to .vstpreset files are also supported for VST3 plug-ins. See TrackFX_GetPreset. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param presetname [*:0]const u8
pub const TrackFX_SetPreset = function(&reaper.TrackFX_SetPreset, 3, &.{ MediaTrack, c_int, [*:0]const u8 });

/// TrackFX_SetPresetByIndex
/// Sets the preset idx, or the factory preset (idx==-2), or the default user preset (idx==-1). Returns true on success. See TrackFX_GetPresetIndex. FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param fx c_int
///-- @param idx c_int
pub const TrackFX_SetPresetByIndex = function(&reaper.TrackFX_SetPresetByIndex, 3, &.{ MediaTrack, c_int, c_int });

/// TrackFX_Show
/// showflag=0 for hidechain, =1 for show chain(index valid), =2 for hide f32ing window(index valid), =3 for show f32ing window (index valid) FX indices for tracks can have 0x1000000 added to them in order to reference record input FX (normal tracks) or hardware output FX (master track). FX indices can have 0x2000000 added to them, in which case they will be used to address FX in containers. To address a container, the 1-based subitem is multiplied by one plus the count of the FX chain and added to the 1-based container item index. e.g. to address the third item in the container at the second position of the track FX chain for tr, the index would be 0x2000000 + 3*(TrackFX_GetCount(tr)+1) + 2. This can be extended to sub-containers using TrackFX_GetNamedConfigParm with container_count and similar logic. In REAPER v7.06+, you can use the much more convenient method to navigate hierarchies, see TrackFX_GetNamedConfigParm with parent_container and container_item.X.
///-- @param track MediaTrack
///-- @param index c_int
///-- @param showFlag c_int
pub const TrackFX_Show = function(&reaper.TrackFX_Show, 3, &.{ MediaTrack, c_int, c_int });

/// TrackList_AdjustWindows
///-- @param isMinor bool
pub const TrackList_AdjustWindows = function(&reaper.TrackList_AdjustWindows, 1, &.{bool});

/// TrackList_UpdateAllExternalSurfaces
pub const TrackList_UpdateAllExternalSurfaces = function(&reaper.TrackList_UpdateAllExternalSurfaces, 0, &.{});

/// Undo_BeginBlock
/// call to start a new block
pub const Undo_BeginBlock = function(&reaper.Undo_BeginBlock, 0, &.{});

/// Undo_BeginBlock2
/// call to start a new block
///-- @param proj *ReaProject
pub const Undo_BeginBlock2 = function(&reaper.Undo_BeginBlock2, 1, &.{*ReaProject});

/// Undo_CanRedo2
/// returns string of next action,if able,NULL if not
///-- @param proj *ReaProject
pub const Undo_CanRedo2 = function(&reaper.Undo_CanRedo2, 1, &.{*ReaProject});

/// Undo_CanUndo2
/// returns string of last action,if able,NULL if not
///-- @param proj *ReaProject
pub const Undo_CanUndo2 = function(&reaper.Undo_CanUndo2, 1, &.{*ReaProject});

/// Undo_DoRedo2
/// nonzero if success
///-- @param proj *ReaProject
pub const Undo_DoRedo2 = function(&reaper.Undo_DoRedo2, 1, &.{*ReaProject});

/// Undo_DoUndo2
/// nonzero if success
///-- @param proj *ReaProject
pub const Undo_DoUndo2 = function(&reaper.Undo_DoUndo2, 1, &.{*ReaProject});

/// Undo_EndBlock
/// call to end the block,with extra flags if any,and a description
///-- @param descchange [*:0]const u8
///-- @param extraflags c_int
pub const Undo_EndBlock = function(&reaper.Undo_EndBlock, 2, &.{ [*:0]const u8, c_int });

/// Undo_EndBlock2
/// call to end the block,with extra flags if any,and a description
///-- @param proj *ReaProject
///-- @param descchange [*:0]const u8
///-- @param extraflags c_int
pub const Undo_EndBlock2 = function(&reaper.Undo_EndBlock2, 3, &.{ *ReaProject, [*:0]const u8, c_int });

/// Undo_OnStateChange
/// limited state change to items
///-- @param descchange [*:0]const u8
pub const Undo_OnStateChange = function(&reaper.Undo_OnStateChange, 1, &.{[*:0]const u8});

/// Undo_OnStateChange2
/// limited state change to items
///-- @param proj *ReaProject
///-- @param descchange [*:0]const u8
pub const Undo_OnStateChange2 = function(&reaper.Undo_OnStateChange2, 2, &.{ *ReaProject, [*:0]const u8 });

/// Undo_OnStateChange_Item
///-- @param proj *ReaProject
///-- @param name [*:0]const u8
///-- @param item *MediaItem
pub const Undo_OnStateChange_Item = function(&reaper.Undo_OnStateChange_Item, 3, &.{ *ReaProject, [*:0]const u8, *MediaItem });

/// Undo_OnStateChangeEx
/// trackparm=-1 by default,or if updating one fx chain,you can specify track index
///-- @param descchange [*:0]const u8
///-- @param whichStates c_int
///-- @param trackparm c_int
pub const Undo_OnStateChangeEx = function(&reaper.Undo_OnStateChangeEx, 3, &.{ [*:0]const u8, c_int, c_int });

/// Undo_OnStateChangeEx2
/// trackparm=-1 by default,or if updating one fx chain,you can specify track index
///-- @param proj *ReaProject
///-- @param descchange [*:0]const u8
///-- @param whichStates c_int
///-- @param trackparm c_int
pub const Undo_OnStateChangeEx2 = function(&reaper.Undo_OnStateChangeEx2, 4, &.{ *ReaProject, [*:0]const u8, c_int, c_int });

/// update_disk_counters
/// Updates disk I/O statistics with bytes transferred since last call. notify REAPER of a write error by calling with readamt=0, writeamt=-101010110 for unknown or -101010111 for disk full
///-- @param readamt c_int
///-- @param writeamt c_int
pub const update_disk_counters = function(&reaper.update_disk_counters, 2, &.{ c_int, c_int });

/// UpdateArrange
/// Redraw the arrange view
pub const UpdateArrange = function(&reaper.UpdateArrange, 0, &.{});

/// UpdateItemInProject
///-- @param item *MediaItem
pub const UpdateItemInProject = function(&reaper.UpdateItemInProject, 1, &.{*MediaItem});

/// UpdateItemLanes
/// Recalculate lane arrangement for fixed lane tracks, including auto-removing empty lanes at the bottom of the track
///-- @param proj *ReaProject
pub const UpdateItemLanes = function(&reaper.UpdateItemLanes, 1, &.{*ReaProject});

/// UpdateTimeline
/// Redraw the arrange view and ruler
pub const UpdateTimeline = function(&reaper.UpdateTimeline, 0, &.{});

/// ValidatePtr
/// see ValidatePtr2
///-- @param pointer *void
///-- @param ctypename [*:0]const u8
pub const ValidatePtr = function(&reaper.ValidatePtr, 2, &.{ *void, [*:0]const u8 });

/// ValidatePtr2
/// Return true if the pointer is a valid object of the right type in proj (proj is ignored if pointer is itself a project). Supported types are: *ReaProject, *MediaTrack, *MediaItem, *MediaItem_Take, *TrackEnvelope and *PCM_source.
///-- @param proj *ReaProject
///-- @param pointer *void
///-- @param ctypename [*:0]const u8
pub const ValidatePtr2 = function(&reaper.ValidatePtr2, 3, &.{ *ReaProject, *void, [*:0]const u8 });

/// ViewPrefs
/// Opens the prefs to a page, use pageByName if page is 0.
///-- @param page c_int
///-- @param pageByName [*:0]const u8
pub const ViewPrefs = function(&reaper.ViewPrefs, 2, &.{ c_int, [*:0]const u8 });

/// WDL_VirtualWnd_ScaledBlitBG
///-- @param dest *LICE_IBitmap
///-- @param src *WDL_VirtualWnd_BGCfg
///-- @param destx c_int
///-- @param desty c_int
///-- @param destw c_int
///-- @param desth c_int
///-- @param clipx c_int
///-- @param clipy c_int
///-- @param clipw c_int
///-- @param cliph c_int
///-- @param alpha f32
///-- @param mode c_int
pub const WDL_VirtualWnd_ScaledBlitBG = function(&reaper.WDL_VirtualWnd_ScaledBlitBG, 12, &.{ *LICE_IBitmap, *WDL_VirtualWnd_BGCfg, c_int, c_int, c_int, c_int, c_int, c_int, c_int, c_int, f32, c_int });

fn funcType(comptime func: anytype) type {
    return @typeInfo(@TypeOf(func.*)).Pointer.child;
}

fn returnType(comptime func: anytype) type {
    return @typeInfo(funcType(func)).Fn.return_type.?;
}

fn function(comptime func: anytype, min_argc: comptime_int, comptime arg_types: []const type) fn (args: anytype) callconv(.Inline) returnType(func) {
    return struct {
        inline fn wrapper(args: anytype) returnType(func) {
            var cast_args: std.meta.Tuple(arg_types) = undefined;
            if (args.len < min_argc) {
                @compileError(std.fmt.comptimePrint("{s}: expected {}..{} arguments, got {}", .{ @typeName(@TypeOf(func.*)), min_argc, cast_args.len, args.len }));
            }

            // Set ignore notifications flag
            const csurf = @import("csurf/control_surface.zig");
            csurf.ignore_notifications = true;
            defer csurf.ignore_notifications = false;

            inline for (0..cast_args.len) |i| {
                if (i >= args.len) {
                    cast_args[i] = null;
                    continue;
                }
                const arg_type = @typeInfo(@TypeOf(args[i]));
                comptime var cast_arg_type = @typeInfo(@TypeOf(cast_args[i]));
                if (cast_arg_type == .Optional)
                    cast_arg_type = @typeInfo(cast_arg_type.Optional.child);
                cast_args[i] = if (cast_arg_type == .Int and
                    ((arg_type == .ComptimeInt and args[i] > std.math.maxInt(c_int)) or
                    (arg_type == .Int and arg_type.Int.signedness == .unsigned)))
                    @bitCast(@as(c_uint, args[i]))
                else
                    args[i];
            }

            var call_args: std.meta.ArgsTuple(funcType(func)) = undefined;
            inline for (0..call_args.len) |i| {
                const cast_arg_type = @typeInfo(@TypeOf(cast_args[i]));
                call_args[i] =
                    if (cast_arg_type == .Optional)
                    if (cast_args[i]) |*arg_val|
                        if (@typeInfo(cast_arg_type.Optional.child) == .Pointer)
                            arg_val.*
                        else
                            arg_val
                    else
                        null
                else
                    cast_args[i];
            }

            const rv = @call(.auto, func.*, call_args);
            return rv;
        }
    }.wrapper;
}

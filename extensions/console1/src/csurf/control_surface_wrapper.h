#include <stdbool.h>
#include "../../WDL/swell/swell-types.h"
#include "../../WDL/wdltypes.h"
#ifdef __cplusplus
#include "../reaper_plugin.h"
/*#include "../WDL/localize/localize.h"*/
extern "C" {
#endif

typedef void *C_ControlSurface;
typedef void *midi_Input;
typedef void *MIDI_eventlist;

typedef struct MediaTrack
    MediaTrack; // Forward declaration of MediaTrack as an opaque struct
C_ControlSurface ControlSurface_Create();

void ControlSurface_Destroy(C_ControlSurface instance);

HWND configFunc(const char *type_string, HWND parent, const char *initConfigString);
typedef struct _REAPER_reaper_csurf_reg_t reaper_csurf_reg_t;

void MidiIn_start(midi_Input *m_midiin);
void MidiIn_SwapBufs(midi_Input *m_midiin, unsigned int timestamp);
MIDI_eventlist *cMidiIn_GetReadBuf(midi_Input *m_midiin);

void MidiOut_Send(midi_Output *m_midiout,unsigned char status, unsigned char d1, unsigned char d2, int frame_offset);

#ifdef __cplusplus
}
#endif

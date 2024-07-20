// midi_input_wrapper.h
#ifndef MIDI_INPUT_WRAPPER_H
#define MIDI_INPUT_WRAPPER_H
#include "../reaper_plugin.h"

#ifdef __cplusplus
extern "C" {
#endif

// C wrapper function prototypes
void MidiIn_start(midi_Input *m_midiin);
void MidiIn_stop(midi_Input *m_midiin);
void MidiIn_SwapBufs(midi_Input *m_midiin, unsigned int timestamp);
MIDI_eventlist *MidiIn_GetReadBuf(midi_Input *m_midiin);
void MidiIn_SwapBufsPrecise(midi_Input *m_midiin, unsigned int coarsetimestamp,
                            double precisetimestamp);
void MidiIn_Destroy(midi_Input *m_midiin);

typedef struct MIDI_event_t
    MIDI_event_t; // Forward declaration of MIDI_event_t as an opaque struct

void MidiOut_Destroy(midi_Output *m_midiout);
void MidiOut_BeginBlock(midi_Output *m_midiout);
void MidiOut_EndBlock(midi_Output *m_midiout, int length, double srate,
                      double curtempo);
void MidiOut_SendMsg(midi_Output *m_midiout, MIDI_event_t *msg,
                     int frame_offset);
void MidiOut_Send(midi_Output *m_midiout, unsigned char status,
                  unsigned char d1, unsigned char d2, int frame_offset);

void MDEvtLs_AddItem(MIDI_eventlist *mdEvtLs, MIDI_event_t *evt);
MIDI_event_t *MDEvtLs_EnumItems(MIDI_eventlist *mdEvtLs, int *bpos);
void MDEvtLs_DeleteItem(MIDI_eventlist *mdEvtLs, int bpos);
int MDEvtLs_GetSize(MIDI_eventlist *mdEvtLs); // size of block in bytes
void MDEvtLs_Empty(MIDI_eventlist *mdEvtLs);

#ifdef __cplusplus
}
#endif

#endif // MIDI_INPUT_WRAPPER_H

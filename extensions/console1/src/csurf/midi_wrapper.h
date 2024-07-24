// midi_input_wrapper.h
#ifndef MIDI_INPUT_WRAPPER_H
#define MIDI_INPUT_WRAPPER_H

#ifdef __cplusplus
#include "../reaper_plugin.h"
extern "C" {
#endif
typedef void *midi_Input_w;
typedef void *midi_Output_w;
typedef void *MIDI_eventlist_w;
typedef struct MIDI_event_t MIDI_event_t;
// C wrapper function prototypes

void MidiIn_start(midi_Input_w m_midiin);
void MidiIn_stop(midi_Input_w m_midiin);
void MidiIn_SwapBufs(midi_Input_w m_midiin, unsigned int timestamp);
MIDI_eventlist_w MidiIn_GetReadBuf(midi_Input_w m_midiin);
void MidiIn_SwapBufsPrecise(midi_Input_w m_midiin, unsigned int coarsetimestamp,
                            double precisetimestamp);
void MidiIn_Destroy(midi_Input_w m_midiin);

void MidiOut_Destroy(midi_Output_w m_midiout);
void MidiOut_BeginBlock(midi_Output_w m_midiout);
void MidiOut_EndBlock(midi_Output_w m_midiout, int length, double srate,
                      double curtempo);
void MidiOut_SendMsg(midi_Output_w m_midiout, MIDI_event_t *msg,
                     int frame_offset);
void MidiOut_Send(midi_Output_w m_midiout, unsigned char status,
                  unsigned char d1, unsigned char d2, int frame_offset);

void MDEvtLs_AddItem(MIDI_eventlist_w mdEvtLs, MIDI_event_t *evt);
MIDI_event_t *MDEvtLs_EnumItems(MIDI_eventlist_w mdEvtLs, int *bpos);
void MDEvtLs_DeleteItem(MIDI_eventlist_w mdEvtLs, int bpos);
int MDEvtLs_GetSize(MIDI_eventlist_w mdEvtLs); // size of block in bytes
void MDEvtLs_Empty(MIDI_eventlist_w mdEvtLs);

int MIDI_event_size(MIDI_event_t *evt);

unsigned char *MIDI_event_message(MIDI_event_t *evt);

midi_Output_w CreateThreadedMIDIOutput(midi_Output_w output);

#ifdef __cplusplus
}
#endif

#endif // MIDI_INPUT_WRAPPER_H

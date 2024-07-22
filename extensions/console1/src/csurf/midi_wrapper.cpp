// midi_input_wrapper.cpp
// midi_input_wrapper.cpp
#include "midi_wrapper.h"
#include "midi_wrapper_classes.h"

extern "C" {

void MidiIn_start(midi_Input_w m_midiin) {
  if (m_midiin) {
    static_cast<zMidi_Input *>(m_midiin)->start();
  }
}

void MidiIn_stop(midi_Input_w m_midiin) {
  if (m_midiin) {
    static_cast<zMidi_Input *>(m_midiin)->stop();
  }
}

void MidiIn_SwapBufs(midi_Input_w m_midiin, unsigned int timestamp) {
  if (m_midiin) {
    static_cast<zMidi_Input *>(m_midiin)->SwapBufs(timestamp);
  }
}

MIDI_eventlist_w MidiIn_GetReadBuf(midi_Input_w m_midiin) {
  if (m_midiin) {
    return static_cast<MIDI_eventlist_w>(
        static_cast<zMidi_Input *>(m_midiin)->GetReadBuf());
  }
  return nullptr;
}

void MidiIn_SwapBufsPrecise(midi_Input_w m_midiin, unsigned int coarsetimestamp,
                            double precisetimestamp) {
  if (m_midiin) {
    static_cast<zMidi_Input *>(m_midiin)->SwapBufsPrecise(coarsetimestamp,
                                                          precisetimestamp);
  }
}

void MidiIn_Destroy(midi_Input_w m_midiin) {
  if (m_midiin) {
    static_cast<zMidi_Input *>(m_midiin)->Destroy();
  }
}

void MidiOut_Destroy(midi_Output_w m_midiout) {
  if (m_midiout) {
    static_cast<zMidi_Output *>(m_midiout)->Destroy();
  }
}

void MidiOut_BeginBlock(midi_Output_w m_midiout) {
  if (m_midiout) {
    static_cast<zMidi_Output *>(m_midiout)->BeginBlock();
  }
}

void MidiOut_EndBlock(midi_Output_w m_midiout, int length, double srate,
                      double curtempo) {
  if (m_midiout) {
    static_cast<zMidi_Output *>(m_midiout)->EndBlock(length, srate, curtempo);
  }
}

void MidiOut_SendMsg(midi_Output_w m_midiout, MIDI_event_t *msg,
                     int frame_offset) {
  if (m_midiout) {
    static_cast<zMidi_Output *>(m_midiout)->SendMsg(msg, frame_offset);
  }
}

void MidiOut_Send(midi_Output_w m_midiout, unsigned char status,
                  unsigned char d1, unsigned char d2, int frame_offset) {
  if (m_midiout) {
    static_cast<zMidi_Output *>(m_midiout)->Send(status, d1, d2, frame_offset);
  }
}

void MDEvtLs_AddItem(MIDI_eventlist_w mdEvtLs, MIDI_event_t *evt) {
  if (mdEvtLs) {
    static_cast<zMIDI_eventlist *>(mdEvtLs)->AddItem(evt);
  }
};
MIDI_event_t *MDEvtLs_EnumItems(MIDI_eventlist_w mdEvtLs, int *bpos) {
  if (mdEvtLs) {
    return static_cast<zMIDI_eventlist *>(mdEvtLs)->EnumItems(bpos);
  }
  return nullptr;
};
void MDEvtLs_DeleteItem(MIDI_eventlist_w mdEvtLs, int bpos) {
  if (mdEvtLs) {
    static_cast<zMIDI_eventlist *>(mdEvtLs)->DeleteItem(bpos);
  }
};
int MDEvtLs_GetSize(MIDI_eventlist_w mdEvtLs) {
  if (mdEvtLs) {
    return static_cast<zMIDI_eventlist *>(mdEvtLs)->GetSize();
  }
  return 0;
};
void MDEvtLs_Empty(MIDI_eventlist_w mdEvtLs) {
  if (mdEvtLs) {
    static_cast<zMIDI_eventlist *>(mdEvtLs)->Empty();
  }
};
}

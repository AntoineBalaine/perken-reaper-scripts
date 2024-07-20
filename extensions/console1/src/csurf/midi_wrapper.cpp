// midi_input_wrapper.cpp
// midi_input_wrapper.cpp
#include "midi_wrapper.h"

extern "C" {

void MidiIn_start(midi_Input *m_midiin) {
  if (m_midiin) {
    m_midiin->start();
  }
}

void MidiIn_stop(midi_Input *m_midiin) {
  if (m_midiin) {
    m_midiin->stop();
  }
}

void MidiIn_SwapBufs(midi_Input *m_midiin, unsigned int timestamp) {
  if (m_midiin) {
    m_midiin->SwapBufs(timestamp);
  }
}

MIDI_eventlist *MidiIn_GetReadBuf(midi_Input *m_midiin) {
  if (m_midiin) {
    return m_midiin->GetReadBuf();
  }
  return nullptr;
}

void MidiIn_SwapBufsPrecise(midi_Input *m_midiin, unsigned int coarsetimestamp,
                            double precisetimestamp) {
  if (m_midiin) {
    m_midiin->SwapBufsPrecise(coarsetimestamp, precisetimestamp);
  }
}

void MidiIn_Destroy(midi_Input *m_midiin) {
  if (m_midiin) {
    m_midiin->Destroy();
  }
}

void MidiOut_Destroy(midi_Output *m_midiout) {
  if (m_midiout) {
    static_cast<midi_Output *>(m_midiout)->Destroy();
  }
}

void MidiOut_BeginBlock(midi_Output *m_midiout) {
  if (m_midiout) {
    static_cast<midi_Output *>(m_midiout)->BeginBlock();
  }
}

void MidiOut_EndBlock(midi_Output *m_midiout, int length, double srate,
                      double curtempo) {
  if (m_midiout) {
    static_cast<midi_Output *>(m_midiout)->EndBlock(length, srate, curtempo);
  }
}

void MidiOut_SendMsg(midi_Output *m_midiout, MIDI_event_t *msg,
                     int frame_offset) {
  if (m_midiout) {
    static_cast<midi_Output *>(m_midiout)->SendMsg(msg, frame_offset);
  }
}

void MidiOut_Send(midi_Output *m_midiout, unsigned char status,
                  unsigned char d1, unsigned char d2, int frame_offset) {
  if (m_midiout) {
    static_cast<midi_Output *>(m_midiout)->Send(status, d1, d2, frame_offset);
  }
}
}

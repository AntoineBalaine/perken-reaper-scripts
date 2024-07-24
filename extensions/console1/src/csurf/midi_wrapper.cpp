#include "midi_wrapper.h"
#include "../../WDL/heapbuf.h"
#include "../../WDL/mutex.h"
#include "../../WDL/ptrlist.h"
#include "../../WDL/setthreadname.h"
#include "midi_wrapper_classes.h"

class threadedMIDIOutput : public midi_Output {
public:
  threadedMIDIOutput(midi_Output *out) {
    m_output = out;
    m_quit = 0;
    unsigned id;
    m_hThread = (HANDLE)_beginthreadex(NULL, 0, threadProc, this, 0, &id);
  }

  virtual ~threadedMIDIOutput() {
    if (m_hThread) {
      m_quit = 1;
      WaitForSingleObject(m_hThread, INFINITE);
      CloseHandle(m_hThread);
      m_hThread = 0;
      Sleep(30);
    }

    if (m_output)
      m_output->Destroy();
    m_empty.Empty(true);
    m_full.Empty(true);
  }

  virtual void Destroy() {
    HANDLE thread = m_hThread;
    if (!thread) {
      delete this;
    } else {
      m_hThread = NULL;
      m_quit = 2;

      // thread will delete self
      WaitForSingleObject(thread, 100);
      CloseHandle(thread);
    }
  }

  virtual void
  SendMsg(MIDI_event_t *msg,
          int frame_offset) // frame_offset can be <0 for "instant" if supported
  {
    if (!msg)
      return;

    WDL_HeapBuf *b = NULL;
    if (m_empty.GetSize()) {
      m_mutex.Enter();
      b = m_empty.Get(m_empty.GetSize() - 1);
      m_empty.Delete(m_empty.GetSize() - 1);
      m_mutex.Leave();
    }
    if (!b && m_empty.GetSize() + m_full.GetSize() < 500)
      b = new WDL_HeapBuf(256);

    if (b) {
      int sz = msg->size;
      if (sz < 3)
        sz = 3;
      int len = msg->midi_message + sz - (unsigned char *)msg;
      memcpy(b->Resize(len, false), msg, len);
      m_mutex.Enter();
      m_full.Add(b);
      m_mutex.Leave();
    }
  }

  virtual void
  Send(unsigned char status, unsigned char d1, unsigned char d2,
       int frame_offset) // frame_offset can be <0 for "instant" if supported
  {
    MIDI_event_t evt = {0, 3, status, d1, d2};
    SendMsg(&evt, frame_offset);
  }

  ///////////

  static unsigned WINAPI threadProc(LPVOID p) {
    WDL_SetThreadName("reaper/cs_midio");
    WDL_HeapBuf *lastbuf = NULL;
    threadedMIDIOutput *_this = (threadedMIDIOutput *)p;
    unsigned int scnt = 0;
    for (;;) {
      if (_this->m_full.GetSize() || lastbuf) {
        _this->m_mutex.Enter();
        if (lastbuf)
          _this->m_empty.Add(lastbuf);
        lastbuf = _this->m_full.Get(0);
        _this->m_full.Delete(0);
        _this->m_mutex.Leave();

        if (lastbuf)
          _this->m_output->SendMsg((MIDI_event_t *)lastbuf->Get(), -1);
        scnt = 0;
      } else {
        Sleep(1);
        if (_this->m_quit && scnt++ > 3)
          break; // only quit once all messages have been sent
      }
    }
    delete lastbuf;
    if (_this->m_quit == 2)
      delete _this;
    return 0;
  }

  WDL_Mutex m_mutex;
  WDL_PtrList<WDL_HeapBuf> m_full, m_empty;

  HANDLE m_hThread;
  int m_quit; // set to 1 to finish, 2 to finish+delete self
  midi_Output *m_output;
};

midi_Output_w CreateThreadedMIDIOutput(midi_Output_w output) {
  if (!output)
    return output;
  return new threadedMIDIOutput(static_cast<zMidi_Output *>(output));
}

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

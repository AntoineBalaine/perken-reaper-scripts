#include "../reaper_plugin.h"

class zMidi_Input : public midi_Input {
public:
  ~zMidi_Input() {}

  void start() override;
  void stop() override;

  void SwapBufs(
      unsigned int timestamp) override; // DEPRECATED call SwapBufsPrecise()
                                        // instead  // timestamp=process ms

  void RunPreNoteTracking(int isAccum) override;

  MIDI_eventlist *
  GetReadBuf() override; // note: the event list here has frame offsets that are
                         // in units of 1/1024000 of a second, NOT sample frames

  void SwapBufsPrecise(
      unsigned int coarsetimestamp,
      double precisetimestamp) // coarse=process ms, precise=process sec, the
                               // target will know internally which to use
      override;

  void Destroy()
      override; // allows implementations to do asynchronous destroy (5.95+)
};

class zMidi_Output : public midi_Output {
public:
  ~zMidi_Output() {}
  void BeginBlock() override; // outputs can implement these if they wish to
  void EndBlock(int length, double srate, double curtempo) override;
  void SendMsg(MIDI_event_t *msg, int frame_offset)
      override; // frame_offset can be <0 for "instant" if supported
  void Send(unsigned char status, unsigned char d1, unsigned char d2,
            int frame_offset)
      override; // frame_offset can be <0 for "instant" if supported

  void Destroy()
      override; // allows implementations to do asynchronous destroy (5.95+)
};

class zMIDI_eventlist : public MIDI_eventlist {
public:
  void AddItem(MIDI_event_t *evt) override;
  MIDI_event_t *EnumItems(int *bpos) override;
  void DeleteItem(int bpos) override;
  int GetSize() override; // size of block in bytes
  void Empty() override;

protected:
  // this is only defined in REAPER 4.60+, for 4.591 and earlier you should
  // delete only via the implementation pointer
  ~zMIDI_eventlist() override;
};

unsigned char *MIDI_event_message(MIDI_event_t *evt) {
  return evt->midi_message;
};

int MIDI_event_size(MIDI_event_t *evt) { return evt->size; }

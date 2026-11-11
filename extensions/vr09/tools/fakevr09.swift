// A stand-in for the VR-09, for testing the plugin without the keyboard (macOS).
//
//   swiftc -O tools/fakevr09.swift -o fakevr09
//   ./fakevr09 /path/to/dump.json /path/to/log.txt
//
// It creates a virtual MIDI input and output named "VR-09 Fake", loads a dump of the roland-vr09
// project (the JSON that vr09.py writes), and behaves like the keyboard in MIDI IN Mode 2: it answers
// an Identity Request and every RQ1 with a DT1 from the dump, and applies every DT1 it receives to
// the dump. Each message it handles is appended to the log file, so that a test can check them.
import CoreMIDI
import Foundation

struct Key: Hashable { let synth: Bool; let address: UInt32 }

var state: [Key: UInt8] = [:]
let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: fakevr09 dump.json log.txt"); exit(1) }
let logHandle: FileHandle = {
    FileManager.default.createFile(atPath: args[2], contents: nil)
    return FileHandle(forWritingAtPath: args[2])!
}()

func log(_ text: String) {
    logHandle.write((text + "\n").data(using: .utf8)!)
}

if let data = FileManager.default.contents(atPath: args[1]),
   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Int] {
    for (key, value) in json {
        let parts = key.split(separator: ":")
        guard parts.count == 2, let address = UInt32(parts[1], radix: 16) else { continue }
        state[Key(synth: parts[0].hasPrefix("synth_set"), address: address)] = UInt8(value)
    }
}
log("loaded \(state.count) values")

func checksum(_ bytes: [UInt8]) -> UInt8 {
    let sum = bytes.reduce(0) { $0 + Int($1) }
    return UInt8((128 - sum % 128) % 128)
}

func unpack(_ bytes: ArraySlice<UInt8>) -> UInt32 {
    bytes.reduce(0) { ($0 << 7) | UInt32($1 & 0x7F) }
}

func pack(_ value: UInt32, _ length: Int) -> [UInt8] {
    (0..<length).reversed().map { UInt8((value >> (7 * UInt32($0))) & 0x7F) }
}

var client = MIDIClientRef()
var source = MIDIEndpointRef()
var destination = MIDIEndpointRef()

func send(_ bytes: [UInt8]) {
    var buffer = [UInt8](repeating: 0, count: 1024)
    buffer.withUnsafeMutableBytes { raw in
        let list = raw.baseAddress!.assumingMemoryBound(to: MIDIPacketList.self)
        var packet = MIDIPacketListInit(list)
        packet = MIDIPacketListAdd(list, 1024, packet, 0, bytes.count, bytes)
        MIDIReceived(source, list)
    }
}

func handleShort(_ bytes: [UInt8]) {
    log("MIDI " + bytes.map { String($0, radix: 16) }.joined(separator: " "))
}

func handle(_ message: [UInt8]) {
    guard message.first == 0xF0, message.last == 0xF7 else { return }
    let body = Array(message.dropFirst().dropLast())
    if body == [0x7E, 0x7F, 0x06, 0x01] {
        log("identity request")
        send([0xF0, 0x7E, 0x10, 0x06, 0x02, 0x41, 0x62, 0x00, 0x00, 0x06, 0x00, 0x01, 0x00, 0x00, 0xF7])
        return
    }
    guard body.count > 4, body[0] == 0x41, body[1] == 0x10 else { log("ignored \(message.count) bytes"); return }
    let synth = body[2] == 0x00 && body[3] == 0x00 && body.count > 4 && body[4] == 0x71
    let modelLen = synth ? 3 : 1
    let addrLen = synth ? 4 : 3
    let command = body[2 + modelLen]
    let payload = Array(body[(3 + modelLen)...])
    guard payload.count > addrLen else { return }
    let covered = Array(payload.dropLast())
    if checksum(covered) != payload.last! { log("bad checksum"); return }
    let address = unpack(covered[0..<addrLen])
    if command == 0x12 {
        for (i, v) in covered[addrLen...].enumerated() {
            state[Key(synth: synth, address: address + UInt32(i))] = v
        }
        log("DT1 \(synth ? "synth" : "kb") \(String(address, radix: 16)) \(covered[addrLen...].map { String($0) }.joined(separator: ","))")
    } else if command == 0x11 {
        let size = unpack(covered[addrLen..<(addrLen * 2)])
        var data: [UInt8] = []
        var any = false
        for i in 0..<size {
            if let v = state[Key(synth: synth, address: address + i)] { data.append(v); any = true } else { data.append(0) }
        }
        log("RQ1 \(synth ? "synth" : "kb") \(String(address, radix: 16)) size \(size) \(any ? "answered" : "silent")")
        if !any { return }
        let model: [UInt8] = synth ? [0x00, 0x00, 0x71] : [0x62]
        let inner = pack(address, addrLen) + data
        send([0xF0, 0x41, 0x10] + model + [0x12] + inner + [checksum(inner), 0xF7])
    }
}

var pending: [UInt8] = []
MIDIClientCreate("fakevr09" as CFString, nil, nil, &client)
MIDISourceCreate(client, "VR-09 Fake" as CFString, &source)
MIDIDestinationCreateWithBlock(client, "VR-09 Fake" as CFString, &destination) { list, _ in
    var packet = list.pointee.packet
    for _ in 0..<list.pointee.numPackets {
        let bytes = withUnsafeBytes(of: &packet.data) { Array($0.prefix(Int(packet.length))) }
        for b in bytes {
            if b >= 0xF8 { continue }
            if b == 0xF0 { pending = [] }
            if pending.isEmpty && b != 0xF0 {
                // A channel message outside a SysEx: log the whole packet once.
                if b >= 0x80 { handleShort(bytes); break }
                continue
            }
            pending.append(b)
            if b == 0xF7 { handle(pending); pending = [] }
        }
        packet = MIDIPacketNext(&packet).pointee
    }
}
log("ready")
// The unit also sends what the player plays; a note every two seconds stands in for that.
Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
    send([0x93, 60, 100])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { send([0x83, 60, 0]) }
}
// A drawbar moved on the panel: the unit sends a DT1 by itself, here the upper 16' drawbar between two values.
var panelValue: UInt8 = 2
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
    panelValue = panelValue == 2 ? 6 : 2
    state[Key(synth: false, address: 0x8003)] = panelValue
    let inner = pack(0x8003, 3) + [panelValue]
    send([0xF0, 0x41, 0x10, 0x62, 0x12] + inner + [checksum(inner), 0xF7])
    log("panel: drawbar 0x8003 -> \(panelValue)")
}
// The real unit sends MIDI clock all the time.
Timer.scheduledTimer(withTimeInterval: 0.0132, repeats: true) { _ in send([0xF8]) }
RunLoop.main.run()

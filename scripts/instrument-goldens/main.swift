// Prints the Swift loader's and wheel rules' answers as JSON so the web port
// (src/lib/instruments) can be checked against the real iOS code. See README.md.
//
// JSONDecoder/JSONEncoder only: JSONSerialization drops a leading U+FEFF from
// strings, which the loader itself keeps.
import Foundation

struct Case: Codable { let name: String; let text: String }

struct Load: Codable {
    let name: String
    let text: String
    let accepted: Bool
    let issues: [String]
    /// The repaired instrument as Swift encodes it.
    let spec: String?
}

struct RulesRow: Codable {
    let key: String, semitone: Int, scale: String, intervals: [Int], degree: Int
    let scaleChord: [Int], splitChord: [Int], scaleLanes: [Int], splitLanes: [Int]
    let scaleChordToneLanes: [Int], splitChordToneLanes: [Int], chordName: String
}

struct Output: Codable {
    let generatedBy: String
    let loads: [Load]
    let rules: [RulesRow]
    let suffix: [String: String]
    let swapHands: [Bool]
}

let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let specEncoder = JSONEncoder()
specEncoder.outputFormatting = .sortedKeys

let loads = cases.map { item -> Load in
    let result = InstrumentSpec.load(Data(item.text.utf8))
    let spec = result.spec.map { String(data: try! specEncoder.encode($0), encoding: .utf8)! }
    return Load(name: item.name, text: item.text, accepted: result.accepted, issues: result.issues.map(\.rawValue), spec: spec)
}

let scale = InstrumentLibrary.scaleWheel.rules
let split = InstrumentLibrary.splitWheel.rules
var rules: [RulesRow] = []
for key in [MusicKey.C, .D, .Eb, .Gb, .A, .B] {
    for builtIn in BuiltInScale.allCases {
        let mode = Scale.builtIn(builtIn)
        for degree in 0..<7 {
            let lanes = scale.noteLanes(key: key, scale: mode, chordDegree: degree)
            let splitLanes = split.noteLanes(key: key, scale: mode, chordDegree: degree)
            rules.append(RulesRow(
                key: key.rawValue, semitone: key.semitone, scale: builtIn.rawValue, intervals: mode.intervals, degree: degree,
                scaleChord: scale.chordTones(key: key, scale: mode, degree: degree),
                splitChord: split.chordTones(key: key, scale: mode, degree: degree),
                scaleLanes: lanes, splitLanes: splitLanes,
                scaleChordToneLanes: scale.chordToneLanes(key: key, scale: mode, chordDegree: degree, lanes: lanes).sorted(),
                splitChordToneLanes: split.chordToneLanes(key: key, scale: mode, chordDegree: degree, lanes: splitLanes).sorted(),
                chordName: chordDisplayName(key: key, scale: mode, degree: degree)))
        }
    }
}

let output = Output(
    generatedBy: "scripts/instrument-goldens from InstrumentSpec.swift and MusicTheory.swift",
    loads: loads, rules: rules,
    suffix: ["scale": scale.chordNameSuffix, "split": split.chordNameSuffix],
    swapHands: [scale.swapHands(playerSwap: false), scale.swapHands(playerSwap: true)])
let encoder = JSONEncoder()
encoder.outputFormatting = .sortedKeys
FileHandle.standardOutput.write(try encoder.encode(output))

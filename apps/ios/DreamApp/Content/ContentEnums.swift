import Foundation
import GRDB

/// Universal part-of-speech tags shared by words and sentence breakdowns.
nonisolated enum PartOfSpeech: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case adjective = "ADJ"
    case adposition = "ADP"
    case adverb = "ADV"
    case auxiliary = "AUX"
    case coordinatingConjunction = "CCONJ"
    case determiner = "DET"
    case interjection = "INTJ"
    case noun = "NOUN"
    case numeral = "NUM"
    case particle = "PART"
    case pronoun = "PRON"
    case properNoun = "PROPN"
    case punctuation = "PUNCT"
    case subordinatingConjunction = "SCONJ"
    case symbol = "SYM"
    case verb = "VERB"
    case other = "X"
}

/// The kind of a sentence row.
nonisolated enum SentenceType: String, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case phrase
    case sentence
    case question
}

/// Where a media asset came from.
nonisolated enum MediaOrigin: String, Codable, Sendable, CaseIterable {
    case ai
    case user
    case curated
}

/// The speaking pace of an audio recording.
nonisolated enum AudioPace: String, Codable, Sendable, CaseIterable {
    case slow
    case normal
    case fast
}

/// Word frequency buckets. The raw value is the bucket's upper bound.
nonisolated enum FrequencyRank: Int, Codable, Sendable, CaseIterable, DatabaseValueConvertible {
    case top100 = 100
    case top200 = 200
    case top500 = 500
    case top1000 = 1000
    case top2000 = 2000
    case top5000 = 5000
    case top10000 = 10000
    case top20000 = 20000
}

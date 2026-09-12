import AVFoundation
import Foundation
import Observation
import Synchronization

nonisolated enum PronunciationError: Error {
    /// The text was empty and there was no recording to play.
    case nothingToPlay
    /// No installed voice for the locale. Speaking anyway would read the text
    /// with another language's phonology.
    case voiceUnavailable(String)
    /// The recording started but did not play to the end.
    case playbackFailed((any Error)?)
    case audioSessionUnavailable(any Error)
}

/// Plays one pronunciation at a time: the recording when it is ready quickly,
/// device speech otherwise. Owned by `AppDependencies`; speaker controls read
/// `activity` to draw themselves. Everything about executing one
/// pronunciation lives here. Spoken-text selection stays with the language
/// rules, media caching with `MediaCache`, and sequencing with the feature.
@MainActor @Observable
final class Pronunciation {
    /// The playback multiplier the user asks for. Independent of `AudioPace`,
    /// which labels a recording and says nothing about its actual speed:
    /// normal plays the file unchanged, slow and fast adjust from there.
    nonisolated enum Speed: Sendable {
        case slow
        case normal
        case fast

        var multiplier: Double {
            switch self {
            case .slow: 0.7
            case .normal: 1
            case .fast: 1.25
            }
        }
    }

    /// Identifies the control a sound belongs to, so the right speaker
    /// animates. Owned by the feature and handed to its controls; autoplay
    /// and the visible button for the same track share one key.
    nonisolated struct Key: Hashable, Sendable {
        private let id = UUID()

        init() {}
    }

    nonisolated struct Request: Sendable {
        /// Already resolved to the form the synthesizer should read.
        var text: String
        var voice: SpokenVoice
        /// Preferred when present; speech takes over when it is missing,
        /// unreadable, or misses the loading deadline.
        var recording: AudioAsset?
        var speed: Speed = .normal
    }

    nonisolated enum Phase: Sendable {
        case loading
        case playing
    }

    nonisolated struct Activity: Equatable, Sendable {
        var key: Key
        var speed: Speed
        var phase: Phase
        /// Distinguishes repeated playback under one key, so a finished
        /// operation's cleanup cannot touch its successor's state.
        let operationID: UUID
    }

    private(set) var activity: Activity?

    /// How long a recording may take before speech starts instead. The
    /// download keeps running, so the next tap plays the recording.
    /// Initial value; set by listening.
    var loadingDeadline: Duration = .milliseconds(1200)

    /// Idle gap after the last sound before the audio session is released
    /// and other apps' audio comes back. Long enough that a feed sequence
    /// does not duck and restore between its tracks. Initial value.
    var sessionIdleRelease: Duration = .milliseconds(1500)

    @ObservationIgnored private let mode: Mode
    @ObservationIgnored private let session = AudioSession()
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let utterances = UtteranceRouter()
    @ObservationIgnored private var current: Operation?
    @ObservationIgnored private var interruptionWatch: Task<Void, Never>?
    @ObservationIgnored private var routeWatch: Task<Void, Never>?

    private enum Mode {
        case live(MediaCache)
        /// Resolves nothing and speaks nothing. `completesAfter: nil` never
        /// completes on its own but still answers cancellation.
        case preview(completesAfter: Duration?)
    }

    private struct Operation {
        let id: UUID
        let task: Task<Void, any Error>
    }

    convenience init(cache: MediaCache) {
        self.init(mode: .live(cache))
    }

    /// A fresh instance for previews: never touches the network or the
    /// speakers. Playback completes after `completesAfter`, or never when
    /// `nil`, so an autoplay sequence in a preview stays on its card.
    static func preview(completesAfter: Duration? = .zero) -> Pronunciation {
        Pronunciation(mode: .preview(completesAfter: completesAfter))
    }

    private init(mode: Mode) {
        self.mode = mode
        synthesizer.delegate = utterances
        guard case .live = mode else { return }
        interruptionWatch = Task { [weak self] in
            let began = AVAudioSession.InterruptionType.began.rawValue
            let notifications = NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification)
            for await notification in notifications {
                guard notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == began else { continue }
                guard let self else { return }
                await self.interrupted()
            }
        }
        routeWatch = Task { [weak self] in
            let lost = AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            let notifications = NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification)
            for await notification in notifications {
                guard notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == lost else { continue }
                guard let self else { return }
                self.routeLost()
            }
        }
    }

    deinit {
        interruptionWatch?.cancel()
        routeWatch?.cancel()
    }

    func isActive(_ key: Key) -> Bool {
        activity?.key == key
    }

    func phase(of key: Key) -> Phase? {
        guard let activity, activity.key == key else { return nil }
        return activity.phase
    }

    /// Plays the request, replacing whatever is sounding, and returns when
    /// playback finishes. A stop, a replacement, or cancellation of the
    /// caller's task throws `CancellationError`; a `PronunciationError` means
    /// nothing could be played.
    func play(_ request: Request, for key: Key) async throws {
        let previous = current
        previous?.task.cancel()

        let operationID = UUID()
        activity = Activity(key: key, speed: request.speed, phase: .loading, operationID: operationID)
        let task = Task {
            // The old sound is fully stopped before this one starts. Fast,
            // because every wait on the old path answers cancellation.
            _ = await previous?.task.result
            try Task.checkCancellation()
            try await self.run(request, operationID: operationID)
        }
        current = Operation(id: operationID, task: task)

        do {
            try await withTaskCancellationHandler {
                try await task.value
                // A completion that settled just before a stop, replacement,
                // or caller cancellation still counts as interrupted: the
                // awaiting caller must not continue.
                try Task.checkCancellation()
                guard !task.isCancelled,
                      current?.id == operationID,
                      activity?.operationID == operationID
                else { throw CancellationError() }
            } onCancel: {
                task.cancel()
            }
        } catch {
            await finish(operationID)
            throw error
        }
        await finish(operationID)
    }

    /// Stops the sound if this control owns it. Anything still waiting to
    /// start under this key is dropped too.
    func stop(_ key: Key) {
        guard let activity, activity.key == key else { return }
        current?.task.cancel()
        self.activity = nil
    }

    // MARK: - Operation lifecycle

    private func run(_ request: Request, operationID: UUID) async throws {
        switch mode {
        case .preview(let completesAfter):
            try await previewPlayback(completesAfter, operationID: operationID)
        case .live(let cache):
            do {
                try await session.activate()
            } catch {
                throw PronunciationError.audioSessionUnavailable(error)
            }
            try Task.checkCancellation()
            if let recording = request.recording,
               try await playRecording(recording, speed: request.speed, cache: cache, operationID: operationID) {
                return
            }
            // Reached only when the recording is missing, unreadable, or
            // slow. Cancellation threw above and never lands here.
            try await speak(request, operationID: operationID)
        }
    }

    private func finish(_ operationID: UUID) async {
        guard current?.id == operationID else { return }
        current = nil
        activity = nil
        await session.releaseWhenIdle(after: sessionIdleRelease)
    }

    private func setPhase(_ phase: Phase, for operationID: UUID) {
        guard activity?.operationID == operationID else { return }
        activity?.phase = phase
    }

    /// The system took the session (a call, Siri). Playback stops and does
    /// not resume; the next request reactivates the session.
    private func interrupted() async {
        current?.task.cancel()
        activity = nil
        await session.interrupted()
    }

    /// Headphones or a Bluetooth output went away. Playback stops rather
    /// than carrying on through the speaker. Unlike an interruption the
    /// session stays active; the usual idle release handles it once the
    /// cancelled `play()` unwinds.
    private func routeLost() {
        current?.task.cancel()
        activity = nil
    }

    private func previewPlayback(_ completesAfter: Duration?, operationID: UUID) async throws {
        setPhase(.playing, for: operationID)
        if let completesAfter {
            try await Task.sleep(for: completesAfter)
        } else {
            // Never yields; the iterator still returns on cancellation.
            let never = AsyncStream<Never> { _ in }
            for await _ in never {}
            try Task.checkCancellation()
        }
    }

    // MARK: - Recorded audio

    /// `true` when the recording played to the end. `false` when it could not
    /// be had in time, so speech takes over: falling back is decided before
    /// anything sounds. A failure after playback started throws instead,
    /// since part of the audio may already be out.
    private func playRecording(
        _ asset: AudioAsset,
        speed: Speed,
        cache: MediaCache,
        operationID: UUID
    ) async throws -> Bool {
        let file: URL?
        do {
            file = try await fileWithinDeadline(for: asset, cache: cache)
        } catch let error as CancellationError {
            throw error
        } catch {
            return false
        }
        guard let file else { return false }

        let playback: RecordingPlayback
        do {
            playback = try RecordingPlayback(file: file)
        } catch {
            // Not something the player can read: drop it so the next attempt
            // downloads a fresh copy.
            await cache.invalidate(asset.storagePath)
            return false
        }
        try Task.checkCancellation()
        guard playback.start(rate: Float(speed.multiplier)) else { return false }
        setPhase(.playing, for: operationID)
        try await playback.waitUntilFinished()
        return true
    }

    /// Races the file against the deadline. Losing releases the wait at once;
    /// `MediaCache` keeps the download going for next time.
    private func fileWithinDeadline(for asset: AudioAsset, cache: MediaCache) async throws -> URL? {
        try await withThrowingTaskGroup(of: URL?.self) { group in
            group.addTask { try await cache.file(for: asset.storagePath) }
            group.addTask { [loadingDeadline] in
                try await Task.sleep(for: loadingDeadline)
                return nil
            }
            defer { group.cancelAll() }
            return try await group.next() ?? nil
        }
    }

    // MARK: - Device speech

    private func speak(_ request: Request, operationID: UUID) async throws {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw PronunciationError.nothingToPlay }
        guard let voice = AVSpeechSynthesisVoice(language: request.voice.locale) else {
            throw PronunciationError.voiceUnavailable(request.voice.locale)
        }

        let settings = request.voice.settings
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Self.speechRate(fraction: settings.rate * request.speed.multiplier)
        utterance.pitchMultiplier = Float(settings.pitch)
        utterance.volume = Float(settings.volume)

        let completion = utterances.expect(utterance) { [weak self] in
            Task { @MainActor in self?.setPhase(.playing, for: operationID) }
        }
        defer { _ = synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(utterance)
        try await withTaskCancellationHandler {
            try await completion.wait()
        } onCancel: {
            completion.cancel()
        }
    }

    /// `AVSpeechUtterance.rate` is 0...1 around a platform default, not a
    /// multiplier.
    private static func speechRate(fraction: Double) -> Float {
        let rate = Float(Double(AVSpeechUtteranceDefaultSpeechRate) * fraction)
        return min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    }
}

// MARK: - Audio session

/// The process's audio session. The category is configured once and only
/// remembered after `setCategory` succeeds; activation is per playback and
/// released after an idle gap so other apps' audio comes back. An actor so
/// the blocking calls never run on the main actor.
private actor AudioSession {
    private var configured = false
    private var active = false
    private var release: Task<Void, Never>?

    func activate() throws {
        release?.cancel()
        release = nil
        let session = AVAudioSession.sharedInstance()
        if !configured {
            // `.playback` is what makes pronunciations audible with the
            // ring/silent switch on.
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            configured = true
        }
        if !active {
            try session.setActive(true)
            active = true
        }
    }

    /// Deactivates after `delay` unless a new activation comes first.
    func releaseWhenIdle(after delay: Duration) {
        release?.cancel()
        release = Task {
            guard (try? await Task.sleep(for: delay)) != nil else { return }
            deactivate()
        }
    }

    /// The system deactivated the session. The next activation calls
    /// `setActive` again.
    func interrupted() {
        release?.cancel()
        release = nil
        active = false
    }

    private func deactivate() {
        guard active else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        active = false
    }
}

// MARK: - SDK bridges

/// One prepared recording, used for a single playback. Decoding a short local
/// file on the main actor is cheap; the download before it is what has to
/// stay off it.
private final class RecordingPlayback {
    private let player: AVAudioPlayer
    private let completion = AsyncCompletion()
    private let delegate: PlaybackDelegate

    init(file: URL) throws {
        player = try AVAudioPlayer(contentsOf: file)
        delegate = PlaybackDelegate(completion: completion)
        player.delegate = delegate
        player.enableRate = true
        player.prepareToPlay()
    }

    /// Starts playback; `false` when the player refused.
    func start(rate: Float) -> Bool {
        player.rate = rate
        return player.play()
    }

    /// Waits for the end. Cancellation stops the player and throws.
    func waitUntilFinished() async throws {
        defer { player.stop() }
        try await withTaskCancellationHandler {
            try await completion.wait()
        } onCancel: { [completion] in
            completion.cancel()
        }
    }
}

/// `AVAudioPlayer` holds its delegate weakly and calls it off the main actor.
private nonisolated final class PlaybackDelegate: NSObject, AVAudioPlayerDelegate, Sendable {
    private let completion: AsyncCompletion

    init(completion: AsyncCompletion) {
        self.completion = completion
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            completion.finish()
        } else {
            completion.fail(PronunciationError.playbackFailed(nil))
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        completion.fail(PronunciationError.playbackFailed(error))
    }
}

/// Matches synthesizer callbacks, which arrive off the main actor, to the
/// utterance awaiting them. The utterance object is the operation identity,
/// so a late `didCancel` for a replaced utterance cannot settle the new one.
private nonisolated final class UtteranceRouter: NSObject, AVSpeechSynthesizerDelegate, Sendable {
    private struct Pending: Sendable {
        let completion: AsyncCompletion
        let onStart: @Sendable () -> Void
    }

    private let pending = Mutex<[ObjectIdentifier: Pending]>([:])

    func expect(_ utterance: AVSpeechUtterance, onStart: @escaping @Sendable () -> Void) -> AsyncCompletion {
        let completion = AsyncCompletion()
        pending.withLock { $0[ObjectIdentifier(utterance)] = Pending(completion: completion, onStart: onStart) }
        return completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        pending.withLock { $0[ObjectIdentifier(utterance)] }?.onStart()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        take(utterance)?.completion.finish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        take(utterance)?.completion.cancel()
    }

    private func take(_ utterance: AVSpeechUtterance) -> Pending? {
        pending.withLock { $0.removeValue(forKey: ObjectIdentifier(utterance)) }
    }
}

/// A one-shot completion an SDK callback settles from any thread. `cancel()`
/// makes the waiter throw `CancellationError`; later callbacks are ignored,
/// so every operation completes exactly once.
private nonisolated final class AsyncCompletion: Sendable {
    private enum State {
        case waiting
        case suspended(CheckedContinuation<Void, any Error>)
        case settled(Result<Void, any Error>)
        case done
    }

    private let state = Mutex<State>(.waiting)

    func wait() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let ready: Result<Void, any Error>? = state.withLock { state in
                switch state {
                case .waiting:
                    state = .suspended(continuation)
                    return nil
                case .settled(let result):
                    state = .done
                    return result
                case .suspended, .done:
                    return nil
                }
            }
            if let ready { continuation.resume(with: ready) }
        }
    }

    func finish() { settle(.success(())) }
    func fail(_ error: any Error) { settle(.failure(error)) }
    func cancel() { settle(.failure(CancellationError())) }

    private func settle(_ result: Result<Void, any Error>) {
        let continuation = state.withLock { state -> CheckedContinuation<Void, any Error>? in
            switch state {
            case .waiting:
                state = .settled(result)
                return nil
            case .suspended(let continuation):
                state = .done
                return continuation
            case .settled, .done:
                return nil
            }
        }
        continuation?.resume(with: result)
    }
}

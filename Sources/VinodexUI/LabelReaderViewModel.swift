#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import Observation
import VinodexCore

/// What the label reader is doing, and everything the screen needs to draw it
/// (0.7.2, LR1).
///
/// **All of the feature's behaviour is here; `LabelReaderView` only draws.**
/// That split is the reason the view is readable at all — the alternative is a
/// SwiftUI body with a permission check, a picker presentation, an OCR call, a
/// five-stage progress sequence and a matcher invocation braided through it.
///
/// The recogniser arrives through the initialiser rather than being reached for
/// inside: swapping `VisionOCRProvider` for a future `OpenAIProvider` is a
/// change at the one call site that constructs this, and neither this class nor
/// the view learns anything about which one it got. See
/// `LabelRecognitionProvider`.
@MainActor
@Observable
public final class LabelReaderViewModel {

    /// The screen's four states, matching the spec's Loading / Success /
    /// Failure / No-Match.
    ///
    /// No-match is **not** a fifth case: it is a `LabelReading` whose
    /// `isConfident` is false, and it carries the same extracted text, the same
    /// suggestions and the same vintage as a confident one. Modelling it as a
    /// separate phase would mean two paths producing a result, and the no-match
    /// screen is the one that has historically been left behind.
    public enum Phase: Equatable {
        /// Nothing captured yet — the camera chooser.
        case idle
        /// Working, at a named stage.
        case processing(LabelReaderStage)
        /// A reading, confident or not.
        case result(LabelReading)
        /// Something went wrong before there was a reading.
        case failed(LabelReadError)
    }

    public private(set) var phase: Phase = .idle
    /// Set when the camera cannot be opened — shown inline rather than as a
    /// failure, because the library is still available and the screen should not
    /// look broken over a permission the user may have meant to withhold.
    public private(set) var cameraNotice: LabelReadError?
    /// Drives the camera sheet.
    public var showingCamera = false

    private let provider: any LabelRecognitionProvider
    private let service: LabelRecognitionService

    /// How long each stage is held on screen.
    ///
    /// The pipeline is genuinely staged — text recognition, then catalog search,
    /// then the inference walk — but on a modern phone the whole thing is well
    /// under a second, and five status lines flashing past faster than they can
    /// be read is worse than no status at all. This is the floor, not a delay
    /// added to real work: a stage that takes longer than this simply takes
    /// longer.
    static let stageDwell = Duration.milliseconds(420)

    public init(
        provider: any LabelRecognitionProvider = VisionOCRProvider(),
        service: LabelRecognitionService = .shared
    ) {
        self.provider = provider
        self.service = service
    }

    // MARK: - Capture

    /// Asks for the camera, then opens it — or explains why it cannot.
    public func requestCamera() async {
        guard CameraAvailability.hasCamera else {
            cameraNotice = .cameraUnavailable
            return
        }
        switch await CameraPermission.request() {
        case .granted:
            cameraNotice = nil
            showingCamera = true
        case .denied, .undetermined:
            // `.undetermined` after a request means the prompt was dismissed
            // without an answer, which for our purposes is a no.
            cameraNotice = .cameraDenied
        }
    }

    // MARK: - The pipeline

    /// Runs the whole read: OCR, then match, then infer.
    ///
    /// The stages are stepped explicitly rather than derived from where the work
    /// has got to, because the work does not report progress — Vision returns
    /// once, and `LabelRecognitionService.read` is a single synchronous pass. The
    /// honest description is that this narrates a pipeline whose shape is known
    /// in advance, which is what `LabelReaderStage` is: an ordered fact about
    /// the pipeline, kept in Core where it can be asserted.
    public func process(imageData: Data) async {
        cameraNotice = nil
        await stage(.reading)

        guard !imageData.isEmpty else {
            phase = .failed(.imageUnreadable)
            return
        }

        await stage(.recognizing)
        let strings: [RecognizedString]
        do {
            strings = try await provider.recognizeText(in: imageData)
        } catch let error as LabelReadError {
            phase = .failed(error)
            return
        } catch {
            phase = .failed(.recognitionFailed(error.localizedDescription))
            return
        }

        await stage(.searching)
        // Off the main actor: the fuzzy pass walks every catalog name for every
        // phrase on the label, and the progress bar is mid-animation.
        let name = provider.providerName
        let reading = await Task.detached(priority: .userInitiated) { [service] in
            service.read(strings, providerName: name)
        }.value

        // The last two stages narrate work that has already happened — the
        // matcher resolves place and grape in the same pass. They are here
        // because the spec names five stages and because "FINDING GRAPES…"
        // vanishing before it can be read would be the same defect as skipping
        // it. Nothing is recomputed.
        await stage(.findingRegions)
        await stage(.findingGrapes)

        phase = .result(reading)
        persist(reading)
    }

    /// Shows a stage and holds it long enough to be read.
    private func stage(_ stage: LabelReaderStage) async {
        phase = .processing(stage)
        try? await Task.sleep(for: Self.stageDwell)
    }

    /// Back to the chooser, dropping the held reading.
    ///
    /// Clears the stored state too: SCAN AGAIN means the previous result is
    /// gone, and leaving it in `ScreenStateStore` would resurrect it on the next
    /// navigation back into the screen.
    public func reset() {
        phase = .idle
        cameraNotice = nil
        ScreenStateStore.shared.forget(ScreenStateStore.labelReader)
    }

    // MARK: - Surviving the trip to an entry

    /// Restores the last reading, if the screen is being rebuilt rather than
    /// entered fresh.
    ///
    /// `RootView` has no `NavigationStack` — it swaps the LCD's content — so
    /// opening a suggested grape from the results destroys this screen outright.
    /// Without this, Back from that grape would land on the camera chooser and
    /// the user would have to photograph the bottle again. Same contract, same
    /// mechanism as the blind-tasting screen's criteria.
    public func restore() {
        guard case .idle = phase else { return }
        guard let reading = ScreenStateStore.shared.decoded(
            LabelReading.self, "reading", for: ScreenStateStore.labelReader
        ) else { return }
        phase = .result(reading)
    }

    private func persist(_ reading: LabelReading) {
        ScreenStateStore.shared.encode(reading, "reading", for: ScreenStateStore.labelReader)
    }
}
#endif

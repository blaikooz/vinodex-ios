#if canImport(SwiftUI) && canImport(UIKit)
import AVFoundation
import SwiftUI
import UIKit
import VinodexCore
import Vision

/// On-device text recognition (0.7.2, LR1).
///
/// **This file is the iOS-only half of the label reader and it is deliberately
/// thin.** Vision cannot run on the Linux CI, so everything it touches is
/// quarantined here behind `LabelRecognitionProvider`; the matching, scoring and
/// inference the feature actually reasons with live in `VinodexCore` and are
/// gated by `swift test`. If this file grows a rule about *wine*, that rule is
/// in the wrong module.
///
/// No network, no API key, no account: `VNRecognizeTextRequest` is a system
/// framework doing the work on the phone, which is the constraint the feature
/// was specified under.
public struct OCRService: Sendable {
    /// Languages worth asking for, in preference order.
    ///
    /// Wine labels are overwhelmingly Latin-script and the catalog's countries
    /// are French, Italian, Spanish, Portuguese and German before they are
    /// anything else. The list is intersected with what the running OS actually
    /// supports before it is applied — Vision *throws* on an unsupported
    /// language rather than ignoring it, and the supported set has changed
    /// between OS versions, so asking blind is a crash waiting for a user on an
    /// older device.
    public static let preferredLanguages = [
        "en-US", "fr-FR", "it-IT", "es-ES", "pt-BR", "de-DE",
    ]

    public init() {}

    /// Every string Vision found, largest text first.
    ///
    /// - `accurate` rather than `fast`: a label is one still photograph the user
    ///   has already waited for, and the fast path drops accents and small caps
    ///   — which on a wine label is most of the useful text.
    /// - Language correction **on**: it is what turns `CHATEAUNEUE` back into
    ///   something the matcher can fold onto `Châteauneuf`.
    /// - `minimumTextHeight` left at the default: back-label small print is
    ///   where the grape is often stated.
    /// - **Every** observation is kept, not the top one. The producer, the
    ///   appellation and the vintage are three different lines, and the matcher
    ///   scans across all of them.
    ///
    /// Sorted by descending height so that if a consumer ever does take a
    /// prefix, it takes the biggest text rather than whatever order Vision
    /// happened to return.
    public func recognize(imageData: Data) async throws -> [RecognizedString] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if let supported = try? request.supportedRecognitionLanguages() {
            let wanted = Self.preferredLanguages.filter { supported.contains($0) }
            if !wanted.isEmpty { request.recognitionLanguages = wanted }
        }

        let handler = VNImageRequestHandler(data: imageData, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw LabelReadError.recognitionFailed(error.localizedDescription)
        }

        guard let observations = request.results else { return [] }
        return observations
            .compactMap { observation -> RecognizedString? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return RecognizedString(
                    text: text,
                    confidence: Double(candidate.confidence),
                    // The observation box is normalised to the image already, so
                    // this is the fraction of the bottle's height the line
                    // occupies — which is what `LabelTextScan.producerGuess`
                    // means by prominence.
                    prominence: Double(observation.boundingBox.height)
                )
            }
            .sorted { $0.prominence > $1.prominence }
    }
}

/// The shipping `LabelRecognitionProvider`.
///
/// **The extension point.** Swapping recognisers is one line at the
/// `LabelReaderViewModel` initialiser — a hypothetical
/// `OpenAIProvider: LabelRecognitionProvider` or `GoogleVisionProvider` would
/// implement the same single method against the same `Data`, and neither
/// `LabelReaderView` nor `LabelRecognitionService` would change by a character.
/// That is why the protocol takes encoded bytes rather than a `UIImage`: a
/// remote provider wants exactly those bytes, and Core cannot see UIKit anyway.
///
/// It is also why the default stays here and not in Core. The product decision —
/// on-device only, no paid AI APIs — is a decision about which provider is
/// *installed*, and it belongs at the composition root rather than inside a
/// module that would then have to be edited to reverse it.
public struct VisionOCRProvider: LabelRecognitionProvider {
    public let providerName = "Apple Vision"
    private let service = OCRService()

    public init() {}

    public func recognizeText(in imageData: Data) async throws -> [RecognizedString] {
        try await service.recognize(imageData: imageData)
    }
}

// MARK: - Camera permission

/// The camera's authorisation state, in the three shapes the screen cares about.
///
/// `restricted` and `denied` collapse into one case on purpose: the screen's
/// answer to both is the same — explain, and offer the photo library instead —
/// and a user under a restriction cannot act on being told which of the two it
/// was.
public enum CameraPermission: Sendable {
    case granted
    case denied
    case undetermined

    public static var current: CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .undetermined
        default: .denied
        }
    }

    /// Prompts if the user has not been asked, otherwise reports what they said.
    public static func request() async -> CameraPermission {
        switch current {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        }
    }
}

// MARK: - Camera capture

/// `UIImagePickerController` in a SwiftUI wrapper, for the camera only.
///
/// A picker rather than a hand-built `AVCaptureSession` preview: the tool needs
/// one still photograph, and the system camera already provides framing, focus,
/// flash, a retake step and the rotation handling that a bespoke preview would
/// have to reimplement — inside an app that is portrait-locked at the delegate
/// (see `AppDelegate`), which is exactly where a custom capture layer goes
/// wrong. The library side does **not** use this: `PhotosPicker` runs
/// out-of-process and needs no library permission at all, which is the better
/// trade there.
///
/// Hands back JPEG `Data` rather than a `UIImage` because that is what
/// `LabelRecognitionProvider` takes — see the note there.
struct CameraCapture: UIViewControllerRepresentable {
    /// Quality of the JPEG handed to Vision.
    ///
    /// 0.9 rather than 1.0: the recogniser is reading printed type, JPEG
    /// artefacts at 0.9 are well below the size of a serif, and the difference
    /// is a couple of megabytes crossing an `async` boundary on the main thread's
    /// watch.
    static let jpegQuality: CGFloat = 0.9

    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        // **No crop step.** A tighter frame really would help the matcher —
        // less background text to fold into phrases — but it costs a mandatory
        // extra tap on every single scan, and the flow this tool is for is
        // "point at the bottle in front of you". Vision handles a label that
        // fills half the frame perfectly well; a user who wants a tight crop
        // can take the photo first and come in through the library.
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (Data) -> Void
        private let onCancel: () -> Void

        init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // `.originalImage` is the only key populated, because
            // `allowsEditing` is off above. `.editedImage` is read first anyway
            // so that flipping that one line is the whole change if the crop
            // step is ever wanted — not so that it silently does nothing today.
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            guard let data = image?.jpegData(compressionQuality: CameraCapture.jpegQuality) else {
                onCancel()
                return
            }
            onCapture(data)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

/// Whether this device can take a photograph at all.
///
/// False in the simulator, which is the case that matters during development —
/// the screen offers the library instead rather than presenting a picker that
/// comes up black.
enum CameraAvailability {
    /// `@MainActor` because `UIImagePickerController` is: in Swift 6 mode a
    /// nonisolated static reaching a MainActor class method is an error, not a
    /// warning, and CI compiles in Swift 6 mode. Costs nothing — the only
    /// caller, `LabelReaderViewModel.requestCamera()`, is already on the main
    /// actor, as anything about to present a picker has to be.
    @MainActor
    static var hasCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
#endif

import SwiftUI
import UIKit

/// Data to pre-fill in AddRecordView
struct PrefilledFuelData {
    var gallons: Double?
    var pricePerGallon: Double?
    var totalCost: Double?
}

/// Main view for AI-powered receipt scanning
struct AIReceiptScannerView: View {
    let vehicle: Vehicle
    let onComplete: (PrefilledFuelData) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var processingStatus = "Initializing..."
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var debugLog: [String] = []

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessing {
                    // Processing view
                    ProcessingView(status: processingStatus, debugLog: debugLog)
                } else if let image = capturedImage {
                    // Show captured image with retry option
                    CapturedImageView(
                        image: image,
                        onRetake: {
                            capturedImage = nil
                            debugLog = []
                        },
                        onProcess: {
                            Task {
                                await processImage(image)
                            }
                        }
                    )
                } else {
                    // Initial state - prompt to take photo
                    InitialPromptView(
                        isCameraAvailable: isCameraAvailable,
                        onTakePhoto: {
                            if isCameraAvailable {
                                showingCamera = true
                            } else {
                                showingPhotoLibrary = true
                            }
                        },
                        onChoosePhoto: {
                            showingPhotoLibrary = true
                        }
                    )
                }
            }
            .padding()
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(image: $capturedImage, sourceType: .photoLibrary)
                    .ignoresSafeArea()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    errorMessage = nil
                }
                Button("Try Again") {
                    capturedImage = nil
                    debugLog = []
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .onChange(of: capturedImage) { _, newImage in
                if newImage != nil {
                    // Auto-process when image is captured
                    Task {
                        await processImage(newImage!)
                    }
                }
            }
            .onAppear {
                // Check if API key is configured
                if !LLMService.shared.hasAnyAPIKey {
                    errorMessage = "No AI API key configured. Please add your Claude or ChatGPT API key in Settings."
                    showingError = true
                }
            }
        }
    }

    private func addLog(_ message: String) {
        print("[AIScanner] \(message)")
        DispatchQueue.main.async {
            debugLog.append(message)
        }
    }

    private func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        debugLog = []

        addLog("Starting image processing...")
        addLog("Image size: \(Int(image.size.width))x\(Int(image.size.height))")

        do {
            // Step 1: OCR
            processingStatus = "Extracting text from image..."
            addLog("Starting OCR...")

            let ocrText = try await OCRService.shared.recognizeText(from: image)

            addLog("OCR completed. Text length: \(ocrText.count) chars")
            addLog("--- OCR Text ---")
            addLog(ocrText)
            addLog("--- End OCR ---")

            // Step 2: LLM parsing
            processingStatus = "Analyzing receipt with AI..."
            addLog("Sending to LLM...")

            let result = try await LLMService.shared.parseFuelReceipt(ocrText: ocrText)

            addLog("LLM response received (\(result.tokenUsage.provider)):")
            addLog("  Input tokens: \(result.tokenUsage.inputTokens)")
            addLog("  Output tokens: \(result.tokenUsage.outputTokens)")
            addLog("  Total tokens: \(result.tokenUsage.totalTokens)")
            addLog("Parsed data:")
            addLog("  gallons: \(result.receiptData.gallons?.description ?? "nil")")
            addLog("  pricePerGallon: \(result.receiptData.pricePerGallon?.description ?? "nil")")
            addLog("  totalCost: \(result.receiptData.totalCost?.description ?? "nil")")

            // Step 3: Return data
            isProcessing = false

            let prefilledData = PrefilledFuelData(
                gallons: result.receiptData.gallons,
                pricePerGallon: result.receiptData.pricePerGallon,
                totalCost: result.receiptData.totalCost
            )

            addLog("Processing complete. Returning data...")

            dismiss()
            onComplete(prefilledData)

        } catch {
            addLog("ERROR: \(error.localizedDescription)")
            isProcessing = false
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Supporting Views

struct ProcessingView: View {
    let status: String
    let debugLog: [String]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(2)
                .tint(.teal)

            Text(status)
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("Please wait...")
                .font(.custom("Avenir Next", size: 14))
                .foregroundColor(.secondary.opacity(0.7))

            // Debug log view
            if !debugLog.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(debugLog.enumerated()), id: \.offset) { _, log in
                            Text(log)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .frame(maxHeight: 150)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
            }

            Spacer()
        }
    }
}

struct InitialPromptView: View {
    let isCameraAvailable: Bool
    let onTakePhoto: () -> Void
    let onChoosePhoto: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Scan Your Receipt")
                .font(.custom("Avenir Next", size: 24))
                .fontWeight(.bold)

            Text("Take a photo of your fuel receipt and AI will automatically extract the details.")
                .font(.custom("Avenir Next", size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                if isCameraAvailable {
                    Button(action: onTakePhoto) {
                        Label("Take Photo", systemImage: "camera.fill")
                            .font(.custom("Avenir Next", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.teal, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button(action: onChoosePhoto) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .font(.custom("Avenir Next", size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(isCameraAvailable ? .teal : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            isCameraAvailable
                                ? AnyShapeStyle(Color.teal.opacity(0.1))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [.teal, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)

            Spacer()
        }
    }
}

struct CapturedImageView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onProcess: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 400)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5)

            HStack(spacing: 16) {
                Button(action: onRetake) {
                    Label("Retake", systemImage: "camera")
                        .font(.custom("Avenir Next", size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.teal)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: onProcess) {
                    Label("Process", systemImage: "sparkles")
                        .font(.custom("Avenir Next", size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.teal, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

// MARK: - Image Picker (Camera)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    AIReceiptScannerView(vehicle: Vehicle(name: "Test Car")) { _ in }
}

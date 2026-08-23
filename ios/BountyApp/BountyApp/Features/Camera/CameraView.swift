import SwiftUI
import AVFoundation
import CoreLocation

struct CameraView: View {
    @ObservedObject private var lang = LanguageManager.shared
    @StateObject private var vm = CameraViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var note = ""
    var taskID: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    CameraPreview(session: vm.session)
                        .ignoresSafeArea()

                    VStack {
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Circle().fill(.black.opacity(0.4)))
                            }
                            Spacer()
                            Text(L10n.taskEvidence)
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Color.clear.frame(width: 40, height: 40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 50)

                        Spacer()

                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String(format: L10n.cameraTimestampFmt, L10n.cameraTimestamp, Date().formatMedium()))
                                Text(String(format: L10n.cameraGpsFmt, L10n.cameraGPS, "\(String(format: "%.5f", vm.currentLat)), \(String(format: "%.5f", vm.currentLng))"))
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(.black.opacity(0.5))
                            .cornerRadius(6)
                            .padding(.trailing, 16)
                        }
                        .padding(.bottom, 20)
                    }
                }

                VStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(vm.capturedImages.enumerated()), id: \.offset) { idx, img in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button(action: { vm.removeImage(at: idx) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.white)
                                            .background(Circle().fill(.red))
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 70)

                    TextField(L10n.reviewNotes, text: $note)
                        .font(.system(size: 14))
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)

                    HStack(spacing: 40) {
                        Spacer()
                        Button(action: { vm.capturePhoto() }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 72, height: 72)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                            }
                        }
                        Spacer()
                    }

                    if !vm.capturedImages.isEmpty {
                        Button(L10n.taskSubmitEvidence + " (\(vm.capturedImages.count)/3)") {
                            vm.submit(taskID: taskID, note: note) { dismiss() }
                        }
                        .bountyButton()
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
                .background(.black.opacity(0.9))
            }
        }
        .onAppear { vm.setupCamera() }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        guard let session = session else { return view }
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class CameraViewModel: ObservableObject {
    @Published var capturedImages: [UIImage] = []
    @Published var currentLat: Double = 39.9042
    @Published var currentLng: Double = 116.4074
    @Published var session: AVCaptureSession?

    private let locationManager = CLLocationManager()
    private var photoOutput = AVCapturePhotoOutput()

    func setupCamera() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        if let loc = locationManager.location?.coordinate {
            currentLat = loc.latitude
            currentLng = loc.longitude
        }

        let session = AVCaptureSession()
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        session.addOutput(photoOutput)
        DispatchQueue.global().async { session.startRunning() }
        self.session = session
    }

    func capturePhoto() {
        guard capturedImages.count < 3 else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: PhotoDelegate { [weak self] img in
            DispatchQueue.main.async { self?.capturedImages.append(img) }
        })
    }

    func removeImage(at index: Int) {
        capturedImages.remove(at: index)
    }

    func submit(taskID: String, note: String, onSuccess: @escaping () -> Void) {
        Task {
            let photos = capturedImages.map { _ in
                ["url": "https://placeholder.jpg", "latitude": currentLat, "longitude": currentLng, "timestamp": Date().ISO8601Format()] as [String: Any]
            }
            let body: [String: Any] = [
                "task_id": taskID,
                "photos": photos,
                "note": note.isEmpty ? nil : note,
                "submit_lat": currentLat,
                "submit_lng": currentLng
            ]
            let _ = try? await APIClient.shared.request(
                "/tasks/\(taskID)/submit",
                method: "POST",
                body: body
            ) as APIResponse<EmptyResponse>
            await MainActor.run { onSuccess() }
        }
    }
}

class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage) -> Void
    init(completion: @escaping (UIImage) -> Void) { self.completion = completion }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let img = UIImage(data: data) else { return }
        completion(img)
    }
}

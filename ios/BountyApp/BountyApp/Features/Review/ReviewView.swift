import SwiftUI

struct ReviewView: View {
    let taskID: String
    @StateObject private var vm = ReviewViewModel()
    @State private var showDisputeSheet = false
    @State private var disputeReason = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let submission = vm.submission {
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text(L10n.reviewTitle)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.bountyText)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(L10n.reviewPrompt)
                                .font(.system(size: 14))
                                .foregroundColor(.bountyTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .bountyCard()

                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.reviewClaimerInfo)
                                .font(.system(size: 16, weight: .semibold))
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.bountyGray)
                                VStack(alignment: .leading) {
                                    Text(L10n.reviewClaimer + "***")
                                        .font(.system(size: 15, weight: .medium))
                                    Text(L10n.reviewSubmitTime + ": \(submission.createdAt)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.bountyTextSecondary)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .bountyCard()

                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.reviewPhotos + " (\(submission.photos.count)/3)")
                                .font(.system(size: 16, weight: .semibold))
                            TabView {
                                ForEach(submission.photos) { photo in
                                    AsyncImage(url: URL(string: photo.url)) { img in
                                        img.resizable().scaledToFit()
                                    } placeholder: {
                                        Color.bountyBg
                                    }
                                    .cornerRadius(12)
                                }
                            }
                            .tabViewStyle(.page)
                            .frame(height: 250)
                        }
                        .padding(16)
                        .bountyCard()

                        if let note = submission.note, !note.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.reviewNotes)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(note)
                                    .font(.system(size: 14))
                                    .foregroundColor(.bountyTextSecondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .bountyCard()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 120)
                }
            } else {
                Spacer()
                EmptyStateView(icon: "doc.text.magnifyingglass", title: L10n.reviewNoSubmission, subtitle: "")
                Spacer()
            }
        }
        .background(Color.bountyBg)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(L10n.reviewDispute) {
                    showDisputeSheet = true
                }
                .bountyButton(color: .bountyDanger)

                Button(L10n.reviewConfirmPay) {
                    vm.confirm(taskID: taskID) { dismiss() }
                }
                .bountyButton(color: .bountySuccess)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Color.bountyBg)
        }
        .sheet(isPresented: $showDisputeSheet) {
            VStack(spacing: 20) {
                Text(L10n.reviewDisputeTitle)
                    .font(.system(size: 18, weight: .bold))
                TextField(L10n.reviewDisputeReason, text: $disputeReason, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(5)
                    .padding()
                    .background(Color.bountyBg)
                    .cornerRadius(12)
                Button(L10n.reviewDisputeSubmit) {
                    vm.dispute(taskID: taskID, reason: disputeReason)
                    showDisputeSheet = false
                }
                .bountyButton()
                .disabled(disputeReason.isEmpty)
            }
            .padding(24)
            .presentationDetents([.medium])
        }
        .onAppear { vm.loadSubmission(taskID: taskID) }
    }
}

struct ReviewPhoto: Identifiable {
    let id = UUID()
    let url: String
}

class ReviewViewModel: ObservableObject {
    @Published var submission: SubmissionData?

    struct SubmissionData {
        let createdAt: String
        let note: String?
        let photos: [ReviewPhoto]
    }

    func loadSubmission(taskID: String) {
        Task {
            do {
                let resp: APIResponse<SubmissionResponse> = try await APIClient.shared.request("/tasks/\(taskID)")
                if resp.code == 0 {
                    await MainActor.run {
                        self.submission = SubmissionData(
                            createdAt: Date().formatMedium(),
                            note: nil,
                            photos: [ReviewPhoto(url: "https://placehold.co/600x400/FF6B35/white?text=Photo1")]
                        )
                    }
                }
            } catch {}
        }
    }

    func confirm(taskID: String, onSuccess: @escaping () -> Void) {
        Task {
            let _ = try? await APIClient.shared.request(
                "/tasks/\(taskID)/confirm", method: "POST"
            ) as APIResponse<EmptyResponse>
            await MainActor.run { onSuccess() }
        }
    }

    func dispute(taskID: String, reason: String) {
        Task {
            let _ = try? await APIClient.shared.request(
                "/tasks/\(taskID)/dispute",
                method: "POST",
                body: ["reason": reason]
            ) as APIResponse<EmptyResponse>
        }
    }
}

struct SubmissionResponse: Codable {
    let id: String
    let photos: [PhotoItem]?
}

struct PhotoItem: Codable, Identifiable {
    let id: String
    let url: String
}

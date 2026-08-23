import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var lang = LanguageManager.shared
    @State private var selectedTab = 0

    /// Privacy consent is driven directly by the persistent UserDefault so that
    /// tapping "Agree" (which writes the same key via @AppStorage) actually
    /// dismisses the full-screen cover instead of it re-presenting forever.
    @AppStorage("hasAcceptedPrivacyPolicy") private var hasAcceptedPrivacyPolicy = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景铺满整个物理屏幕，消除刘海/Home Indicator 区域黑边
            Color.bountyBg
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                SquareView()
                    .tabItem {
                        Image(systemName: "mappin.and.ellipse")
                        Text(L10n.tabSquare)
                    }
                    .tag(0)

                MyTasksView()
                    .tabItem {
                        Image(systemName: "list.clipboard")
                        Text(L10n.tabMyTasks)
                    }
                    .tag(1)

                MessagesView()
                    .tabItem {
                        Image(systemName: "bell.badge")
                        Text(L10n.tabMessages)
                    }
                    .tag(2)

                ProfileView()
                    .tabItem {
                        Image(systemName: "person.circle")
                        Text(L10n.tabProfile)
                    }
                    .tag(3)
            }
            .tint(.bountyGold)
            .toolbarBackground(Color.bountyBg, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)

            VStack {
                Spacer()
                Button(action: {
                    if appState.isLoggedIn {
                        appState.showPublishSheet = true
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(Color.bountyGold)
                                .shadow(color: .bountyGold.opacity(0.5), radius: 8, x: 0, y: 4)
                        )
                }
                .accessibilityIdentifier("publishPlusButton")
                .offset(y: -10)
            }

            if appState.showToast {
                ToastView(message: appState.toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $appState.showPublishSheet) {
            PublishView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { !hasAcceptedPrivacyPolicy },
            set: { presented in
                if !presented { hasAcceptedPrivacyPolicy = true }
            }
        )) {
            PrivacyConsentView()
        }
    }
}

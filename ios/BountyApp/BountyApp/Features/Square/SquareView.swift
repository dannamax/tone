import SwiftUI

struct SquareView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var lang = LanguageManager.shared
    @StateObject private var vm = SquareViewModel()
    @State private var selectedRadius = 0
    @State private var selectedSort = "distance"
    @State private var hasLocatedOnce = false
    let radii = [0, 1000, 3000, 5000]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SquareHeader()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                RadiusFilterBar(radii: radii, selected: $selectedRadius)
                    .padding(.vertical, 8)

                SortFilterBar(selected: $selectedSort)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)

                if appState.userLat == 0 && appState.userLng == 0 && !hasLocatedOnce {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text(L10n.squareLocating).font(.system(size: 12)).foregroundColor(.bountyTextSecondary)
                    }
                    .padding(.vertical, 6)
                }

                content
            }
            .background(Color.bountyBg)
            .onAppear {
                // 首屏先尝试用已知坐标拉一次（无坐标时后端返回全部），随后定位到了再刷新
                Task { await vm.refresh(lat: appState.userLat, lng: appState.userLng, radius: selectedRadius, sort: selectedSort) }
            }
            .onChange(of: selectedRadius) { newVal in
                Task { await vm.refresh(lat: appState.userLat, lng: appState.userLng, radius: newVal, sort: selectedSort) }
            }
            .onChange(of: selectedSort) { newVal in
                Task { await vm.refresh(lat: appState.userLat, lng: appState.userLng, radius: selectedRadius, sort: newVal) }
            }
            .onChange(of: appState.refreshSquareTrigger) { _ in
                Task { await vm.refresh(lat: appState.userLat, lng: appState.userLng, radius: selectedRadius, sort: selectedSort) }
            }
            .onChange(of: appState.userLat) { lat in
                // 定位成功且之前未用真实坐标刷新过，则按真实距离动态刷新列表
                guard lat != 0, !hasLocatedOnce else { return }
                hasLocatedOnce = true
                Task { await vm.refresh(lat: lat, lng: appState.userLng, radius: selectedRadius, sort: selectedSort) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in SkeletonCard() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            Spacer()
        } else if vm.tasks.isEmpty {
            Spacer()
            EmptyStateView(
                icon: "magnifyingglass",
                title: L10n.squareEmpty,
                subtitle: L10n.squareEmptyHint,
                actionLabel: L10n.squarePublishAction,
                action: { appState.showPublishSheet = true }
            )
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.tasks) { task in
                        NavigationLink {
                            TaskDetailView(taskID: task.id)
                        } label: {
                            TaskCardView(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .refreshable { await vm.refresh(lat: appState.userLat, lng: appState.userLng, radius: selectedRadius, sort: selectedSort) }
        }
    }
}

private struct SquareHeader: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.squareTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.bountyText)
                Text(L10n.squareSubtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.bountyTextSecondary)
            }
            Spacer()
        }
    }
}

private struct RadiusFilterBar: View {
    let radii: [Int]
    @Binding var selected: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(radii, id: \.self) { r in
                    RadiusChip(title: r == 0 ? L10n.squareFilterAll : "\(r/1000)km " + L10n.squareFilterWithin, isSelected: selected == r) {
                        withAnimation { selected = r }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

private struct RadiusChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .bountyTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.bountyGold : Color.white)
                )
                .overlay(
                    Capsule().strokeBorder(Color.bountyBg, lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

/// 任务广场排序切换：距离最近 / 赏金最多 / 最新发布
private struct SortFilterBar: View {
    @Binding var selected: String

    private let options: [(key: String, icon: String)] = [
        ("distance", "location.fill"),
        ("beans", "circle.circle.fill"),
        ("newest", "clock.fill"),
    ]

    private var titles: [String: String] {
        [
            "distance": L10n.squareSortDistance,
            "beans": L10n.squareSortBeans,
            "newest": L10n.squareSortNewest,
        ]
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.key) { opt in
                Button {
                    withAnimation { selected = opt.key }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 11))
                        Text(titles[opt.key] ?? opt.key)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(selected == opt.key ? .white : .bountyTextSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(selected == opt.key ? Color.bountyGold : Color.white)
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.bountyBg, lineWidth: selected == opt.key ? 0 : 1)
                    )
                }
            }
            Spacer()
        }
    }
}

class SquareViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var isLoading = true
    private var currentPage = 1
    private var hasMore = true

    func refresh(lat: Double, lng: Double, radius: Int, sort: String = "distance") async {
        await MainActor.run { isLoading = true }

        do {
            let resp: APIResponse<PaginatedResponse<TaskItem>> = try await APIClient.shared.request(
                "/tasks/square?lat=\(lat)&lng=\(lng)&radius=\(radius)&sort=\(sort)&page=1&size=20"
            )
            if resp.code == 0, let data = resp.data {
                await MainActor.run {
                    tasks = data.items
                    hasMore = data.page < data.totalPages
                    currentPage = 1
                }
            }
        } catch {
            print("Square load error: \(error)")
        }

        await MainActor.run { isLoading = false }
    }
}

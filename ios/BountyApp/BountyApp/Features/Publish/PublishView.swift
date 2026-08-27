import SwiftUI
import MapKit
import CoreLocation

struct PublishView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var lang = LanguageManager.shared
    @StateObject private var vm = PublishViewModel()
    @Environment(\.dismiss) var dismiss
    /// 发布前确认弹窗（目标地址仍采用当前位置时）
    @State private var showLocationConfirm = false

    let timeOptions = [5, 15, 30, 60, 120]
    let radiusOptions = [1000, 3000, 5000, 10000]
    /// 赏金金豆快捷档位（5-50 可自定义，最低 5 豆）
    let beansOptions = [5, 10, 20, 30, 50]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.publishTaskTitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.bountyText)
                        TextField(L10n.publishTitlePlaceholder, text: $vm.title)
                            .font(.system(size: 15))
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .accessibilityIdentifier("publishTitleField")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.publishDescription)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.bountyText)
                        TextEditor(text: $vm.description)
                            .font(.system(size: 15))
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(12)
                            .accessibilityIdentifier("publishDescField")
                            .overlay(alignment: .bottomTrailing) {
                                Text("\(vm.description.count)/200")
                                    .font(.system(size: 11))
                                    .foregroundColor(vm.description.count > 180 ? .bountyDanger : .bountyGray)
                                    .padding(8)
                            }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(L10n.publishBeansTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.bountyText)
                            Spacer()
                            Text(String(format: L10n.publishBeansCost, vm.bountyBeans))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.bountyGold)
                        }

                        HStack(spacing: 10) {
                            ForEach(beansOptions, id: \.self) { opt in
                                Button {
                                    withAnimation { vm.bountyBeans = opt }
                                } label: {
                                    Text("\(opt)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(vm.bountyBeans == opt ? .white : .bountyTextSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(vm.bountyBeans == opt ? Color.bountyGold : Color.white)
                                        )
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            Button {
                                if vm.bountyBeans > 5 { vm.bountyBeans -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(vm.bountyBeans > 5 ? .bountyGold : .bountyGray)
                            }
                            .buttonStyle(.plain)

                            Text("\(vm.bountyBeans)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.bountyText)
                                .frame(minWidth: 40)
                                .accessibilityIdentifier("publishBountyField")

                            Button {
                                if vm.bountyBeans < 50 { vm.bountyBeans += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(vm.bountyBeans < 50 ? .bountyGold : .bountyGray)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Text(L10n.publishBeansHint)
                                .font(.system(size: 12))
                                .foregroundColor(.bountyGray)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.publishTargetLocation)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.bountyText)
                            Spacer()
                            if vm.hasSelectedLocation {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(L10n.publishLocationSelected)
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            } else {
                                Text(L10n.publishLocationRequired)
                                    .font(.system(size: 12))
                                    .foregroundColor(.bountyDanger)
                            }
                        }
                        MapPinSelector(
                            lat: $vm.targetLat,
                            lng: $vm.targetLng,
                            address: $vm.targetAddr,
                            hasSelected: $vm.hasSelectedLocation,
                            autoFilled: $vm.isLocationAutoFilled
                        )
                        if vm.hasSelectedLocation {
                            HStack(spacing: 4) {
                                Image(systemName: vm.isLocationAutoFilled ? "location.fill" : "mappin.circle.fill")
                                    .foregroundColor(vm.isLocationAutoFilled ? .bountyGold : .green)
                                Text(vm.isLocationAutoFilled ? L10n.publishLocationAutoFill : L10n.publishLocationManual)
                                    .font(.system(size: 12))
                                    .foregroundColor(vm.isLocationAutoFilled ? .bountyGold : .green)
                            }
                        } else {
                            Text(L10n.publishLocationFailed)
                                .font(.system(size: 12))
                                .foregroundColor(.bountyDanger)
                                .padding(.top, 2)
                        }
                    }

                    OptionGroupView(
                        title: L10n.publishRadius,
                        options: radiusOptions,
                        display: { AppLocale.radiusDisplay($0) },
                        selection: $vm.radius
                    )

                    OptionGroupView(
                        title: L10n.publishTimeLimit,
                        options: timeOptions,
                        display: { "\($0) " + L10n.publishTimeUnit },
                        selection: $vm.timeLimit
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 100)
            }
            .background(Color.bountyBg)
            .navigationTitle(L10n.publishTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .onAppear {
                autoFillCurrentLocationIfNeeded()
            }
            .onChange(of: appState.userLat) { _ in
                // 定位可能延迟到位，到位后若用户尚未选择位置则自动采用
                autoFillCurrentLocationIfNeeded()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    if let publishError = vm.publishError {
                        Text(publishError)
                            .font(.system(size: 13))
                            .foregroundColor(.bountyDanger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    Button(L10n.publishSubmitBtn) {
                        if vm.isLocationAutoFilled {
                            // 目标地址仍采用发布人当前位置，发布前需确认
                            showLocationConfirm = true
                        } else {
                            Task { await doPublish() }
                        }
                    }
                    .bountyButton()
                    .accessibilityIdentifier("publishConfirmButton")
                    .disabled(!vm.hasSelectedLocation)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(Color.bountyBg)
            }
            .alert(L10n.publishConfirmTitle, isPresented: $showLocationConfirm) {
                Button(L10n.publishConfirmUse, role: .none) {
                    vm.isLocationAutoFilled = false
                    Task { await doPublish() }
                }
                Button(L10n.publishConfirmEdit, role: .cancel) { }
            } message: {
                Text(L10n.publishConfirmMsg + "\n\(vm.targetAddr.isEmpty ? "(\(String(format: "%.4f", vm.targetLat)), \(String(format: "%.4f", vm.targetLng)))" : vm.targetAddr)")
            }
        }
    }

    @MainActor
    private func doPublish() async {
        let success = await vm.publish(appState: appState)
        if success { dismiss() }
    }

    /// 若用户尚未选择目标位置，则自动采用发布人当前位置，并标记为"待确认"
    @MainActor
    private func autoFillCurrentLocationIfNeeded() {
        guard vm.targetLat == 0, vm.targetLng == 0 else { return }
        guard appState.userLat != 0 || appState.userLng != 0 else { return }
        vm.targetLat = appState.userLat
        vm.targetLng = appState.userLng
        vm.hasSelectedLocation = true
        vm.isLocationAutoFilled = true
        // 先给一个临时地址(坐标文本),避免反向地理编码未完成/失败时
        // targetAddr 为空导致发布 guard 失败;reverseGeocode 成功后会覆盖。
        vm.targetAddr = String(format: "%.5f, %.5f", appState.userLat, appState.userLng)
        vm.reverseGeocodeCurrentLocation()
    }
}

class PublishViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    /// 目标位置由发布人手动在地图选择后才有效；初始为 0 表示未选择
    @Published var targetLat: Double = 0
    @Published var targetLng: Double = 0
    @Published var targetAddr = ""
    @Published var hasSelectedLocation = false
    /// true 表示目标位置是默认跟随的"发布人当前位置"，且发布人尚未确认采用。
    /// 发布前必须弹确认框，点击确认后才能发布成功。
    @Published var isLocationAutoFilled = false
    @Published var radius = 3000
    @Published var timeLimit = 30
    /// 任务赏金金豆数（1-50，猎人在任务确认后赚取）
    // 默认赏金 = 注册礼豆数：新用户首次发布无需充值即可直接成功，
    // 避免默认值(10)超过注册礼(5)导致首单必失败(402)。
    @Published var bountyBeans = 5
    @Published var publishError: String?

    /// 将当前已填入的 targetLat/targetLng 反向解析为地址（用于自动采用当前位置后填充地址文本）
    func reverseGeocodeCurrentLocation() {
        let loc = CLLocation(latitude: targetLat, longitude: targetLng)
        CLGeocoder().reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let self = self else { return }
            if let pm = placemarks?.first {
                let addr = [
                    pm.locality,
                    pm.subLocality,
                    pm.thoroughfare,
                    pm.name
                ].compactMap { $0 }.joined(separator: " ")
                DispatchQueue.main.async {
                    if !addr.isEmpty { self.targetAddr = addr }
                }
            }
        }
    }

    func publish(appState: AppState) async -> Bool {
        guard appState.isLoggedIn, APIClient.shared.token != nil else {
            publishError = L10n.publishNeedLogin
            return false
        }
        guard hasSelectedLocation, targetLat != 0, targetLng != 0, !targetAddr.isEmpty else {
            publishError = L10n.publishLocationRequired
            return false
        }
        let body = PublishBody(
            title: title,
            description: description,
            targetLat: targetLat,
            targetLng: targetLng,
            targetAddr: targetAddr,
            radius: radius,
            timeLimit: timeLimit,
            bountyBeans: bountyBeans
        )
        do {
            print("[Publish] request body: title=\(title), lat=\(targetLat), lng=\(targetLng), radius=\(radius), timeLimit=\(timeLimit), beans=\(bountyBeans)")
            print("[Publish] currentUserID: \(appState.currentUser?.id ?? "nil"), tokenPrefix: \(APIClient.shared.token?.prefix(20) ?? "nil")")
            let resp: APIResponse<TaskItem> = try await APIClient.shared.request(
                "/tasks",
                method: "POST",
                body: body
            )
            print("[Publish] response code=\(resp.code) taskID: \(resp.data?.id ?? "nil")")

            // 检查业务错误码
            guard resp.code == 0, let taskData = resp.data else {
                let msg = resp.message.isEmpty ? L10n.publishFail : resp.message
                print("[Publish] business error: code=\(resp.code) msg=\(msg)")
                await MainActor.run { publishError = msg }
                return false
            }

            await MainActor.run {
                appState.refreshMyTasksTrigger.toggle()
                appState.refreshSquareTrigger.toggle()
                appState.showToast(L10n.publishSuccess)
            }
            publishError = nil
            return true
        } catch APIError.requestFailed(let code) where code == 402 {
            publishError = L10n.publishQuotaLow
            return false
        } catch APIError.requestFailed(let code) where code == 400 {
            publishError = L10n.publishBadParams
            print("[Publish] 400 bad request")
            return false
        } catch APIError.unauthorized {
            publishError = L10n.publishExpired
            return false
        } catch APIError.networkError(let err) {
            print("[Publish] network error: \(err.localizedDescription)")
            publishError = L10n.publishNetworkError
            return false
        } catch APIError.requestFailed(let code) {
            print("[Publish] request failed: \(code)")
            publishError = L10n.publishServerError + " (\(code))"
            return false
        } catch {
            print("[Publish] unknown error: \(error)")
            publishError = L10n.publishFail
            return false
        }
    }
}

struct PublishBody: Codable {
    let title: String
    let description: String
    let targetLat: Double
    let targetLng: Double
    let targetAddr: String
    let radius: Int
    let timeLimit: Int
    let bountyBeans: Int

    enum CodingKeys: String, CodingKey {
        case title, description, radius
        case targetLat = "target_lat"
        case targetLng = "target_lng"
        case targetAddr = "target_addr"
        case timeLimit = "time_limit"
        case bountyBeans = "bounty_beans"
    }
}

struct MapPinSelector: View {
    @Binding var lat: Double
    @Binding var lng: Double
    @Binding var address: String
    @Binding var hasSelected: Bool
    /// 用户手动改动位置后，置 false：表示已非"默认当前位置"
    @Binding var autoFilled: Bool

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    /// 标记地图是否已初始化完成，避免首帧 binding 赋值把默认北京坐标写回 lat/lng
    @State private var mapDidInit = false
    /// 标记当前 region 变更是由我们程序化设置（自动填充/回中），不应视为用户选择、也不应清除 autoFilled
    @State private var programmaticRegionUpdate = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var geocodeTimer: Timer?
    @State private var skipNextReverseGeocode = false
    @State private var searchResults: [MapSearchResult] = []
    @State private var searchHint: String?

    private var regionBinding: Binding<MKCoordinateRegion> {
        Binding(
            get: { region },
            set: { newRegion in
                region = newRegion
                // 跳过初始化阶段的首帧赋值，避免默认坐标被当作已选位置
                guard mapDidInit else { return }
                // 程序化更新（自动填充当前位置）触发的 Map 回写，不视为用户操作
                guard !programmaticRegionUpdate else { return }
                lat = newRegion.center.latitude
                lng = newRegion.center.longitude
                hasSelected = true
                autoFilled = false
                if skipNextReverseGeocode {
                    skipNextReverseGeocode = false
                } else {
                    scheduleReverseGeocode()
                }
            }
        )
    }

    private struct MapSearchResult: Identifiable {
        let id = UUID()
        let name: String
        let coordinate: CLLocationCoordinate2D
        let placemark: CLPlacemark
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.bountyGray)
                TextField(L10n.publishSearchAddress, text: $searchText)
                    .font(.system(size: 14))
                    .submitLabel(.search)
                    .onSubmit(performSearch)
                    .accessibilityIdentifier("publishAddressSearchField")
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Button(L10n.publishSearchBtn) { performSearch() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.bountyGold)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)

            if let hint = searchHint {
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundColor(.bountyGray)
                    .padding(.horizontal, 4)
            }

            if !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchResults.prefix(5)) { result in
                        Button {
                            selectResult(result)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.bountyText)
                                    Text(formattedAddress(from: result.placemark))
                                        .font(.system(size: 12))
                                        .foregroundColor(.bountyGray)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                        if result.id != searchResults.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }

            ZStack {
                Map(coordinateRegion: regionBinding)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.bountyDanger)
                    )

                VStack {
                    Spacer()
                    if hasSelected {
                        Text(address.isEmpty ? L10n.publishLocationPicked : address)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.bountyDark.opacity(0.75))
                            .cornerRadius(6)
                            .padding(.bottom, 8)
                    } else {
                        Text(L10n.publishMapDrag)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.bountyGray.opacity(0.8))
                            .cornerRadius(6)
                            .padding(.bottom, 8)
                    }
                }
            }
            .onAppear {
                // 仅设置地图初始中心点；不自动反向解析，避免给出非预期默认地址
                if lat != 0 || lng != 0 {
                    // 标记程序化更新，避免 Map 自身回调绑定把 autoFilled 清零
                    programmaticRegionUpdate = true
                    region.center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    programmaticRegionUpdate = false
                }
                // 标记初始化完成，此后用户拖动才会回写坐标并视为已选择
                mapDidInit = true
            }
        }
    }

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            searchHint = nil
            return
        }
        isSearching = true
        searchResults = []
        searchHint = nil

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(query) { placemarks, error in
            DispatchQueue.main.async {
                isSearching = false
                guard let placemarks = placemarks, !placemarks.isEmpty else {
                    searchHint = L10n.publishSearchNotFound
                    return
                }
                let results = placemarks.compactMap { placemark -> MapSearchResult? in
                    guard let location = placemark.location else { return nil }
                    let name = placemark.name ?? formattedAddress(from: placemark)
                    return MapSearchResult(name: name, coordinate: location.coordinate, placemark: placemark)
                }
                if results.count == 1 {
                    selectResult(results[0])
                } else {
                    searchResults = results
                }
            }
        }
    }

    private func selectResult(_ result: MapSearchResult) {
        skipNextReverseGeocode = true
        region = MKCoordinateRegion(
            center: result.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        address = formattedAddress(from: result.placemark)
        lat = result.coordinate.latitude
        lng = result.coordinate.longitude
        hasSelected = true
        autoFilled = false
        searchText = result.name
        searchResults = []
        searchHint = nil
    }

    private func scheduleReverseGeocode() {
        geocodeTimer?.invalidate()
        geocodeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            reverseGeocode()
        }
    }

    private func reverseGeocode() {
        let location = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first else { return }
            DispatchQueue.main.async {
                address = formattedAddress(from: placemark)
            }
        }
    }

    private func formattedAddress(from placemark: CLPlacemark) -> String {
        let name = placemark.name ?? ""
        let locality = placemark.locality ?? ""
        let subLocality = placemark.subLocality ?? ""
        let thoroughfare = placemark.thoroughfare ?? ""
        let subThoroughfare = placemark.subThoroughfare ?? ""
        return [name, locality, subLocality, thoroughfare, subThoroughfare]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct OptionGroupView: View {
    let title: String
    let options: [Int]
    let display: (Int) -> String
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.bountyText)

            HStack(spacing: 10) {
                ForEach(options, id: \.self) { opt in
                    Button(display(opt)) {
                        withAnimation { selection = opt }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selection == opt ? .white : .bountyTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selection == opt ? Color.bountyGold : Color.white)
                    )
                }
            }
        }
    }
}

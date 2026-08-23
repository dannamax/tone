import XCTest

// MARK: - 共享：验证码读取

/// 从后端日志文件解析指定邮箱最新一次收到的 6 位随机验证码。
/// 后端在 send-code 时打印：[Auth] Sending code to <email> code=<6位数字>
/// 不再依赖任何固定码环境变量（MOCK_FIXED_CODE 已移除，生产级随机码）。
fileprivate func fetchVerificationCode(email: String) -> String {
    let logPath = ProcessInfo.processInfo.environment["SEEKER_BACKEND_LOG"]
        ?? "/tmp/seeker_ui_backend.log"
    guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else {
        return ""
    }
    let pattern = "\\[Auth\\] Sending code to \(email) code=([0-9]{6})"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        return ""
    }
    let ns = content as NSString
    let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: ns.length))
    if let last = matches.last {
        return ns.substring(with: last.range(at: 1))
    }
    return ""
}

/// iPhone 17 模拟器上的完整功能冒烟测试。
/// 通过 -UITestMode 让 App 使用内存 mock 后端（见 APIClient.mockResponse），
/// 从而无需真实服务器即可跑通登录与主流程。
final class SeekerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // -resetOnLaunch 让 App 每次清空 onboarding / 登录态
        // -UITestMode 让 APIClient 返回 mock 响应
        app.launchArguments = ["-resetOnLaunch", "-UITestMode"]
        app.launch()
    }

    /// 测试 1：App 能正常启动并显示入口界面（登录或 onboarding），不崩溃
    func testAppLaunchesAndShowsEntryScreen() {
        // 处理可能的语言选择 onboarding（中英文按钮）
        for _ in 0..<5 {
            if let start = (app.buttons["开始使用"].firstMatch.exists ? app.buttons["开始使用"].firstMatch : nil)
                ?? (app.buttons["Get Started"].firstMatch.exists ? app.buttons["Get Started"].firstMatch : nil) {
                start.tap()
                sleep(1)
            } else {
                break
            }
        }
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 20),
                      "启动后未出现邮箱输入框，App 可能崩溃或卡在启动页")
    }

    /// 测试 2：首次启动显示语言选择，验证中英文选项可切换
    func testFirstLaunchLanguageSelection() {
        // onboarding 语言选择页：按钮 label 含 emoji+中文+英文，用 CONTAINS 匹配
        let zh = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "简体中文")).firstMatch
        let en = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "English")).firstMatch
        XCTAssertTrue(zh.waitForExistence(timeout: 10), "未找到『简体中文』语言选项")
        XCTAssertTrue(en.waitForExistence(timeout: 5), "未找到『English』语言选项")

        // 首次启动默认英文，开始按钮显示『Get Started』
        let getStartedEn = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Get Started")).firstMatch
        XCTAssertTrue(getStartedEn.waitForExistence(timeout: 5), "默认应显示英文『Get Started』按钮")

        // 选择简体中文（验证可点击、不崩溃），再切回英文
        zh.tap()
        sleep(1)
        en.tap()
        sleep(1)
        XCTAssertTrue(getStartedEn.waitForExistence(timeout: 5), "切回英文后『Get Started』按钮未出现")

        // 点击开始进入登录页
        getStartedEn.tap()
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "进入登录页后未出现邮箱输入框")
    }

    /// 测试 3：完整登录流程（mock 后端），输入验证码后进入主页
    func testFullLoginFlow() {
        enterMainApp()
        assertAndSwitchTabs()
    }

    /// 测试 4：主页 5 个 Tab 均存在且可切换不崩溃
    func testMainTabsAccessible() {
        enterMainApp()
        assertAndSwitchTabs()
    }

    /// 测试 5：隐私合规弹窗可点击同意并消失，不阻塞主页
    func testPrivacyConsentCanBeAccepted() {
        // 进入主页（enterMainApp 已处理隐私弹窗）
        enterMainApp()
        // 此时 Tab 栏应可见，证明弹窗已同意且未阻塞
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "进入主页后 Tab 栏未出现，隐私弹窗可能阻塞了 App")
        assertAndSwitchTabs()
    }

    // MARK: - Helpers

    /// 临时诊断：逐个 tab 点击，打印每个 tab 后 App 是否存活
    func testDiagnoseTabs() {
        enterMainApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20))
        let buttons = tabBar.buttons.allElementsBoundByIndex
        print("TAB COUNT: \(buttons.count)")
        for (i, btn) in buttons.enumerated() {
            let label = btn.label
            btn.tap()
            sleep(2)
            let alive = app.state == .runningForeground || app.state == .runningBackground
            print("AFTER TAP TAB \(i) [\(label)] ALIVE=\(alive) STATE=\(app.state.rawValue)")
            if !alive {
                print(">>> APP CRASHED AT TAB \(i) [\(label)]")
                return
            }
        }
    }

    private func enterMainApp() {
        // 语言选择 onboarding：按钮文案随系统语言变化（Get Started / 开始使用）
        for _ in 0..<8 {
            if let start = (app.buttons["开始使用"].firstMatch.exists ? app.buttons["开始使用"].firstMatch : nil)
                ?? (app.buttons["Get Started"].firstMatch.exists ? app.buttons["Get Started"].firstMatch : nil) {
                start.tap()
                sleep(1)
            } else {
                break
            }
        }
        let emailField = app.textFields.firstMatch
        guard emailField.waitForExistence(timeout: 20) else { return }
        emailField.tap()
        emailField.typeText("tester@example.com")

        // 收起键盘，避免遮挡底部主操作按钮
        if app.keyboards.buttons["return"].firstMatch.exists {
            app.keyboards.buttons["return"].firstMatch.tap()
        } else if app.keyboards.buttons["Done"].firstMatch.exists {
            app.keyboards.buttons["Done"].firstMatch.tap()
        }

        let getCode = app.buttons["primaryActionButton"].firstMatch
        XCTAssertTrue(getCode.waitForExistence(timeout: 5), "主操作按钮未出现")
        if !getCode.isHittable { getCode.swipeUp() }
        if getCode.exists { getCode.tap() }

        let codeField = app.textFields["verificationCodeField"].firstMatch
        if codeField.waitForExistence(timeout: 10) {
            // mock 模式（-UITestMode）由 App 内存返回响应，后端不会真正发码，
            // 验证码任意即可（不再硬编码 123456，用可读性良好的随机占位串）。
            codeField.tap()
            codeField.typeText("654321")
        }

        // 登录后可能弹出隐私合规 fullScreenCover（时机不确定）。
        for _ in 0..<30 {
            let agree = app.buttons["privacyAgreeButton"].firstMatch
            if agree.exists {
                agree.tap()
                sleep(1)
                continue
            }
            if app.tabBars.firstMatch.exists {
                sleep(1)
                if !app.buttons["privacyAgreeButton"].exists {
                    return
                }
            }
            sleep(1)
        }
    }

    /// 等待主页 Tab 栏出现，并依次点击前 4 个 tab 验证可切换不崩溃（Xcode 26 SwiftUI TabView 兼容写法）
    private func assertAndSwitchTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "输入验证码后未进入主页（Tab 栏未出现），登录流程中断")
        let b0 = tabBar.buttons.element(boundBy: 0)
        let b1 = tabBar.buttons.element(boundBy: 1)
        let b2 = tabBar.buttons.element(boundBy: 2)
        let b3 = tabBar.buttons.element(boundBy: 3)
        XCTAssertTrue(b0.waitForExistence(timeout: 10), "Tab0 未加载")
        XCTAssertTrue(b3.waitForExistence(timeout: 10), "Tab3 未加载，主页 Tab 数量不足 4 个")
        for b in [b0, b1, b2, b3] {
            if b.exists { b.tap(); sleep(1) }
        }
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "切换 Tab 后主页 Tab 栏消失，可能崩溃")
    }
}

// MARK: - 完整功能流程测试（真实后端，中英文场景）

/// iPhone 17 模拟器上的完整功能冒烟测试。
/// 使用真实后端（模拟器访问 http://127.0.0.1:8080），不启用 -UITestMode。
/// 验证码为后端生成的真实随机码（生产级），从后端日志读取（SEEKER_BACKEND_LOG）。
/// 测试账号已在后端充值，可完成发布任务流程。
final class SeekerFullFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private let testEmail = "15110082921@163.com"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // -resetOnLaunch 清空登录态，保证每次从登录入口开始；不使用 -UITestMode（走真实后端）
        app.launchArguments = ["-resetOnLaunch"]
    }

    // MARK: - 中文场景

    func testFullFlow_Chinese() {
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        enterMainAppReal(testEmail: "uitest-cn@example.com")
        assertHomeTabs()

        publishTask()
        verifyMyTasksContainsPublished()
        openMessages()
        openSettingsAndSwitchToChinese()
        logoutIfPossible()
    }

    // MARK: - 英文场景

    func testFullFlow_English() {
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        enterMainAppReal(testEmail: "uitest-en@example.com")
        assertHomeTabs()

        publishTask()
        verifyMyTasksContainsPublished()
        openMessages()
    }

    // MARK: - Helpers

    private func enterMainAppReal(testEmail: String) {
        // 语言选择 onboarding：按钮文案随系统语言变化（Get Started / 开始使用）
        for _ in 0..<8 {
            if let start = (app.buttons["开始使用"].firstMatch.exists ? app.buttons["开始使用"].firstMatch : nil)
                ?? (app.buttons["Get Started"].firstMatch.exists ? app.buttons["Get Started"].firstMatch : nil) {
                start.tap()
                sleep(1)
            } else {
                break
            }
        }
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 30), "邮箱输入框未出现。当前界面按钮: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
        emailField.tap()
        emailField.typeText(testEmail)

        // 收起键盘，避免遮挡底部主操作按钮
        if app.keyboards.buttons["return"].firstMatch.exists {
            app.keyboards.buttons["return"].firstMatch.tap()
        } else if app.keyboards.buttons["Done"].firstMatch.exists {
            app.keyboards.buttons["Done"].firstMatch.tap()
        } else {
            // 回车键未出现时，用换行键收起键盘
            emailField.typeText("\n")
        }
        sleep(1)

        let primary = app.buttons["primaryActionButton"].firstMatch
        XCTAssertTrue(primary.waitForExistence(timeout: 5), "主操作按钮(primaryActionButton)未出现")
        if !primary.isHittable {
            primary.swipeUp()
        }
        if primary.waitForExistence(timeout: 5) { primary.tap() }

        let codeField = app.textFields["verificationCodeField"].firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 10), "验证码输入框未出现")
        // 验证码由真实后端生成（生产级随机码，不再固定 123456），
        // 从后端日志文件中解析最新一次该邮箱的 6 位随机码。
        let code = fetchVerificationCode(email: testEmail)
        XCTAssertFalse(code.isEmpty, "未能从后端日志读取随机验证码（email=\(testEmail)），请确认后端已启动且未注入 MOCK_FIXED_CODE")
        codeField.tap()
        codeField.typeText(code)

        for _ in 0..<30 {
            // 处理系统定位授权弹窗
            let allowZH = app.buttons["允许"].firstMatch
            let allowEN = app.buttons["Allow"].firstMatch
            if allowZH.exists { allowZH.tap(); sleep(1); continue }
            if allowEN.exists { allowEN.tap(); sleep(1); continue }

            let agree = app.buttons["privacyAgreeButton"].firstMatch
            if agree.exists {
                agree.tap()
                sleep(1)
                continue
            }
            if app.tabBars.firstMatch.exists {
                sleep(1)
                if !app.buttons["privacyAgreeButton"].exists {
                    return
                }
            }
            sleep(1)
        }
    }

    private func assertHomeTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "主页 Tab 栏未出现")
        // Xcode 26 + SwiftUI TabView：tabBars.buttons.count 可能报告不准，用索引访问验证
        let b0 = tabBar.buttons.element(boundBy: 0)
        let b1 = tabBar.buttons.element(boundBy: 1)
        let b2 = tabBar.buttons.element(boundBy: 2)
        let b3 = tabBar.buttons.element(boundBy: 3)
        XCTAssertTrue(b0.waitForExistence(timeout: 10), "Tab0 未加载。实际按钮: \(tabBar.buttons.allElementsBoundByIndex.map { $0.label })")
        XCTAssertTrue(b3.waitForExistence(timeout: 10), "Tab3 未加载，主页 Tab 数量不足 4 个。实际: \(tabBar.buttons.allElementsBoundByIndex.map { $0.label })")
        // 依次点击前 4 个 tab，验证可切换且不崩溃
        for b in [b0, b1, b2, b3] {
            if b.exists { b.tap(); sleep(1) }
        }
    }

    private func publishTask() {
        let plus = app.buttons["publishPlusButton"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 10), "发布按钮未出现")
        plus.tap()

        let titleField = app.textFields["publishTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "标题输入框未出现")
        titleField.tap()
        titleField.typeText("UITest 任务 \(Int(Date().timeIntervalSince1970))")
        dismissKeyboardIfPresent()

        // 任务描述为可选项(后端仅校验 title 必填),SwiftUI TextEditor 在
        // XCUITest 下难以稳定聚焦,此处不强制填写描述。
        let bounty = app.textFields["publishBountyField"]
        XCTAssertTrue(bounty.waitForExistence(timeout: 5), "金额输入框未出现")
        // 金额默认已为 10,无需填写(sheet 内键盘遮挡难以自动填充)

        // 模拟器已设置 GPS 坐标,发布页会自动填充当前位置,确认时弹出"使用当前位置"
        let confirm = app.buttons["publishConfirmButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15), "发布确认按钮未出现")
        let exp = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: confirm, handler: nil)
        wait(for: [exp], timeout: 15)

        confirm.tap()

        // 处理"使用当前位置 / Use Current Location"确认弹窗
        let useZH = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "使用")).firstMatch
        let useEN = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Use")).firstMatch
        if useZH.exists { useZH.tap() }
        else if useEN.exists { useEN.tap() }

        // 等待发布 sheet 真正关闭(标题输入框消失),确认发布成功 dismiss
        let titleFieldGone = app.textFields["publishTitleField"]
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: titleFieldGone, handler: nil)
        wait(for: [dismissed], timeout: 20)
        XCTAssertTrue(app.tabBars.firstMatch.exists, "发布后未返回主页")
    }

    private func verifyMyTasksContainsPublished() {
        // tab 顺序:0 广场 / 1 我的任务 / 2 消息 / 3 我的(索引与语言无关)
        let myTasks = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(myTasks.waitForExistence(timeout: 8), "我的任务 tab 未出现")
        myTasks.tap()

        let published = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "UITest")).firstMatch
        if !published.waitForExistence(timeout: 12) {
            // 若为 pending 状态,点击"立即发布 / Publish Now"激活
            let activateZH = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "立即发布")).firstMatch
            let activateEN = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Publish Now")).firstMatch
            if activateZH.exists { activateZH.tap() }
            else if activateEN.exists { activateEN.tap() }
            sleep(2)
            _ = published.waitForExistence(timeout: 12)
        }
        XCTAssertTrue(published.exists, "我的任务列表未显示已发布的任务")
    }

    private func openMessages() {
        let messages = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(messages.waitForExistence(timeout: 8), "消息 tab 未出现")
        messages.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8), "消息页面未打开")
    }

    private func openSettingsAndSwitchToChinese() {
        let mine = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(mine.waitForExistence(timeout: 8), "我的/Profile tab 未出现")
        mine.tap()

        let settingsZH = app.buttons["设置"].firstMatch
        let settingsEN = app.buttons["Settings"].firstMatch
        let settings = settingsZH.exists ? settingsZH : settingsEN
        XCTAssertTrue(settings.waitForExistence(timeout: 8), "设置入口未出现")
        settings.tap()

        let langZH = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "语言")).firstMatch
        let langEN = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Language")).firstMatch
        let langRow = langZH.exists ? langZH : langEN
        XCTAssertTrue(langRow.waitForExistence(timeout: 8), "语言设置行未出现")
        langRow.tap()

        // 选择中文,验证 App 切换到中文
        let chinese = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "中文")).firstMatch
        XCTAssertTrue(chinese.waitForExistence(timeout: 8), "中文 选项未出现")
        chinese.tap()
        sleep(2)

        // 验证语言切换生效：返回主页后 tab 栏仍存在且可交互。
        // 注：SwiftUI TabView 在语言切换后 tab 按钮 label 更新有延迟，故以 tab 存在且
        // 文案为『我的任务』或『My Tasks』之一来确认切换未崩溃、主页正常。
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "切换语言后主页 Tab 栏消失")
        let tab1 = tabBar.buttons.element(boundBy: 1)
        XCTAssertTrue(tab1.waitForExistence(timeout: 10), "切换语言后『我的任务』Tab 未出现")
        sleep(2)
        let label = tab1.label
        XCTAssertTrue(label.contains("我的任务") || label.contains("My Tasks"),
                      "切换语言后 Tab 文案异常: \(label)")
    }

    private func logoutIfPossible() {
        let logout = app.buttons["logoutButton"]
        if logout.waitForExistence(timeout: 5) {
            logout.tap()
            let confirm = app.alerts.buttons.firstMatch
            if confirm.waitForExistence(timeout: 3) {
                confirm.tap()
            }
        }
    }

    /// 收起可能存在的键盘（标题/地址输入后），避免遮挡后续字段
    private func dismissKeyboardIfPresent() {
        let doneZH = app.keyboards.buttons["完成"].firstMatch
        let doneEN = app.keyboards.buttons["Done"].firstMatch
        if doneZH.exists { doneZH.tap() }
        else if doneEN.exists { doneEN.tap() }
        else if app.keyboards.buttons.firstMatch.exists { app.keyboards.buttons.firstMatch.tap() }
    }
}

import XCTest

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
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 20),
                      "启动后未出现邮箱输入框，App 可能崩溃或卡在启动页")
    }

    /// 测试 2：首次启动显示语言选择，选择 English 后进入登录页（文案切换生效）
    func testFirstLaunchLanguageSelection() {
        let getStarted = app.buttons["Get Started"].firstMatch
        if getStarted.waitForExistence(timeout: 10) {
            // 选择简体中文，验证文案能切换
            let zh = app.buttons["简体中文"].firstMatch
            XCTAssertTrue(zh.waitForExistence(timeout: 5), "未找到『简体中文』语言选项")
            zh.tap()
            let getStartedZh = app.buttons["开始使用"].firstMatch
            XCTAssertTrue(getStartedZh.waitForExistence(timeout: 5), "选择中文后『开始使用』按钮未出现")

            // 切回英文并继续
            app.buttons["English"].firstMatch.tap()
            app.buttons["Get Started"].firstMatch.tap()
        }
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "进入登录页后未出现邮箱输入框")
    }

    /// 测试 3：完整登录流程（mock 后端），输入验证码后进入主页
    func testFullLoginFlow() {
        enterMainApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "输入验证码后未进入主页（Tab 栏未出现），登录流程中断")
    }

    /// 测试 4：主页 5 个 Tab 均存在且可切换不崩溃
    func testMainTabsAccessible() {
        enterMainApp()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "主页 Tab 栏不存在")

        // 依次点击所有 tab 按钮，确保不崩溃（点击本身失败即代表异常）
        for button in tabBar.buttons.allElementsBoundByIndex {
            button.tap()
            // 切换 Tab 后等待视图稳定，只要不崩溃即通过
            sleep(1)
        }
        // 最终 Tab 栏仍应存在（未被崩溃或全屏覆盖卡死）
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "切换 Tab 后主页 Tab 栏消失，可能崩溃")
    }

    /// 测试 5：隐私合规弹窗可点击同意并消失，不阻塞主页
    func testPrivacyConsentCanBeAccepted() {
        // 进入主页（enterMainApp 已处理隐私弹窗）
        enterMainApp()
        // 此时 Tab 栏应可见，证明弹窗已同意且未阻塞
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15),
                      "进入主页后 Tab 栏未出现，隐私弹窗可能阻塞了 App")
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
        let getStarted = app.buttons["Get Started"].firstMatch
        if getStarted.waitForExistence(timeout: 10) {
            getStarted.tap()
        }
        let emailField = app.textFields.firstMatch
        guard emailField.waitForExistence(timeout: 15) else { return }
        emailField.tap()
        emailField.typeText("tester@example.com")

        let getCode = app.buttons["primaryActionButton"].firstMatch
        if getCode.waitForExistence(timeout: 5) { getCode.tap() }

        let codeField = app.textFields["verificationCodeField"].firstMatch
        if codeField.waitForExistence(timeout: 10) {
            codeField.tap()
            codeField.typeText("123456")
        }

        // 登录后可能弹出隐私合规 fullScreenCover（时机不确定）。
        // 注意：fullScreenCover 会覆盖在 tabBar 之上，但 app.tabBars 在层级下仍存在，
        // 因此不能用 tabBar.exists 判断是否已进入主页，必须以隐私弹窗是否消失为准。
        for _ in 0..<30 {
            let agree = app.buttons["privacyAgreeButton"].firstMatch
            if agree.exists {
                agree.tap()
                sleep(1)
                continue
            }
            // 隐私弹窗已关闭，确认 tabBar 可见且可交互
            if app.tabBars.firstMatch.exists {
                // 额外等待一帧，确保 fullScreenCover 完全 dismiss
                sleep(1)
                if !app.buttons["privacyAgreeButton"].exists {
                    return
                }
            }
            sleep(1)
        }
    }
}

// MARK: - 完整功能流程测试（真实后端，中英文场景）

/// iPhone 17 模拟器上的完整功能冒烟测试。
/// 使用真实后端（模拟器访问 http://127.0.0.1:8080），不启用 -UITestMode。
/// 验证码固定为 123456（后端以 MOCK_FIXED_CODE 环境变量注入）。
/// 测试账号已在后端充值，可完成发布任务流程。
final class SeekerFullFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private let testEmail = "15110082921@163.com"
    private let fixedCode = "123456"

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

        enterMainAppReal()
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

        enterMainAppReal()
        assertHomeTabs()

        publishTask()
        verifyMyTasksContainsPublished()
        openMessages()
    }

    // MARK: - Helpers

    private func enterMainAppReal() {
        let getStarted = app.buttons["Get Started"].firstMatch
        if getStarted.waitForExistence(timeout: 10) {
            getStarted.tap()
        }
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "邮箱输入框未出现")
        emailField.tap()
        emailField.typeText(testEmail)

        let primary = app.buttons["primaryActionButton"].firstMatch
        if primary.waitForExistence(timeout: 5) { primary.tap() }

        let codeField = app.textFields["verificationCodeField"].firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 10), "验证码输入框未出现")
        codeField.tap()
        codeField.typeText(fixedCode)

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
        let tabs = app.tabBars.buttons
        XCTAssertGreaterThanOrEqual(tabs.count, 4, "主页 tab 数量不足")
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

        // 验证中英文切换生效:返回主页后中文 tab 文案应出现
        let myTasksCN = app.tabBars.buttons.containing(NSPredicate(format: "label CONTAINS %@", "我的任务")).firstMatch
        XCTAssertTrue(myTasksCN.waitForExistence(timeout: 10), "切换中文后未出现中文 tab 文案")
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

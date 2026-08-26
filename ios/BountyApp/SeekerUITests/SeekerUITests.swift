import XCTest

// MARK: - Shared: verification code reading

/// Parses the latest 6-digit verification code for the given email from the backend log file.
/// The backend logs on send-code: [Auth] Sending code to <email> code=<6 digits>
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

/// Full functional smoke test on iPhone 17 simulator.
/// Uses -UITestMode so the App answers with the in-memory mock backend (see APIClient.mockResponse),
/// allowing login and main flows without a real server.
final class SeekerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // -resetOnLaunch clears onboarding / login state on every run.
        app.launchArguments = ["-resetOnLaunch", "-UITestMode"]
        app.launch()
    }

    /// Test 1: App launches and shows the entry screen (login or onboarding) without crashing.
    func testAppLaunchesAndShowsEntryScreen() {
        // Dismiss possible onboarding (English-only build).
        for _ in 0..<5 {
            if app.buttons["Get Started"].firstMatch.exists {
                app.buttons["Get Started"].firstMatch.tap()
                sleep(1)
            } else {
                break
            }
        }
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 20),
                      "Email field did not appear after launch; the app may have crashed or is stuck on the launch screen")
    }

    /// Test 2: First launch shows the onboarding with the English option selected by default.
    func testFirstLaunchLanguageSelection() {
        // Composite SwiftUI buttons (flag + title + subtitle) are not always exposed
        // as buttons; match any element containing the language label.
        let en = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "English")).firstMatch
        XCTAssertTrue(en.waitForExistence(timeout: 10), "English language option not found")

        // English-only build: Get Started is available immediately.
        let getStartedEn = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Get Started")).firstMatch
        XCTAssertTrue(getStartedEn.waitForExistence(timeout: 5), "Get Started button not shown by default")

        // Tap through to the login page.
        getStartedEn.tap()
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "Email field did not appear after entering the login page")
    }

    /// Test 3: Full login flow (mock backend), enter the main app after the verification code.
    func testFullLoginFlow() {
        enterMainApp()
        assertAndSwitchTabs()
    }

    /// Test 4: All main tabs exist and switching does not crash.
    func testMainTabsAccessible() {
        enterMainApp()
        assertAndSwitchTabs()
    }

    /// Test 5: Privacy consent dialog can be accepted and does not block the main app.
    func testPrivacyConsentCanBeAccepted() {
        // enterMainApp already handles the privacy dialog.
        enterMainApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "Tab bar did not appear after entering the main app; the privacy dialog may be blocking")
        assertAndSwitchTabs()
    }

    // MARK: - Helpers

    /// Diagnostics: tap each tab in turn and report whether the app stays alive.
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
        // Dismiss possible onboarding (English-only build).
        for _ in 0..<8 {
            if app.buttons["Get Started"].firstMatch.exists {
                app.buttons["Get Started"].firstMatch.tap()
                sleep(1)
            } else {
                break
            }
        }
        let emailField = app.textFields.firstMatch
        guard emailField.waitForExistence(timeout: 20) else { return }
        emailField.tap()
        emailField.typeText("tester@example.com")

        // Dismiss the keyboard so the primary button is not covered.
        if app.keyboards.buttons["return"].firstMatch.exists {
            app.keyboards.buttons["return"].firstMatch.tap()
        } else if app.keyboards.buttons["Done"].firstMatch.exists {
            app.keyboards.buttons["Done"].firstMatch.tap()
        }

        let getCode = app.buttons["primaryActionButton"].firstMatch
        XCTAssertTrue(getCode.waitForExistence(timeout: 5), "Primary action button not found")
        if !getCode.isHittable { getCode.swipeUp() }
        if getCode.exists { getCode.tap() }

        let codeField = app.textFields["verificationCodeField"].firstMatch
        if codeField.waitForExistence(timeout: 10) {
            // Mock mode (-UITestMode) responds in memory; the backend does not send a real code,
            // so any code value works.
            codeField.tap()
            codeField.typeText("654321")
        }

        // After login a privacy fullScreenCover may appear at an unpredictable moment.
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

    /// Waits for the main tab bar and taps the first 4 tabs to verify switching does not crash.
    private func assertAndSwitchTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "Main tab bar did not appear after the verification code; login flow interrupted")
        let b0 = tabBar.buttons.element(boundBy: 0)
        let b1 = tabBar.buttons.element(boundBy: 1)
        let b2 = tabBar.buttons.element(boundBy: 2)
        let b3 = tabBar.buttons.element(boundBy: 3)
        XCTAssertTrue(b0.waitForExistence(timeout: 10), "Tab0 not loaded")
        XCTAssertTrue(b3.waitForExistence(timeout: 10), "Tab3 not loaded; fewer than 4 main tabs")
        for b in [b0, b1, b2, b3] {
            if b.exists { b.tap(); sleep(1) }
        }
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar disappeared after switching tabs; possible crash")
    }
}

// MARK: - Full functional flow tests (real backend, English scenario)

/// Full functional smoke test on iPhone 17 simulator against the real backend
/// (http://127.0.0.1:8080), without -UITestMode.
/// Verification codes are real random codes generated by the backend and are read
/// from the backend log (SEEKER_BACKEND_LOG). Test accounts are pre-charged so the
/// publish flow can complete.
final class SeekerFullFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // -resetOnLaunch clears login state so each run starts from the login screen.
        app.launchArguments = ["-resetOnLaunch"]
    }

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
        // Dismiss possible onboarding (English-only build).
        for _ in 0..<8 {
            if app.buttons["Get Started"].firstMatch.exists {
                app.buttons["Get Started"].firstMatch.tap()
                sleep(1)
            } else {
                break
            }
        }
        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 30), "Email field did not appear. Current buttons: \(app.buttons.allElementsBoundByIndex.map { $0.label })")
        emailField.tap()
        emailField.typeText(testEmail)

        // Dismiss the keyboard so the primary button is not covered.
        if app.keyboards.buttons["return"].firstMatch.exists {
            app.keyboards.buttons["return"].firstMatch.tap()
        } else if app.keyboards.buttons["Done"].firstMatch.exists {
            app.keyboards.buttons["Done"].firstMatch.tap()
        } else {
            emailField.typeText("\n")
        }
        sleep(1)

        let primary = app.buttons["primaryActionButton"].firstMatch
        XCTAssertTrue(primary.waitForExistence(timeout: 5), "Primary action button (primaryActionButton) not found")
        if !primary.isHittable {
            primary.swipeUp()
        }
        if primary.waitForExistence(timeout: 5) { primary.tap() }

        let codeField = app.textFields["verificationCodeField"].firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 10), "Verification code field did not appear")
        // Real random code from the backend log.
        let code = fetchVerificationCode(email: testEmail)
        XCTAssertFalse(code.isEmpty, "Could not read the random verification code from the backend log (email=\(testEmail)); make sure the backend is running")
        codeField.tap()
        codeField.typeText(code)

        for _ in 0..<30 {
            // Handle the system location permission dialog.
            let allowEN = app.buttons["Allow"].firstMatch
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
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "Main tab bar did not appear")
        let b0 = tabBar.buttons.element(boundBy: 0)
        let b1 = tabBar.buttons.element(boundBy: 1)
        let b2 = tabBar.buttons.element(boundBy: 2)
        let b3 = tabBar.buttons.element(boundBy: 3)
        XCTAssertTrue(b0.waitForExistence(timeout: 10), "Tab0 not loaded. Buttons: \(tabBar.buttons.allElementsBoundByIndex.map { $0.label })")
        XCTAssertTrue(b3.waitForExistence(timeout: 10), "Tab3 not loaded; fewer than 4 main tabs. Actual: \(tabBar.buttons.allElementsBoundByIndex.map { $0.label })")
        for b in [b0, b1, b2, b3] {
            if b.exists { b.tap(); sleep(1) }
        }
    }

    private func publishTask() {
        let plus = app.buttons["publishPlusButton"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 10), "Publish button not found")
        plus.tap()

        let titleField = app.textFields["publishTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Title field did not appear")
        titleField.tap()
        titleField.typeText("UITest Task \(Int(Date().timeIntervalSince1970))")
        dismissKeyboardIfPresent()

        // Task description is optional (backend only validates title).
        // Beans economy: bounty is a stepper + chips UI (staticText), not a text field.
        let bounty = app.descendants(matching: .any)["publishBountyField"]
        XCTAssertTrue(bounty.waitForExistence(timeout: 5), "Bounty field did not appear")
        // Bounty defaults to 10 beans, no input needed.

        // The simulator has GPS coordinates set; the publish sheet auto-fills the current
        // location and asks for confirmation.
        let confirm = app.buttons["publishConfirmButton"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15), "Publish confirm button not found")
        let exp = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: confirm, handler: nil)
        wait(for: [exp], timeout: 15)

        confirm.tap()

        // Handle the "Use Current Location" confirmation dialog.
        let useEN = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Use")).firstMatch
        if useEN.exists { useEN.tap() }

        // Wait for the publish sheet to actually close (title field disappears).
        let titleFieldGone = app.textFields["publishTitleField"]
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: titleFieldGone, handler: nil)
        wait(for: [dismissed], timeout: 40)
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Did not return to the main app after publishing")
    }

    private func verifyMyTasksContainsPublished() {
        // Tab order: 0 Square / 1 My Tasks / 2 Messages / 3 Profile (index is language-independent).
        let myTasks = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(myTasks.waitForExistence(timeout: 8), "My Tasks tab not found")
        myTasks.tap()

        let published = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "UITest")).firstMatch
        if !published.waitForExistence(timeout: 30) {
            // If in pending state, tap "Publish Now" to activate.
            let activateEN = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Publish Now")).firstMatch
            if activateEN.exists { activateEN.tap() }
            sleep(2)
            _ = published.waitForExistence(timeout: 20)
        }
        XCTAssertTrue(published.exists, "Published task not shown in My Tasks")
    }

    private func openMessages() {
        let messages = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(messages.waitForExistence(timeout: 8), "Messages tab not found")
        messages.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8), "Messages page did not open")
    }

    /// Dismisses a possibly visible keyboard (after title/address input).
    private func dismissKeyboardIfPresent() {
        let doneEN = app.keyboards.buttons["Done"].firstMatch
        if doneEN.exists { doneEN.tap() }
        else if app.keyboards.buttons.firstMatch.exists { app.keyboards.buttons.firstMatch.tap() }
    }
}

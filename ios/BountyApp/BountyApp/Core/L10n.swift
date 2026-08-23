import Foundation

/// 集中式多语言管理枚举
/// 用法: Text(L10n.loginEmailPlaceholder)
/// 自动根据系统语言选择对应的 Localizable.strings
enum L10n {
    // MARK: - General
    static let appName = localized("app_name")
    static let appSlogan = localized("app_slogan")
    static let ok = localized("ok")
    static let cancel = localized("cancel")
    static let confirm = localized("confirm")
    static let done = localized("done")
    static let retry = localized("retry")
    static let loading = localized("loading")
    static let delete = localized("delete")
    static let save = localized("save")
    static let search = localized("search")
    static let noData = localized("no_data")
    static let networkError = localized("network_error")
    static let unknownError = localized("unknown_error")
    static let pullRefresh = localized("pull_refresh")

    // MARK: - Login
    static let loginEmailPlaceholder = localized("login_email_placeholder")
    static let loginCodePlaceholder = localized("login_code_placeholder")
    static let loginGetCode = localized("login_get_code")
    static let loginResendCode = localized("login_resend_code")
    static let loginRegister = localized("login_register")
    static let loginVerify = localized("login_verify")
    static let loginRetryAfter = localized("login_retry_after")
    static let loginErrorTitle = localized("login_error_title")
    static let loginAgreementHint = localized("login_agreement_hint")
    static let loginInvalidEmail = localized("login_invalid_email")
    static let loginCodeSent = localized("login_code_sent")
    static let loginCodeSendFailed = localized("login_code_send_failed")
    static let loginFailed = localized("login_failed")
    static let loginAuthFailed = localized("login_auth_failed")
    static let loginServerError = localized("login_server_error")
    static let loginDecodeFailed = localized("login_decode_failed")
    static let loginInvalidURL = localized("login_invalid_url")
    static let loginNetworkFail = localized("login_network_fail")

    // MARK: - Tabs
    static let tabSquare = localized("tab_square")
    static let tabMyTasks = localized("tab_my_tasks")
    static let tabMessages = localized("tab_messages")
    static let tabProfile = localized("tab_profile")

    // MARK: - Square
    static let squareTitle = localized("square_title")
    static let squareSubtitle = localized("square_subtitle")
    static let squareFilterAll = localized("square_filter_all")
    static let squareFilterWithin = localized("square_filter_within")
    static let squareLocating = localized("square_locating")
    static let squareEmpty = localized("square_empty")
    static let squareEmptyHint = localized("square_empty_hint")
    static let squarePublishAction = localized("square_publish_action")

    // MARK: - Task Card
    static let taskCardMinutes = localized("task_card_minutes")

    // MARK: - Task Status
    static let statusPending = localized("status_pending")
    static let statusClaimed = localized("status_claimed")
    static let statusSubmitted = localized("status_submitted")
    static let statusCompleted = localized("status_completed")
    static let statusReleased = localized("status_released")
    static let statusDisputed = localized("status_disputed")
    static let statusPublished = localized("status_published")

    // MARK: - Task Detail
    static let taskDetailTitle = localized("task_detail_title")
    static let taskNotFound = localized("task_not_found")
    static let taskNotFoundHint = localized("task_not_found_hint")
    static let taskNoLocation = localized("task_no_location")
    static let taskInProgress = localized("task_in_progress")
    static let taskReceivedSubmit = localized("task_received_submit")
    static let taskWaitReview = localized("task_wait_review")
    static let taskCompletedPaid = localized("task_completed_paid")
    static let taskDisputed = localized("task_disputed_hint")
    static let taskAddPhoto = localized("task_add_photo")
    static let taskSubmitEvidence = localized("task_submit_evidence")
    static let taskEvidence = localized("task_evidence")
    static let taskEvidenceLoadFailed = localized("task_evidence_load_failed")
    static let taskChatTitle = localized("task_chat_title")
    static let taskChatPlaceholder = localized("task_chat_placeholder")
    static let taskChatEmpty = localized("task_chat_empty")
    static let taskClaim = localized("task_claim")
    static let taskClaiming = localized("task_claiming")
    static let taskPublishConfirm = localized("task_publish_confirm")
    static let taskPublishing = localized("task_publishing")
    static let taskBalanceLow = localized("task_balance_low")
    static let taskRechargeHint = localized("task_recharge_hint")
    static let taskQuotaLow = localized("task_quota_low")
    static let taskQuotaHint = localized("task_quota_hint")
    static let taskConfirmPass = localized("task_confirm_pass")
    static let taskRequestMore = localized("task_request_more")
    static let taskSenderPub = localized("task_sender_pub")
    static let taskSenderClaimer = localized("task_sender_claimer")
    static let taskSubmitSuccess = localized("task_submit_success")
    static let taskSubmitFail = localized("task_submit_fail")
    static let taskConfirmPaid = localized("task_confirm_paid")
    static let taskDisputeRequested = localized("task_dispute_requested")
    static let taskClaimedBanner = localized("task_claimed_banner")
    static let taskOpsFailed = localized("task_ops_failed")
    static let taskSendFail = localized("task_send_fail")
    static let taskMsgEmpty = localized("task_msg_empty")
    static let taskEvidencePreview = localized("task_evidence_preview")
    static let taskSendFailRetry = localized("task_send_fail_retry")
    static let taskSubmitFailNetwork = localized("task_submit_fail_network")
    static let taskOpsFailShort = localized("task_ops_fail_short")
    static let taskEvidenceRequested = localized("task_evidence_requested")

    // MARK: - Publish
    static let publishTitle = localized("publish_title")
    static let publishTaskTitle = localized("publish_task_title")
    static let publishTitlePlaceholder = localized("publish_title_placeholder")
    static let publishDescription = localized("publish_description")
    static let publishBountyAmount = localized("publish_bounty_amount")
    static let publishCurrency = localized("publish_currency")
    static let publishCurrencyCNY = localized("publish_currency_cny")
    static let publishCurrencyUSD = localized("publish_currency_usd")
    static let publishAmountPlaceholder = localized("publish_amount_placeholder")
    static let publishBountyTotal = localized("publish_bounty_total")
    static let publishServiceFee = localized("publish_service_fee")
    static let publishTotalPay = localized("publish_total_pay")
    static let publishApproxCNY = localized("publish_approx_cny")
    static let publishTargetLocation = localized("publish_target_location")
    static let publishLocationSelected = localized("publish_location_selected")
    static let publishLocationRequired = localized("publish_location_required")
    static let publishLocationAutoFill = localized("publish_location_auto_fill")
    static let publishLocationManual = localized("publish_location_manual")
    static let publishLocationFailed = localized("publish_location_failed")
    static let publishRadius = localized("publish_radius")
    static let publishTimeLimit = localized("publish_time_limit")
    static let publishTimeUnit = localized("publish_time_unit")
    static let publishSearchAddress = localized("publish_search_address")
    static let publishSearchBtn = localized("publish_search_btn")
    static let publishSearchNotFound = localized("publish_search_not_found")
    static let publishMapDrag = localized("publish_map_drag")
    static let publishLocationPicked = localized("publish_location_picked")
    static let publishConfirmTitle = localized("publish_confirm_title")
    static let publishConfirmUse = localized("publish_confirm_use")
    static let publishConfirmEdit = localized("publish_confirm_edit")
    static let publishConfirmMsg = localized("publish_confirm_msg")
    static let publishPayBtn = localized("publish_pay_btn")
    static let publishQuotaHint = localized("publish_quota_hint")
    static let publishQuotaCost = localized("publish_quota_cost")
    static let publishQuotaDesc = localized("publish_quota_desc")
    static let publishSubmitBtn = localized("publish_submit_btn")
    static let publishNeedLogin = localized("publish_need_login")
    static let publishNeedLocation = localized("publish_need_location")
    static let publishFail = localized("publish_fail")
    static let publishSuccess = localized("publish_success")
    static let publishSuccessPending = localized("publish_success_pending")
    static let publishBalanceLow = localized("publish_balance_low")
    static let publishQuotaLow = localized("publish_quota_low")
    static let publishBadParams = localized("publish_bad_params")
    static let publishExpired = localized("publish_expired")
    static let publishNetworkError = localized("publish_network_error")
    static let publishServerError = localized("publish_server_error")

    // MARK: - My Tasks
    static let myTasksTitle = localized("my_tasks_title")
    static let myTasksPublished = localized("my_tasks_published")
    static let myTasksClaimed = localized("my_tasks_claimed")
    static let myTasksEmptyPub = localized("my_tasks_empty_pub")
    static let myTasksEmptyClaimed = localized("my_tasks_empty_claimed")
    static let myTasksGoSquare = localized("my_tasks_go_square")
    static let myTasksReload = localized("my_tasks_reload")
    static let myTasksPublishNow = localized("my_tasks_publish_now")
    static let myTasksPublishedToast = localized("my_tasks_published_toast")
    static let myTasksPublishFailed = localized("my_tasks_publish_failed")
    static let myTasksLoadFailed = localized("my_tasks_load_failed")

    // MARK: - Messages
    static let messagesTitle = localized("messages_title")
    static let messagesEmpty = localized("messages_empty")
    static let messagesEmptyHint = localized("messages_empty_hint")
    static let messagesReadAll = localized("messages_read_all")
    static let messagesGotIt = localized("messages_got_it")

    // MARK: - Wallet
    static let walletTitle = localized("wallet_title")
    static let walletBalance = localized("wallet_balance")
    static let walletFrozen = localized("wallet_frozen")
    static let walletTotalEarned = localized("wallet_total_earned")
    static let walletWithdraw = localized("wallet_withdraw")
    static let walletRecharge = localized("wallet_recharge")
    static let walletRechargeSim = localized("wallet_recharge_sim")
    static let walletMinWithdraw = localized("wallet_min_withdraw")
    static let walletTransactions = localized("wallet_transactions")
    static let walletHelp = localized("wallet_help")
    static let walletHelpPage = localized("wallet_help_page")
    static let walletWithdrawTitle = localized("wallet_withdraw_title")
    static let walletWithdrawAmount = localized("wallet_withdraw_amount")
    static let walletWithdrawMin = localized("wallet_withdraw_min")
    static let walletWithdrawMethod = localized("wallet_withdraw_method")
    static let walletWithdrawBank = localized("wallet_withdraw_bank")
    static let walletWithdrawPaypal = localized("wallet_withdraw_paypal")
    static let walletWithdrawETA = localized("wallet_withdraw_eta")
    static let walletWithdrawConfirm = localized("wallet_withdraw_confirm")
    static let walletRechargeTitle = localized("wallet_recharge_title")
    static let walletRechargeAmount = localized("wallet_recharge_amount")
    static let walletRechargePlaceholder = localized("wallet_recharge_placeholder")
    static let walletRechargeHint = localized("wallet_recharge_hint")
    static let walletRechargeConfirm = localized("wallet_recharge_confirm")
    static let walletLoadFailed = localized("wallet_load_failed")
    static let walletWithdrawFailed = localized("wallet_withdraw_failed")
    static let walletRechargeFailed = localized("wallet_recharge_failed")
    static let walletAuthExpired = localized("wallet_auth_expired")

    // MARK: - Publish Quota (方案1)
    static let quotaRemainingTitle = localized("quota_remaining_title")
    static let quotaUsedFmt = localized("quota_used_fmt")
    static let quotaBuyButton = localized("quota_buy_button")
    static let quotaPackagesTitle = localized("quota_packages_title")
    static let quotaLoading = localized("quota_loading")
    static let quotaPackageCountFmt = localized("quota_package_count_fmt")
    static let quotaPurchasing = localized("quota_purchasing")
    static let commonClose = localized("common_close")

    // MARK: - StoreKit / Apple IAP
    static let storeProductNotFound = localized("store_product_not_found")
    static let storeUserCancelled = localized("store_user_cancelled")
    static let storePending = localized("store_pending")
    static let storeUnknown = localized("store_unknown")
    static let walletBounty = localized("wallet_bounty")

    // MARK: - Profile
    static let profileTitle = localized("profile_title")
    static let profileWallet = localized("profile_wallet")
    static let profileMyTasks = localized("profile_my_tasks")
    static let profileSettings = localized("profile_settings")
    static let profileHelp = localized("profile_help")
    static let profileTerms = localized("profile_terms")
    static let profilePrivacy = localized("profile_privacy")
    static let profileLogout = localized("profile_logout")
    static let profileLogoutConfirm = localized("profile_logout_confirm")
    static let profileLogoutAction = localized("profile_logout_action")

    // MARK: - Settings
    static let settingsTitle = localized("settings_title")
    static let settingsPermissions = localized("settings_permissions")
    static let settingsNotifications = localized("settings_notifications")
    static let settingsLocation = localized("settings_location")
    static let settingsAbout = localized("settings_about")
    static let settingsVersion = localized("settings_version")
    static let settingsBuild = localized("settings_build")
    static let settingsLanguage = localized("settings_language")
    static let settingsSectionGeneral = localized("settings_section_general")
    static let settingsSectionNotifications = localized("settings_section_notifications")
    static let settingsSectionPrivacy = localized("settings_section_privacy")
    static let settingsPrivacyPolicy = localized("settings_privacy_policy")
    static let settingsTermsOfService = localized("settings_terms_of_service")

    // MARK: - Onboarding
    static let onboardingLangTitle = localized("onboarding_lang_title")
    static let onboardingLangSubtitle = localized("onboarding_lang_subtitle")
    static let onboardingGetStarted = localized("onboarding_get_started")

    // MARK: - Server Settings
    static let serverSettingsTitle = localized("server_settings_title")
    static let serverCurrentHost = localized("server_current_host")
    static let serverPersistHost = localized("server_persist_host")
    static let serverManualIP = localized("server_manual_ip")
    static let serverIPPlaceholder = localized("server_ip_placeholder")
    static let serverSaveApply = localized("server_save_apply")
    static let serverConnectivity = localized("server_connectivity")
    static let serverTestConn = localized("server_test_conn")
    static let serverTesting = localized("server_testing")
    static let serverSaved = localized("server_saved")
    static let serverAddrInvalid = localized("server_addr_invalid")
    static let serverHint = localized("server_hint")
    static let serverHintFooter = localized("server_hint_footer")
    static let serverTimeout = localized("server_timeout")
    static let serverUnreachable = localized("server_unreachable")
    static let serverNoInternet = localized("server_no_internet")
    static let serverOK = localized("server_ok")
    static let serverUnknown = localized("server_unknown")
    static let serverNotTested = localized("server_not_tested")
    static let serverSavedHostFmt = localized("server_saved_host_fmt")

    // MARK: - Review
    static let reviewTitle = localized("review_title")
    static let reviewPrompt = localized("review_prompt")
    static let reviewClaimerInfo = localized("review_claimer_info")
    static let reviewClaimer = localized("review_claimer")
    static let reviewSubmitTime = localized("review_submit_time")
    static let reviewPhotos = localized("review_photos")
    static let reviewNotes = localized("review_notes")
    static let reviewNoSubmission = localized("review_no_submission")
    static let reviewDispute = localized("review_dispute")
    static let reviewConfirmPay = localized("review_confirm_pay")
    static let reviewDisputeTitle = localized("review_dispute_title")
    static let reviewDisputeReason = localized("review_dispute_reason")
    static let reviewDisputeSubmit = localized("review_dispute_submit")

    // MARK: - Network
    static let networkSwitched = localized("network_switched")
    static let networkDisconnected = localized("network_disconnected")

    // MARK: - API Errors
    static let apiServerErrorFmt = localized("api_server_error_fmt")
    static let apiTimeout = localized("api_timeout")
    static let apiCannotConnect = localized("api_cannot_connect")
    static let apiCancelled = localized("api_cancelled")
    static let apiNetworkErrorFmt = localized("api_network_error_fmt")
    static let apiNetworkError = localized("api_network_error")

    // MARK: - Server Settings Detail
    static let serverNotConfigured = localized("server_not_configured")
    static let serverAddrNotSet = localized("server_addr_not_set")
    static let serverSetHint = localized("server_set_hint")
    static let serverDefault = localized("server_default")
    static let serverAddrParseFail = localized("server_addr_parse_fail")
    static let serverTimeoutDetail = localized("server_timeout_detail")
    static let serverCannotConnectDetail = localized("server_cannot_connect_detail")
    static let serverNoInternetDetail = localized("server_no_internet_detail")
    static let serverErrorCodeFmt = localized("server_error_code_fmt")
    static let serverConnSuccessFmt = localized("server_conn_success_fmt")

    // MARK: - Formatting
    static let distanceMeter = localized("distance_meter")
    static let distanceKm = localized("distance_km")
    static let durationHourMin = localized("duration_hour_min")
    static let durationMinSec = localized("duration_min_sec")
    static let durationZero = localized("duration_zero")
    static let countdownSec = localized("countdown_sec")
    static let taskDistanceKm = localized("task_distance_km")
    static let taskTimeMin = localized("task_time_min")

    // MARK: - Camera
    static let cameraTimestampFmt = localized("camera_timestamp_fmt")
    static let cameraGpsFmt = localized("camera_gps_fmt")
    static let cameraPhotoCount = localized("camera_photo_count")

    // MARK: - Login Debug
    static let loginConnectingFmt = localized("login_connecting_fmt")
    static let loginHostErrorFmt = localized("login_host_error_fmt")

    // MARK: - Messages (Mock)
    static let messagesOfferClaimed = localized("messages_offer_claimed")
    static let messagesEvidenceSubmitted = localized("messages_evidence_submitted")
    static let messagesBountyReceived = localized("messages_bounty_received")

    // MARK: - Privacy / GDPR
    static let privacyConsentTitle = localized("privacy_consent_title")
    static let privacyConsentBody = localized("privacy_consent_body")
    static let privacyConsentAgree = localized("privacy_consent_agree")
    static let privacyConsentDisagree = localized("privacy_consent_disagree")

    // MARK: - Country Picker
    static let countryPickerTitle = localized("country_picker_title")
    static let countryPickerSearch = localized("country_picker_search")

    // MARK: - Exchange Rate
    static let exchangeRateLabel = localized("exchange_rate_label")

    // MARK: - Camera
    static let cameraTimestamp = localized("camera_timestamp")
    static let cameraGPS = localized("camera_gps")

    // MARK: - Helper
    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    /// 带格式化参数的多语言字符串
    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: localized(key), arguments: args)
    }

    /// 根据状态码获取本地化文本
    static func statusText(for status: String) -> String {
        switch status {
        case "pending": return L10n.statusPending
        case "claimed": return L10n.statusClaimed
        case "submitted": return L10n.statusSubmitted
        case "completed": return L10n.statusCompleted
        case "released": return L10n.statusReleased
        case "disputed": return L10n.statusDisputed
        case "published": return L10n.statusPublished
        default: return status
        }
    }
}

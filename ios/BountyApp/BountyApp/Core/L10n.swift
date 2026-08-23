import Foundation

/// 集中式多语言管理枚举
/// 用法: Text(L10n.loginEmailPlaceholder)
/// 自动根据系统语言选择对应的 Localizable.strings
enum L10n {
    // MARK: - General
    static var appName = localized("app_name")
    static var appSlogan = localized("app_slogan")
    static var ok = localized("ok")
    static var cancel = localized("cancel")
    static var confirm = localized("confirm")
    static var done = localized("done")
    static var retry = localized("retry")
    static var loading = localized("loading")
    static var delete = localized("delete")
    static var save = localized("save")
    static var search = localized("search")
    static var noData = localized("no_data")
    static var networkError = localized("network_error")
    static var unknownError = localized("unknown_error")
    static var pullRefresh = localized("pull_refresh")

    // MARK: - Login
    static var loginEmailPlaceholder = localized("login_email_placeholder")
    static var loginCodePlaceholder = localized("login_code_placeholder")
    static var loginGetCode = localized("login_get_code")
    static var loginResendCode = localized("login_resend_code")
    static var loginRegister = localized("login_register")
    static var loginVerify = localized("login_verify")
    static var loginRetryAfter = localized("login_retry_after")
    static var loginErrorTitle = localized("login_error_title")
    static var loginAgreementHint = localized("login_agreement_hint")
    static var loginInvalidEmail = localized("login_invalid_email")
    static var loginCodeSent = localized("login_code_sent")
    static var loginCodeSendFailed = localized("login_code_send_failed")
    static var loginFailed = localized("login_failed")
    static var loginAuthFailed = localized("login_auth_failed")
    static var loginServerError = localized("login_server_error")
    static var loginDecodeFailed = localized("login_decode_failed")
    static var loginInvalidURL = localized("login_invalid_url")
    static var loginNetworkFail = localized("login_network_fail")

    // MARK: - Tabs
    static var tabSquare = localized("tab_square")
    static var tabMyTasks = localized("tab_my_tasks")
    static var tabMessages = localized("tab_messages")
    static var tabProfile = localized("tab_profile")

    // MARK: - Square
    static var squareTitle = localized("square_title")
    static var squareSubtitle = localized("square_subtitle")
    static var squareFilterAll = localized("square_filter_all")
    static var squareFilterWithin = localized("square_filter_within")
    static var squareLocating = localized("square_locating")
    static var squareEmpty = localized("square_empty")
    static var squareEmptyHint = localized("square_empty_hint")
    static var squarePublishAction = localized("square_publish_action")

    // MARK: - Task Card
    static var taskCardMinutes = localized("task_card_minutes")

    // MARK: - Task Status
    static var statusPending = localized("status_pending")
    static var statusClaimed = localized("status_claimed")
    static var statusSubmitted = localized("status_submitted")
    static var statusCompleted = localized("status_completed")
    static var statusReleased = localized("status_released")
    static var statusDisputed = localized("status_disputed")
    static var statusPublished = localized("status_published")

    // MARK: - Task Detail
    static var taskDetailTitle = localized("task_detail_title")
    static var taskNotFound = localized("task_not_found")
    static var taskNotFoundHint = localized("task_not_found_hint")
    static var taskNoLocation = localized("task_no_location")
    static var taskInProgress = localized("task_in_progress")
    static var taskReceivedSubmit = localized("task_received_submit")
    static var taskWaitReview = localized("task_wait_review")
    static var taskCompletedPaid = localized("task_completed_paid")
    static var taskDisputed = localized("task_disputed_hint")
    static var taskAddPhoto = localized("task_add_photo")
    static var taskSubmitEvidence = localized("task_submit_evidence")
    static var taskEvidence = localized("task_evidence")
    static var taskEvidenceLoadFailed = localized("task_evidence_load_failed")
    static var taskChatTitle = localized("task_chat_title")
    static var taskChatPlaceholder = localized("task_chat_placeholder")
    static var taskChatEmpty = localized("task_chat_empty")
    static var taskClaim = localized("task_claim")
    static var taskClaiming = localized("task_claiming")
    static var taskPublishConfirm = localized("task_publish_confirm")
    static var taskPublishing = localized("task_publishing")
    static var taskBalanceLow = localized("task_balance_low")
    static var taskRechargeHint = localized("task_recharge_hint")
    static var taskQuotaLow = localized("task_quota_low")
    static var taskQuotaHint = localized("task_quota_hint")
    static var taskConfirmPass = localized("task_confirm_pass")
    static var taskRequestMore = localized("task_request_more")
    static var taskSenderPub = localized("task_sender_pub")
    static var taskSenderClaimer = localized("task_sender_claimer")
    static var taskSubmitSuccess = localized("task_submit_success")
    static var taskSubmitFail = localized("task_submit_fail")
    static var taskConfirmPaid = localized("task_confirm_paid")
    static var taskDisputeRequested = localized("task_dispute_requested")
    static var taskClaimedBanner = localized("task_claimed_banner")
    static var taskOpsFailed = localized("task_ops_failed")
    static var taskSendFail = localized("task_send_fail")
    static var taskMsgEmpty = localized("task_msg_empty")
    static var taskEvidencePreview = localized("task_evidence_preview")
    static var taskSendFailRetry = localized("task_send_fail_retry")
    static var taskSubmitFailNetwork = localized("task_submit_fail_network")
    static var taskOpsFailShort = localized("task_ops_fail_short")
    static var taskEvidenceRequested = localized("task_evidence_requested")

    // MARK: - Publish
    static var publishTitle = localized("publish_title")
    static var publishTaskTitle = localized("publish_task_title")
    static var publishTitlePlaceholder = localized("publish_title_placeholder")
    static var publishDescription = localized("publish_description")
    static var publishBountyAmount = localized("publish_bounty_amount")
    static var publishCurrency = localized("publish_currency")
    static var publishCurrencyCNY = localized("publish_currency_cny")
    static var publishCurrencyUSD = localized("publish_currency_usd")
    static var publishAmountPlaceholder = localized("publish_amount_placeholder")
    static var publishBountyTotal = localized("publish_bounty_total")
    static var publishServiceFee = localized("publish_service_fee")
    static var publishTotalPay = localized("publish_total_pay")
    static var publishApproxCNY = localized("publish_approx_cny")
    static var publishTargetLocation = localized("publish_target_location")
    static var publishLocationSelected = localized("publish_location_selected")
    static var publishLocationRequired = localized("publish_location_required")
    static var publishLocationAutoFill = localized("publish_location_auto_fill")
    static var publishLocationManual = localized("publish_location_manual")
    static var publishLocationFailed = localized("publish_location_failed")
    static var publishRadius = localized("publish_radius")
    static var publishTimeLimit = localized("publish_time_limit")
    static var publishTimeUnit = localized("publish_time_unit")
    static var publishSearchAddress = localized("publish_search_address")
    static var publishSearchBtn = localized("publish_search_btn")
    static var publishSearchNotFound = localized("publish_search_not_found")
    static var publishMapDrag = localized("publish_map_drag")
    static var publishLocationPicked = localized("publish_location_picked")
    static var publishConfirmTitle = localized("publish_confirm_title")
    static var publishConfirmUse = localized("publish_confirm_use")
    static var publishConfirmEdit = localized("publish_confirm_edit")
    static var publishConfirmMsg = localized("publish_confirm_msg")
    static var publishPayBtn = localized("publish_pay_btn")
    static var publishQuotaHint = localized("publish_quota_hint")
    static var publishQuotaCost = localized("publish_quota_cost")
    static var publishQuotaDesc = localized("publish_quota_desc")
    static var publishSubmitBtn = localized("publish_submit_btn")
    static var publishNeedLogin = localized("publish_need_login")
    static var publishNeedLocation = localized("publish_need_location")
    static var publishFail = localized("publish_fail")
    static var publishSuccess = localized("publish_success")
    static var publishSuccessPending = localized("publish_success_pending")
    static var publishBalanceLow = localized("publish_balance_low")
    static var publishQuotaLow = localized("publish_quota_low")
    static var publishBadParams = localized("publish_bad_params")
    static var publishExpired = localized("publish_expired")
    static var publishNetworkError = localized("publish_network_error")
    static var publishServerError = localized("publish_server_error")

    // MARK: - My Tasks
    static var myTasksTitle = localized("my_tasks_title")
    static var myTasksPublished = localized("my_tasks_published")
    static var myTasksClaimed = localized("my_tasks_claimed")
    static var myTasksEmptyPub = localized("my_tasks_empty_pub")
    static var myTasksEmptyClaimed = localized("my_tasks_empty_claimed")
    static var myTasksGoSquare = localized("my_tasks_go_square")
    static var myTasksReload = localized("my_tasks_reload")
    static var myTasksPublishNow = localized("my_tasks_publish_now")
    static var myTasksPublishedToast = localized("my_tasks_published_toast")
    static var myTasksPublishFailed = localized("my_tasks_publish_failed")
    static var myTasksLoadFailed = localized("my_tasks_load_failed")

    // MARK: - Messages
    static var messagesTitle = localized("messages_title")
    static var messagesEmpty = localized("messages_empty")
    static var messagesEmptyHint = localized("messages_empty_hint")
    static var messagesReadAll = localized("messages_read_all")
    static var messagesGotIt = localized("messages_got_it")

    // MARK: - Wallet
    static var walletTitle = localized("wallet_title")
    static var walletBalance = localized("wallet_balance")
    static var walletFrozen = localized("wallet_frozen")
    static var walletTotalEarned = localized("wallet_total_earned")
    static var walletWithdraw = localized("wallet_withdraw")
    static var walletRecharge = localized("wallet_recharge")
    static var walletRechargeSim = localized("wallet_recharge_sim")
    static var walletMinWithdraw = localized("wallet_min_withdraw")
    static var walletTransactions = localized("wallet_transactions")
    static var walletHelp = localized("wallet_help")
    static var walletHelpPage = localized("wallet_help_page")
    static var walletWithdrawTitle = localized("wallet_withdraw_title")
    static var walletWithdrawAmount = localized("wallet_withdraw_amount")
    static var walletWithdrawMin = localized("wallet_withdraw_min")
    static var walletWithdrawMethod = localized("wallet_withdraw_method")
    static var walletWithdrawBank = localized("wallet_withdraw_bank")
    static var walletWithdrawPaypal = localized("wallet_withdraw_paypal")
    static var walletWithdrawETA = localized("wallet_withdraw_eta")
    static var walletWithdrawConfirm = localized("wallet_withdraw_confirm")
    static var walletRechargeTitle = localized("wallet_recharge_title")
    static var walletRechargeAmount = localized("wallet_recharge_amount")
    static var walletRechargePlaceholder = localized("wallet_recharge_placeholder")
    static var walletRechargeHint = localized("wallet_recharge_hint")
    static var walletRechargeConfirm = localized("wallet_recharge_confirm")
    static var walletLoadFailed = localized("wallet_load_failed")
    static var walletWithdrawFailed = localized("wallet_withdraw_failed")
    static var walletRechargeFailed = localized("wallet_recharge_failed")
    static var walletAuthExpired = localized("wallet_auth_expired")

    // MARK: - Publish Quota (方案1)
    static var quotaRemainingTitle = localized("quota_remaining_title")
    static var quotaUsedFmt = localized("quota_used_fmt")
    static var quotaBuyButton = localized("quota_buy_button")
    static var quotaPackagesTitle = localized("quota_packages_title")
    static var quotaLoading = localized("quota_loading")
    static var quotaPackageCountFmt = localized("quota_package_count_fmt")
    static var quotaPurchasing = localized("quota_purchasing")
    static var commonClose = localized("common_close")

    // MARK: - StoreKit / Apple IAP
    static var storeProductNotFound = localized("store_product_not_found")
    static var storeUserCancelled = localized("store_user_cancelled")
    static var storePending = localized("store_pending")
    static var storeUnknown = localized("store_unknown")
    static var walletBounty = localized("wallet_bounty")

    // MARK: - Profile
    static var profileTitle = localized("profile_title")
    static var profileWallet = localized("profile_wallet")
    static var profileMyTasks = localized("profile_my_tasks")
    static var profileSettings = localized("profile_settings")
    static var profileHelp = localized("profile_help")
    static var profileTerms = localized("profile_terms")
    static var profilePrivacy = localized("profile_privacy")
    static var profileLogout = localized("profile_logout")
    static var profileLogoutConfirm = localized("profile_logout_confirm")
    static var profileLogoutAction = localized("profile_logout_action")

    // MARK: - Settings
    static var settingsTitle = localized("settings_title")
    static var settingsPermissions = localized("settings_permissions")
    static var settingsNotifications = localized("settings_notifications")
    static var settingsLocation = localized("settings_location")
    static var settingsAbout = localized("settings_about")
    static var settingsVersion = localized("settings_version")
    static var settingsBuild = localized("settings_build")
    static var settingsLanguage = localized("settings_language")
    static var settingsSectionGeneral = localized("settings_section_general")
    static var settingsSectionNotifications = localized("settings_section_notifications")
    static var settingsSectionPrivacy = localized("settings_section_privacy")
    static var settingsPrivacyPolicy = localized("settings_privacy_policy")
    static var settingsTermsOfService = localized("settings_terms_of_service")

    // MARK: - Onboarding
    static var onboardingLangTitle = localized("onboarding_lang_title")
    static var onboardingLangSubtitle = localized("onboarding_lang_subtitle")
    static var onboardingGetStarted = localized("onboarding_get_started")

    // MARK: - Server Settings
    static var serverSettingsTitle = localized("server_settings_title")
    static var serverCurrentHost = localized("server_current_host")
    static var serverPersistHost = localized("server_persist_host")
    static var serverManualIP = localized("server_manual_ip")
    static var serverIPPlaceholder = localized("server_ip_placeholder")
    static var serverSaveApply = localized("server_save_apply")
    static var serverConnectivity = localized("server_connectivity")
    static var serverTestConn = localized("server_test_conn")
    static var serverTesting = localized("server_testing")
    static var serverSaved = localized("server_saved")
    static var serverAddrInvalid = localized("server_addr_invalid")
    static var serverHint = localized("server_hint")
    static var serverHintFooter = localized("server_hint_footer")
    static var serverTimeout = localized("server_timeout")
    static var serverUnreachable = localized("server_unreachable")
    static var serverNoInternet = localized("server_no_internet")
    static var serverOK = localized("server_ok")
    static var serverUnknown = localized("server_unknown")
    static var serverNotTested = localized("server_not_tested")
    static var serverSavedHostFmt = localized("server_saved_host_fmt")

    // MARK: - Review
    static var reviewTitle = localized("review_title")
    static var reviewPrompt = localized("review_prompt")
    static var reviewClaimerInfo = localized("review_claimer_info")
    static var reviewClaimer = localized("review_claimer")
    static var reviewSubmitTime = localized("review_submit_time")
    static var reviewPhotos = localized("review_photos")
    static var reviewNotes = localized("review_notes")
    static var reviewNoSubmission = localized("review_no_submission")
    static var reviewDispute = localized("review_dispute")
    static var reviewConfirmPay = localized("review_confirm_pay")
    static var reviewDisputeTitle = localized("review_dispute_title")
    static var reviewDisputeReason = localized("review_dispute_reason")
    static var reviewDisputeSubmit = localized("review_dispute_submit")

    // MARK: - Network
    static var networkSwitched = localized("network_switched")
    static var networkDisconnected = localized("network_disconnected")

    // MARK: - API Errors
    static var apiServerErrorFmt = localized("api_server_error_fmt")
    static var apiTimeout = localized("api_timeout")
    static var apiCannotConnect = localized("api_cannot_connect")
    static var apiCancelled = localized("api_cancelled")
    static var apiNetworkErrorFmt = localized("api_network_error_fmt")
    static var apiNetworkError = localized("api_network_error")

    // MARK: - Server Settings Detail
    static var serverNotConfigured = localized("server_not_configured")
    static var serverAddrNotSet = localized("server_addr_not_set")
    static var serverSetHint = localized("server_set_hint")
    static var serverDefault = localized("server_default")
    static var serverAddrParseFail = localized("server_addr_parse_fail")
    static var serverTimeoutDetail = localized("server_timeout_detail")
    static var serverCannotConnectDetail = localized("server_cannot_connect_detail")
    static var serverNoInternetDetail = localized("server_no_internet_detail")
    static var serverErrorCodeFmt = localized("server_error_code_fmt")
    static var serverConnSuccessFmt = localized("server_conn_success_fmt")

    // MARK: - Formatting
    static var distanceMeter = localized("distance_meter")
    static var distanceKm = localized("distance_km")
    static var durationHourMin = localized("duration_hour_min")
    static var durationMinSec = localized("duration_min_sec")
    static var durationZero = localized("duration_zero")
    static var countdownSec = localized("countdown_sec")
    static var taskDistanceKm = localized("task_distance_km")
    static var taskTimeMin = localized("task_time_min")

    // MARK: - Camera
    static var cameraTimestampFmt = localized("camera_timestamp_fmt")
    static var cameraGpsFmt = localized("camera_gps_fmt")
    static var cameraPhotoCount = localized("camera_photo_count")

    // MARK: - Login Debug
    static var loginConnectingFmt = localized("login_connecting_fmt")
    static var loginHostErrorFmt = localized("login_host_error_fmt")

    // MARK: - Messages (Mock)
    static var messagesOfferClaimed = localized("messages_offer_claimed")
    static var messagesEvidenceSubmitted = localized("messages_evidence_submitted")
    static var messagesBountyReceived = localized("messages_bounty_received")

    // MARK: - Privacy / GDPR
    static var privacyConsentTitle = localized("privacy_consent_title")
    static var privacyConsentBody = localized("privacy_consent_body")
    static var privacyConsentAgree = localized("privacy_consent_agree")
    static var privacyConsentDisagree = localized("privacy_consent_disagree")

    // MARK: - Country Picker
    static var countryPickerTitle = localized("country_picker_title")
    static var countryPickerSearch = localized("country_picker_search")

    // MARK: - Exchange Rate
    static var exchangeRateLabel = localized("exchange_rate_label")

    // MARK: - Camera
    static var cameraTimestamp = localized("camera_timestamp")
    static var cameraGPS = localized("camera_gps")

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

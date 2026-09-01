import Foundation

/// 集中式多语言管理枚举
/// 用法: Text(L10n.loginEmailPlaceholder)
/// 自动根据系统语言选择对应的 Localizable.strings
enum L10n {
    // MARK: - General
    static var appName: String { localized("app_name") }
    static var appSlogan: String { localized("app_slogan") }
    static var ok: String { localized("ok") }
    static var cancel: String { localized("cancel") }
    static var confirm: String { localized("confirm") }
    static var done: String { localized("done") }
    static var retry: String { localized("retry") }
    static var loading: String { localized("loading") }
    static var delete: String { localized("delete") }
    static var save: String { localized("save") }
    static var search: String { localized("search") }
    static var noData: String { localized("no_data") }
    static var networkError: String { localized("network_error") }
    static var unknownError: String { localized("unknown_error") }
    static var pullRefresh: String { localized("pull_refresh") }

    // MARK: - Login
    static var loginEmailPlaceholder: String { localized("login_email_placeholder") }
    static var loginCodePlaceholder: String { localized("login_code_placeholder") }
    static var loginGetCode: String { localized("login_get_code") }
    static var loginResendCode: String { localized("login_resend_code") }
    static var loginRegister: String { localized("login_register") }
    static var loginVerify: String { localized("login_verify") }
    static var loginRetryAfter: String { localized("login_retry_after") }
    static var loginErrorTitle: String { localized("login_error_title") }
    static var loginAgreementHint: String { localized("login_agreement_hint") }
    static var loginInvalidEmail: String { localized("login_invalid_email") }
    static var loginCodeSent: String { localized("login_code_sent") }
    static var loginCodeSendFailed: String { localized("login_code_send_failed") }
    static var loginFailed: String { localized("login_failed") }
    static var loginAuthFailed: String { localized("login_auth_failed") }
    static var loginServerError: String { localized("login_server_error") }
    static var loginDecodeFailed: String { localized("login_decode_failed") }
    static var loginInvalidURL: String { localized("login_invalid_url") }
    static var loginNetworkFail: String { localized("login_network_fail") }

    // MARK: - Tabs
    static var tabSquare: String { localized("tab_square") }
    static var tabMyTasks: String { localized("tab_my_tasks") }
    static var tabMessages: String { localized("tab_messages") }
    static var tabProfile: String { localized("tab_profile") }

    // MARK: - Square
    static var squareTitle: String { localized("square_title") }
    static var squareSubtitle: String { localized("square_subtitle") }
    static var squareFilterAll: String { localized("square_filter_all") }
    static var squareFilterWithin: String { localized("square_filter_within") }
    static var squareLocating: String { localized("square_locating") }
    static var squareSortDistance: String { localized("square_sort_distance") }
    static var squareSortBeans: String { localized("square_sort_beans") }
    static var squareSortNewest: String { localized("square_sort_newest") }
    static var squareEmpty: String { localized("square_empty") }
    static var squareEmptyHint: String { localized("square_empty_hint") }
    static var squarePublishAction: String { localized("square_publish_action") }

    // MARK: - Task Card
    static var taskCardMinutes: String { localized("task_card_minutes") }

    // MARK: - Task Status
    static var statusPending: String { localized("status_pending") }
    static var statusClaimed: String { localized("status_claimed") }
    static var statusSubmitted: String { localized("status_submitted") }
    static var statusCompleted: String { localized("status_completed") }
    static var statusReleased: String { localized("status_released") }
    static var statusDisputed: String { localized("status_disputed") }
    static var statusPublished: String { localized("status_published") }

    // MARK: - Task Detail
    static var taskDetailTitle: String { localized("task_detail_title") }
    static var taskNotFound: String { localized("task_not_found") }
    static var taskNotFoundHint: String { localized("task_not_found_hint") }
    static var taskNoLocation: String { localized("task_no_location") }
    static var taskInProgress: String { localized("task_in_progress") }
    static var taskReceivedSubmit: String { localized("task_received_submit") }
    static var taskWaitReview: String { localized("task_wait_review") }
    static var taskCompletedPaid: String { localized("task_completed_paid") }
    static var taskDisputed: String { localized("task_disputed_hint") }
    static var taskAddPhoto: String { localized("task_add_photo") }
    static var taskSubmitEvidence: String { localized("task_submit_evidence") }
    static var taskEvidence: String { localized("task_evidence") }
    static var taskEvidenceLoadFailed: String { localized("task_evidence_load_failed") }
    static var taskChatTitle: String { localized("task_chat_title") }
    static var taskChatPlaceholder: String { localized("task_chat_placeholder") }
    static var taskChatEmpty: String { localized("task_chat_empty") }
    static var taskClaim: String { localized("task_claim") }
    static var taskClaiming: String { localized("task_claiming") }
    static var taskPublishConfirm: String { localized("task_publish_confirm") }
    static var taskPublishing: String { localized("task_publishing") }
    static var taskBalanceLow: String { localized("task_balance_low") }
    static var taskRechargeHint: String { localized("task_recharge_hint") }
    static var taskQuotaLow: String { localized("task_quota_low") }
    static var taskQuotaHint: String { localized("task_quota_hint") }
    static var taskConfirmPass: String { localized("task_confirm_pass") }
    static var taskRequestMore: String { localized("task_request_more") }
    static var taskSenderPub: String { localized("task_sender_pub") }
    static var taskSenderClaimer: String { localized("task_sender_claimer") }
    static var taskSubmitSuccess: String { localized("task_submit_success") }
    static var taskSubmitFail: String { localized("task_submit_fail") }
    static var taskConfirmPaid: String { localized("task_confirm_paid") }
    static var taskDisputeRequested: String { localized("task_dispute_requested") }
    static var taskClaimedBanner: String { localized("task_claimed_banner") }
    static var taskOpsFailed: String { localized("task_ops_failed") }
    static var taskSendFail: String { localized("task_send_fail") }
    static var taskMsgEmpty: String { localized("task_msg_empty") }
    static var taskEvidencePreview: String { localized("task_evidence_preview") }
    static var taskSendFailRetry: String { localized("task_send_fail_retry") }
    static var taskSubmitFailNetwork: String { localized("task_submit_fail_network") }
    static var taskOpsFailShort: String { localized("task_ops_fail_short") }
    static var taskEvidenceRequested: String { localized("task_evidence_requested") }

    // MARK: - Publish
    static var publishTitle: String { localized("publish_title") }
    static var publishTaskTitle: String { localized("publish_task_title") }
    static var publishTitlePlaceholder: String { localized("publish_title_placeholder") }
    static var publishDescPlaceholder: String { localized("publish_desc_placeholder") }
    static var publishDescription: String { localized("publish_description") }
    static var publishBountyAmount: String { localized("publish_bounty_amount") }
    static var publishCurrency: String { localized("publish_currency") }
    static var publishCurrencyCNY: String { localized("publish_currency_cny") }
    static var publishCurrencyUSD: String { localized("publish_currency_usd") }
    static var publishAmountPlaceholder: String { localized("publish_amount_placeholder") }
    static var publishBountyTotal: String { localized("publish_bounty_total") }
    static var publishServiceFee: String { localized("publish_service_fee") }
    static var publishTotalPay: String { localized("publish_total_pay") }
    static var publishApproxCNY: String { localized("publish_approx_cny") }
    static var publishTargetLocation: String { localized("publish_target_location") }
    static var publishLocationSelected: String { localized("publish_location_selected") }
    static var publishLocationRequired: String { localized("publish_location_required") }
    static var publishLocationAutoFill: String { localized("publish_location_auto_fill") }
    static var publishLocationManual: String { localized("publish_location_manual") }
    static var publishLocationFailed: String { localized("publish_location_failed") }
    static var publishRadius: String { localized("publish_radius") }
    static var publishTimeLimit: String { localized("publish_time_limit") }
    static var publishTimeUnit: String { localized("publish_time_unit") }
    static var publishSearchAddress: String { localized("publish_search_address") }
    static var publishSearchBtn: String { localized("publish_search_btn") }
    static var publishSearchNotFound: String { localized("publish_search_not_found") }
    static var publishMapDrag: String { localized("publish_map_drag") }
    static var publishLocationPicked: String { localized("publish_location_picked") }
    static var publishConfirmTitle: String { localized("publish_confirm_title") }
    static var publishConfirmUse: String { localized("publish_confirm_use") }
    static var publishConfirmEdit: String { localized("publish_confirm_edit") }
    static var publishConfirmMsg: String { localized("publish_confirm_msg") }
    static var publishPayBtn: String { localized("publish_pay_btn") }
    static var publishQuotaHint: String { localized("publish_quota_hint") }
    static var publishQuotaCost: String { localized("publish_quota_cost") }
    static var publishQuotaDesc: String { localized("publish_quota_desc") }
    static var publishBeansTitle: String { localized("publish_beans_title") }
    static var publishBeansCost: String { localized("publish_beans_cost") }
    static var publishBeansHint: String { localized("publish_beans_hint") }
    static var publishSubmitBtn: String { localized("publish_submit_btn") }
    static var publishNeedLogin: String { localized("publish_need_login") }
    static var publishNeedLocation: String { localized("publish_need_location") }
    static var publishFail: String { localized("publish_fail") }
    static var publishSuccess: String { localized("publish_success") }
    static var publishSuccessPending: String { localized("publish_success_pending") }
    static var publishBalanceLow: String { localized("publish_balance_low") }
    static var publishQuotaLow: String { localized("publish_quota_low") }
    static var publishBadParams: String { localized("publish_bad_params") }
    static var publishExpired: String { localized("publish_expired") }
    static var publishNetworkError: String { localized("publish_network_error") }
    static var publishServerError: String { localized("publish_server_error") }

    // MARK: - My Tasks
    static var myTasksTitle: String { localized("my_tasks_title") }
    static var myTasksPublished: String { localized("my_tasks_published") }
    static var myTasksClaimed: String { localized("my_tasks_claimed") }
    static var myTasksEmptyPub: String { localized("my_tasks_empty_pub") }
    static var myTasksEmptyClaimed: String { localized("my_tasks_empty_claimed") }
    static var myTasksGoSquare: String { localized("my_tasks_go_square") }
    static var myTasksReload: String { localized("my_tasks_reload") }
    static var myTasksPublishNow: String { localized("my_tasks_publish_now") }
    static var myTasksPublishedToast: String { localized("my_tasks_published_toast") }
    static var myTasksPublishFailed: String { localized("my_tasks_publish_failed") }
    static var myTasksLoadFailed: String { localized("my_tasks_load_failed") }
    // 任务管理（批量删除）
    static var myTasksManage: String { localized("my_tasks_manage") }
    static var myTasksDone: String { localized("my_tasks_done") }
    static var myTasksSelectAll: String { localized("my_tasks_select_all") }
    static var myTasksDeselectAll: String { localized("my_tasks_deselect_all") }
    static var myTasksDeleteSelected: String { localized("my_tasks_delete_selected") }
    static var myTasksDeleteConfirmTitle: String { localized("my_tasks_delete_confirm_title") }
    static var myTasksDeleteConfirmMsg: String { localized("my_tasks_delete_confirm_msg") }
    static var myTasksDeleteConfirmAction: String { localized("my_tasks_delete_confirm_action") }
    static var myTasksDeleteConfirmCancel: String { localized("my_tasks_delete_confirm_cancel") }
    static var myTasksDeletedFmt: String { localized("my_tasks_deleted_fmt") }
    static var myTasksDeletedSkippedFmt: String { localized("my_tasks_deleted_skipped_fmt") }
    static var myTasksDeleteFailed: String { localized("my_tasks_delete_failed") }
    // 恢复购买（App Store 3.1.1 合规）
    static var walletRestorePurchases: String { localized("wallet_restore_purchases") }
    static var walletRestoredFmt: String { localized("wallet_restored_fmt") }
    static var walletRestoreAlready: String { localized("wallet_restore_already") }
    static var walletRestoreNothing: String { localized("wallet_restore_nothing") }
    static var walletRestoreFailed: String { localized("wallet_restore_failed") }
    // 删除账户（App Store 5.1.1(v) / GDPR 合规）
    static var profileDeleteAccount: String { localized("profile_delete_account") }
    static var profileDeleteAccountConfirmTitle: String { localized("profile_delete_account_confirm_title") }
    static var profileDeleteAccountConfirmMsg: String { localized("profile_delete_account_confirm_msg") }
    static var profileDeleteAccountAction: String { localized("profile_delete_account_action") }
    static var profileDeleteAccountFailed: String { localized("profile_delete_account_failed") }

    // MARK: - Messages
    static var messagesTitle: String { localized("messages_title") }
    static var messagesEmpty: String { localized("messages_empty") }
    static var messagesEmptyHint: String { localized("messages_empty_hint") }
    static var messagesReadAll: String { localized("messages_read_all") }
    static var messagesGotIt: String { localized("messages_got_it") }

    // MARK: - Wallet
    static var walletTitle: String { localized("wallet_title") }
    static var walletBalance: String { localized("wallet_balance") }
    static var walletFrozen: String { localized("wallet_frozen") }
    static var walletTotalEarned: String { localized("wallet_total_earned") }
    static var walletWithdraw: String { localized("wallet_withdraw") }
    static var walletRecharge: String { localized("wallet_recharge") }
    static var walletRechargeSim: String { localized("wallet_recharge_sim") }
    static var walletMinWithdraw: String { localized("wallet_min_withdraw") }
    static var walletTransactions: String { localized("wallet_transactions") }
    static var walletHelp: String { localized("wallet_help") }
    static var walletHelpPage: String { localized("wallet_help_page") }
    static var walletWithdrawTitle: String { localized("wallet_withdraw_title") }
    static var walletWithdrawAmount: String { localized("wallet_withdraw_amount") }
    static var walletWithdrawMin: String { localized("wallet_withdraw_min") }
    static var walletWithdrawMethod: String { localized("wallet_withdraw_method") }
    static var walletWithdrawBank: String { localized("wallet_withdraw_bank") }
    static var walletWithdrawPaypal: String { localized("wallet_withdraw_paypal") }
    static var walletWithdrawETA: String { localized("wallet_withdraw_eta") }
    static var walletWithdrawConfirm: String { localized("wallet_withdraw_confirm") }
    static var walletRechargeTitle: String { localized("wallet_recharge_title") }
    static var walletRechargeAmount: String { localized("wallet_recharge_amount") }
    static var walletRechargePlaceholder: String { localized("wallet_recharge_placeholder") }
    static var walletRechargeHint: String { localized("wallet_recharge_hint") }
    static var walletRechargeConfirm: String { localized("wallet_recharge_confirm") }
    static var walletLoadFailed: String { localized("wallet_load_failed") }
    static var walletWithdrawFailed: String { localized("wallet_withdraw_failed") }
    static var walletRechargeFailed: String { localized("wallet_recharge_failed") }
    static var walletAuthExpired: String { localized("wallet_auth_expired") }

    // MARK: - Publish Quota (方案1)
    static var quotaRemainingTitle: String { localized("quota_remaining_title") }
    static var quotaUsedFmt: String { localized("quota_used_fmt") }
    static var quotaBuyButton: String { localized("quota_buy_button") }
    static var quotaPackagesTitle: String { localized("quota_packages_title") }
    static var quotaLoading: String { localized("quota_loading") }
    static var quotaPackageCountFmt: String { localized("quota_package_count_fmt") }
    static var quotaPurchasing: String { localized("quota_purchasing") }

    // MARK: - Beans (金豆经济)
    static var beansBalanceTitle: String { localized("beans_balance_title") }
    static var beansBreakdownFmt: String { localized("beans_breakdown_fmt") }
    static var beansBuyButton: String { localized("beans_buy_button") }
    static var beansPackageCountFmt: String { localized("beans_package_count_fmt") }

    // MARK: - Rewards Center (Coming Soon)
    static var rewardsCenterTitle: String { localized("rewards_center_title") }
    static var rewardsCenterSubtitle: String { localized("rewards_center_subtitle") }
    static var rewardsComingSoon: String { localized("rewards_coming_soon") }
    static var rewardsComingSoonMsg: String { localized("rewards_coming_soon_msg") }
    static var rewardsProgressTitle: String { localized("rewards_progress_title") }
    static var rewardsRulesTitle: String { localized("rewards_rules_title") }
    static var rewardsRuleEarnedOnly: String { localized("rewards_rule_earned_only") }
    static var rewardsRuleThreshold: String { localized("rewards_rule_threshold") }
    static var walletBeansSuffix: String { localized("wallet_beans_suffix") }
    static var rewardsTasksSuffix: String { localized("rewards_tasks_suffix") }
    static var rewardsRuleOptions: String { localized("rewards_rule_options") }
    static var rewardsRuleNoTransfer: String { localized("rewards_rule_no_transfer") }
    static var rewardsRuleFinalNote: String { localized("rewards_rule_final_note") }
    static var commonClose: String { localized("common_close") }

    // MARK: - StoreKit / Apple IAP
    static var storeProductNotFound: String { localized("store_product_not_found") }
    static var storeUserCancelled: String { localized("store_user_cancelled") }
    static var storePending: String { localized("store_pending") }
    static var storeUnknown: String { localized("store_unknown") }
    static var walletBounty: String { localized("wallet_bounty") }
    static var walletTxEmptyTitle: String { localized("wallet_tx_empty_title") }
    static var walletTxEmptySubtitle: String { localized("wallet_tx_empty_subtitle") }
    static var walletTxBountyPaid: String { localized("wallet_tx_bounty_paid") }
    static var taskEditTitle: String { localized("task_edit_title") }
    static var taskEditSave: String { localized("task_edit_save") }
    static var taskEditSuccess: String { localized("task_edit_success") }

    // MARK: - Profile
    static var profileTitle: String { localized("profile_title") }
    static var profileWallet: String { localized("profile_wallet") }
    static var profileMyTasks: String { localized("profile_my_tasks") }
    static var profileSettings: String { localized("profile_settings") }
    static var profileHelp: String { localized("profile_help") }
    static var profileTerms: String { localized("profile_terms") }
    static var profilePrivacy: String { localized("profile_privacy") }
    static var profileLogout: String { localized("profile_logout") }
    static var profileLogoutConfirm: String { localized("profile_logout_confirm") }
    static var profileLogoutAction: String { localized("profile_logout_action") }
    static var profileEditName: String { localized("profile_edit_name") }
    static var profileEditNameTitle: String { localized("profile_edit_name_title") }
    static var profileEditNamePlaceholder: String { localized("profile_edit_name_placeholder") }
    static var profileEditNameInvalid: String { localized("profile_edit_name_invalid") }
    static var profileEditNameFailed: String { localized("profile_edit_name_failed") }

    // MARK: - Settings
    static var settingsTitle: String { localized("settings_title") }
    static var settingsPermissions: String { localized("settings_permissions") }
    static var settingsNotifications: String { localized("settings_notifications") }
    static var settingsLocation: String { localized("settings_location") }
    static var settingsAbout: String { localized("settings_about") }
    static var settingsVersion: String { localized("settings_version") }
    static var settingsBuild: String { localized("settings_build") }
    static var settingsLanguage: String { localized("settings_language") }
    static var settingsSectionGeneral: String { localized("settings_section_general") }
    static var settingsSectionNotifications: String { localized("settings_section_notifications") }
    static var settingsSectionPrivacy: String { localized("settings_section_privacy") }
    static var settingsPrivacyPolicy: String { localized("settings_privacy_policy") }
    static var settingsTermsOfService: String { localized("settings_terms_of_service") }

    // MARK: - Onboarding
    static var onboardingLangTitle: String { localized("onboarding_lang_title") }
    static var onboardingLangSubtitle: String { localized("onboarding_lang_subtitle") }
    static var onboardingGetStarted: String { localized("onboarding_get_started") }

    // MARK: - Server Settings
    static var serverSettingsTitle: String { localized("server_settings_title") }
    static var serverCurrentHost: String { localized("server_current_host") }
    static var serverPersistHost: String { localized("server_persist_host") }
    static var serverManualIP: String { localized("server_manual_ip") }
    static var serverIPPlaceholder: String { localized("server_ip_placeholder") }
    static var serverSaveApply: String { localized("server_save_apply") }
    static var serverConnectivity: String { localized("server_connectivity") }
    static var serverTestConn: String { localized("server_test_conn") }
    static var serverTesting: String { localized("server_testing") }
    static var serverSaved: String { localized("server_saved") }
    static var serverAddrInvalid: String { localized("server_addr_invalid") }
    static var serverHint: String { localized("server_hint") }
    static var serverHintFooter: String { localized("server_hint_footer") }
    static var serverTimeout: String { localized("server_timeout") }
    static var serverUnreachable: String { localized("server_unreachable") }
    static var serverNoInternet: String { localized("server_no_internet") }
    static var serverOK: String { localized("server_ok") }
    static var serverUnknown: String { localized("server_unknown") }
    static var serverNotTested: String { localized("server_not_tested") }
    static var serverSavedHostFmt: String { localized("server_saved_host_fmt") }

    // MARK: - Review
    static var reviewTitle: String { localized("review_title") }
    static var reviewPrompt: String { localized("review_prompt") }
    static var reviewClaimerInfo: String { localized("review_claimer_info") }
    static var reviewClaimer: String { localized("review_claimer") }
    static var reviewSubmitTime: String { localized("review_submit_time") }
    static var reviewPhotos: String { localized("review_photos") }
    static var reviewNotes: String { localized("review_notes") }
    static var reviewNoSubmission: String { localized("review_no_submission") }
    static var reviewDispute: String { localized("review_dispute") }
    static var reviewConfirmPay: String { localized("review_confirm_pay") }
    static var reviewDisputeTitle: String { localized("review_dispute_title") }
    static var reviewDisputeReason: String { localized("review_dispute_reason") }
    static var reviewDisputeSubmit: String { localized("review_dispute_submit") }

    // MARK: - Network
    static var networkSwitched: String { localized("network_switched") }
    static var networkDisconnected: String { localized("network_disconnected") }

    // MARK: - API Errors
    static var apiServerErrorFmt: String { localized("api_server_error_fmt") }
    static var apiTimeout: String { localized("api_timeout") }
    static var apiCannotConnect: String { localized("api_cannot_connect") }
    static var apiCancelled: String { localized("api_cancelled") }
    static var apiNetworkErrorFmt: String { localized("api_network_error_fmt") }
    static var apiNetworkError: String { localized("api_network_error") }

    // MARK: - Server Settings Detail
    static var serverNotConfigured: String { localized("server_not_configured") }
    static var serverAddrNotSet: String { localized("server_addr_not_set") }
    static var serverSetHint: String { localized("server_set_hint") }
    static var serverDefault: String { localized("server_default") }
    static var serverAddrParseFail: String { localized("server_addr_parse_fail") }
    static var serverTimeoutDetail: String { localized("server_timeout_detail") }
    static var serverCannotConnectDetail: String { localized("server_cannot_connect_detail") }
    static var serverNoInternetDetail: String { localized("server_no_internet_detail") }
    static var serverErrorCodeFmt: String { localized("server_error_code_fmt") }
    static var serverConnSuccessFmt: String { localized("server_conn_success_fmt") }

    // MARK: - Formatting
    static var distanceMeter: String { localized("distance_meter") }
    static var distanceKm: String { localized("distance_km") }
    static var distanceFt: String { localized("distance_ft") }
    static var distanceMi: String { localized("distance_mi") }
    static var durationHourMin: String { localized("duration_hour_min") }
    static var durationMinSec: String { localized("duration_min_sec") }
    static var durationZero: String { localized("duration_zero") }
    static var countdownSec: String { localized("countdown_sec") }
    static var taskDistanceKm: String { localized("task_distance_km") }
    static var taskTimeMin: String { localized("task_time_min") }

    // MARK: - Camera
    static var cameraTimestampFmt: String { localized("camera_timestamp_fmt") }
    static var cameraGpsFmt: String { localized("camera_gps_fmt") }
    static var cameraPhotoCount: String { localized("camera_photo_count") }

    // MARK: - Login Debug
    static var loginConnectingFmt: String { localized("login_connecting_fmt") }
    static var loginHostErrorFmt: String { localized("login_host_error_fmt") }

    // MARK: - Messages (Mock)
    static var messagesOfferClaimed: String { localized("messages_offer_claimed") }
    static var messagesEvidenceSubmitted: String { localized("messages_evidence_submitted") }
    static var messagesBountyReceived: String { localized("messages_bounty_received") }

    // MARK: - Privacy / GDPR
    static var privacyConsentTitle: String { localized("privacy_consent_title") }
    static var privacyConsentBody: String { localized("privacy_consent_body") }
    static var privacyConsentAgree: String { localized("privacy_consent_agree") }
    static var privacyConsentDisagree: String { localized("privacy_consent_disagree") }
    static var privacyConsentRequired: String { localized("privacy_consent_required") }
    static var webviewInvalidUrl: String { localized("webview_invalid_url") }

    // MARK: - Country Picker
    static var countryPickerTitle: String { localized("country_picker_title") }
    static var countryPickerSearch: String { localized("country_picker_search") }

    // MARK: - Exchange Rate
    static var exchangeRateLabel: String { localized("exchange_rate_label") }

    // MARK: - Camera
    static var cameraTimestamp: String { localized("camera_timestamp") }
    static var cameraGPS: String { localized("camera_gps") }

    // MARK: - Helper
    private static func localized(_ key: String) -> String {
        let selectedLanguage = LanguageManager.shared.currentCode
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return NSLocalizedString(key, comment: "")
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

package i18n

// enMessages — English message bundle
var enMessages = map[string]string{
	// --- General ---
	"invalid_email":            "Invalid email address",
	"device_id_invalid":        "Device ID is invalid",
	"image_data_invalid":        "Image data is invalid",
	"code_expired":             "Verification code has expired, please request a new one",
	"code_invalid":             "Verification code is incorrect",
	"code_max_attempts":        "Too many failed attempts, please request a new verification code",
	"rate_limited":             "Too many requests, please try again later",
	"email_send_failed":        "Failed to send verification code",
	"code_sent":                "Verification code sent",
	"bad_request":              "Invalid request parameters",
	"unauthorized":             "Unauthorized, please log in again",
	"internal_error":           "Internal server error",
	"not_found":                "Not found",
	"not_owner":                "You do not own this resource",

	// --- User ---
	"user_not_found":            "User not found",
	"target_user_not_found":     "Target user not found",
	"register_failed":           "Registration failed",
	"token_generate_failed":     "Failed to generate token",
	"device_id_required":        "Device ID is required",
	"nickname_required":         "Nickname is required",
	"default_nickname":          "Hunter%s",

	// --- Auth ---
	"auth_header_missing":       "Authorization header is required",
	"auth_scheme_invalid":       "Invalid authorization scheme",
	"token_parse_failed":        "Failed to parse token",

	// --- Task ---
	"task_not_found":            "Task not found",
	"task_create_failed":        "Failed to create task",
	"task_activate_failed":      "Failed to activate task",
	"task_status_invalid":       "Task status does not allow this operation",
	"task_not_permitted":        "Not authorized to perform this operation",
	"task_already_claimed":      "Task has already been claimed",
	"task_submitted":            "Task already submitted",
	"task_completed":            "Task is already completed",
	"task_closed":               "Task has been closed",
	"cannot_claim_own":          "You cannot claim your own task",
	"max_concurrent_tasks":      "Max %d concurrent active tasks",
	"not_claimer":               "You are not the claimer of this task",
	"not_publisher":             "You are not the publisher of this task",
	"not_in_radius":             "Current location is not within the task radius",
	"submission_save_failed":    "Failed to save submission",
	"no_location":               "No location provided",

	// --- Balance / Payment ---
	"insufficient_funds":        "Insufficient balance",
	"insufficient_balance_detail": "Insufficient balance: need approx ¥%.2f (bounty + fee), current ¥%.2f",
	"freeze_balance_failed":     "Failed to freeze balance",
	"unfreeze_deduct_failed":    "Failed to unfreeze and deduct bounty",
	"bounty_payout_failed":      "Failed to pay out bounty",
	"refund_failed":             "Failed to process refund",
	"low_balance":               "Insufficient balance, please recharge",
	"invalid_amount":            "Invalid amount",

	// --- Recharge ---
	"recharge_min_amount":       "Recharge amount must be greater than 0",
	"recharge_failed":           "Recharge failed",
	"recharge_txn_failed":       "Failed to write recharge transaction record",
	"recharge_simulated":        "Account recharge (simulated)",

	// --- Publish Quota (方案1) ---
	"package_not_found":         "Quota package not found",
	"order_not_found":           "Recharge order not found",
	"invalid_receipt":           "Invalid receipt",
	"service_unavailable":       "Service temporarily unavailable",
	"quota_spend_failed":        "Failed to consume publish quota",
	"insufficient_quota":        "Insufficient publish quota, please recharge",

	// --- Wallet / Withdraw ---
	"withdraw_below_min":        "Withdrawal amount is below the minimum",
	"frozen_not_available":      "Frozen balance is not available for withdrawal",
	"transaction_not_found":     "Transaction not found",
	"wallet_withdraw_insufficient": "Insufficient balance, available: ¥%.2f",
	"deduct_failed":             "Failed to deduct from balance",
	"withdraw_to_channel":       "Withdrawal to %s: %s",

	// --- File ---
	"file_empty":                "File is empty",
	"file_too_large":            "File is too large",
	"unsupported_image_format":  "Unsupported image format (allowed: JPEG, PNG, GIF, WebP)",
	"url_not_allowed":           "Links are not allowed in messages",
	"image_url_not_allowed":     "Image URL must point to this app's storage",
	"file_type_not_allowed":     "File type is not allowed",
	"upload_failed":             "Upload failed",

	// --- Notification titles & bodies (stored in DB) ---
	"notif_task_claimed_title":  "Task Claimed",
	"notif_task_claimed_body":   "Your task \"%s\" has been claimed",
	"notif_task_submitted_title": "Evidence Submitted",
	"notif_task_submitted_body": "Evidence for task \"%s\" has been submitted, please review",
	"notif_bounty_received_title": "Bounty Received",
	"notif_bounty_received_body": "Bounty ¥%.2f for task \"%s\" has been deposited",
	"notif_task_abandoned_title": "Task Abandoned",
	"notif_task_abandoned_body": "The claimer has abandoned task \"%s\", it has been re-published",
	"notif_task_disputed_title":  "Task Disputed",
	"notif_task_disputed_body":   "Task \"%s\" has been disputed by the publisher, awaiting support",
	"notif_task_refunded_title":  "Task Refunded",
	"notif_task_refunded_body":   "Task \"%s\" has been refunded, ¥%.2f returned to your balance",

	// --- DB transaction remark ---
	"txn_bounty_transfer":       "Task completed, bounty transferred",
	"txn_refunded":              "Task returned, full refund",

	// --- Handler response messages ---
	"publish_pending_hint":      "Published, insufficient balance. Recharge then confirm in My Tasks",
	"task_published":            "Task published, waiting for claimers",
	"task_claimed_ok":           "Task claimed",
	"task_abandoned_ok":         "Task abandoned",
	"task_cancelled_ok":         "Task cancelled",
	"evidence_submitted":        "Evidence submitted",
	"evidence_submitted_msg":    "Evidence submitted, waiting for review",
	"evidence_submitted_with_note": "Evidence submitted (note: %s), waiting for review",
	"payment_confirmed":         "Payment confirmed",
	"dispute_submitted":         "Dispute submitted, support will review",
	"load_tasks_failed":         "Failed to load tasks",
	"content_empty":             "Content is empty",
	"send_message_failed":       "Failed to send message: %s",
	"get_messages_failed":       "Failed to get messages: %s",
	"load_wallet_failed":        "Failed to load wallet",
	"withdraw_submitted":        "Withdrawal submitted, estimated T+1",
	"recharge_success":          "Recharge successful (simulated)",
	"load_transactions_failed":  "Failed to load transactions",
	"load_notifications_failed": "Failed to load notifications",
	"operation_failed":          "Operation failed",
	"mark_all_read":             "All marked as read",
	"mark_read":                 "Marked as read",
}

// zhMessages — Simplified Chinese message bundle
var zhMessages = map[string]string{
	// --- General ---
	"invalid_email":             "邮箱格式不正确",
	"device_id_invalid":         "设备标识无效",
	"image_data_invalid":         "图片数据无效",
	"code_expired":              "验证码已过期，请重新获取",
	"code_invalid":              "验证码错误",
	"code_max_attempts":         "尝试次数过多，请重新获取验证码",
	"rate_limited":              "操作过于频繁，请稍后再试",
	"email_send_failed":         "验证码发送失败",
	"code_sent":                 "验证码已发送",
	"bad_request":               "参数不正确",
	"unauthorized":              "未授权，请重新登录",
	"internal_error":            "服务器内部错误",
	"not_found":                 "未找到",
	"not_owner":                 "您不是该资源的拥有者",

	// --- User ---
	"user_not_found":             "用户不存在",
	"target_user_not_found":      "目标用户不存在",
	"register_failed":            "注册失败",
	"token_generate_failed":      "生成令牌失败",
	"device_id_required":         "设备ID不能为空",
	"nickname_required":          "昵称不能为空",
	"default_nickname":           "赏金猎人%s",

	// --- Auth ---
	"auth_header_missing":        "缺少授权头",
	"auth_scheme_invalid":        "授权方案无效",
	"token_parse_failed":         "令牌解析失败",

	// --- Task ---
	"task_not_found":             "任务不存在",
	"task_create_failed":         "创建任务失败",
	"task_activate_failed":       "激活任务失败",
	"task_status_invalid":        "任务状态不允许此操作",
	"task_not_permitted":         "无权操作此任务",
	"task_already_claimed":       "任务已被领取",
	"task_submitted":             "任务已提交",
	"task_completed":             "任务已完成",
	"task_closed":                "任务已关闭",
	"cannot_claim_own":           "不能领取自己发布的任务",
	"max_concurrent_tasks":       "最多同时持有 %d 个进行中任务",
	"not_claimer":                "您不是该任务的接单人",
	"not_publisher":              "您不是该任务的发布者",
	"not_in_radius":              "当前位置不在任务范围内",
	"submission_save_failed":     "保存提交失败",
	"no_location":                "未提供位置信息",

	// --- Balance / Payment ---
	"insufficient_funds":          "余额不足",
	"insufficient_balance_detail": "余额不足，需要约 ¥%.2f（赏金 + 手续费），当前余额 ¥%.2f",
	"freeze_balance_failed":       "冻结余额失败",
	"unfreeze_deduct_failed":      "解冻并扣除赏金失败",
	"bounty_payout_failed":        "发放赏金失败",
	"refund_failed":               "退款失败",
	"low_balance":                 "余额不足，请充值",
	"invalid_amount":              "金额无效",

	// --- Recharge ---
	"recharge_min_amount":         "充值金额必须大于 0",
	"recharge_failed":             "充值失败",
	"recharge_txn_failed":         "充值流水写入失败",
	"recharge_simulated":          "账户充值（模拟）",

	// --- Publish Quota (方案1) ---
	"package_not_found":           "额度套餐不存在",
	"order_not_found":             "充值订单不存在",
	"invalid_receipt":             "凭证无效",
	"service_unavailable":         "服务暂不可用",
	"quota_spend_failed":          "消耗发布额度失败",
	"insufficient_quota":          "发布额度不足，请充值",

	// --- Wallet / Withdraw ---
	"withdraw_below_min":          "提现金额低于最低限额",
	"frozen_not_available":        "冻结余额不可用",
	"transaction_not_found":       "交易记录不存在",
	"wallet_withdraw_insufficient": "余额不足，当前可提现 ¥%.2f",
	"deduct_failed":               "扣款失败",
	"withdraw_to_channel":         "提现到%s: %s",

	// --- File ---
	"file_empty":                  "文件为空",
	"file_too_large":              "文件过大",
	"unsupported_image_format":    "不支持的图片格式（仅允许 JPEG、PNG、GIF、WebP）",
	"url_not_allowed":             "消息中不允许包含链接",
	"image_url_not_allowed":       "图片地址必须指向本应用的存储空间",
	"file_type_not_allowed":       "文件类型不允许",
	"upload_failed":               "上传失败",

	// --- Notification ---
	"notif_task_claimed_title":    "任务已被领取",
	"notif_task_claimed_body":     "您的任务「%s」已被领取",
	"notif_task_submitted_title":  "任务已提交证据",
	"notif_task_submitted_body":   "任务「%s」已有接单人提交证据，请及时审核",
	"notif_bounty_received_title": "赏金已到账",
	"notif_bounty_received_body":  "任务「%s」的赏金 ¥%.2f 已到账",
	"notif_task_abandoned_title":  "任务已放弃",
	"notif_task_abandoned_body":   "接单人已放弃任务「%s」，任务已重新发布",
	"notif_task_disputed_title":   "任务存在争议",
	"notif_task_disputed_body":    "任务「%s」被发布人提出异议，请等待客服处理",
	"notif_task_refunded_title":   "任务已退款",
	"notif_task_refunded_body":    "任务「%s」已退回，¥%.2f 已返还",

	// --- DB transaction remark ---
	"txn_bounty_transfer":         "任务完成，赏金划转",
	"txn_refunded":                "任务退回，全额退款",

	// --- Handler response messages ---
	"publish_pending_hint":        "已创建，余额不足请充值后在「我的任务」确认发布",
	"task_published":              "任务已发布，等待猎人领取",
	"task_claimed_ok":             "任务已领取",
	"task_abandoned_ok":           "已放弃任务",
	"task_cancelled_ok":           "已撤回任务",
	"evidence_submitted":          "证据已提交",
	"evidence_submitted_msg":      "证据已提交，等待审核",
	"evidence_submitted_with_note": "证据已提交（备注：%s），等待审核",
	"payment_confirmed":           "赏金已发放",
	"dispute_submitted":           "争议已提交，客服将介入处理",
	"load_tasks_failed":           "加载任务失败",
	"content_empty":               "内容不能为空",
	"send_message_failed":         "发送消息失败: %s",
	"get_messages_failed":         "获取消息失败: %s",
	"load_wallet_failed":          "获取钱包失败",
	"withdraw_submitted":          "提现已提交，预计T+1到账",
	"recharge_success":            "充值成功（模拟）",
	"load_transactions_failed":    "加载交易记录失败",
	"load_notifications_failed":   "加载通知失败",
	"operation_failed":            "操作失败",
	"mark_all_read":               "已全部标记已读",
	"mark_read":                   "已标记已读",
}


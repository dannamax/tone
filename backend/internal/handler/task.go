package handler

import (
	"fmt"

	"seeker/internal/middleware"
	"seeker/internal/model"
	"seeker/internal/repository"
	"seeker/internal/service"
	"seeker/internal/validator"
	"seeker/pkg/i18n"
	"seeker/pkg/response"

	"github.com/gin-gonic/gin"
)

type TaskHandler struct {
	taskSvc      *service.TaskService
	subSvc       *service.SubmissionService
	paySvc       *service.PaymentService
	messageRepo  *repository.MessageRepo
	allowedImageBases []string
}

func NewTaskHandler(taskSvc *service.TaskService, subSvc *service.SubmissionService, paySvc *service.PaymentService, messageRepo *repository.MessageRepo, allowedImageBases []string) *TaskHandler {
	return &TaskHandler{taskSvc: taskSvc, subSvc: subSvc, paySvc: paySvc, messageRepo: messageRepo, allowedImageBases: allowedImageBases}
}

func (h *TaskHandler) Square(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	var req model.SquareListRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	tasks, total, err := h.taskSvc.SquareList(c.Request.Context(), &req)
	if err != nil {
		response.InternalError(c, err.Error())
		return
	}

	response.Paginated(c, tasks, total, req.DefaultPage(), req.DefaultSize())
}

// EditTask 编辑未被领取的任务（发布者本人）。
func (h *TaskHandler) EditTask(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	var req model.PublishTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}
	if req.Title == "" {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}
	if req.TargetAddr == "" && (req.TargetLat == 0 && req.TargetLng == 0) {
		response.BadRequest(c, i18n.T(lang, "no_location"))
		return
	}

	task, err := h.taskSvc.UpdateTask(c.Request.Context(), taskID, userID, &req)
	if err != nil {
		if taskErr, ok := err.(*service.TaskError); ok {
			if taskErr.Code == service.ErrInsufficientQuota {
				response.PaymentRequired(c, taskErr.Message)
				return
			}
			if taskErr.Code == service.ErrTaskNotFound {
				response.NotFound(c, taskErr.Message)
				return
			}
		}
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, task)
}

func (h *TaskHandler) Publish(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	var req model.PublishTaskRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	if req.Title == "" {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}
	// 既无地址也无坐标才视为缺少位置信息（OR -> AND 语义修正）
	if req.TargetAddr == "" && (req.TargetLat == 0 && req.TargetLng == 0) {
		response.BadRequest(c, i18n.T(lang, "no_location"))
		return
	}

	userID := middleware.GetUserID(c)

	task, err := h.taskSvc.Publish(c.Request.Context(), userID, &req)
	if err != nil {
		if taskErr, ok := err.(*service.TaskError); ok && taskErr.Code == service.ErrInsufficientQuota {
			response.PaymentRequired(c, taskErr.Message)
			return
		}
		response.BadRequest(c, err.Error())
		return
	}

	fmt.Printf("[TaskPublish] userID=%s taskID=%s title=%s beans=%d\n", userID, task.ID, task.Title, task.BountyBeans)

	response.Created(c, task)
}

func (h *TaskHandler) Activate(c *gin.Context) {
	// 方案1（额度制）：任务在 Publish 时已直接发布，无需二次激活。
	// 保留该接口以兼容旧版前端调用，直接返回成功。
	response.SuccessWithMessage(c, i18n.T(i18n.LanguageFromRequest(c.Request), "task_published"), nil)
}

func (h *TaskHandler) Get(c *gin.Context) {
	taskID := c.Param("id")
	task, err := h.taskSvc.GetTask(c.Request.Context(), taskID)
	if err != nil {
		response.NotFound(c, err.Error())
		return
	}
	response.Success(c, task)
}

func (h *TaskHandler) Claim(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	// 定向领取：必须携带领取者当前位置（不在围栏内一律拒绝）
	var req model.ClaimRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "not_in_radius", 0))
		return
	}

	if err := h.taskSvc.Claim(c.Request.Context(), taskID, userID, &req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, i18n.T(lang, "task_claimed_ok"), nil)
}

func (h *TaskHandler) Submit(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	var req model.SubmitEvidenceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	submission, err := h.taskSvc.Submit(c.Request.Context(), taskID, userID, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	msg := &model.TaskMessage{
		TaskID:    taskID,
		SenderID:  userID,
		Content:   i18n.T(lang, "evidence_submitted_msg"),
		ImageURLs: []string{},
	}
	if req.Note != nil && *req.Note != "" {
		if validator.ContainsURL(*req.Note) {
			response.BadRequest(c, i18n.T(lang, "url_not_allowed"))
			return
		}
		msg.Content = i18n.T(lang, "evidence_submitted_with_note", *req.Note)
	}
	_, _ = h.messageRepo.Create(c.Request.Context(), msg)

	response.SuccessWithMessage(c, i18n.T(lang, "evidence_submitted"), submission)
}

func (h *TaskHandler) Confirm(c *gin.Context) {
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	if err := h.paySvc.ConfirmTask(c.Request.Context(), taskID, userID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, i18n.T(i18n.LanguageFromRequest(c.Request), "payment_confirmed"), nil)
}

func (h *TaskHandler) Dispute(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	var req struct {
		Reason string `json:"reason" binding:"required,min=1,max=500"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	if err := h.paySvc.DisputeTask(c.Request.Context(), taskID, userID, req.Reason); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, i18n.T(lang, "dispute_submitted"), nil)
}

// RequestChanges 发布人"要求补充证据"：任务回退 claimed，接单人可修改后重新提交。
func (h *TaskHandler) RequestChanges(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	var req struct {
		Reason string `json:"reason" binding:"required,min=1,max=500"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	if err := h.taskSvc.RequestChanges(c.Request.Context(), taskID, userID, req.Reason); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, i18n.T(lang, "changes_requested"), nil)
}

func (h *TaskHandler) Abandon(c *gin.Context) {
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)
	lang := i18n.LanguageFromRequest(c.Request)

	// 先查任务，区分发布人撤回 / 接单人放弃
	task, err := h.taskSvc.GetTask(c.Request.Context(), taskID)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	if task == nil {
		response.NotFound(c, i18n.T(lang, "task_not_found"))
		return
	}

	if task.PublisherID == userID {
		// 发布人撤回自己发布的任务（回收额度）
		if err := h.paySvc.CancelByPublisher(c.Request.Context(), taskID, userID); err != nil {
			response.BadRequest(c, err.Error())
			return
		}
		response.SuccessWithMessage(c, i18n.T(lang, "task_cancelled_ok"), nil)
		return
	}

	// 接单人放弃已认领的任务
	if err := h.paySvc.AbandonTask(c.Request.Context(), taskID, userID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "task_abandoned_ok"), nil)
}

func (h *TaskHandler) MyTasks(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	userID := middleware.GetUserID(c)
	tab := c.DefaultQuery("tab", "published")
	page := 1
	size := 20
	fmt.Sscanf(c.DefaultQuery("page", "1"), "%d", &page)
	fmt.Sscanf(c.DefaultQuery("size", "20"), "%d", &size)
	if page <= 0 {
		page = 1
	}
	if size <= 0 {
		size = 20
	}

	if tab == "claimed" {
		tasks, total, err := h.taskSvc.GetClaimedTasks(c.Request.Context(), userID, page, size)
		if err != nil {
			response.InternalError(c, i18n.T(lang, "load_tasks_failed"))
			return
		}
		response.Paginated(c, tasks, total, page, size)
		return
	}

	tasks, total, err := h.taskSvc.GetPublishedTasks(c.Request.Context(), userID, page, size)
	if err != nil {
		response.InternalError(c, i18n.T(lang, "load_tasks_failed"))
		return
	}
	response.Paginated(c, tasks, total, page, size)
}

// GetSubmission 获取任务提交证据
func (h *TaskHandler) GetSubmission(c *gin.Context) {
	taskID := c.Param("id")
	sub, err := h.subSvc.GetByTaskID(c.Request.Context(), taskID)
	if err != nil {
		response.NotFound(c, err.Error())
		return
	}
	response.Success(c, sub)
}

// Delete 发布人删除单个任务
func (h *TaskHandler) Delete(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	result, err := h.taskSvc.DeleteTasks(c.Request.Context(), userID, []string{taskID})
	if err != nil {
		fmt.Printf("[TaskDelete] userID=%s taskID=%s err=%v\n", userID, taskID, err)
		response.BadRequest(c, i18n.T(lang, "task_delete_failed"))
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "task_deleted"), result)
}

// BatchDelete 发布人批量删除任务（未认领任务自动退豆，进行中任务跳过）
func (h *TaskHandler) BatchDelete(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)

	var req struct {
		TaskIDs []string `json:"task_ids" binding:"required,min=1,max=100"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	result, err := h.taskSvc.DeleteTasks(c.Request.Context(), middleware.GetUserID(c), req.TaskIDs)
	if err != nil {
		response.BadRequest(c, i18n.T(lang, "task_delete_failed"))
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "task_deleted"), result)
}

func (h *TaskHandler) SendMessage(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	var req model.SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}
	if req.Content == "" && len(req.ImageURLs) == 0 {
		response.BadRequest(c, i18n.T(lang, "content_empty"))
		return
	}

	// Reject any embedded links in chat text (anti-spam / anti-phishing).
	if validator.ContainsURL(req.Content) {
		response.BadRequest(c, i18n.T(lang, "url_not_allowed"))
		return
	}

	// Only allow image URLs that belong to this app's own storage.
	for _, u := range req.ImageURLs {
		if !validator.IsAllowedImageURL(u, h.allowedImageBases) {
			response.BadRequest(c, i18n.T(lang, "image_url_not_allowed"))
			return
		}
	}

	msg := &model.TaskMessage{
		TaskID:    taskID,
		SenderID:  userID,
		Content:   req.Content,
		ImageURLs: []string{},
	}
	if len(req.ImageURLs) > 0 {
		msg.ImageURLs = req.ImageURLs
	}

	created, err := h.messageRepo.Create(c.Request.Context(), msg)
	if err != nil {
		response.InternalError(c, i18n.T(lang, "send_message_failed", err.Error()))
		return
	}

	fmt.Printf("[Message] taskID=%s senderID=%s contentLen=%d images=%d\n", taskID, userID, len(created.Content), len(created.ImageURLs))
	response.Created(c, created)
}

func (h *TaskHandler) GetMessages(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	taskID := c.Param("id")
	msgs, err := h.messageRepo.FindByTaskID(c.Request.Context(), taskID)
	if err != nil {
		response.InternalError(c, i18n.T(lang, "get_messages_failed", err.Error()))
		return
	}
	response.Paginated(c, msgs, int64(len(msgs)), 1, max(len(msgs), 1))
}

// Refund 争议后发布人确认退款，冻结金额退回发布人余额
func (h *TaskHandler) Refund(c *gin.Context) {
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)
	lang := i18n.LanguageFromRequest(c.Request)

	if err := h.paySvc.RefundTask(c.Request.Context(), taskID, userID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.SuccessWithMessage(c, i18n.T(lang, "task_refund_ok"), nil)
}

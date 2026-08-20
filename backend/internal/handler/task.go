package handler

import (
	"fmt"

	"seeker/internal/middleware"
	"seeker/internal/model"
	"seeker/internal/repository"
	"seeker/internal/service"
	"seeker/pkg/i18n"
	"seeker/pkg/response"

	"github.com/gin-gonic/gin"
)

type TaskHandler struct {
	taskSvc     *service.TaskService
	subSvc      *service.SubmissionService
	paySvc      *service.PaymentService
	messageRepo *repository.MessageRepo
}

func NewTaskHandler(taskSvc *service.TaskService, subSvc *service.SubmissionService, paySvc *service.PaymentService, messageRepo *repository.MessageRepo) *TaskHandler {
	return &TaskHandler{taskSvc: taskSvc, subSvc: subSvc, paySvc: paySvc, messageRepo: messageRepo}
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
	if req.TargetAddr == "" || (req.TargetLat == 0 && req.TargetLng == 0) {
		response.BadRequest(c, i18n.T(lang, "no_location"))
		return
	}

	userID := middleware.GetUserID(c)

	task, err := h.taskSvc.Publish(c.Request.Context(), userID, &req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	fmt.Printf("[TaskPublish] userID=%s taskID=%s title=%s status=%s\n", userID, task.ID, task.Title, task.Status)

	if task.Status == model.StatusPending {
		response.CreatedWithMessage(c, i18n.T(lang, "publish_pending_hint"), task)
		return
	}
	response.Created(c, task)
}

func (h *TaskHandler) Activate(c *gin.Context) {
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	if err := h.taskSvc.ActivateTask(c.Request.Context(), userID, taskID); err != nil {
		if taskSvcErr, ok := err.(*service.TaskError); ok && taskSvcErr.Code == service.ErrInsufficientBalance {
			response.PaymentRequired(c, err.Error())
			return
		}
		response.BadRequest(c, err.Error())
		return
	}

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
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	if err := h.taskSvc.Claim(c.Request.Context(), taskID, userID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, i18n.T(i18n.LanguageFromRequest(c.Request), "task_claimed_ok"), nil)
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

func (h *TaskHandler) Abandon(c *gin.Context) {
	taskID := c.Param("id")
	userID := middleware.GetUserID(c)

	if err := h.paySvc.AbandonTask(c.Request.Context(), taskID, userID); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, i18n.T(i18n.LanguageFromRequest(c.Request), "task_abandoned_ok"), nil)
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

func (h *TaskHandler) GetSubmission(c *gin.Context) {
	taskID := c.Param("id")
	sub, err := h.subSvc.GetByTaskID(c.Request.Context(), taskID)
	if err != nil {
		response.NotFound(c, err.Error())
		return
	}
	response.Success(c, sub)
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

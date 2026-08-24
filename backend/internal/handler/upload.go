package handler

import (
	"encoding/base64"
	"fmt"
	"path"
	"strings"
	"time"

	"seeker/internal/model"
	"seeker/internal/storage"
	"seeker/pkg/i18n"
	"seeker/pkg/response"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type UploadHandler struct {
	store storage.Storage
}

func NewUploadHandler(store storage.Storage) *UploadHandler {
	return &UploadHandler{store: store}
}

func (h *UploadHandler) Upload(c *gin.Context) {
	lang := i18n.LanguageFromRequest(c.Request)
	var req model.UploadImageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, i18n.T(lang, "bad_request"))
		return
	}

	// Strip data URI prefix if present (e.g. data:image/...;base64,xxx)
	b64 := req.Base64
	if idx := strings.Index(b64, ","); idx != -1 {
		b64 = b64[idx+1:]
	}

	data, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		response.BadRequest(c, i18n.T(lang, "image_data_invalid"))
		return
	}

	// Max 10MB
	if len(data) > 10*1024*1024 {
		response.BadRequest(c, i18n.T(lang, "file_too_large"))
		return
	}

	contentType := "image/jpeg"
	ext := ".jpg"
	// 简单检测 PNG 头部
	if len(data) > 4 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
		ext = ".png"
		contentType = "image/png"
	} else if len(data) > 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
		// JPEG 起始标记，保持默认
	}

	key := fmt.Sprintf("%s_%d%s", uuid.NewString(), time.Now().UnixNano(), ext)
	url, err := h.store.Save(path.Base(key), data, contentType)
	if err != nil {
		fmt.Printf("[Upload] save failed: %v\n", err)
		response.InternalError(c, i18n.T(lang, "upload_failed"))
		return
	}

	fmt.Printf("[Upload] saved %s (%d bytes) -> %s\n", key, len(data), url)
	response.Success(c, model.UploadImageResponse{URL: url})
}

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

	if len(data) == 0 {
		response.BadRequest(c, i18n.T(lang, "image_data_invalid"))
		return
	}

	// Max 5MB (App Store review-safe, COS cost-friendly)
	const maxUploadSize = 5 * 1024 * 1024
	if len(data) > maxUploadSize {
		response.BadRequest(c, i18n.T(lang, "file_too_large"))
		return
	}

	// Strict MIME validation by magic bytes. Reject anything that is not a
	// real image (prevents uploading HTML/JS/SVG disguised as an image).
	contentType, ext := detectImageFormat(data)
	if contentType == "" {
		response.BadRequest(c, i18n.T(lang, "unsupported_image_format"))
		return
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

// detectImageFormat sniffs the image magic bytes and returns the corresponding
// MIME type and file extension. Returns ("", "") if the data is not a supported
// image format.
func detectImageFormat(data []byte) (contentType, ext string) {
	if len(data) < 4 {
		return "", ""
	}
	// PNG: 89 50 4E 47
	if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
		return "image/png", ".png"
	}
	// JPEG: FF D8 FF
	if data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
		return "image/jpeg", ".jpg"
	}
	// GIF: 47 49 46 38 (GIF87a / GIF89a)
	if data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x38 {
		return "image/gif", ".gif"
	}
	// WebP: 52 49 46 46 ?? ?? ?? ?? 57 45 42 50 (RIFF....WEBP)
	if len(data) >= 12 &&
		data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
		data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50 {
		return "image/webp", ".webp"
	}
	return "", ""
}

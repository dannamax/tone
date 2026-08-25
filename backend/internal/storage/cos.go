package storage

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"net/url"
	"path/filepath"
	"strings"
	"time"

	"github.com/tencentyun/cos-go-sdk-v5"
)

// COSStorage stores objects in Tencent Cloud Object Storage (COS).
type COSStorage struct {
	client *cos.Client
	bucket string
	region string
	// publicBase is the publicly reachable base URL of the bucket, e.g.
	// https://seekerhub-1301056533.cos.ap-hongkong.myqcloud.com
	publicBase string
}

// NewCOSStorage builds a COS client from permanent API credentials.
//   - secretID / secretKey: Tencent Cloud API credentials
//     (injected via env in production, never committed to source)
//   - bucket: bucket name, e.g. "seekerhub-1301056533"
//   - region: bucket region, e.g. "ap-hongkong"
func NewCOSStorage(secretID, secretKey, bucket, region string) (*COSStorage, error) {
	if bucket == "" || region == "" {
		return nil, fmt.Errorf("cos: bucket and region are required")
	}
	host := fmt.Sprintf("%s.cos.%s.myqcloud.com", bucket, region)
	raw := fmt.Sprintf("https://%s/", host)
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("cos: invalid bucket host: %w", err)
	}

	baseURL := &cos.BaseURL{BucketURL: u}
	client := cos.NewClient(baseURL, &http.Client{
		Timeout: 60 * time.Second,
		Transport: &cos.AuthorizationTransport{
			SecretID:  secretID,
			SecretKey: secretKey,
		},
	})

	return &COSStorage{
		client:     client,
		bucket:     bucket,
		region:     region,
		publicBase: fmt.Sprintf("https://%s", host),
	}, nil
}

func (s *COSStorage) Save(key string, data []byte, contentType string) (string, error) {
	// Defense in depth: only ever serve images inline. Even if a non-image
	// content type were somehow passed, force image/* + Content-Disposition
	// so browsers never render uploaded objects as HTML/JS (stored XSS / SVG
	// script execution risk).
	if !strings.HasPrefix(contentType, "image/") {
		contentType = "application/octet-stream"
	}
	disp := fmt.Sprintf("inline; filename=%q", filepath.Base(key))
	opt := &cos.ObjectPutOptions{
		ObjectPutHeaderOptions: &cos.ObjectPutHeaderOptions{
			ContentType: contentType,
			// 任务/头像图片需公网可读（前端 AsyncImage 直链加载），
			// 故对象级设为公有读，桶本身保持私有。
			XOptionHeader: &http.Header{
				"x-cos-acl":            []string{"public-read"},
				"Content-Disposition": []string{disp},
			},
		},
	}
	// PutFromFile-style upload via reader.
	_, err := s.client.Object.Put(context.Background(), key, bytes.NewReader(data), opt)
	if err != nil {
		return "", fmt.Errorf("cos: put object %s: %w", key, err)
	}
	return s.URL(key), nil
}

func (s *COSStorage) Delete(key string) error {
	_, err := s.client.Object.Delete(context.Background(), key)
	if err != nil {
		return fmt.Errorf("cos: delete object %s: %w", key, err)
	}
	return nil
}

func (s *COSStorage) URL(key string) string {
	return fmt.Sprintf("%s/%s", s.publicBase, key)
}

// PublicBase returns the COS bucket's public base URL.
func (s *COSStorage) PublicBase() string {
	return s.publicBase
}

package storage

import (
	"os"
	"path/filepath"
)

// LocalStorage stores objects on the local filesystem and serves them via a
// static file route. Suitable for development and CI; not for multi-replica
// production deployments.
type LocalStorage struct {
	dir  string
	base string // public base path, e.g. "/uploads"
}

// NewLocalStorage creates the upload directory if needed.
func NewLocalStorage(dir, base string) *LocalStorage {
	_ = os.MkdirAll(dir, 0755)
	return &LocalStorage{dir: dir, base: base}
}

func (s *LocalStorage) Save(key string, data []byte, contentType string) (string, error) {
	full := filepath.Join(s.dir, key)
	if err := os.WriteFile(full, data, 0644); err != nil {
		return "", err
	}
	return s.URL(key), nil
}

func (s *LocalStorage) Delete(key string) error {
	return os.Remove(filepath.Join(s.dir, key))
}

func (s *LocalStorage) URL(key string) string {
	return s.base + "/" + key
}

// Package storage abstracts object storage so the upload handler can target
// either local disk (development / CI) or a remote object store (Tencent COS
// in production) behind a single interface.
package storage

// Storage is the object-storage contract used by the upload handler.
type Storage interface {
	// Save writes data under the given object key and returns the publicly
	// accessible URL. The caller owns key generation (e.g. uuid + timestamp).
	Save(key string, data []byte, contentType string) (url string, err error)
	// Delete removes an object by key. It is best-effort; errors are surfaced
	// to the caller but should not block the request lifecycle.
	Delete(key string) error
	// URL returns the public URL for a previously stored key.
	URL(key string) string
	// PublicBase returns the public base URL (or path) that stored objects
	// live under, used to validate user-supplied image URLs.
	PublicBase() string
}

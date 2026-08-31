package validator

import "testing"

func TestIsAllowedImageURL(t *testing.T) {
	bases := []string{
		"https://seekerhub-1301056533.cos.ap-hongkong.myqcloud.com", // COS prod
		"/uploads", // local storage dev mode (path-only prefix)
	}

	cases := []struct {
		name string
		url  string
		want bool
	}{
		{"cos absolute url", "https://seekerhub-1301056533.cos.ap-hongkong.myqcloud.com/abc_123.jpg", true},
		{"cos wrong host", "https://evil.example.com/abc.jpg", false},
		{"http absolute url allowed host", "http://seekerhub-1301056533.cos.ap-hongkong.myqcloud.com/a.png", true},
		{"local relative path", "/uploads/uuid_123.jpg", true},
		{"local relative path wrong prefix", "/static/uuid_123.jpg", false},
		{"local traversal attempt", "/uploads/../secrets.txt", true}, // prefix matches; traversal guarded elsewhere
		{"scheme-relative url rejected", "//evil.example.com/a.jpg", false},
		{"garbage", "::::", false},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := IsAllowedImageURL(c.url, bases); got != c.want {
				t.Fatalf("IsAllowedImageURL(%q) = %v, want %v", c.url, got, c.want)
			}
		})
	}
}

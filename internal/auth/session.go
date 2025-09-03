// internal/auth/session.go
package auth

import (
	"encoding/base64"
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
)

type Session struct {
	UserID    uuid.UUID
	ActiveOrg uuid.UUID
	Provider  string
	Expiry    time.Time
}

func SetSessionCookie(w http.ResponseWriter, s Session) {
	b, _ := json.Marshal(s)
	http.SetCookie(w, &http.Cookie{
		Name:     "sess",
		Value:    base64.RawStdEncoding.EncodeToString(b),
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		Expires:  s.Expiry,
	})
}

func ReadSession(r *http.Request) *Session {
	c, err := r.Cookie("sess")
	if err != nil {
		return nil
	}
	b, err := base64.RawStdEncoding.DecodeString(c.Value)
	if err != nil {
		return nil
	}
	var s Session
	if json.Unmarshal(b, &s) != nil {
		return nil
	}
	if s.Expiry.Before(time.Now()) {
		return nil
	}
	return &s
}

// internal/auth/session.go
package auth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"time"

	"yourapp/internal/models"
)

type ctxKeyUser struct{}
type ctxKeySession struct{}

type ctxKey string

var (
	ctxOrg  ctxKey = "org"
	ctxSess ctxKey = "session"
)

func SetSessionCookie(w http.ResponseWriter, s models.Session) {
	b, _ := json.Marshal(s)
	http.SetCookie(w, &http.Cookie{
		Name:     "session",
		Value:    base64.RawStdEncoding.EncodeToString(b),
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		Expires:  s.Expiry,
	})
}

func ReadSession(r *http.Request) *models.Session {
	c, err := r.Cookie("session")
	if err != nil {
		return nil
	}
	b, err := base64.RawStdEncoding.DecodeString(c.Value)
	if err != nil {
		return nil
	}
	var s models.Session
	if json.Unmarshal(b, &s) != nil {
		return nil
	}
	if s.Expiry.Before(time.Now()) {
		return nil
	}
	return &s
}

func OrgFromContext(ctx context.Context) models.Org {
	val := ctx.Value(ctxOrg)
	if val == nil {
		return models.Org{}
	}
	return val.(models.Org)
}

func UserFromContext(ctx context.Context) (*models.User, bool) {
	val := ctx.Value(ctxKeyUser{})
	if val == nil {
		return nil, false
	}
	return val.(*models.User), true
}

func SessionFromContext(ctx context.Context) (*models.Session, bool) {
	val := ctx.Value(ctxSess)
	if val == nil {
		return nil, false
	}
	return val.(*models.Session), true
}

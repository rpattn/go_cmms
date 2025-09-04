// internal/auth/session.go
package auth

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"time"

	"yourapp/internal/models"

	"github.com/google/uuid"
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

func OrgFromContext(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(ctxOrg).(uuid.UUID)
	return id, ok
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

func WithUser(ctx context.Context, u *models.User) context.Context {
	return context.WithValue(ctx, ctxKeyUser{}, u)
}

func WithOrg(ctx context.Context, id uuid.UUID) context.Context {
	return context.WithValue(ctx, ctxOrg, id)
}

func GetUserFromContext(ctx context.Context) (*models.User, bool) {
	u, ok := ctx.Value(ctxKeyUser{}).(*models.User)
	return u, ok
}

func WithSession(ctx context.Context, s *models.Session) context.Context {
	return context.WithValue(ctx, ctxKeySession{}, s)
}

func GetSessionFromContext(ctx context.Context) (*models.Session, bool) {
	s, ok := ctx.Value(ctxKeySession{}).(*models.Session)
	return s, ok
}

package middleware

import (
	"context"
	"net/http"

	"yourapp/internal/auth"
	"yourapp/internal/models"
	"yourapp/internal/repo"
)

type ctxKeyUser struct{}
type ctxKeySession struct{}

func WithUser(ctx context.Context, u *models.User) context.Context {
	return context.WithValue(ctx, ctxKeyUser{}, u)
}

func GetUserFromContext(ctx context.Context) (*models.User, bool) {
	u, ok := ctx.Value(ctxKeyUser{}).(*models.User)
	return u, ok
}

func WithSession(ctx context.Context, s *auth.Session) context.Context {
	return context.WithValue(ctx, ctxKeySession{}, s)
}

func GetSessionFromContext(ctx context.Context) (*auth.Session, bool) {
	s, ok := ctx.Value(ctxKeySession{}).(*auth.Session)
	return s, ok
}

// RequireAuth authenticates using the "sess" cookie (auth.ReadSession),
// then loads the user by Session.UserID from the repo and injects both
// session and user into the context.
func RequireAuth(r repo.Repo) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			s := auth.ReadSession(req)
			if s == nil {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}

			user, err := r.GetUserByID(req.Context(), s.UserID)
			if err != nil {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}

			ctx := WithSession(req.Context(), s)
			ctx = WithUser(ctx, &user)
			next.ServeHTTP(w, req.WithContext(ctx))
		})
	}
}

// internal/middleware/org_context.go
package middleware

import (
	"context"
	"net/http"

	"github.com/go-chi/chi/v5"
	//"github.com/google/uuid"

	"yourapp/internal/auth"
	"yourapp/internal/models"
	"yourapp/internal/repo"
)

type ctxKey string

var (
	ctxOrg  ctxKey = "org"
	ctxSess ctxKey = "sess"
)

func OrgContext(r repo.Repo) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			sess := auth.ReadSession(req)
			if sess == nil {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}
			slug := chi.URLParam(req, "slug")
			org, err := r.FindOrgBySlug(req.Context(), slug)
			if err != nil || org.ID != sess.ActiveOrg {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}
			ctx := context.WithValue(req.Context(), ctxOrg, org)
			ctx = context.WithValue(ctx, ctxSess, sess)
			next.ServeHTTP(w, req.WithContext(ctx))
		})
	}
}

func OrgFromContext(ctx context.Context) models.Org {
	val := ctx.Value(ctxOrg)
	if val == nil {
		return models.Org{}
	}
	return val.(models.Org)
}

func SessionFromContext(ctx context.Context) *auth.Session {
	val := ctx.Value(ctxSess)
	if val == nil {
		return nil
	}
	return val.(*auth.Session)
}

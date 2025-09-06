package middleware

import (
    "context"
    "net/http"
    "github.com/google/uuid"
)

// ctxKeyRequestID is the context key type for request IDs.
type ctxKeyRequestID struct{}

// RequestID ensures each request has a request ID.
// It reads X-Request-ID if provided; otherwise, it generates a UUID.
// The value is stored in context and also set in the response header.
func RequestID(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        rid := r.Header.Get("X-Request-ID")
        if rid == "" {
            rid = uuid.NewString()
        }
        ctx := context.WithValue(r.Context(), ctxKeyRequestID{}, rid)
        w.Header().Set("X-Request-ID", rid)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}


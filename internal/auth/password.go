package auth

import (
    "encoding/json"
    "net/http"
    "strings"

    "yourapp/internal/config"
    "yourapp/internal/repo"
)

// SetPasswordHandler sets or updates the local password for the current user session.
// POST /auth/set-password { "password": "..." }
func SetPasswordHandler(r repo.Repo, cfg config.Config) http.HandlerFunc {
    type bodyT struct { Password string `json:"password"` }
    return func(w http.ResponseWriter, req *http.Request) {
        sess := ReadSession(req)
        if sess == nil {
            http.Error(w, "unauthorized", http.StatusUnauthorized)
            return
        }
        var b bodyT
        if err := json.NewDecoder(req.Body).Decode(&b); err != nil || len(b.Password) < 8 {
            http.Error(w, "bad json or weak password", http.StatusBadRequest)
            return
        }
        phc, err := HashPassword(b.Password, defaultArgonParams())
        if err != nil {
            http.Error(w, "hash error", http.StatusInternalServerError)
            return
        }
        // Try update; if credential doesn't exist, create with username = email
        if err := r.UpdateLocalPasswordHash(req.Context(), sess.UserID, phc); err != nil {
            // Fallback: create local credential if missing
            // Need user email to set username
            u, uerr := r.GetUserByID(req.Context(), sess.UserID)
            if uerr != nil {
                http.Error(w, "user not found", http.StatusInternalServerError)
                return
            }
            if u.Email == "" {
                http.Error(w, "user has no email", http.StatusBadRequest)
                return
            }
            if cerr := r.CreateLocalCredential(req.Context(), sess.UserID, u.Email, phc); cerr != nil {
                http.Error(w, "cannot set credential", http.StatusInternalServerError)
                return
            }
        }
        // Compute redirect destination
        base := strings.TrimRight(cfg.Frontend.URL, "/")
        path := cfg.Frontend.PostLoginPath
        if strings.TrimSpace(path) == "" { path = "/app/work-orders" }
        if !strings.HasPrefix(path, "/") { path = "/" + path }
        redirectURL := path
        if base != "" { redirectURL = base + path }

        // If caller expects navigation (HTML) or explicitly asks, perform redirect
        if strings.Contains(req.Header.Get("Accept"), "text/html") || req.URL.Query().Get("redirect") == "1" || req.URL.Query().Get("navigate") == "1" {
            http.Redirect(w, req, redirectURL, http.StatusSeeOther)
            return
        }
        // Otherwise return JSON with redirect hint
        writeJSON(w, http.StatusOK, map[string]any{"ok": true, "redirect": redirectURL})
    }
}

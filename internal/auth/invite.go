package auth

import (
    "crypto/rand"
    "crypto/sha256"
    "encoding/base64"
    "encoding/hex"
    "encoding/json"
    "net/http"
    neturl "net/url"
    "strings"
    "time"

    "yourapp/internal/models"
    "yourapp/internal/repo"
)

// InviteCreateHandler: Owners can invite users to current org.
// POST /auth/invite { "email": "user@example.com", "role": "Member" }
// Returns a one-time token (plaintext) for delivery via email. The token is hashed at rest.
func InviteCreateHandler(r repo.Repo) http.HandlerFunc {
    type bodyT struct {
        Email string `json:"email"`
        Role  string `json:"role"` // optional; defaults to Member
    }
    return func(w http.ResponseWriter, req *http.Request) {
        sess := ReadSession(req)
        if sess == nil {
            http.Error(w, "unauthorized", http.StatusUnauthorized)
            return
        }
        var b bodyT
        if err := json.NewDecoder(req.Body).Decode(&b); err != nil || strings.TrimSpace(b.Email) == "" {
            http.Error(w, "bad json", http.StatusBadRequest)
            return
        }
        role := models.RoleMember
        if strings.TrimSpace(b.Role) != "" {
            switch strings.ToLower(b.Role) {
            case strings.ToLower(string(models.RoleViewer)):
                role = models.RoleViewer
            case strings.ToLower(string(models.RoleMember)):
                role = models.RoleMember
            case strings.ToLower(string(models.RoleAdmin)):
                role = models.RoleAdmin
            case strings.ToLower(string(models.RoleOwner)):
                // Disallow creating Owner via invite for safety
                http.Error(w, "invalid role", http.StatusBadRequest)
                return
            default:
                http.Error(w, "invalid role", http.StatusBadRequest)
                return
            }
        }
        // Generate token (plaintext) and store a SHA-256 hash
        raw := make([]byte, 32)
        if _, err := rand.Read(raw); err != nil {
            http.Error(w, "server error", http.StatusInternalServerError)
            return
        }
        token := base64.RawURLEncoding.EncodeToString(raw)
        sum := sha256.Sum256([]byte(token))
        tokenHash := hex.EncodeToString(sum[:])
        // Expiry: 7 days
        exp := time.Now().Add(7 * 24 * time.Hour)
        if err := r.CreateInvite(req.Context(), sess.ActiveOrg, sess.UserID, strings.ToLower(strings.TrimSpace(b.Email)), role, tokenHash, exp); err != nil {
            http.Error(w, "create invite failed", http.StatusInternalServerError)
            return
        }
        // Build an acceptance link; prefer same-origin convenience route
        scheme := req.Header.Get("X-Forwarded-Proto")
        if scheme == "" { scheme = "http" }
        host := req.Header.Get("X-Forwarded-Host")
        if host == "" { host = req.Host }
        acceptURL := scheme + "://" + host + "/invite/accept?token=" + neturl.QueryEscape(token)
        writeJSON(w, http.StatusOK, map[string]any{
            "ok":          true,
            "accept_url":  acceptURL,
            "exp":         exp,
            "role":        role,
        })
    }
}

// InviteAcceptHandler: Accepts an invite token for the logged-in user (email must match invite).
// POST /auth/invite/accept { "token": "..." }
func InviteAcceptHandler(r repo.Repo) http.HandlerFunc {
    type bodyT struct{ Token string `json:"token"` }
    return func(w http.ResponseWriter, req *http.Request) {
        var b bodyT
        if err := json.NewDecoder(req.Body).Decode(&b); err != nil || strings.TrimSpace(b.Token) == "" {
            http.Error(w, "bad json", http.StatusBadRequest)
            return
        }
        sess := ReadSession(req)
        if sess == nil {
            http.Error(w, "unauthorized", http.StatusUnauthorized)
            return
        }
        // Lookup invite by token hash
        sum := sha256.Sum256([]byte(b.Token))
        tokenHash := hex.EncodeToString(sum[:])
        inv, err := r.GetInviteByTokenHash(req.Context(), tokenHash)
        if err != nil {
            http.Error(w, "invalid invite", http.StatusBadRequest)
            return
        }
        if !inv.UsedAt.IsZero() || time.Now().After(inv.ExpiresAt) {
            http.Error(w, "invite expired or used", http.StatusBadRequest)
            return
        }
        // Ensure current user email matches invite email (case-insensitive)
        u, err := r.GetUserByID(req.Context(), sess.UserID)
        if err != nil || strings.ToLower(u.Email) != strings.ToLower(inv.Email) {
            http.Error(w, "email mismatch", http.StatusForbidden)
            return
        }
        // Add membership with invited role
        if _, err := r.EnsureMembership(req.Context(), inv.OrgID, sess.UserID, inv.Role); err != nil {
            http.Error(w, "membership failed", http.StatusInternalServerError)
            return
        }
        // Mark invite as used
        if err := r.UseInvite(req.Context(), tokenHash); err != nil {
            http.Error(w, "invite update failed", http.StatusInternalServerError)
            return
        }
        // Switch session to invited org
        SetSessionCookie(w, models.Session{
            UserID:    sess.UserID,
            ActiveOrg: inv.OrgID,
            Provider:  sess.Provider,
            Expiry:    time.Now().Add(8 * time.Hour),
        })
        writeJSON(w, http.StatusOK, map[string]any{"ok": true})
    }
}

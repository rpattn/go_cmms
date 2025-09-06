// internal/handlers/teams/teams.go
package teams

import (
    "encoding/json"
    "net/http"

    "yourapp/internal/auth"
    httpserver "yourapp/internal/http"
    "yourapp/internal/repo"
)

type Handler struct {
    repo repo.Repo
}

func New(repo repo.Repo) *Handler {
    return &Handler{repo: repo}
}

// Search handles searching for teams based on query parameters.
func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
    orgID, ok := auth.OrgFromContext(r.Context())
    if !ok {
        httpserver.JSON(w, http.StatusUnauthorized, map[string]string{
            "error": "unauthorized",
        })
        return
    }

    defer r.Body.Close()
    var body map[string]any
    dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20)) // 1MB
    if err := dec.Decode(&body); err != nil {
        httpserver.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON: " + err.Error()})
        return
    }
    if dec.More() {
        httpserver.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON (extra content)"})
        return
    }

    payload, err := json.Marshal(body)
    if err != nil {
        httpserver.JSON(w, http.StatusBadRequest, map[string]string{"error": "failed to encode payload"})
        return
    }

    teams, err := h.repo.SearchTeams(r.Context(), orgID, payload)
    if err != nil {
        httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
            "error": "failed to search teams",
        })
        return
    }

    httpserver.JSON(w, http.StatusOK, map[string]any{
        "content": teams,
    })
}


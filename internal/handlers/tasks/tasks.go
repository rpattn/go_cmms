// internal/handlers/workorders/controller.go
package tasks

import (
	"fmt"
	"net/http"
	"yourapp/internal/auth"
	httpserver "yourapp/internal/http"
	"yourapp/internal/repo"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type Handler struct {
	repo repo.Repo
}

func New(repo repo.Repo) *Handler {
	return &Handler{repo: repo}
}

func (h *Handler) GetByWOID(w http.ResponseWriter, r *http.Request) {
	// Get org_id from context (set by middleware)
	org_id, ok := auth.OrgFromContext(r.Context())
	if !ok {
		httpserver.JSON(w, http.StatusUnauthorized, map[string]string{
			"error": "unauthorized",
		})
		return
	}
	// 1. Parse workOrderID from URL
	idStr := chi.URLParam(r, "workOrderID")
	wo_id, err := uuid.Parse(idStr)
	if err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid work order ID",
		})
		return
	}
	fmt.Printf("Fetching tasks for work order ID: %s\n", idStr)
	// 2. Fetch tasks from the repository
	tasks, err := h.repo.ListSimpleTasksByWorkOrderID(r.Context(), org_id, wo_id)
	if err != nil {
		//fmt.Printf("Error fetching tasks: %v\n", err)
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to fetch tasks",
		})
		return
	}
	//fmt.Printf("Fetched %d tasks\n", len(tasks))
	// 3. Return tasks as JSON response
	httpserver.JSON(w, http.StatusOK, tasks)
}

func (h *Handler) GetByWOIDFull(w http.ResponseWriter, r *http.Request) {
	// Get org_id from context (set by middleware)
	org_id, ok := auth.OrgFromContext(r.Context())
	if !ok {
		httpserver.JSON(w, http.StatusUnauthorized, map[string]string{
			"error": "unauthorized",
		})
		return
	}
	// 1. Parse workOrderID from URL
	idStr := chi.URLParam(r, "workOrderID")
	wo_id, err := uuid.Parse(idStr)
	if err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid work order ID",
		})
		return
	}
	fmt.Printf("Fetching tasks for work order ID: %s\n", idStr)
	// 2. Fetch tasks from the repository
	tasks, err := h.repo.GetTasksByWorkOrderID(r.Context(), org_id, wo_id)
	if err != nil {
		//fmt.Printf("Error fetching tasks: %v\n", err)
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to fetch tasks",
		})
		return
	}
	//fmt.Printf("Fetched %d tasks\n", len(tasks))
	// 3. Return tasks as JSON response
	httpserver.JSON(w, http.StatusOK, tasks)
}

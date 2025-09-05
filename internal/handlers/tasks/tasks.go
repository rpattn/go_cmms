// internal/handlers/workorders/controller.go
package tasks

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
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
	//fmt.Printf("Fetching tasks for work order ID: %s\n", idStr)
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

// Additional handlers for creating, updating, deleting tasks can be added here.
func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	httpserver.JSON(w, http.StatusCreated, map[string]string{
		"message": "create task",
	})
}

func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	httpserver.JSON(w, http.StatusOK, map[string]string{
		"message": "update task",
	})
}

func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	// Get org_id from context (set by middleware)
	org_id, ok := auth.OrgFromContext(r.Context())
	if !ok {
		httpserver.JSON(w, http.StatusUnauthorized, map[string]string{
			"error": "unauthorized",
		})
		return
	}
	// 1. Parse task from URL
	idStr := chi.URLParam(r, "taskID")
	t_id, err := uuid.Parse(idStr)
	if err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid task ID",
		})
		return
	}
	// 2. Call repo to delete task
	err = h.repo.DeleteTaskByID(r.Context(), org_id, t_id)
	if err != nil {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to delete task",
		})
		return
	}
	httpserver.JSON(w, http.StatusOK, map[string]string{
		"message": "task deleted",
	})
}

func (h *Handler) MarkComplete(w http.ResponseWriter, r *http.Request) {
	// Get org_id from context (set by middleware)
	org_id, ok := auth.OrgFromContext(r.Context())
	if !ok {
		httpserver.JSON(w, http.StatusUnauthorized, map[string]string{
			"error": "unauthorized",
		})
		return
	}
	// 1. Parse task from URL
	idStr := chi.URLParam(r, "taskID")
	t_id, err := uuid.Parse(idStr)
	if err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid task ID",
		})
		return
	}
	// 2. Call repo to mark task complete
	updatedTask, err := h.repo.MarkTaskComplete(r.Context(), org_id, t_id)
	if err != nil {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to mark task complete",
		})
		return
	}
	httpserver.JSON(w, http.StatusOK, updatedTask)
}

func (h *Handler) ToggleComplete(w http.ResponseWriter, r *http.Request) {
	// 0. Get org_id from context (set by middleware)
	org_id, ok := auth.OrgFromContext(r.Context())
	if !ok {
		httpserver.JSON(w, http.StatusUnauthorized, map[string]string{
			"error": "unauthorized",
		})
		return
	}

	// 1. Parse task ID from URL
	idStr := chi.URLParam(r, "taskID")
	t_id, err := uuid.Parse(idStr)
	if err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid task ID",
		})
		return
	}

	// 2. Parse request body
	var req struct {
		Value string `json:"value"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid request body",
		})
		return
	}

	// 3. Convert value string -> bool
	var complete bool
	switch strings.ToLower(req.Value) {
	case "true", "1", "yes", "complete":
		complete = true
	case "false", "0", "no", "open":
		complete = false
	default:
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid value, must be 'true' or 'false'",
		})
		return
	}

	// 4. Call repo
	updatedTask, err := h.repo.ToggleTaskComplete(r.Context(), org_id, t_id, complete)
	if err != nil {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to toggle task complete",
		})
		return
	}

	// 5. Return result
	httpserver.JSON(w, http.StatusOK, updatedTask)
}

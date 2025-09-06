// internal/handlers/workorders/controller.go
package work_orders

import (
	"encoding/json"
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

type SortDirection string

const (
	DirectionASC  SortDirection = "ASC"
	DirectionDESC SortDirection = "DESC"
)

type SearchRequest struct {
	PageNum      int `json:"pageNum"`
	PageSize     int `json:"pageSize"`
	FilterFields []struct {
		Field     string      `json:"field"`
		Operation string      `json:"operation"`
		Value     interface{} `json:"value"`
		Values    []string    `json:"values"`
		EnumName  string      `json:"enumName"`
	} `json:"filterFields,omitempty"`

	// NEW
	SortField string        `json:"sortField,omitempty"`
	Direction SortDirection `json:"direction,omitempty"` // "ASC" | "DESC"
}

type StatusRequest struct {
	Status string `json:"status"` // e.g., "open", "in_progress", "completed"
}

func (h *Handler) FilterSearch(w http.ResponseWriter, r *http.Request) {
	// get org from context
	org, ok := auth.OrgFromContext(r.Context())
	if !ok {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to get org from context",
		})
		return
	}

	// parse body into SearchRequest
	var req SearchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid request body",
		})
		return
	}

	// encode to raw []byte for query
	arg, err := json.Marshal(req)
	if err != nil {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to encode search request",
		})
		return
	}

	// call the sqlc query
	wos, err := h.repo.ListWorkOrdersPaged(r.Context(), arg)
	if err != nil {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to search work orders",
		})
		return
	}

	httpserver.JSON(w, http.StatusOK, map[string]any{
		"message": "search work orders",
		"org":     org, // optional: include org id/slug
		"content": wos,
	})
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	// Placeholder implementation
	// Example Query Parameters:
	/*
		{
			"title": "Title",
			"priority": "LOW",
			"description": "Description Here",
			"dueDate": "2025-09-18",
			"estimatedStartDate": "2025-09-07",
			"estimatedDuration": 20,
			"requiredSignature": false
			"primary_worker": "user-uuid-here",
			"location": "location-uuid-here",
			"asset": "asset-uuid-here",
			"assigned_to": ["uuid", "uuid"],
			"customers": ["uuid", "uuid"],
		}
	*/
	orgID, ok := auth.OrgFromContext(r.Context())
	if !ok {
		httpserver.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	user, ok := auth.UserFromContext(r.Context()) // or however you store user id
	if !ok {
		httpserver.JSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}

	// 1) Decode JSON body
	defer r.Body.Close()
	var body map[string]any
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20)) // 1MB cap
	// dec.DisallowUnknownFields() // enable if you want to reject unknown keys
	if err := dec.Decode(&body); err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON: " + err.Error()})
		return
	}
	// Optional: ensure there’s no trailing junk
	if dec.More() {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON (extra content)"})
		return
	}

	// 2) Minimal validation (title required)
	if t, ok := body["title"].(string); !ok || strings.TrimSpace(t) == "" {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{"error": "title is required"})
		return
	}

	// 3) Marshal back to raw JSON for SQL function
	payload, err := json.Marshal(body)
	if err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{"error": "failed to encode payload"})
		return
	}

	// Call the sqlc query
	id, err := h.repo.CreateWorkOrderFromJSON(r.Context(), orgID, user.ID, payload)
	if err != nil {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to create work order",
		})
		return
	}
	httpserver.JSON(w, http.StatusOK, map[string]any{
		"message": "created work order",
		"id":      id,
	})
}

func (h *Handler) GetByID(w http.ResponseWriter, r *http.Request) {
	// 1. Parse workOrderID from URL
	idStr := chi.URLParam(r, "workOrderID")
	id, err := uuid.Parse(idStr)
	if err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid work order ID",
		})
		return
	}

	// 2. Call repo
	ctx := r.Context()
	wo, err := h.repo.GetWorkOrderDetail(ctx, id)
	if err != nil {
		// You might want to distinguish sql.ErrNoRows here
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
		return
	}
	if len(wo) == 0 {
		httpserver.JSON(w, http.StatusNotFound, map[string]string{
			"error": "work order not found",
		})
		return
	}

	// 3. Send the JSON document returned from DB directly
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(wo)
}

// GET /work-orders
func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	httpserver.JSON(w, http.StatusOK, map[string]any{
		"message": "list work orders",
		"data":    []string{}, // placeholder for an array of work orders
	})
}

// PUT /work-orders/{workOrderID}
func (h *Handler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "workOrderID")

	httpserver.JSON(w, http.StatusOK, map[string]any{
		"message": "update work order",
		"id":      id,
	})
}

// DELETE /work-orders/{workOrderID}
func (h *Handler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "workOrderID")

	httpserver.JSON(w, http.StatusOK, map[string]any{
		"message": "deleted work order",
		"id":      id,
	})
}

// PATCH /work-orders/{workOrderID}/change-status
func (h *Handler) ChangeStatus(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "workOrderID")
	id, err := uuid.Parse(idStr)
	if err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid work order ID",
		})
		return
	}
	// get org from context
	org, ok := auth.OrgFromContext(r.Context())
	if !ok {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to get org from context",
		})
		return
	}
	// parse body into SearchRequest
	var req StatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "invalid request body",
		})
		return
	}

	// encode to raw []byte for query
	arg := req.Status
	if arg == "" {
		httpserver.JSON(w, http.StatusBadRequest, map[string]string{
			"error": "status field is required",
		})
		return
	}

	//Call the sqlc query
	err = h.repo.ChangeWorkOrderStatus(r.Context(), org, id, arg)
	if err != nil {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to change work order status",
		})
		return
	}
	httpserver.JSON(w, http.StatusOK, map[string]any{
		"message": "changed work order status",
		"id":      id,
		"status":  arg,
	})
}

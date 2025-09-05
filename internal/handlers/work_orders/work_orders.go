// internal/handlers/workorders/controller.go
package work_orders

import (
	"encoding/json"
	"net/http"
	"yourapp/internal/auth"
	httpserver "yourapp/internal/http"
	"yourapp/internal/repo"

	"github.com/go-chi/chi/v5"
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
	httpserver.JSON(w, http.StatusCreated, map[string]string{
		"message": "create work order",
	})
}

func (h *Handler) GetByID(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "workOrderID")
	httpserver.JSON(w, http.StatusOK, map[string]string{
		"id":      id,
		"message": "get work order",
	})
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

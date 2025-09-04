// internal/handlers/workorders/controller.go
package work_orders

import (
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

func (h *Handler) Search(w http.ResponseWriter, r *http.Request) {
	//get from org context
	org, ok := auth.OrgFromContext(r.Context())
	if !ok {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to get org from context",
		})
		return
	}
	wos, err := h.repo.ListWorkOrders(r.Context(), org, 10)

	if err != nil {
		httpserver.JSON(w, http.StatusInternalServerError, map[string]string{
			"error": "failed to list work orders",
		})
		return
	}
	httpserver.JSON(w, http.StatusOK, map[string]any{
		"message": "search work orders",
		"data":    wos,
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

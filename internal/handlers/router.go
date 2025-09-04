// internal/handlers/router.go
package handlers

import (
	"yourapp/internal/handlers/work_orders"
	"yourapp/internal/middleware"
	"yourapp/internal/repo"

	"github.com/go-chi/chi/v5"
)

func RegisterRoutes(mux *chi.Mux, r repo.Repo) {
	h := work_orders.New(r)

	mux.Route("/work-orders", func(sr chi.Router) {
		// Apply auth to the whole group ONCE
		sr.Use(middleware.RequireAuth(r))

		sr.Post("/search", h.Search)
		sr.Post("/", h.Create)
		sr.Get("/", h.List)
		sr.Get("/{workOrderID}", h.GetByID)
		sr.Put("/{workOrderID}", h.Update)
		sr.Delete("/{workOrderID}", h.Delete)
	})
}

// internal/handlers/router.go
package handlers

import (
	"yourapp/internal/handlers/tasks"
	"yourapp/internal/handlers/users"
	"yourapp/internal/handlers/work_orders"
	"yourapp/internal/middleware"
	"yourapp/internal/repo"

	"github.com/go-chi/chi/v5"
)

func RegisterRoutes(mux *chi.Mux, r repo.Repo) {
	h := work_orders.New(r)
	t := tasks.New(r)
	u := users.New(r)

	mux.Route("/work-orders", func(sr chi.Router) {
		// Apply auth to the whole group ONCE
		sr.Use(middleware.RequireAuth(r))

		sr.Post("/search", h.FilterSearch)
		sr.Post("/", h.Create)
		sr.Get("/", h.List)
		sr.Get("/{workOrderID}", h.GetByID)
		sr.Put("/{workOrderID}", h.Update)
		sr.Delete("/{workOrderID}", h.Delete)
		sr.Patch("/{workOrderID}", h.Modify)
		sr.Patch("/{workOrderID}/change-status", h.ChangeStatus)
	})

	mux.Route("/tasks", func(sr chi.Router) {
		// Apply auth to the whole group ONCE
		sr.Use(middleware.RequireAuth(r))

		sr.Get("/work-order/{workOrderID}", t.GetByWOID)
		sr.Get("/work-order/{workOrderID}/full", t.GetByWOIDFull)
		sr.Patch("/{taskID}", t.ToggleComplete)
		sr.Delete("/{taskID}", t.Delete)
		sr.Post("/", t.Create)
		sr.Put("/{taskID}", t.Update)
	})

	mux.Route("/users", func(sr chi.Router) {
		// Apply auth to the whole group ONCE
		sr.Use(middleware.RequireAuth(r))

		sr.Post("/search", u.Search)
	})
}

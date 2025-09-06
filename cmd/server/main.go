// cmd/server/main.go
package main

import (
	"context"
	"log"
	"net/http"
	"os"

	//"time"

	_ "github.com/jackc/pgx/v5/stdlib"

	"github.com/go-chi/chi/v5"
	mux_middleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors" // <-- cors
	"github.com/jackc/pgx/v5/pgxpool"

	"yourapp/internal/auth"
	"yourapp/internal/config"
	db "yourapp/internal/db/gen"
	"yourapp/internal/handlers"
	"yourapp/internal/middleware"
	"yourapp/internal/models"
	"yourapp/internal/repo"
)

func main() {
	// --- Load config (config.yaml + env overrides) ---
	cfg := config.Load()

	// --- Connect to Postgres ---
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, cfg.Database.URL)
	if err != nil {
		log.Fatalf("db connect error: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("db ping error: %v", err)
	}

	// sqlc queries + repo wrapper
	q := db.New(pool)
	r := repo.New(q)

	// --- Setup OAuth/OIDC providers ---
	providers := auth.SetupProviders(cfg)

	// --- Router ---
	mux := chi.NewRouter()

	// Simple request logger (logs method, path, status, and duration)
	mux.Use(mux_middleware.Logger)

	// --- CORS middleware ---
	mux.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"http://localhost:5500", "http://localhost:3000", "http://127.0.0.1:5500", "http://127.0.0.1:3000"}, // adjust as needed
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300, // Maximum value not ignored by browsers
	}))

	// OAuth/OIDC routes
	log.Printf("Setup providers: %+v\n", providers)
	//mux.Get("/auth/{provider}", auth.StartHandler(providers, r))
	//mux.Get("/auth/{provider}/callback", auth.CallbackHandler(providers, r))

	// Local auth routes
	mux.Post("/auth/signup", auth.SignupHandler(r))
	mux.Post("/auth/login", auth.LoginHandler(r))
	mux.Post("/auth/logout", auth.LogoutHandler())
	mux.Get("/auth/mfa/totp/setup", auth.TOTPSetupBeginHandler(r))
	mux.Post("/auth/mfa/totp/verify", auth.TOTPSetupVerifyHandler(r))

	// main.go (add inside main())

	// --- Protected routes ---
	// All routes below require authentication

	mux.Handle("/auth/me", auth.ProfileHandler(r))

	// Example protected routes by org/role
	mux.Route("/orgs/{slug}", func(sr chi.Router) {
		sr.With(middleware.RequireRole(r, models.RoleViewer)).
			Get("/projects", func(w http.ResponseWriter, _ *http.Request) {
				w.Write([]byte("list projects"))
			})
		sr.With(middleware.RequireRole(r, models.RoleAdmin, models.RoleOwner)).
			Post("/projects", func(w http.ResponseWriter, _ *http.Request) {
				w.Write([]byte("create project"))
			})
	})

	// Work orders and tasks routes
	handlers.RegisterRoutes(mux, r)

	// Serve static files from ./static at /static/*
	mux.Handle("/static/*", http.StripPrefix("/static/", http.FileServer(http.Dir("./static/"))))

	// Health root
	mux.Get("/", func(w http.ResponseWriter, r *http.Request) {
		//w.Write([]byte("OK"))
		http.ServeFile(w, r, "./cmd/server/static/test.html")
	})

	// --- Start server ---
	addr := "127.0.0.1:8080"
	if v := os.Getenv("PORT"); v != "" {
		addr = ":" + v
	}
	log.Printf("listening on %s (BASE_URL=%s)", addr, cfg.BaseURL)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

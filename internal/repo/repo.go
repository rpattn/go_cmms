// internal/repo/repo.go
package repo

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"

	db "yourapp/internal/db/gen" // <-- change if your sqlc package path differs
	"yourapp/internal/models"
)

// Repo defines the methods the rest of the app uses.
type Repo interface {
	UpsertUserByVerifiedEmail(ctx context.Context, email, name string) (models.User, error)
	LinkIdentity(ctx context.Context, userID uuid.UUID, provider, subject string) error

	FindOrgBySlug(ctx context.Context, slug string) (models.Org, error)
	FindOrgByID(ctx context.Context, id uuid.UUID) (models.Org, error)
	FindOrgByTenantID(ctx context.Context, tid string) (models.Org, error)
	EnsureMembership(ctx context.Context, orgID, userID uuid.UUID, defaultRole models.OrgRole) (models.OrgRole, error)
	GetRole(ctx context.Context, orgID, userID uuid.UUID) (models.OrgRole, error)
	GetUserWithOrgAndRole(ctx context.Context, uid, oid uuid.UUID) (models.User, models.Org, models.OrgRole, error)
	ApplyGroupRoleMappings(ctx context.Context, orgID uuid.UUID, provider string, groupIDs []string) (models.OrgRole, error)

	// Local auth
	CreateLocalCredential(ctx context.Context, uid uuid.UUID, username, phc string) error
	GetLocalCredentialByUsername(ctx context.Context, username string) (models.LocalCredential, models.User, error)
	GetUserByID(ctx context.Context, id uuid.UUID) (models.User, error)
	PickUserOrg(ctx context.Context, uid uuid.UUID) (models.Org, error)
	SearchUsers(ctx context.Context, org_id uuid.UUID, payload []byte) ([]models.User, error)
	SearchLocations(ctx context.Context, org_id uuid.UUID, payload []byte) ([]models.Location, error)
	SearchTeams(ctx context.Context, org_id uuid.UUID, payload []byte) ([]models.Team, error)
	SearchAssets(ctx context.Context, org_id uuid.UUID, payload []byte) ([]models.Asset, error)

	UserHasTOTP(ctx context.Context, uid uuid.UUID) bool
	SetTOTPSecret(ctx context.Context, uid uuid.UUID, secret, issuer, label string) error
	GetTOTPSecret(ctx context.Context, uid uuid.UUID) (string, bool)

	ListWorkOrdersPaged(ctx context.Context, org_id uuid.UUID, arg []byte) ([]models.WorkOrder, error)
	GetWorkOrderDetail(ctx context.Context, id uuid.UUID) (json.RawMessage, error)
	ChangeWorkOrderStatus(ctx context.Context, org_id uuid.UUID, workOrderID uuid.UUID, status string) error
	CreateWorkOrderFromJSON(ctx context.Context, org_id uuid.UUID, user_id uuid.UUID, payload []byte) (uuid.UUID, error)
	UpdateWorkOrderFromJSON(ctx context.Context, org_id uuid.UUID, workOrderID uuid.UUID, user_id uuid.UUID, payload []byte) (uuid.UUID, error)
	DeleteWorkOrderByID(ctx context.Context, org_id, workOrderID uuid.UUID) error

	// Tasks
	GetTasksByWorkOrderID(ctx context.Context, org_id uuid.UUID, workOrderID uuid.UUID) ([]db.GetTasksByWorkOrderIDRow, error)
	ListSimpleTasksByWorkOrderID(ctx context.Context, org_id, workOrderID uuid.UUID) ([]db.ListSimpleTasksByWorkOrderRow, error)
	MarkTaskComplete(ctx context.Context, org_id uuid.UUID, taskID uuid.UUID) (db.MarkTaskCompleteRow, error)
	DeleteTaskByID(ctx context.Context, org_id, taskID uuid.UUID) error
	ToggleTaskComplete(ctx context.Context, org_id uuid.UUID, taskID uuid.UUID, complete bool) (db.ToggleTaskCompletionRow, error)
}

// pgRepo wraps the sqlc Queries.
type pgRepo struct{ q *db.Queries }

func New(q *db.Queries) Repo { return &pgRepo{q: q} }

// internal/repo/repo.go
package repo

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"

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

	UserHasTOTP(ctx context.Context, uid uuid.UUID) bool
	SetTOTPSecret(ctx context.Context, uid uuid.UUID, secret, issuer, label string) error
	GetTOTPSecret(ctx context.Context, uid uuid.UUID) (string, bool)
}

// pgRepo wraps the sqlc Queries.
type pgRepo struct{ q *db.Queries }

func New(q *db.Queries) Repo { return &pgRepo{q: q} }

// ---------------- Users & Identities ----------------

func (p *pgRepo) UpsertUserByVerifiedEmail(ctx context.Context, email string, name string) (models.User, error) {
	u, err := p.q.UpsertUserByVerifiedEmail(ctx, db.UpsertUserByVerifiedEmailParams{
		Email: email,
		Name:  toText(name),
	})
	if err != nil {
		return models.User{}, err
	}
	return models.User{
		ID:    toUUID(u.ID),
		Email: u.Email,
		Name:  fromText(u.Name),
	}, nil
}

func (p *pgRepo) LinkIdentity(ctx context.Context, userID uuid.UUID, provider, subject string) error {
	return p.q.LinkIdentity(ctx, db.LinkIdentityParams{
		UserID:   fromUUID(userID),
		Provider: provider,
		Subject:  subject,
	})
}

// ---------------- Orgs & Memberships ----------------

func (p *pgRepo) FindOrgBySlug(ctx context.Context, slug string) (models.Org, error) {
	o, err := p.q.FindOrgBySlug(ctx, slug)
	if err != nil {
		return models.Org{}, err
	}
	return models.Org{
		ID:       toUUID(o.ID),
		Slug:     o.Slug,
		Name:     o.Name,
		TenantID: fromText(o.MsTenantID),
	}, nil
}

func (p *pgRepo) FindOrgByID(ctx context.Context, id uuid.UUID) (models.Org, error) {
	o, err := p.q.FindOrgByID(ctx, toPgUUID(id))
	if err != nil {
		return models.Org{}, err
	}
	return models.Org{
		ID:       toUUID(o.ID),
		Slug:     o.Slug,
		Name:     o.Name,
		TenantID: fromText(o.MsTenantID),
	}, nil
}

func (p *pgRepo) FindOrgByTenantID(ctx context.Context, tid string) (models.Org, error) {
	o, err := p.q.FindOrgByTenantID(ctx, toText(tid))
	if err != nil {
		return models.Org{}, err
	}
	return models.Org{
		ID:       toUUID(o.ID),
		Slug:     o.Slug,
		Name:     o.Name,
		TenantID: fromText(o.MsTenantID),
	}, nil
}

func (p *pgRepo) EnsureMembership(ctx context.Context, orgID, userID uuid.UUID, defaultRole models.OrgRole) (models.OrgRole, error) {
	roleText, err := p.q.EnsureMembership(ctx, db.EnsureMembershipParams{
		OrgID:  fromUUID(orgID),
		UserID: fromUUID(userID),
		Role:   string(defaultRole), // if sqlc made this a string
	})
	if err != nil {
		return "", fmt.Errorf("membership failed: %w", err)
	}

	return models.OrgRole(roleText), nil
}

func (p *pgRepo) GetRole(ctx context.Context, orgID, userID uuid.UUID) (models.OrgRole, error) {
	roleStr, err := p.q.GetRole(ctx, db.GetRoleParams{
		OrgID:  fromUUID(orgID),
		UserID: fromUUID(userID),
	})
	if err != nil {
		return "", err
	}
	return models.OrgRole(roleStr), nil
}

// Find best mapped role for given IdP groups (no persistence here).
func (p *pgRepo) ApplyGroupRoleMappings(ctx context.Context, orgID uuid.UUID, provider string, groupIDs []string) (models.OrgRole, error) {
	if len(groupIDs) == 0 {
		return "", nil
	}
	rows, err := p.q.GetMappedRolesForGroups(ctx, db.GetMappedRolesForGroupsParams{
		OrgID:    fromUUID(orgID),
		Provider: provider,
		GroupIds: groupIDs,
	})
	if err != nil {
		return "", err
	}

	best := ""
	for _, v := range rows {
		var role string
		switch x := v.(type) {
		case string:
			role = x
		case []byte:
			role = string(x)
		default:
			continue // skip unknown/null
		}
		if best == "" || rankRole(role) > rankRole(best) {
			best = role
		}
	}

	if best == "" {
		return "", nil
	}
	return models.OrgRole(best), nil
}

// ---------------- Local credentials & TOTP ----------------

func (p *pgRepo) CreateLocalCredential(ctx context.Context, uid uuid.UUID, username, phc string) error {
	return p.q.CreateLocalCredential(ctx, db.CreateLocalCredentialParams{
		UserID:       fromUUID(uid),
		Lower:        strings.ToLower(username), // string
		PasswordHash: phc,
	})
}

func (p *pgRepo) GetLocalCredentialByUsername(ctx context.Context, username string) (models.LocalCredential, models.User, error) {
	row, err := p.q.GetLocalCredentialByUsername(ctx, username)
	if err != nil {
		return models.LocalCredential{}, models.User{}, err
	}
	lc := models.LocalCredential{
		UserID:       toUUID(row.UserID),
		Username:     row.Username,
		PasswordHash: row.PasswordHash,
	}
	u := models.User{
		ID:    toUUID(row.UserID),
		Email: row.Email,
		Name:  fromText(row.Name),
	}
	return lc, u, nil
}

// GetUserByUUID fetches a user by their UUID.
func (p *pgRepo) GetUserByID(ctx context.Context, id uuid.UUID) (models.User, error) {
	row, err := p.q.GetUserByID(ctx, toPgUUID(id)) // assumes you have this sqlc query
	if err != nil {
		return models.User{}, err
	}

	u := models.User{
		ID:    toUUID(row.ID),
		Email: row.Email,
		Name:  fromText(row.Name),
	}

	return u, nil
}

func (p *pgRepo) GetUserWithOrgAndRole(
	ctx context.Context,
	uid uuid.UUID,
	oid uuid.UUID,
) (models.User, models.Org, models.OrgRole, error) {
	// Build params
	params := db.GetUserWithOrgAndRoleParams{
		Column1: toPgUUID(uid),
		Column2: toPgUUID(oid),
	}

	row, err := p.q.GetUserWithOrgAndRole(ctx, params)
	if err != nil {
		return models.User{}, models.Org{}, "", err
	}

	// Helpers to unwrap sqlc's interface{} fields
	toBool := func(x interface{}) bool {
		switch v := x.(type) {
		case bool:
			return v
		case pgtype.Bool:
			return v.Bool
		case string:
			return v == "t" || v == "true" || v == "1"
		case []byte:
			s := string(v)
			return s == "t" || s == "true" || s == "1"
		case int64:
			return v != 0
		case nil:
			return false
		default:
			return false
		}
	}
	toString := func(x interface{}) (string, bool) {
		switch v := x.(type) {
		case string:
			return v, v != ""
		case []byte:
			if len(v) == 0 {
				return "", false
			}
			return string(v), true
		case pgtype.Text:
			if v.Valid {
				return v.String, true
			}
			return "", false
		case nil:
			return "", false
		default:
			return fmt.Sprintf("%v", v), true
		}
	}

	// Not-found checks (keep your own sentinels if you have them)
	if !toBool(row.UserExists) {
		return models.User{}, models.Org{}, "", models.ErrUserNotFound
	}
	if !toBool(row.OrgExists) {
		return models.User{}, models.Org{}, "", models.ErrOrgNotFound
	}
	if !toBool(row.RoleExists) {
		return models.User{}, models.Org{}, "", models.ErrRoleNotFound
	}

	// Map to domain types
	var (
		uID = row.UserID.Bytes
		oID = row.OrgID.Bytes
	)
	u := models.User{
		ID:    uID,
		Email: textOrEmpty(row.UserEmail),
		Name:  textOrEmpty(row.UserName),
	}
	o := models.Org{
		ID:       oID,
		Slug:     textOrEmpty(row.OrgSlug),
		Name:     textOrEmpty(row.OrgName),
		TenantID: "", // not in this query
	}

	roleStr, _ := toString(row.Role)
	role := models.OrgRole(roleStr)

	return u, o, role, nil
}

// tiny helpers for pgtype.Text
func textOrEmpty(t pgtype.Text) string {
	if t.Valid {
		return t.String
	}
	return ""
}

// If your query doesn't return created_at columns, delete uses of extractTime/CreatedAt.
func extractTime(_ db.GetUserWithOrgAndRoleRow, _ string) *time.Time { return nil }
func zeroIfNil(t *time.Time) time.Time {
	if t == nil {
		return time.Time{}
	}
	return *t
}

func (p *pgRepo) PickUserOrg(ctx context.Context, uid uuid.UUID) (models.Org, error) {
	o, err := p.q.PickUserOrg(ctx, fromUUID(uid))
	if err != nil {
		return models.Org{}, err
	}
	return models.Org{
		ID:       toUUID(o.ID),
		Slug:     o.Slug,
		Name:     o.Name,
		TenantID: fromText(o.MsTenantID),
	}, nil
}

func (p *pgRepo) UserHasTOTP(ctx context.Context, uid uuid.UUID) bool {
	ok, err := p.q.UserHasTOTP(ctx, fromUUID(uid))
	return err == nil && ok
}

func (p *pgRepo) SetTOTPSecret(ctx context.Context, uid uuid.UUID, secret, issuer, label string) error {
	return p.q.SetTOTPSecret(ctx, db.SetTOTPSecretParams{
		UserID: fromUUID(uid),
		Secret: secret,
		Issuer: issuer,
		Label:  label,
	})
}

func (p *pgRepo) GetTOTPSecret(ctx context.Context, uid uuid.UUID) (string, bool) {
	sec, err := p.q.GetTOTPSecret(ctx, fromUUID(uid))
	return sec, err == nil
}

// ---------------- Helpers ----------------

func fromUUID(id uuid.UUID) pgtype.UUID {
	return pgtype.UUID{Bytes: id, Valid: true}
}

func toUUID(u pgtype.UUID) uuid.UUID {
	return uuid.UUID(u.Bytes)
}

func rankRole(r string) int {
	switch r {
	case string(models.RoleOwner):
		return 4
	case string(models.RoleAdmin):
		return 3
	case string(models.RoleMember):
		return 2
	default:
		return 1 // Viewer or unknown
	}
}

// Convert string → pgtype.Text
func toText(s string) pgtype.Text {
	return pgtype.Text{String: s, Valid: true}
}

// Convert pgtype.Text → string
func fromText(t pgtype.Text) string {
	return t.String
}

// toPgUUID converts a google/uuid.UUID into a pgtype.UUID for queries.
func toPgUUID(id uuid.UUID) pgtype.UUID {
	return pgtype.UUID{
		Bytes: id,
		Valid: true,
	}
}

package repo

import (
    "context"
    "log/slog"
    "time"

    "github.com/google/uuid"

    db "yourapp/internal/db/gen"
    "yourapp/internal/models"
)

// ---------------- Search ----------------

func (p *pgRepo) SearchUsers(ctx context.Context, org_id uuid.UUID, payload []byte) ([]models.User, error) {
    slog.DebugContext(ctx, "SearchUsers", "org_id", org_id.String())
    params := db.SearchOrgUsersParams{
        OrgID:   fromUUID(org_id),
        Payload: payload,
    }
    rows, err := p.q.SearchOrgUsers(ctx, params)
    if err != nil {
        slog.ErrorContext(ctx, "SearchUsers failed", "err", err)
        return nil, err
    }
    if len(rows) == 0 {
        return []models.User{}, nil
    }
	users := make([]models.User, 0, len(rows))
	for _, r := range rows {
		u := models.User{
			ID:    toUUID(r.ID),
			Email: r.Email,
			Name:  r.Name,
		}
		users = append(users, u)
    }
    slog.DebugContext(ctx, "SearchUsers ok", "count", len(users))
    return users, nil
}

func (p *pgRepo) SearchLocations(ctx context.Context, org_id uuid.UUID, payload []byte) ([]models.Location, error) {
    slog.DebugContext(ctx, "SearchLocations", "org_id", org_id.String())
    params := db.SearchOrgLocationsParams{
        OrgID:   fromUUID(org_id),
        Payload: payload,
    }
    rows, err := p.q.SearchOrgLocations(ctx, params)
    if err != nil {
        slog.ErrorContext(ctx, "SearchLocations failed", "err", err)
        return nil, err
    }
    if len(rows) == 0 {
        return []models.Location{}, nil
    }
	out := make([]models.Location, 0, len(rows))
	for _, r := range rows {
		var createdAt time.Time
		if r.CreatedAt.Valid {
			createdAt = r.CreatedAt.Time
		}
		out = append(out, models.Location{
			ID:        r.ID.Bytes,
			Name:      r.Name,
			CreatedAt: createdAt,
		})
    }
    slog.DebugContext(ctx, "SearchLocations ok", "count", len(out))
    return out, nil
}

func (p *pgRepo) SearchTeams(ctx context.Context, org_id uuid.UUID, payload []byte) ([]models.Team, error) {
    slog.DebugContext(ctx, "SearchTeams", "org_id", org_id.String())
    params := db.SearchOrgTeamsParams{
        OrgID:   fromUUID(org_id),
        Payload: payload,
    }
    rows, err := p.q.SearchOrgTeams(ctx, params)
    if err != nil {
        slog.ErrorContext(ctx, "SearchTeams failed", "err", err)
        return nil, err
    }
    if len(rows) == 0 {
        return []models.Team{}, nil
    }
	out := make([]models.Team, 0, len(rows))
	for _, r := range rows {
		var createdAt time.Time
		if r.CreatedAt.Valid {
			createdAt = r.CreatedAt.Time
		}
		out = append(out, models.Team{
			ID:        r.ID.Bytes,
			Name:      r.Name,
			CreatedAt: createdAt,
		})
    }
    slog.DebugContext(ctx, "SearchTeams ok", "count", len(out))
    return out, nil
}

func (p *pgRepo) SearchAssets(ctx context.Context, org_id uuid.UUID, payload []byte) ([]models.Asset, error) {
    slog.DebugContext(ctx, "SearchAssets", "org_id", org_id.String())
    params := db.SearchOrgAssetsParams{
        OrgID:   fromUUID(org_id),
        Payload: payload,
    }
    rows, err := p.q.SearchOrgAssets(ctx, params)
    if err != nil {
        slog.ErrorContext(ctx, "SearchAssets failed", "err", err)
        return nil, err
    }
    if len(rows) == 0 {
        return []models.Asset{}, nil
    }
	out := make([]models.Asset, 0, len(rows))
	for _, r := range rows {
		var createdAt time.Time
		if r.CreatedAt.Valid {
			createdAt = r.CreatedAt.Time
		}
		out = append(out, models.Asset{
			ID:        r.ID.Bytes,
			Name:      r.Name,
			CreatedAt: createdAt,
		})
    }
    slog.DebugContext(ctx, "SearchAssets ok", "count", len(out))
    return out, nil
}

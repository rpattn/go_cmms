package repo

import (
    "context"
    "encoding/json"
    "errors"
    "log/slog"

    "github.com/google/uuid"

    db "yourapp/internal/db/gen"
    "yourapp/internal/models"
)

// ---------------- Work Orders ----------------

func (p *pgRepo) GetWorkOrderDetail(ctx context.Context, id uuid.UUID) (json.RawMessage, error) {
    slog.DebugContext(ctx, "GetWorkOrderDetail", "work_order_id", id.String())
    row, err := p.q.GetWorkOrderDetail(ctx, toPgUUID(id))
    if err != nil {
        slog.ErrorContext(ctx, "GetWorkOrderDetail failed", "err", err)
        return nil, err
    }

    switch v := any(row).(type) {
    case []byte:
        if len(v) == 0 {
            return nil, errors.New("work order not found")
        }
        out := make([]byte, len(v))
        copy(out, v)
        return json.RawMessage(out), nil
    case struct{ WorkOrder []byte }:
        if len(v.WorkOrder) == 0 {
            return nil, errors.New("work order not found")
        }
        out := make([]byte, len(v.WorkOrder))
        copy(out, v.WorkOrder)
        return json.RawMessage(out), nil
    case interface{ Get() any }:
        if got := v.Get(); got != nil {
            if b, ok := got.([]byte); ok {
                out := make([]byte, len(b))
                copy(out, b)
                return json.RawMessage(out), nil
            }
        }
    }

    type rowJSONB struct{ WorkOrder json.RawMessage }
    if r, ok := any(row).(rowJSONB); ok {
        if len(r.WorkOrder) == 0 {
            return nil, errors.New("work order not found")
        }
        out := make([]byte, len(r.WorkOrder))
        copy(out, r.WorkOrder)
        return json.RawMessage(out), nil
    }
    return nil, errors.New("unexpected row type for GetWorkOrderDetail; check sqlc-generated type")
}

func (p *pgRepo) ListWorkOrdersPaged(ctx context.Context, arg []byte) ([]models.WorkOrder, error) {
    slog.DebugContext(ctx, "ListWorkOrdersPaged")
    rows, err := p.q.ListWorkOrdersPaged(ctx, arg)
    if err != nil {
        slog.ErrorContext(ctx, "ListWorkOrdersPaged failed", "err", err)
        return nil, err
    }
    if len(rows) == 0 {
        return []models.WorkOrder{}, nil
    }

    wos := make([]models.WorkOrder, 0, len(rows))
    for _, r := range rows {
        wo := models.WorkOrder{
            ID:        toUUID(r.ID),
            OrgID:     toUUID(r.OrganisationID),
            Title:     r.Title,
            Status:    r.Status,
            Priority:  r.Priority,
            CreatedAt: toTime(r.CreatedAt),
            UpdatedAt: toTime(r.UpdatedAt),
            DueDate:   toTime(r.DueDate),
            CustomID:  fromText(r.CustomID),
        }
        wo.Description = fromText(r.Description)
        wos = append(wos, wo)
    }
    slog.DebugContext(ctx, "ListWorkOrdersPaged ok", "count", len(wos))
    return wos, nil
}

func (p *pgRepo) ChangeWorkOrderStatus(ctx context.Context, org_id uuid.UUID, workOrderID uuid.UUID, status string) error {
    slog.DebugContext(ctx, "ChangeWorkOrderStatus", "org_id", org_id.String(), "work_order_id", workOrderID.String(), "status", status)
    args := db.ChangeWorkOrderStatusParams{
        OrganisationID: fromUUID(org_id),
        WorkOrderID:    toPgUUID(workOrderID),
        Status:         status,
    }
    return p.q.ChangeWorkOrderStatus(ctx, args)
}

func (p *pgRepo) CreateWorkOrderFromJSON(ctx context.Context, org_id uuid.UUID, user_id uuid.UUID, payload []byte) (uuid.UUID, error) {
    slog.DebugContext(ctx, "CreateWorkOrderFromJSON", "org_id", org_id.String(), "user_id", user_id.String())
    args := db.CreateWorkOrderFromJSONParams{
        OrganisationID: fromUUID(org_id),
        CreatedByID:    fromUUID(user_id),
        Payload:        payload,
    }
    id, err := p.q.CreateWorkOrderFromJSON(ctx, args)
    if err != nil {
        slog.ErrorContext(ctx, "CreateWorkOrderFromJSON failed", "err", err)
        return uuid.Nil, err
    }
    return toUUID(id), nil
}

func (p *pgRepo) UpdateWorkOrderFromJSON(ctx context.Context, org_id uuid.UUID, workOrderID uuid.UUID, user_id uuid.UUID, payload []byte) (uuid.UUID, error) {
    slog.DebugContext(ctx, "UpdateWorkOrderFromJSON", "org_id", org_id.String(), "work_order_id", workOrderID.String(), "user_id", user_id.String())
    args := db.UpdateWorkOrderFromJSONParams{
        OrganisationID: fromUUID(org_id),
        WorkOrderID:    toPgUUID(workOrderID),
        UpdatedByID:    fromUUID(user_id),
        Payload:        payload,
    }
    id, err := p.q.UpdateWorkOrderFromJSON(ctx, args)
    if err != nil {
        slog.ErrorContext(ctx, "UpdateWorkOrderFromJSON failed", "err", err)
        return uuid.Nil, err
    }
    return toUUID(id), nil
}

func (p *pgRepo) DeleteWorkOrderByID(ctx context.Context, org_id, workOrderID uuid.UUID) error {
    slog.DebugContext(ctx, "DeleteWorkOrderByID", "org_id", org_id.String(), "work_order_id", workOrderID.String())
    args := db.DeleteWorkOrderByIDParams{
        OrganisationID: fromUUID(org_id),
        ID:             toPgUUID(workOrderID),
    }
    return p.q.DeleteWorkOrderByID(ctx, args)
}

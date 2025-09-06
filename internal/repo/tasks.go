package repo

import (
    "context"
    "log/slog"

    "github.com/google/uuid"

    db "yourapp/internal/db/gen"
)

// ---------------- Tasks ----------------

func (p *pgRepo) ToggleTaskComplete(ctx context.Context, org_id uuid.UUID, taskID uuid.UUID, complete bool) (db.ToggleTaskCompletionRow, error) {
    slog.DebugContext(ctx, "ToggleTaskComplete", "org_id", org_id.String(), "task_id", taskID.String(), "complete", complete)
    args := db.ToggleTaskCompletionParams{
        OrganisationID: fromUUID(org_id),
        ID:             toPgUUID(taskID),
        Complete:       complete,
    }
    return p.q.ToggleTaskCompletion(ctx, args)
}

func (p *pgRepo) MarkTaskComplete(ctx context.Context, org_id uuid.UUID, taskID uuid.UUID) (db.MarkTaskCompleteRow, error) {
    slog.DebugContext(ctx, "MarkTaskComplete", "org_id", org_id.String(), "task_id", taskID.String())
    args := db.MarkTaskCompleteParams{
        OrganisationID: fromUUID(org_id),
        ID:             toPgUUID(taskID),
    }
    return p.q.MarkTaskComplete(ctx, args)
}

func (p *pgRepo) DeleteTaskByID(ctx context.Context, org_id, taskID uuid.UUID) error {
    slog.DebugContext(ctx, "DeleteTaskByID", "org_id", org_id.String(), "task_id", taskID.String())
    args := db.DeleteTaskByIDParams{
        OrganisationID: fromUUID(org_id),
        ID:             fromUUID(taskID),
    }
    return p.q.DeleteTaskByID(ctx, args)
}

func (p *pgRepo) ListSimpleTasksByWorkOrderID(ctx context.Context, org_id, workOrderID uuid.UUID) ([]db.ListSimpleTasksByWorkOrderRow, error) {
    slog.DebugContext(ctx, "ListSimpleTasksByWorkOrderID", "org_id", org_id.String(), "work_order_id", workOrderID.String())
    params := db.ListSimpleTasksByWorkOrderParams{
        OrganisationID: fromUUID(org_id),
        WorkOrderID:    fromUUID(workOrderID),
    }
    rows, err := p.q.ListSimpleTasksByWorkOrder(ctx, params)
    if err != nil {
        slog.ErrorContext(ctx, "ListSimpleTasksByWorkOrder failed", "err", err)
        return nil, err
    }
    if len(rows) == 0 {
        return []db.ListSimpleTasksByWorkOrderRow{}, nil
    }
    slog.DebugContext(ctx, "ListSimpleTasksByWorkOrderID ok", "count", len(rows))
    return rows, nil
}

func (p *pgRepo) GetTasksByWorkOrderID(ctx context.Context, org_id uuid.UUID, workOrderID uuid.UUID) ([]db.GetTasksByWorkOrderIDRow, error) {
    slog.DebugContext(ctx, "GetTasksByWorkOrderID", "org_id", org_id.String(), "work_order_id", workOrderID.String())
    params := db.GetTasksByWorkOrderIDParams{
        OrganisationID: fromUUID(org_id),
        WorkOrderID:    fromUUID(workOrderID),
    }
    rows, err := p.q.GetTasksByWorkOrderID(ctx, params)
    if err != nil {
        slog.ErrorContext(ctx, "GetTasksByWorkOrderID failed", "err", err)
        return nil, err
    }
    if len(rows) == 0 {
        return []db.GetTasksByWorkOrderIDRow{}, nil
    }
    slog.DebugContext(ctx, "GetTasksByWorkOrderID ok", "count", len(rows))
    return rows, nil
}

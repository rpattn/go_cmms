// internal/models/types.go
package models

import "github.com/google/uuid"

type OrgRole string

const (
	RoleOwner  OrgRole = "Owner"
	RoleAdmin  OrgRole = "Admin"
	RoleMember OrgRole = "Member"
	RoleViewer OrgRole = "Viewer"
)

type User struct {
	ID    uuid.UUID
	Email string
	Name  string
}

type Org struct {
	ID       uuid.UUID
	Slug     string
	Name     string
	TenantID string
}

type LocalCredential struct {
	UserID       uuid.UUID
	Username     string
	PasswordHash string
}

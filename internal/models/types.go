// internal/models/types.go
package models

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

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

var (
	ErrUserNotFound = errors.New("user not found")
	ErrOrgNotFound  = errors.New("org not found")
	ErrRoleNotFound = errors.New("role not found")
)

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

type Session struct {
	UserID    uuid.UUID
	ActiveOrg uuid.UUID
	Provider  string
	Expiry    time.Time
}

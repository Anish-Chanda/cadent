package models

// AuthProvider represents the authentication provider
type AuthProvider string

const (
	AuthProviderLocal AuthProvider = "local"
	// add other providers like google, github, etc. as needed
)

type UserRecord struct {
	ID           string       `json:"id"`
	Email        string       `json:"email"`
	PasswordHash *string      `json:"password_hash,omitempty"` // nil if using OAuth
	AuthProvider AuthProvider `json:"auth_provider"`
	CreatedAt    int64        `json:"created_at"`
	UpdatedAt    int64        `json:"updated_at"`
	// add other fields as needed, e.g., name, profile picture URL, etc.
}

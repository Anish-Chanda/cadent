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
	Name         string       `json:"name"`
	PasswordHash *string      `json:"password_hash"` // nil if using OAuth
	AuthProvider AuthProvider `json:"auth_provider"`
	CreatedAt    int64        `json:"created_at"`
	UpdatedAt    int64        `json:"updated_at"`
	// we will add other fields as needed, e.g., profile picture URL, etc.
}

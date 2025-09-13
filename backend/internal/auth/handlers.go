package auth

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/anish-chanda/cadence/backend/internal/db"
)

func HandleLocalLogin(db db.Database, email, password string) (ok bool, err error) {
	// set timeout context
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	//get user by email
	normalized := strings.TrimSpace(strings.ToLower(email))
	userRecord, err := db.GetUserByEmail(ctx, normalized)
	if err != nil {
		fmt.Println("failed to get user by email:", err)
		return false, err
	}
	if userRecord == nil {
		// No such user
		return false, nil
	}

	// verify password
	if userRecord.PasswordHash == nil {
		return false, fmt.Errorf("user has no password set")
	}
	ok, err = VerifyPassword(password, *userRecord.PasswordHash)
	if err != nil {
		fmt.Println("failed to verify password:", err)
		return false, fmt.Errorf("failed to verify password: %w", err)
	}

	if !ok {
		return false, fmt.Errorf("invalid credentials")
	}
	// if password is correct, return true
	return ok, err
}

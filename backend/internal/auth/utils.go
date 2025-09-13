package auth

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"strings"

	"golang.org/x/crypto/argon2"
)

const (
	argonTime    = 1
	argonMemory  = 64 * 1024
	argonThreads = 4
	argonSaltLen = 16
	argonKeyLen  = 32
)

// hashPassword applies Argon2id with OWASP‐recommended params and returns
// a single string in the standard “$argon2id$v=19$m=…,t=…,p=…$salt$hash” format.
func HashPassword(password string) (string, error) {
	salt := make([]byte, argonSaltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	hash := argon2.IDKey(
		[]byte(password),
		salt,
		argonTime,
		argonMemory,
		argonThreads,
		argonKeyLen,
	)
	b64Salt := base64.RawStdEncoding.EncodeToString(salt)
	b64Hash := base64.RawStdEncoding.EncodeToString(hash)
	parts := []string{
		"argon2id",
		fmt.Sprintf("v=%d", argon2.Version),
		fmt.Sprintf("m=%d,t=%d,p=%d", argonMemory, argonTime, argonThreads),
		b64Salt,
		b64Hash,
	}
	return "$" + strings.Join(parts, "$"), nil
}

// verifyPassword parses and verifies an encoded Argon2id hash.
func VerifyPassword(password, encoded string) (bool, error) {
	// encoded: $argon2id$v=19$m=...,t=...,p=...$<salt>$<hash>
	fields := strings.Split(encoded, "$")
	if len(fields) != 6 || fields[1] != "argon2id" {
		return false, fmt.Errorf("invalid hash format")
	}
	var memory, timeParam, threads uint32
	if _, err := fmt.Sscanf(fields[3], "m=%d,t=%d,p=%d", &memory, &timeParam, &threads); err != nil {
		return false, err
	}
	salt, err := base64.RawStdEncoding.DecodeString(fields[4])
	if err != nil {
		return false, err
	}
	hash, err := base64.RawStdEncoding.DecodeString(fields[5])
	if err != nil {
		return false, err
	}

	computed := argon2.IDKey([]byte(password), salt, timeParam, memory, uint8(threads), uint32(len(hash)))
	// constant-time compare
	if subtle.ConstantTimeCompare(computed, hash) == 1 {
		return true, nil
	}
	return false, nil
}

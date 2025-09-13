package migrations

import (
	"embed"
	"fmt"
)

//go:embed postgresql/*sql
var PostgresMigrations embed.FS

func GetMigrationsFS(dbType string) (embed.FS, string, error) {
	switch dbType {
	case "postgres":
		return PostgresMigrations, "postgresql", nil
	default:
		return embed.FS{}, "", fmt.Errorf("unsupported database type: %s", dbType)
	}
	// add case for other DBs based on user need

}

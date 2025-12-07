package migrations

import (
	"embed"
	"testing"
)

func TestGetMigrationsFS(t *testing.T) {
	tests := []struct {
		name         string
		dbType       string
		expectedPath string
		expectError  bool
		errorMessage string
	}{
		{
			name:         "postgres database type",
			dbType:       "postgres",
			expectedPath: "postgresql",
			expectError:  false,
		},
		{
			name:         "mysql database type (unsupported)",
			dbType:       "mysql",
			expectedPath: "",
			expectError:  true,
			errorMessage: "unsupported database type: mysql",
		},
		{
			name:         "empty database type",
			dbType:       "",
			expectedPath: "",
			expectError:  true,
			errorMessage: "unsupported database type: ",
		},
		{
			name:         "unknown database type",
			dbType:       "unknown",
			expectedPath: "",
			expectError:  true,
			errorMessage: "unsupported database type: unknown",
		},
		{
			name:         "case sensitive check",
			dbType:       "POSTGRES",
			expectedPath: "",
			expectError:  true,
			errorMessage: "unsupported database type: POSTGRES",
		},
		{
			name:         "postgresql full name",
			dbType:       "postgresql",
			expectedPath: "",
			expectError:  true,
			errorMessage: "unsupported database type: postgresql",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fs, path, err := GetMigrationsFS(tt.dbType)

			// Check error expectation
			if tt.expectError {
				if err == nil {
					t.Errorf("GetMigrationsFS() expected error but got none")
					return
				}
				if err.Error() != tt.errorMessage {
					t.Errorf("GetMigrationsFS() error = %v, want %v", err.Error(), tt.errorMessage)
				}

				// Check that empty values are returned on error
				if path != "" {
					t.Errorf("GetMigrationsFS() path = %v, want empty string on error", path)
				}

				// Check that empty FS is returned on error
				emptyFS := embed.FS{}
				if fs != emptyFS {
					t.Errorf("GetMigrationsFS() should return empty FS on error")
				}
			} else {
				if err != nil {
					t.Errorf("GetMigrationsFS() unexpected error = %v", err)
					return
				}

				if path != tt.expectedPath {
					t.Errorf("GetMigrationsFS() path = %v, want %v", path, tt.expectedPath)
				}

				// For successful postgres case, verify the FS contains expected files
				if tt.dbType == "postgres" {
					// Check if the embedded filesystem is not empty
					if fs == (embed.FS{}) {
						t.Error("GetMigrationsFS() returned empty filesystem for postgres")
					}

					// Try to read directory to verify it contains migration files
					entries, err := fs.ReadDir("postgresql")
					if err != nil {
						t.Errorf("GetMigrationsFS() could not read postgresql directory: %v", err)
					}

					if len(entries) == 0 {
						t.Error("GetMigrationsFS() postgresql directory is empty")
					}

					// Check for expected migration files
					expectedFiles := []string{
						"0001_placeholder.up.sql",
						"0001_placeholder.down.sql",
						"0002_activities_table.up.sql",
						"0002_activities_table.down.sql",
					}

					foundFiles := make(map[string]bool)
					for _, entry := range entries {
						foundFiles[entry.Name()] = true
					}

					for _, expectedFile := range expectedFiles {
						if !foundFiles[expectedFile] {
							t.Errorf("GetMigrationsFS() missing expected file: %s", expectedFile)
						}
					}
				}
			}
		})
	}
}

func TestPostgresMigrationsEmbedded(t *testing.T) {
	// Test that PostgresMigrations is properly embedded
	if PostgresMigrations == (embed.FS{}) {
		t.Error("PostgresMigrations should not be empty")
	}

	// Test reading the postgresql directory
	entries, err := PostgresMigrations.ReadDir("postgresql")
	if err != nil {
		t.Fatalf("Could not read postgresql directory: %v", err)
	}

	if len(entries) == 0 {
		t.Error("PostgresMigrations postgresql directory should not be empty")
	}

	// Test reading actual migration files
	migrationFiles := []string{
		"postgresql/0001_placeholder.up.sql",
		"postgresql/0001_placeholder.down.sql",
		"postgresql/0002_activities_table.up.sql",
		"postgresql/0002_activities_table.down.sql",
	}

	for _, filename := range migrationFiles {
		content, err := PostgresMigrations.ReadFile(filename)
		if err != nil {
			t.Errorf("Could not read migration file %s: %v", filename, err)
			continue
		}

		if len(content) == 0 {
			t.Errorf("Migration file %s should not be empty", filename)
		}

		// Basic validation that it looks like SQL
		contentStr := string(content)
		if len(contentStr) < 3 {
			t.Errorf("Migration file %s seems too short to be valid SQL: %s", filename, contentStr)
		}
	}
}

func TestGetMigrationsFSReturnsSameInstanceForPostgres(t *testing.T) {
	// Test that multiple calls return the same embedded FS
	fs1, path1, err1 := GetMigrationsFS("postgres")
	fs2, path2, err2 := GetMigrationsFS("postgres")

	if err1 != nil || err2 != nil {
		t.Fatalf("Unexpected errors: err1=%v, err2=%v", err1, err2)
	}

	if path1 != path2 {
		t.Errorf("Paths should be the same: path1=%s, path2=%s", path1, path2)
	}

	// Both should be able to read the same content
	entries1, err1 := fs1.ReadDir("postgresql")
	entries2, err2 := fs2.ReadDir("postgresql")

	if err1 != nil || err2 != nil {
		t.Fatalf("Unexpected errors reading directories: err1=%v, err2=%v", err1, err2)
	}

	if len(entries1) != len(entries2) {
		t.Errorf("Directory entries should be the same length: len1=%d, len2=%d", len(entries1), len(entries2))
	}
}

// Edge case testing for potential future database types
func TestGetMigrationsFSEdgeCases(t *testing.T) {
	edgeCases := []string{
		"sqlite",
		"mongodb",
		"redis",
		"postgres ", // with trailing space
		" postgres", // with leading space
		"Postgres",  // different case
		"POSTGRES",  // all caps
	}

	for _, dbType := range edgeCases {
		t.Run("unsupported_"+dbType, func(t *testing.T) {
			fs, path, err := GetMigrationsFS(dbType)

			if err == nil {
				t.Errorf("Expected error for unsupported database type: %s", dbType)
			}

			if path != "" {
				t.Errorf("Expected empty path for unsupported database type %s, got: %s", dbType, path)
			}

			if fs != (embed.FS{}) {
				t.Errorf("Expected empty FS for unsupported database type: %s", dbType)
			}
		})
	}
}

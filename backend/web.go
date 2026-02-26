package main

import (
	"embed"
	"io/fs"
	"net/http"
	"strings"
)

//go:embed all:web/dist
var webFS embed.FS

const webNotBuiltHTML = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>Cadent — Web UI not built</title>
    <style>body{font-family:sans-serif;padding:2rem;color:#333}</style>
  </head>
  <body>
    <h2>Web UI not built</h2>
    <p>Run <code>make build-api</code> (or <code>make build-web</code>) to build the web UI.</p>
  </body>
</html>`

// spaHandler serves the embedded React SPA. Any path that doesn't correspond
// to a real file falls back to index.html so client-side routing works.
// If the web UI has not been built yet it returns a helpful HTML message.
// This woudl happen in situations where the backend was run without building the web or without using the makefile helper.
func spaHandler() http.Handler {
	distFS, err := fs.Sub(webFS, "web/dist")
	if err != nil {
		panic("failed to open embedded web/dist sub-filesystem")
	}

	// Detect at startup whether the web UI has been built
	webBuilt := false
	if f, err := distFS.Open("index.html"); err == nil {
		_ = f.Close()
		webBuilt = true
	}

	fileServer := http.FileServer(http.FS(distFS))

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !webBuilt {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(webNotBuiltHTML))
			return
		}

		path := strings.TrimPrefix(r.URL.Path, "/")
		if path == "" {
			path = "index.html"
		}

		f, err := distFS.Open(path)
		if err != nil {
			// Unknown path — serve index.html for SPA client-side routing
			r.URL.Path = "/"
		} else {
			_ = f.Close()
		}

		fileServer.ServeHTTP(w, r)
	})
}

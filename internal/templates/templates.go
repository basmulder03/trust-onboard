package templates

import (
	"html/template"
	"io/fs"

	"trust-onboard/web"
)

func Parse() (*template.Template, error) {
	return template.ParseFS(web.Files, "templates/*.html")
}

func StaticFS() (fs.FS, error) {
	return fs.Sub(web.Files, "static")
}

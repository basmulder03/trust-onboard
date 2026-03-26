package server

import (
	"fmt"
	"html/template"
	"log"
	"net/http"
	"strings"

	"trust-onboard/internal/cert"
	"trust-onboard/internal/templates"
)

type pageData struct {
	SiteTitle              string
	OrganizationName       string
	DisplayedCAName        string
	BaseURL                string
	Fingerprint            string
	SupportText            string
	SupportURL             string
	InternalDomains        []string
	ExternalDomains        []string
	FooterText             string
	AdvancedSectionEnabled bool
	HasLogo                bool
	AndroidFormat          string
	HomeQRURL              string
	IOSQRURL               string
	AndroidQRURL           string
	RootURL                string
	IOSURL                 string
	AndroidURL             string
	LogoURL                string
	CertificateSubject     string
	CertificateValidity    string
	ManualPEMURL           string
	RootCASourcePath       string
	LinuxLocations         []string
	MacOSLocations         []string
	WindowsLocations       []string
	AndroidLocations       []string
	IOSLocations           []string
	ManualLocations        []string
}

func New(bundle *cert.Bundle) (http.Handler, error) {
	tmpl, err := templates.Parse()
	if err != nil {
		return nil, fmt.Errorf("parse templates: %w", err)
	}
	staticFS, err := templates.StaticFS()
	if err != nil {
		return nil, fmt.Errorf("load static assets: %w", err)
	}

	mux := http.NewServeMux()
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.FS(staticFS))))
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("/", indexHandler(tmpl, bundle))
	mux.HandleFunc("/download/root.crt", download(bundle.RootDownloadName, contentTypeForRoot(bundle), bundle.CertificatePEM, false))
	mux.HandleFunc("/download/ios.mobileconfig", download(bundle.IOSDownloadName, "application/x-apple-aspen-config", bundle.MobileConfig, true))
	mux.HandleFunc("/download/android.cer", download(bundle.AndroidDownloadName, contentTypeForAndroid(bundle), bundle.AndroidCertificate, false))
	mux.HandleFunc("/qr/home.png", binary("image/png", bundle.HomeQRCodePNG))
	mux.HandleFunc("/qr/ios.png", binary("image/png", bundle.IOSQRCodePNG))
	mux.HandleFunc("/qr/android.png", binary("image/png", bundle.AndroidQRCodePNG))
	if len(bundle.LogoBytes) > 0 {
		mux.HandleFunc("/assets/logo", binary(bundle.LogoContentType, bundle.LogoBytes))
	}

	return requestLogger(mux), nil
}

func indexHandler(tmpl *template.Template, bundle *cert.Bundle) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		data := pageData{
			SiteTitle:              bundle.Config.SiteTitle,
			OrganizationName:       bundle.Config.OrganizationName,
			DisplayedCAName:        bundle.Config.DisplayedCAName,
			BaseURL:                strings.TrimRight(bundle.Config.BaseURL, "/"),
			Fingerprint:            bundle.Fingerprint,
			SupportText:            bundle.Config.SupportText,
			SupportURL:             bundle.Config.SupportURL,
			InternalDomains:        bundle.Config.InternalDomains,
			ExternalDomains:        bundle.Config.ExternalDomains,
			FooterText:             bundle.Config.FooterText,
			AdvancedSectionEnabled: bundle.Config.AdvancedSectionEnabled,
			HasLogo:                len(bundle.LogoBytes) > 0,
			AndroidFormat:          strings.ToUpper(bundle.Config.Android.CertFormat),
			HomeQRURL:              "/qr/home.png",
			IOSQRURL:               "/qr/ios.png",
			AndroidQRURL:           "/qr/android.png",
			RootURL:                "/download/root.crt",
			IOSURL:                 "/download/ios.mobileconfig",
			AndroidURL:             "/download/android.cer",
			LogoURL:                "/assets/logo",
			CertificateSubject:     bundle.Certificate.Subject.String(),
			CertificateValidity:    bundle.Certificate.NotBefore.Format("2006-01-02") + " to " + bundle.Certificate.NotAfter.Format("2006-01-02"),
			ManualPEMURL:           "/download/root.crt",
			RootCASourcePath:       bundle.Config.RootCASourcePath(),
			LinuxLocations:         bundle.Config.RootCALocations.LinuxPaths,
			MacOSLocations:         bundle.Config.RootCALocations.MacOSStores,
			WindowsLocations:       bundle.Config.RootCALocations.Windows,
			AndroidLocations:       bundle.Config.RootCALocations.Android,
			IOSLocations:           bundle.Config.RootCALocations.IOS,
			ManualLocations:        bundle.Config.RootCALocations.Manual,
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		if err := tmpl.ExecuteTemplate(w, "index.html", data); err != nil {
			http.Error(w, "template render error", http.StatusInternalServerError)
		}
	}
}

func download(filename, contentType string, body []byte, attachment bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if attachment {
			w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", filename))
		} else {
			w.Header().Set("Content-Disposition", fmt.Sprintf("inline; filename=%q", filename))
		}
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Cache-Control", "public, max-age=300")
		_, _ = w.Write(body)
	}
}

func binary(contentType string, body []byte) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Cache-Control", "public, max-age=300")
		_, _ = w.Write(body)
	}
}

func requestLogger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s %s", r.Method, r.URL.Path, r.RemoteAddr)
		next.ServeHTTP(w, r)
	})
}

func contentTypeForAndroid(bundle *cert.Bundle) string {
	if bundle.Config.Android.CertFormat == "der" {
		return "application/pkix-cert"
	}
	return "application/x-pem-file"
}

func contentTypeForRoot(bundle *cert.Bundle) string {
	if len(bundle.CertificatePEM) > 0 {
		return "application/x-pem-file"
	}
	return "application/pkix-cert"
}

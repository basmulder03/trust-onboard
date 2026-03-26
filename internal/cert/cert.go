package cert

import (
	"crypto/sha256"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"trust-onboard/internal/config"
	"trust-onboard/internal/mobileconfig"
	"trust-onboard/internal/qr"
)

type Bundle struct {
	Config              *config.Config
	Certificate         *x509.Certificate
	CertificatePEM      []byte
	CertificateDER      []byte
	Fingerprint         string
	MobileConfig        []byte
	AndroidCertificate  []byte
	LogoBytes           []byte
	LogoContentType     string
	HomeQRCodePNG       []byte
	IOSQRCodePNG        []byte
	AndroidQRCodePNG    []byte
	ResolvedRootCAPath  string
	ResolvedLogoPath    string
	RootDownloadName    string
	AndroidDownloadName string
	IOSDownloadName     string
}

func LoadBundle(cfg *config.Config) (*Bundle, error) {
	resolvedRoot := cfg.ResolvePath(cfg.RootCASourcePath())
	pemBytes, cert, err := readCertificate(resolvedRoot)
	if err != nil {
		return nil, err
	}

	fingerprint := cfg.Fingerprint.Override
	if cfg.Fingerprint.AutoCalculate || fingerprint == "" {
		fingerprint = SHA256Fingerprint(cert.Raw)
	}

	profile, err := mobileconfig.Build(cfg, cert.Raw)
	if err != nil {
		return nil, fmt.Errorf("build mobileconfig: %w", err)
	}

	androidBytes := pemBytes
	if cfg.Android.CertFormat == "der" {
		androidBytes = cert.Raw
	}

	base := strings.TrimRight(cfg.BaseURL, "/")
	homeQR, err := qr.PNG(base+"/", 256)
	if err != nil {
		return nil, fmt.Errorf("generate home QR code: %w", err)
	}
	iosQR, err := qr.PNG(base+"/download/ios.mobileconfig", 256)
	if err != nil {
		return nil, fmt.Errorf("generate iOS QR code: %w", err)
	}
	androidQR, err := qr.PNG(base+"/download/android.cer", 256)
	if err != nil {
		return nil, fmt.Errorf("generate Android QR code: %w", err)
	}

	bundle := &Bundle{
		Config:              cfg,
		Certificate:         cert,
		CertificatePEM:      pemBytes,
		CertificateDER:      cert.Raw,
		Fingerprint:         fingerprint,
		MobileConfig:        profile,
		AndroidCertificate:  androidBytes,
		HomeQRCodePNG:       homeQR,
		IOSQRCodePNG:        iosQR,
		AndroidQRCodePNG:    androidQR,
		ResolvedRootCAPath:  resolvedRoot,
		RootDownloadName:    "root_ca.crt",
		AndroidDownloadName: "android-root.cer",
		IOSDownloadName:     "trust-onboard.mobileconfig",
	}

	if cfg.LogoPath != "" {
		resolvedLogo := cfg.ResolvePath(cfg.LogoPath)
		logo, err := os.ReadFile(resolvedLogo)
		if err != nil {
			return nil, fmt.Errorf("read logo file: %w", err)
		}
		bundle.LogoBytes = logo
		bundle.LogoContentType = detectLogoContentType(resolvedLogo)
		bundle.ResolvedLogoPath = resolvedLogo
	}

	return bundle, nil
}

func readCertificate(path string) ([]byte, *x509.Certificate, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, fmt.Errorf("read root certificate: %w", err)
	}

	block, _ := pem.Decode(data)
	if block == nil {
		cert, err := x509.ParseCertificate(data)
		if err != nil {
			return nil, nil, fmt.Errorf("parse DER certificate: %w", err)
		}
		return pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: cert.Raw}), cert, nil
	}

	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, nil, fmt.Errorf("parse PEM certificate: %w", err)
	}
	return pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: cert.Raw}), cert, nil
}

func SHA256Fingerprint(raw []byte) string {
	sum := sha256.Sum256(raw)
	encoded := strings.ToUpper(hex.EncodeToString(sum[:]))
	parts := make([]string, 0, len(encoded)/2)
	for i := 0; i < len(encoded); i += 2 {
		parts = append(parts, encoded[i:i+2])
	}
	return strings.Join(parts, ":")
}

func detectLogoContentType(path string) string {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".svg":
		return "image/svg+xml"
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".gif":
		return "image/gif"
	case ".webp":
		return "image/webp"
	default:
		return "image/png"
	}
}

func (b *Bundle) WriteArtifacts(outputDir string) error {
	files := map[string][]byte{
		filepath.Join(outputDir, b.RootDownloadName):    b.CertificatePEM,
		filepath.Join(outputDir, b.IOSDownloadName):     b.MobileConfig,
		filepath.Join(outputDir, b.AndroidDownloadName): b.AndroidCertificate,
		filepath.Join(outputDir, "home-qr.png"):         b.HomeQRCodePNG,
		filepath.Join(outputDir, "ios-qr.png"):          b.IOSQRCodePNG,
		filepath.Join(outputDir, "android-qr.png"):      b.AndroidQRCodePNG,
		filepath.Join(outputDir, "fingerprint.txt"):     []byte(b.Fingerprint + "\n"),
	}

	for path, content := range files {
		if err := os.WriteFile(path, content, 0o644); err != nil {
			return fmt.Errorf("write %s: %w", path, err)
		}
	}
	return nil
}

package config

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

type Config struct {
	SiteTitle              string            `json:"site_title" yaml:"site_title"`
	OrganizationName       string            `json:"organization_name" yaml:"organization_name"`
	ListenAddress          string            `json:"listen_address" yaml:"listen_address"`
	BaseURL                string            `json:"base_url" yaml:"base_url"`
	DisplayedCAName        string            `json:"displayed_ca_name" yaml:"displayed_ca_name"`
	RootCACertPath         string            `json:"root_ca_cert_path" yaml:"root_ca_cert_path"`
	RootCALocations        RootCALocations   `json:"root_ca_locations" yaml:"root_ca_locations"`
	Android                AndroidConfig     `json:"android" yaml:"android"`
	IOS                    IOSConfig         `json:"ios" yaml:"ios"`
	Fingerprint            FingerprintConfig `json:"fingerprint" yaml:"fingerprint"`
	SupportText            string            `json:"support_text" yaml:"support_text"`
	SupportURL             string            `json:"support_url" yaml:"support_url"`
	LogoPath               string            `json:"logo_path" yaml:"logo_path"`
	InternalDomains        []string          `json:"internal_domains" yaml:"internal_domains"`
	ExternalDomains        []string          `json:"external_domains" yaml:"external_domains"`
	FooterText             string            `json:"footer_text" yaml:"footer_text"`
	AdvancedSectionEnabled bool              `json:"advanced_section_enabled" yaml:"advanced_section_enabled"`
	ConfigDir              string            `json:"-" yaml:"-"`
}

type AndroidConfig struct {
	CertFormat string `json:"cert_format" yaml:"cert_format"`
}

type RootCALocations struct {
	SourcePath  string   `json:"source_path" yaml:"source_path"`
	LinuxPaths  []string `json:"linux_paths" yaml:"linux_paths"`
	MacOSStores []string `json:"macos_stores" yaml:"macos_stores"`
	Windows     []string `json:"windows" yaml:"windows"`
	Android     []string `json:"android" yaml:"android"`
	IOS         []string `json:"ios" yaml:"ios"`
	Manual      []string `json:"manual" yaml:"manual"`
}

type IOSConfig struct {
	PayloadIdentifier   string `json:"payload_identifier" yaml:"payload_identifier"`
	PayloadDisplayName  string `json:"payload_display_name" yaml:"payload_display_name"`
	PayloadOrganization string `json:"payload_organization" yaml:"payload_organization"`
	PayloadDescription  string `json:"payload_description" yaml:"payload_description"`
}

type FingerprintConfig struct {
	AutoCalculate bool   `json:"auto_calculate" yaml:"auto_calculate"`
	Override      string `json:"override" yaml:"override"`
}

func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read config file: %w", err)
	}

	var cfg Config
	switch strings.ToLower(filepath.Ext(path)) {
	case ".json":
		if err := json.Unmarshal(data, &cfg); err != nil {
			return nil, fmt.Errorf("parse JSON config: %w", err)
		}
	default:
		if err := yaml.Unmarshal(data, &cfg); err != nil {
			return nil, fmt.Errorf("parse YAML config: %w", err)
		}
	}

	cfg.ConfigDir = filepath.Dir(path)
	cfg.applyDefaults()
	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	return &cfg, nil
}

func (c *Config) applyDefaults() {
	if c.ListenAddress == "" {
		c.ListenAddress = ":8080"
	}
	if c.Android.CertFormat == "" {
		c.Android.CertFormat = "pem"
	}
	if c.RootCALocations.SourcePath == "" {
		c.RootCALocations.SourcePath = c.RootCACertPath
	}
	if len(c.RootCALocations.LinuxPaths) == 0 {
		c.RootCALocations.LinuxPaths = []string{"/usr/local/share/ca-certificates/root_ca.crt", "/etc/pki/ca-trust/source/anchors/root_ca.crt"}
	}
	if len(c.RootCALocations.MacOSStores) == 0 {
		c.RootCALocations.MacOSStores = []string{"System keychain", "login keychain"}
	}
	if len(c.RootCALocations.Windows) == 0 {
		c.RootCALocations.Windows = []string{"Local Computer > Trusted Root Certification Authorities", "Current User > Trusted Root Certification Authorities"}
	}
	if len(c.RootCALocations.Android) == 0 {
		c.RootCALocations.Android = []string{"Settings > Security > Encryption & credentials > Install a certificate", "Managed device certificate payload via MDM"}
	}
	if len(c.RootCALocations.IOS) == 0 {
		c.RootCALocations.IOS = []string{"Downloaded configuration profile in Settings", "Managed device trust payload via MDM"}
	}
	if len(c.RootCALocations.Manual) == 0 {
		c.RootCALocations.Manual = []string{"Distribute the PEM root certificate through your configuration management or MDM tooling"}
	}
	if c.FooterText == "" {
		c.FooterText = "Public trust onboarding for internal services."
	}
	if c.Fingerprint.AutoCalculate == false && c.Fingerprint.Override == "" {
		c.Fingerprint.AutoCalculate = true
	}
	if c.IOS.PayloadDisplayName == "" && c.DisplayedCAName != "" {
		c.IOS.PayloadDisplayName = c.DisplayedCAName
	}
	if c.IOS.PayloadOrganization == "" && c.OrganizationName != "" {
		c.IOS.PayloadOrganization = c.OrganizationName
	}
	if c.IOS.PayloadDescription == "" && c.DisplayedCAName != "" {
		c.IOS.PayloadDescription = "Installs the public root certificate for " + c.DisplayedCAName
	}
	if c.IOS.PayloadIdentifier == "" && c.OrganizationName != "" {
		clean := strings.ToLower(strings.ReplaceAll(c.OrganizationName, " ", "-"))
		c.IOS.PayloadIdentifier = "local." + clean + ".trust-onboard.root"
	}
}

func (c *Config) Validate() error {
	var errs []string
	if c.SiteTitle == "" {
		errs = append(errs, "site_title is required")
	}
	if c.OrganizationName == "" {
		errs = append(errs, "organization_name is required")
	}
	if c.BaseURL == "" {
		errs = append(errs, "base_url is required")
	} else if u, err := url.Parse(c.BaseURL); err != nil || u.Scheme == "" || u.Host == "" {
		errs = append(errs, "base_url must be an absolute URL")
	}
	if c.DisplayedCAName == "" {
		errs = append(errs, "displayed_ca_name is required")
	}
	if c.RootCACertPath == "" {
		errs = append(errs, "root_ca_cert_path is required")
	}
	if c.RootCALocations.SourcePath == "" {
		errs = append(errs, "root_ca_locations.source_path is required")
	}
	if c.Android.CertFormat != "pem" && c.Android.CertFormat != "der" {
		errs = append(errs, "android.cert_format must be pem or der")
	}
	if c.IOS.PayloadIdentifier == "" {
		errs = append(errs, "ios.payload_identifier is required")
	}
	if c.IOS.PayloadDisplayName == "" {
		errs = append(errs, "ios.payload_display_name is required")
	}
	if c.IOS.PayloadOrganization == "" {
		errs = append(errs, "ios.payload_organization is required")
	}
	if c.IOS.PayloadDescription == "" {
		errs = append(errs, "ios.payload_description is required")
	}
	if c.SupportURL != "" {
		if u, err := url.Parse(c.SupportURL); err != nil || u.Scheme == "" || u.Host == "" {
			errs = append(errs, "support_url must be an absolute URL when set")
		}
	}
	if len(errs) > 0 {
		return errors.New(strings.Join(errs, "; "))
	}
	return nil
}

func (c *Config) RootCASourcePath() string {
	if c.RootCALocations.SourcePath != "" {
		return c.RootCALocations.SourcePath
	}
	return c.RootCACertPath
}

func (c *Config) ResolvePath(value string) string {
	if value == "" || filepath.IsAbs(value) {
		return value
	}
	return filepath.Join(c.ConfigDir, value)
}

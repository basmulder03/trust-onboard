# Configuration

`trust-onboard` reads YAML or JSON configuration from disk.

The example file is `config.example.yaml`.

## Example

```yaml
site_title: Homelab Trust Onboarding
organization_name: Mulder Homelab
listen_address: ":8080"
base_url: "https://trust.example.internal"
displayed_ca_name: Homelab Root CA
root_ca_cert_path: "assets/root_ca.crt"

root_ca_locations:
  source_path: "assets/root_ca.crt"
  linux_paths:
    - "/usr/local/share/ca-certificates/root_ca.crt"
    - "/etc/pki/ca-trust/source/anchors/root_ca.crt"
  macos_stores:
    - "System keychain"
    - "login keychain"
  windows:
    - "Local Computer > Trusted Root Certification Authorities"
  android:
    - "Settings > Security > Encryption & credentials > Install a certificate"
  ios:
    - "Downloaded configuration profile in Settings"
  manual:
    - "Distribute the PEM root certificate through your configuration management or MDM tooling"

android:
  cert_format: pem

ios:
  payload_identifier: "local.mulder.homelab.trust-onboard.root"
  payload_display_name: "Mulder Homelab Root CA"
  payload_organization: "Mulder Homelab"
  payload_description: "Installs the public root certificate used by internal services."

fingerprint:
  auto_calculate: true
  override: ""

support_text: "If trust still fails, remove older copies of the root certificate and verify the fingerprint with your administrator."
support_url: "https://wiki.example.internal/trust"
logo_path: "assets/logo.svg"

internal_domains:
  - "step.example.internal"
  - "grafana.example.internal"

external_domains:
  - "vpn.example.com"

footer_text: "Public trust onboarding for private infrastructure."
advanced_section_enabled: true
```

## Important fields

- `base_url` is the externally reachable URL used in generated QR codes and links
- `root_ca_cert_path` points to the public root CA certificate on disk
- `root_ca_locations.source_path` is the effective source path used by the app
- `root_ca_locations.*` controls the location hints shown in the onboarding UI
- `android.cert_format` can be `pem` or `der`
- `fingerprint.auto_calculate` computes the SHA-256 fingerprint from the certificate
- `fingerprint.override` replaces the displayed fingerprint value

## Compatibility note

`root_ca_cert_path` is still supported.

- If `root_ca_locations.source_path` is set, it takes precedence
- If `root_ca_locations.source_path` is omitted, it defaults to `root_ca_cert_path`

## Certificate input

Place only the public root certificate on disk.

Example:

- `/var/lib/trust-onboard/assets/root_ca.crt`

The file may be PEM or DER encoded.

Do not place private keys, provisioners, ACME account material, or other CA secrets in this project.

## Generated artifacts

- SHA-256 fingerprint
- iOS `.mobileconfig`
- Android `.cer`
- QR codes for the home page, iOS profile URL, and Android cert URL

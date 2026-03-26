package mobileconfig

import (
	"crypto/sha1"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"strings"

	"trust-onboard/internal/config"
)

func Build(cfg *config.Config, certDER []byte) ([]byte, error) {
	uuid1 := deterministicUUID(cfg.IOS.PayloadIdentifier + ":root")
	uuid2 := deterministicUUID(cfg.IOS.PayloadIdentifier + ":profile")
	encoded := base64.StdEncoding.EncodeToString(certDER)

	content := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PayloadContent</key>
	<array>
		<dict>
			<key>PayloadCertificateFileName</key>
			<string>%s.crt</string>
			<key>PayloadContent</key>
			<data>
			%s
			</data>
			<key>PayloadDescription</key>
			<string>%s</string>
			<key>PayloadDisplayName</key>
			<string>%s</string>
			<key>PayloadIdentifier</key>
			<string>%s.certificate</string>
			<key>PayloadOrganization</key>
			<string>%s</string>
			<key>PayloadType</key>
			<string>com.apple.security.root</string>
			<key>PayloadUUID</key>
			<string>%s</string>
			<key>PayloadVersion</key>
			<integer>1</integer>
		</dict>
	</array>
	<key>PayloadDescription</key>
	<string>%s</string>
	<key>PayloadDisplayName</key>
	<string>%s</string>
	<key>PayloadIdentifier</key>
	<string>%s</string>
	<key>PayloadOrganization</key>
	<string>%s</string>
	<key>PayloadRemovalDisallowed</key>
	<false/>
	<key>PayloadType</key>
	<string>Configuration</string>
	<key>PayloadUUID</key>
	<string>%s</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
</dict>
</plist>
`, xmlSafe(cfg.DisplayedCAName), wrapBase64(encoded, 52), xmlSafe(cfg.IOS.PayloadDescription), xmlSafe(cfg.IOS.PayloadDisplayName), xmlSafe(cfg.IOS.PayloadIdentifier), xmlSafe(cfg.IOS.PayloadOrganization), uuid1, xmlSafe(cfg.IOS.PayloadDescription), xmlSafe(cfg.IOS.PayloadDisplayName), xmlSafe(cfg.IOS.PayloadIdentifier), xmlSafe(cfg.IOS.PayloadOrganization), uuid2)

	return []byte(content), nil
}

func deterministicUUID(seed string) string {
	sum := sha1.Sum([]byte(seed))
	seedHex := hex.EncodeToString(sum[:16])
	return fmt.Sprintf("%s-%s-%s-%s-%s", seedHex[0:8], seedHex[8:12], seedHex[12:16], seedHex[16:20], seedHex[20:32])
}

func wrapBase64(input string, width int) string {
	if width <= 0 || len(input) <= width {
		return input
	}
	var parts []string
	for len(input) > width {
		parts = append(parts, input[:width])
		input = input[width:]
	}
	if input != "" {
		parts = append(parts, input)
	}
	return strings.Join(parts, "\n\t\t\t")
}

func xmlSafe(input string) string {
	replacer := strings.NewReplacer(
		"&", "&amp;",
		"<", "&lt;",
		">", "&gt;",
		`"`, "&quot;",
		"'", "&apos;",
	)
	return replacer.Replace(input)
}

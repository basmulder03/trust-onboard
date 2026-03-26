package qr

import qrcode "github.com/skip2/go-qrcode"

func PNG(content string, size int) ([]byte, error) {
	return qrcode.Encode(content, qrcode.Medium, size)
}

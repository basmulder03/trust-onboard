# Deployment

## Runtime behavior

- Foreground process
- Stdout/stderr logging
- Graceful `SIGINT` and `SIGTERM`
- Startup validation before serving
- Non-zero exit on startup failure
- HTTP timeouts enabled
- `/healthz` endpoint available

## systemd deployment

- Binary: `/usr/local/bin/trust-onboard`
- Config: `/etc/trust-onboard/config.yaml`
- Assets: `/var/lib/trust-onboard/assets/`

Create service user and directories:

```bash
sudo groupadd --system trust-onboard
sudo useradd --system --gid trust-onboard --home /var/lib/trust-onboard --shell /usr/sbin/nologin trust-onboard
sudo install -d -o root -g root -m 0755 /etc/trust-onboard
sudo install -d -o trust-onboard -g trust-onboard -m 0750 /var/lib/trust-onboard
sudo install -d -o trust-onboard -g trust-onboard -m 0750 /var/lib/trust-onboard/assets
```

Install files:

```bash
sudo install -o root -g root -m 0755 ./bin/trust-onboard /usr/local/bin/trust-onboard
sudo install -o root -g root -m 0644 ./config.example.yaml /etc/trust-onboard/config.yaml
sudo install -o trust-onboard -g trust-onboard -m 0644 ./assets/root_ca.crt /var/lib/trust-onboard/assets/root_ca.crt
sudo install -o trust-onboard -g trust-onboard -m 0644 ./assets/logo.svg /var/lib/trust-onboard/assets/logo.svg
sudo install -o root -g root -m 0644 ./packaging/trust-onboard.service /etc/systemd/system/trust-onboard.service
```

Start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now trust-onboard.service
sudo systemctl status trust-onboard.service
```

## Reverse proxy examples

### nginx

```nginx
server {
    listen 443 ssl http2;
    server_name trust.example.internal;

    ssl_certificate /etc/letsencrypt/live/trust.example.internal/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/trust.example.internal/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host $host;
    }
}
```

### Caddy

```caddyfile
trust.example.internal {
    reverse_proxy 127.0.0.1:8080
}
```

### Traefik

```yaml
http:
  routers:
    trust-onboard:
      rule: Host(`trust.example.internal`)
      service: trust-onboard
      tls: {}
  services:
    trust-onboard:
      loadBalancer:
        servers:
          - url: http://127.0.0.1:8080
```

## Security notes

- Run as an unprivileged user
- Put the service behind HTTPS
- Serve only public trust material
- Verify fingerprints out of band when possible
- Test platform trust behavior on the actual device versions you support

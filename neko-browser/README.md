# neko-browser

A free, open-source, self-hosted **virtual browser** you can embed in any website with an `<iframe>` — a Hyperbeam alternative with no API keys, no paid services and no session time limits.

It runs a real Firefox / Chromium / Chrome / Brave / Edge inside Docker on your own Linux server and streams it over WebRTC using [Neko](https://github.com/m1k1o/neko) ([docs](https://neko.m1k1o.net)). Multiple people can watch together and pass control around.

## Requirements

- A Linux server (Ubuntu 22.04 / 24.04, x86_64 or ARM64) with **2+ vCPU and 2+ GB RAM**
- A public IP address
- **Free option:** the [Oracle Cloud Always Free](https://www.oracle.com/cloud/free/) Ampere ARM VM (up to 4 OCPU / 24 GB RAM)

> On ARM, use `firefox`, `chromium` or `brave`. The `google-chrome` and `microsoft-edge` images are x86_64 only.

## Quick start

```bash
git clone https://github.com/<you>/neko-browser.git
cd neko-browser
bash setup.sh
```

The script installs Docker if needed, creates `.env` with your public IP and random passwords, opens the firewall, and starts the container. It prints the URL and passwords when it's done. Open `http://YOUR_IP:8080` and log in with any name plus the user password, or with the admin password.

You can run `setup.sh` again at any time. It won't duplicate firewall rules or overwrite your `.env`.

## HTTPS mode

You need a domain whose DNS A record points to your server. Then run:

```bash
bash setup.sh browser.example.com
```

This starts [Caddy](https://caddyserver.com) on ports 80/443, and Caddy gets a free Let's Encrypt certificate automatically. The browser is then available at `https://browser.example.com`. You need HTTPS mode to embed the browser in a site that uses `https://`.

## Embed it

```html
<iframe
  src="https://browser.example.com/?usr=guest&pwd=YOUR_USER_PASSWORD"
  allow="autoplay; fullscreen; clipboard-read; clipboard-write"
  allowfullscreen
  style="width:100%;height:600px;border:0">
</iframe>
```

`usr` and `pwd` log the viewer in automatically. [`embed.html`](embed.html) is a ready-made full-page version that gives each viewer a random guest name. Edit `NEKO_URL` and `PASSWORD` at the top of its script.

> The user password is visible in your page source. Anyone who has it can join, so use it as a viewer password and keep the admin password private.

## Settings (`.env`)

| Key | Default | Description |
|---|---|---|
| `BROWSER` | `firefox` | `firefox`, `chromium`, `google-chrome`, `brave`, `microsoft-edge` |
| `SCREEN` | `1280x720@30` | Virtual screen resolution and FPS |
| `USER_PASSWORD` | random | Password for regular viewers |
| `ADMIN_PASSWORD` | random | Password for admins |
| `PUBLIC_IP` | auto-detected | Public IP advertised to WebRTC clients |
| `DOMAIN` | empty | If set, Caddy serves HTTPS for this domain |

After you edit `.env`, run `bash setup.sh` again or `docker compose up -d` to apply the changes. Add `--profile https` if you use a domain.

## Common commands

```bash
docker compose logs -f neko                # view logs
docker compose restart neko                # restart the browser
docker compose --profile https down        # stop everything
docker compose pull && bash setup.sh       # update to the latest image
```

(If your user isn't in the `docker` group yet, prefix these with `sudo`. You can also log out and back in to pick up the group.)

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| **Page loads, but the video is black or frozen** | Port **52000 UDP and TCP** is blocked. Open it in your cloud provider's firewall (Oracle security list, AWS security group, …). Also check that `PUBLIC_IP` in `.env` is your real public IP. |
| **Page won't load at all** | Port **8080** (HTTP mode) or **80/443** (HTTPS mode) is blocked in the cloud firewall. Or the container isn't running: check `docker compose ps`. |
| **Blank iframe on an https:// site** | Browsers block `http://` iframes inside `https://` pages. Use HTTPS mode (`bash setup.sh your.domain.com`) and an `https://` URL. |
| **Caddy fails to get a certificate** | The domain's DNS doesn't point to the server yet, or port 80/443 is closed. |

On **Oracle Cloud**, add *Ingress Rules* to the VCN's default security list for TCP 8080, 52000, 80 and 443 and UDP 52000 (source `0.0.0.0/0`). `setup.sh` already handles Ubuntu's built-in iptables REJECT rule.

## License

The files in this repo are MIT. Neko itself is Apache-2.0.

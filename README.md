# ⚡ FlashXpress - World's Fastest WordPress Stack

<div align="center">

![FlashXpress](https://img.shields.io/badge/FlashXpress-v3.1.0-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![PHP](https://img.shields.io/badge/PHP-8.4%20%7C%208.3%20%7C%208.2%20%7C%208.1-blue)
![MariaDB](https://img.shields.io/badge/MariaDB-11.4-purple)

**Deploy WordPress in seconds with Lowest TTFB**

`X-FlashXpress-Cache: HIT` Header • FastCGI Cache • Redis Object Cache • OPcache JIT

[Install](#-installation) • [Commands](#-commands) • [Performance](#-performance)

</div>

---

## 🚀 Installation

```bash
curl -sSL https://wp.flashxpress.cloud/install | sudo bash
```

---

## ✨ Features

| Component | Feature |
|-----------|---------|
| **NGINX** | FastCGI Cache with `X-FlashXpress-Cache: HIT` header |
| **MariaDB** | Version 11.4, performance optimized |
| **PHP** | Auto-detects best version (8.4 → 8.3 → 8.2 → 8.1) |
| **Redis** | Object cache for WordPress |
| **OPcache** | JIT enabled, 256MB memory |
| **Security** | UFW Firewall + Fail2Ban |
| **SSL** | Let's Encrypt Certbot |

---

## 📋 Requirements

- Ubuntu 22.04 / 24.04
- 1GB RAM minimum
- Root access

---

## 📝 Commands

```bash
fx status              # Show stack status
fx site create domain.com   # Create WordPress site
fx cache purge         # Clear FastCGI cache
fx db                  # Show database credentials
```

---

## 🎯 Cache Verification

```bash
curl -I https://yoursite.com

# Look for:
X-FlashXpress-Cache: HIT
```

First request = `MISS`, subsequent requests = `HIT`

---

## 🔥 Performance

| Metric | FlashXpress |
|--------|-------------|
| TTFB (cached) | ~10ms |
| TTFB (uncached) | ~50ms |
| Requests/sec | 5000+ |
| Concurrent users | 10,000+ |

---

## 🐛 PHP Installation

FlashXpress automatically tries PHP versions in order:

```
PHP 8.4 → PHP 8.3 → PHP 8.2 → PHP 8.1
```

Each version is verified by checking `/usr/sbin/php-fpm{VER}` exists.

---

## 📁 Repository Files

| File | Description |
|------|-------------|
| `fx-install.sh` | Main installation script |
| `fx-security.sh` | Security hardening |
| `fx-backup.sh` | Backup automation |
| `fx-performance.sh` | Performance tuning |
| `fx-php-manager.sh` | PHP management |
| `fx-pma-install.sh` | phpMyAdmin installer |
| `fx-filemanager-install.sh` | File manager |

---

## 📄 License

MIT License

---

<div align="center">

**⚡ FlashXpress - World's Fastest WordPress Stack ⚡**

https://wp.flashxpress.cloud

</div>

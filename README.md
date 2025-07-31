# 🚨 Zentra Host DDoS Protection Script

A powerful, production-ready Layer 3, 4 & 7 DDoS protection script designed specifically for **Minecraft VPS servers**. Blocks ICMP floods, UDP spoofing, SYN floods, Minecraft bot spam, and brute-force join attempts.

> ⚙️ Designed for Linux (Debian/Ubuntu/CentOS) VPS with root access

---

## 🔰 Features

- ✅ **Layer 3**: ICMP ping flood blocking
- ✅ **Layer 4**: SYN flood + UDP flood + brute-force limiter
- ✅ **Layer 7**: Detects Minecraft-specific spam via `conntrack`
- ✅ Auto-bans IPs that exceed allowed connections
- ✅ Auto-unban after timeout
- ✅ Logging system with timestamps
- ✅ Can run via `cron`, `screen`, or systemd
- 🛠️ Compatible with: `iptables`, `conntrack-tools`, `bash`, `awk`

---

## 📦 One-Line Installation

```bash
bash <(curl -s https://raw.githubusercontent.com/zentra-host/ddos-protection/main/zentra-ddos-protection.sh)

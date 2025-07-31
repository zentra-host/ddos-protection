#!/bin/bash

# === Zentra Host DDoS Protection Script ===
# Layers: L3 (ICMP), L4 (TCP/UDP), L7 (Minecraft spam bots)
# Target: Minecraft VPS servers
# Requires: iptables, conntrack-tools, screen (optional), fail2ban (optional)

# === CONFIG ===
MC_PORT=25565
MAX_CONN_PER_IP=80
MAX_NEW_CONN_PER_MIN=100
BAN_DURATION=3600
BAN_LOG="/var/log/zentra_ddos_bans.log"
BAN_LIST="/var/tmp/zentra_banned_ips.txt"
RATE_LIMIT_NAME="zentra_mc_conn"

# === Setup ===
mkdir -p /var/tmp
touch "$BAN_LIST"

# === CORE IPTABLES RULES ===

# Reset previous Zentra chains if script is re-run
iptables -F

# Drop invalid packets
iptables -A INPUT -m state --state INVALID -j DROP

# Drop common port scans
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

# ICMP flood protection
iptables -A INPUT -p icmp -m limit --limit 1/s --limit-burst 4 -j ACCEPT
iptables -A INPUT -p icmp -j DROP

# SYN flood protection
iptables -A INPUT -p tcp --syn -m limit --limit 2/s --limit-burst 6 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP

# UDP flood protection (MC ping spoof)
iptables -A INPUT -p udp --dport "$MC_PORT" -m limit --limit 20/s --limit-burst 40 -j ACCEPT
iptables -A INPUT -p udp --dport "$MC_PORT" -j DROP

# L4 brute-force protection
iptables -C INPUT -p tcp --dport "$MC_PORT" -m hashlimit --hashlimit-above ${MAX_NEW_CONN_PER_MIN}/minute --hashlimit-mode srcip --hashlimit-name $RATE_LIMIT_NAME -j DROP 2>/dev/null || \
iptables -A INPUT -p tcp --dport "$MC_PORT" -m hashlimit --hashlimit-above ${MAX_NEW_CONN_PER_MIN}/minute --hashlimit-mode srcip --hashlimit-name $RATE_LIMIT_NAME -j DROP

# === L7: Minecraft DoS via conntrack (established floods) ===
echo "[INFO] Scanning for excessive Minecraft connections on port $MC_PORT..."

suspicious_ips=$(conntrack -L | grep dport=$MC_PORT | grep ESTABLISHED | awk '{print $5}' | cut -d= -f2 | sort | uniq -c | sort -nr | awk -v max="$MAX_CONN_PER_IP" '$1 > max {print $2}')

now=$(date '+%Y-%m-%d %H:%M:%S')

for ip in $suspicious_ips; do
    if ! grep -q "$ip" "$BAN_LIST"; then
        echo "[$now] [BAN] IP: $ip exceeded $MAX_CONN_PER_IP connections" | tee -a "$BAN_LOG"
        iptables -I INPUT -s "$ip" -j DROP
        echo "$ip $(date +%s)" >> "$BAN_LIST"
    fi
done

# === Auto-unban logic ===
tempfile=$(mktemp)
while read -r entry; do
    ip=$(echo $entry | awk '{print $1}')
    ban_time=$(echo $entry | awk '{print $2}')
    current_time=$(date +%s)
    elapsed=$((current_time - ban_time))

    if [[ $elapsed -ge $BAN_DURATION ]]; then
        echo "[$now] [UNBAN] IP: $ip after $BAN_DURATION seconds" | tee -a "$BAN_LOG"
        iptables -D INPUT -s "$ip" -j DROP
    else
        echo "$entry" >> "$tempfile"
    fi
done < "$BAN_LIST"
mv "$tempfile" "$BAN_LIST"

echo "[$now] [COMPLETE] Zentra DDoS scan done."


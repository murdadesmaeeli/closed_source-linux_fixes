#!/bin/bash
# Set up a direct Ethernet link between source and target laptops.
# Uses NetworkManager "shared" mode so the source laptop acts as a
# DHCP server + NAT gateway, giving the target internet access too.
#
# Usage:
#   On source laptop:  sudo ./02-setup-network.sh source
#   On target laptop:  sudo ./02-setup-network.sh target

set -euo pipefail

ROLE="${1:-}"
CON_NAME="ethernet-share"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Network Setup — Direct Ethernet Transfer Link"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$ROLE" != "source" && "$ROLE" != "target" ]]; then
    echo "Usage: sudo $0 <source|target>"
    echo ""
    echo "  source  — run on the current (Intel+NVIDIA) laptop"
    echo "  target  — run on the new (AMD) laptop"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Error: this script must be run as root (sudo)."
    exit 1
fi

# ─── Detect Ethernet interface ──────────────────────────────

echo "=== Detecting Ethernet interface ==="

ETH_IFACE=""
for iface in /sys/class/net/*; do
    name="$(basename "$iface")"
    [[ "$name" == "lo" ]] && continue
    [[ "$name" == veth* ]] && continue
    [[ "$name" == docker* ]] && continue
    [[ "$name" == br-* ]] && continue
    if [ -d "$iface/device" ] && [ ! -d "$iface/wireless" ]; then
        carrier=$(cat "$iface/carrier" 2>/dev/null || echo 0)
        if [ "$carrier" = "1" ]; then
            ETH_IFACE="$name"
            break
        fi
        [ -z "$ETH_IFACE" ] && ETH_IFACE="$name"
    fi
done

if [ -z "$ETH_IFACE" ]; then
    echo "   [!!] No Ethernet interface found."
    echo "   Available interfaces:"
    ip -br link | grep -v lo | while read -r line; do echo "     $line"; done
    echo ""
    read -rp "   Enter interface name manually: " ETH_IFACE
fi

echo "   [OK] Using interface: ${ETH_IFACE}"
echo ""

# ═══════════════════════════════════════════════════════════════
# SOURCE: set up shared connection (DHCP server + NAT gateway)
# ═══════════════════════════════════════════════════════════════

if [ "$ROLE" = "source" ]; then
    echo "=== Setting up shared connection (source) ==="

    # Check if the connection already exists
    if nmcli connection show "$CON_NAME" &>/dev/null; then
        echo "   [--] '${CON_NAME}' already exists"
        # Make sure it's on the right interface
        nmcli connection modify "$CON_NAME" connection.interface-name "$ETH_IFACE" 2>/dev/null || true
    else
        echo "   Creating '${CON_NAME}' on ${ETH_IFACE}..."
        nmcli connection add type ethernet ifname "$ETH_IFACE" \
            con-name "$CON_NAME" \
            ipv4.method shared \
            ipv6.method disabled
        echo "   [OK] Connection created"
    fi

    # Bring it up
    nmcli connection up "$CON_NAME" 2>/dev/null || true
    sleep 2

    # Get the assigned IP
    SOURCE_IP=$(ip -4 addr show "$ETH_IFACE" | grep -oP 'inet \K[^/]+' | head -1)
    echo "   [OK] Source IP: ${SOURCE_IP:-unknown} (${ETH_IFACE})"
    echo ""

    # SSH server
    echo "=== Ensuring SSH server is running ==="

    if ! dpkg -l openssh-server &>/dev/null 2>&1; then
        echo "   Installing openssh-server..."
        apt-get install -y openssh-server
    fi

    # Debian 13 uses 'ssh.service' not 'sshd.service'
    if systemctl is-active --quiet ssh 2>/dev/null; then
        echo "   [OK] ssh already running"
    else
        systemctl start ssh
        echo "   [OK] ssh started"
    fi

    echo ""

    # Wait for cable / target
    echo "=== Waiting for target to connect ==="
    echo "   Plug the Ethernet cable in and run on the target:"
    echo "     sudo ./02-setup-network.sh target"
    echo ""

    MAX_ATTEMPTS=60
    for i in $(seq 1 $MAX_ATTEMPTS); do
        # Check if any DHCP lease was handed out
        LEASES=$(journalctl -u NetworkManager --since "5 minutes ago" --no-pager 2>/dev/null \
            | grep -i "DHCP.*lease" | tail -1 || true)
        CARRIER=$(cat "/sys/class/net/${ETH_IFACE}/carrier" 2>/dev/null || echo 0)

        if [ "$CARRIER" = "1" ]; then
            echo "   [OK] Cable connected! Link is up."
            break
        fi
        if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
            echo "   [!!] No cable detected after ${MAX_ATTEMPTS} attempts."
            echo "   The connection is still active — plug in whenever ready."
            break
        fi
        printf "   Waiting for cable... (%d/%d)\r" "$i" "$MAX_ATTEMPTS"
        sleep 2
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Source Ready"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    SOURCE_IP=$(ip -4 addr show "$ETH_IFACE" | grep -oP 'inet \K[^/]+' | head -1)
    echo ""
    echo "  This machine: ${SOURCE_IP} (${ETH_IFACE})"
    echo "  Mode: shared (DHCP + NAT — target gets internet too)"
    echo "  SSH ready: ssh $(logname 2>/dev/null || echo oneking)@${SOURCE_IP}"
    echo ""
    echo "  The target laptop will auto-get an IP via DHCP."
    echo "  Next step: run 03-transfer.sh on the target"
    echo ""

# ═══════════════════════════════════════════════════════════════
# TARGET: just use DHCP (source is handing out addresses)
# ═══════════════════════════════════════════════════════════════

elif [ "$ROLE" = "target" ]; then
    echo "=== Configuring Ethernet via DHCP (target) ==="

    # Create or update a simple DHCP connection
    TARGET_CON="ethernet-transfer"
    if nmcli connection show "$TARGET_CON" &>/dev/null; then
        nmcli connection modify "$TARGET_CON" connection.interface-name "$ETH_IFACE"
    else
        nmcli connection add type ethernet ifname "$ETH_IFACE" \
            con-name "$TARGET_CON" \
            ipv4.method auto \
            ipv6.method disabled
    fi

    nmcli connection up "$TARGET_CON"
    sleep 3

    TARGET_IP=$(ip -4 addr show "$ETH_IFACE" | grep -oP 'inet \K[^/]+' | head -1)
    GATEWAY=$(ip route | grep "default.*${ETH_IFACE}" | awk '{print $3}' | head -1)

    echo "   [OK] Got IP: ${TARGET_IP:-none}"
    echo "   [OK] Gateway: ${GATEWAY:-none}"
    echo ""

    # Test connectivity to source
    if [ -n "$GATEWAY" ]; then
        echo "=== Testing connectivity ==="
        if ping -c 2 -W 2 "$GATEWAY" &>/dev/null; then
            echo "   [OK] Source (${GATEWAY}) is reachable"
        else
            echo "   [!!] Cannot ping source at ${GATEWAY}"
        fi

        # Test internet
        if ping -c 2 -W 2 8.8.8.8 &>/dev/null; then
            echo "   [OK] Internet is working (through source laptop)"
        else
            echo "   [!!] No internet — source may not be sharing WiFi"
        fi
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Target Ready"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  This machine: ${TARGET_IP} (${ETH_IFACE})"
    echo "  Source:        ${GATEWAY} (gateway)"
    echo ""
    echo "  Test SSH:  ssh oneking@${GATEWAY}"
    echo ""
    echo "  Next step: run 03-transfer.sh on this machine"
    echo ""
fi

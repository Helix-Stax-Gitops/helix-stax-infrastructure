#!/usr/bin/env bash
# =============================================================================
# hardening-audit.sh — Server Hardening Verification Script
# =============================================================================
#
# Author:    Ezra Raines (Security Engineer), Helix Stax LLC
# Created:   2026-03-22
# Version:   1.0.0
#
# Purpose:   Validates all Phase 0 hardening steps against CIS AlmaLinux 9
#            Level 1 benchmarks and Helix Stax operational requirements.
#            Run AFTER Kit completes server hardening on both nodes.
#
# Targets:
#   - helix-stax-cp  (178.156.233.12) — Control Plane
#   - helix-stax-vps (5.78.145.30)    — Worker / Services
#
# Compliance References:
#   - CIS AlmaLinux 9 Benchmark v1.0 (Level 1 - Server)
#   - CIS Distribution Independent Linux Benchmark v2.0
#   - NIST SP 800-123 (Guide to General Server Security)
#
# Usage:
#   chmod +x hardening-audit.sh
#   sudo ./hardening-audit.sh
#
# Exit codes:
#   0 — All checks passed
#   1 — One or more checks failed
#   2 — Script must be run as root
#
# Notes:
#   - Idempotent: safe to run multiple times
#   - Read-only: does NOT modify any system configuration
#   - Requires root privileges for reading shadow, audit rules, etc.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Color and formatting
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
TOTAL_COUNT=0

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
check_pass() {
    local ref="$1"
    local desc="$2"
    echo -e "  ${GREEN}PASS${NC}  ${CYAN}[$ref]${NC} $desc"
    ((PASS_COUNT++))
    ((TOTAL_COUNT++))
}

check_fail() {
    local ref="$1"
    local desc="$2"
    local detail="${3:-}"
    echo -e "  ${RED}FAIL${NC}  ${CYAN}[$ref]${NC} $desc"
    [[ -n "$detail" ]] && echo -e "        ${YELLOW}-> $detail${NC}"
    ((FAIL_COUNT++))
    ((TOTAL_COUNT++))
}

check_warn() {
    local ref="$1"
    local desc="$2"
    local detail="${3:-}"
    echo -e "  ${YELLOW}WARN${NC}  ${CYAN}[$ref]${NC} $desc"
    [[ -n "$detail" ]] && echo -e "        ${YELLOW}-> $detail${NC}"
    ((WARN_COUNT++))
    ((TOTAL_COUNT++))
}

section_header() {
    echo ""
    echo -e "${BOLD}=== $1 ===${NC}"
}

# ---------------------------------------------------------------------------
# Pre-flight: root check
# ---------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: This script must be run as root (sudo).${NC}"
    exit 2
fi

echo -e "${BOLD}"
echo "============================================================"
echo "  Helix Stax — Server Hardening Audit"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "  Host: $(hostname)"
echo "  OS:   $(cat /etc/redhat-release 2>/dev/null || echo 'Unknown')"
echo "============================================================"
echo -e "${NC}"

# ===================================================================
# 1. SSH HARDENING (CIS 5.2)
# ===================================================================
section_header "1. SSH Hardening (CIS 5.2)"

# Use sshd -T to get the effective configuration (resolves drop-in overrides)
SSHD_EFFECTIVE=$(sshd -T 2>/dev/null)

# [CIS 5.2.1] SSH Port
SSHD_PORT=$(echo "$SSHD_EFFECTIVE" | grep -i "^port " | awk '{print $2}')
if [[ "$SSHD_PORT" == "2222" ]]; then
    check_pass "CIS 5.2.1" "SSH Port: 2222"
else
    check_fail "CIS 5.2.1" "SSH Port: expected 2222, got ${SSHD_PORT:-unknown}"
fi

# [CIS 5.2.2] PasswordAuthentication
SSHD_PWAUTH=$(echo "$SSHD_EFFECTIVE" | grep -i "^passwordauthentication " | awk '{print $2}')
if [[ "$SSHD_PWAUTH" == "no" ]]; then
    check_pass "CIS 5.2.2" "PasswordAuthentication: no"
else
    check_fail "CIS 5.2.2" "PasswordAuthentication: expected no, got ${SSHD_PWAUTH:-unknown}"
fi

# [CIS 5.2.3] PermitRootLogin
# Accept both "prohibit-password" and "without-password" (they are equivalent)
SSHD_ROOTLOGIN=$(echo "$SSHD_EFFECTIVE" | grep -i "^permitrootlogin " | awk '{print $2}')
if [[ "$SSHD_ROOTLOGIN" == "prohibit-password" || "$SSHD_ROOTLOGIN" == "without-password" ]]; then
    check_pass "CIS 5.2.3" "PermitRootLogin: $SSHD_ROOTLOGIN (key-only)"
else
    check_fail "CIS 5.2.3" "PermitRootLogin: expected prohibit-password, got ${SSHD_ROOTLOGIN:-unknown}"
fi

# [CIS 5.2.4] X11Forwarding
SSHD_X11=$(echo "$SSHD_EFFECTIVE" | grep -i "^x11forwarding " | awk '{print $2}')
if [[ "$SSHD_X11" == "no" ]]; then
    check_pass "CIS 5.2.4" "X11Forwarding: no"
else
    check_fail "CIS 5.2.4" "X11Forwarding: expected no, got ${SSHD_X11:-unknown}" \
        "Check /etc/ssh/sshd_config.d/50-redhat.conf for override"
fi

# [CIS 5.2.5] MaxAuthTries
SSHD_MAXAUTH=$(echo "$SSHD_EFFECTIVE" | grep -i "^maxauthtries " | awk '{print $2}')
if [[ -n "$SSHD_MAXAUTH" && "$SSHD_MAXAUTH" -le 3 ]]; then
    check_pass "CIS 5.2.5" "MaxAuthTries: $SSHD_MAXAUTH"
else
    check_fail "CIS 5.2.5" "MaxAuthTries: expected <= 3, got ${SSHD_MAXAUTH:-unknown}"
fi

# [CIS 5.2.6] ClientAliveInterval
SSHD_ALIVE=$(echo "$SSHD_EFFECTIVE" | grep -i "^clientaliveinterval " | awk '{print $2}')
if [[ -n "$SSHD_ALIVE" && "$SSHD_ALIVE" -gt 0 && "$SSHD_ALIVE" -le 300 ]]; then
    check_pass "CIS 5.2.6" "ClientAliveInterval: ${SSHD_ALIVE}s"
else
    check_fail "CIS 5.2.6" "ClientAliveInterval: expected 1-300, got ${SSHD_ALIVE:-unknown}"
fi

# [CIS 5.2.7] AllowTcpForwarding
SSHD_TCPFWD=$(echo "$SSHD_EFFECTIVE" | grep -i "^allowtcpforwarding " | awk '{print $2}')
if [[ "$SSHD_TCPFWD" == "no" ]]; then
    check_pass "CIS 5.2.7" "AllowTcpForwarding: no"
else
    check_warn "CIS 5.2.7" "AllowTcpForwarding: expected no, got ${SSHD_TCPFWD:-unknown}" \
        "Not a hard fail but reduces attack surface"
fi

# [CIS 5.2.8] SSH Banner
SSHD_BANNER=$(echo "$SSHD_EFFECTIVE" | grep -i "^banner " | awk '{print $2}')
if [[ -n "$SSHD_BANNER" && "$SSHD_BANNER" != "none" && -f "$SSHD_BANNER" ]]; then
    check_pass "CIS 5.2.8" "SSH Banner: $SSHD_BANNER"
else
    check_warn "CIS 5.2.8" "SSH Banner: not configured or file missing" \
        "Recommended for legal compliance"
fi

# ===================================================================
# 2. FIREWALL (CIS 3.5)
# ===================================================================
section_header "2. Firewall (CIS 3.5)"

# [CIS 3.5.1] firewalld running
if systemctl is-active --quiet firewalld 2>/dev/null; then
    check_pass "CIS 3.5.1" "firewalld: active and running"
else
    check_fail "CIS 3.5.1" "firewalld: not running"
fi

# [CIS 3.5.2] firewalld enabled at boot
if systemctl is-enabled --quiet firewalld 2>/dev/null; then
    check_pass "CIS 3.5.2" "firewalld: enabled at boot"
else
    check_fail "CIS 3.5.2" "firewalld: not enabled at boot"
fi

# [CIS 3.5.3] Default zone or active zone has DROP/REJECT target
ACTIVE_ZONE=$(firewall-cmd --get-active-zones 2>/dev/null | head -1)
if [[ -n "$ACTIVE_ZONE" ]]; then
    ZONE_TARGET=$(firewall-cmd --zone="$ACTIVE_ZONE" --get-target 2>/dev/null)
    if [[ "$ZONE_TARGET" == "DROP" || "$ZONE_TARGET" == "%%REJECT%%" ]]; then
        check_pass "CIS 3.5.3" "Active zone '$ACTIVE_ZONE' target: $ZONE_TARGET (default-deny)"
    else
        check_fail "CIS 3.5.3" "Active zone '$ACTIVE_ZONE' target: $ZONE_TARGET" \
            "Expected DROP or REJECT for default-deny posture"
    fi
else
    check_fail "CIS 3.5.3" "No active firewall zone detected"
fi

# [CIS 3.5.4] Port 22 not open
FW_SERVICES=$(firewall-cmd --list-services 2>/dev/null)
FW_PORTS=$(firewall-cmd --list-ports 2>/dev/null)
if echo "$FW_SERVICES" | grep -qw ssh || echo "$FW_PORTS" | grep -q "22/tcp"; then
    check_fail "CIS 3.5.4" "Port 22 (ssh): still open in firewall" \
        "Should be removed after SSH port change to 2222"
else
    check_pass "CIS 3.5.4" "Port 22 (ssh): not open in firewall"
fi

# ===================================================================
# 3. FAIL2BAN
# ===================================================================
section_header "3. fail2ban"

# [F2B-1] Service running
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    check_pass "F2B-1" "fail2ban: active and running"
else
    check_fail "F2B-1" "fail2ban: not running"
fi

# [F2B-2] sshd jail active
if command -v fail2ban-client &>/dev/null; then
    F2B_JAILS=$(fail2ban-client status 2>/dev/null)
    if echo "$F2B_JAILS" | grep -qi "sshd"; then
        check_pass "F2B-2" "fail2ban sshd jail: active"
    else
        check_fail "F2B-2" "fail2ban sshd jail: not active"
    fi

    # [F2B-3] MaxRetry <= 3
    F2B_MAXRETRY=$(fail2ban-client get sshd maxretry 2>/dev/null)
    if [[ -n "$F2B_MAXRETRY" && "$F2B_MAXRETRY" -le 3 ]]; then
        check_pass "F2B-3" "fail2ban MaxRetry: $F2B_MAXRETRY"
    else
        check_fail "F2B-3" "fail2ban MaxRetry: expected <= 3, got ${F2B_MAXRETRY:-unknown}"
    fi
else
    check_fail "F2B-2" "fail2ban-client: command not found"
    check_fail "F2B-3" "fail2ban MaxRetry: cannot check (fail2ban not installed)"
fi

# ===================================================================
# 4. SELINUX (CIS 1.6)
# ===================================================================
section_header "4. SELinux (CIS 1.6)"

# [CIS 1.6.1] SELinux mode
if command -v getenforce &>/dev/null; then
    SELINUX_MODE=$(getenforce)
    if [[ "$SELINUX_MODE" == "Enforcing" ]]; then
        check_pass "CIS 1.6.1" "SELinux mode: Enforcing"
    elif [[ "$SELINUX_MODE" == "Permissive" ]]; then
        check_fail "CIS 1.6.1" "SELinux mode: Permissive (audit-only, no enforcement)" \
            "Should be Enforcing for CIS compliance"
    else
        check_fail "CIS 1.6.1" "SELinux mode: $SELINUX_MODE" \
            "SELinux is disabled"
    fi
else
    check_fail "CIS 1.6.1" "SELinux: getenforce not found"
fi

# [CIS 1.6.2] SELinux policy
if [[ -f /etc/selinux/config ]]; then
    SELINUX_POLICY=$(grep -E "^SELINUXTYPE=" /etc/selinux/config | cut -d= -f2)
    if [[ "$SELINUX_POLICY" == "targeted" ]]; then
        check_pass "CIS 1.6.2" "SELinux policy: targeted"
    else
        check_fail "CIS 1.6.2" "SELinux policy: expected targeted, got ${SELINUX_POLICY:-unknown}"
    fi

    # [CIS 1.6.3] SELinux config persistence
    SELINUX_CONFIG_MODE=$(grep -E "^SELINUX=" /etc/selinux/config | cut -d= -f2)
    if [[ "$SELINUX_CONFIG_MODE" == "enforcing" ]]; then
        check_pass "CIS 1.6.3" "SELinux config persistence: enforcing (survives reboot)"
    else
        check_fail "CIS 1.6.3" "SELinux config: $SELINUX_CONFIG_MODE (may revert on reboot)" \
            "/etc/selinux/config should set SELINUX=enforcing"
    fi
else
    check_fail "CIS 1.6.2" "SELinux config: /etc/selinux/config not found"
    check_fail "CIS 1.6.3" "SELinux config persistence: cannot verify"
fi

# ===================================================================
# 5. CIS LEVEL 1 CHECKS
# ===================================================================
section_header "5. CIS Level 1 — Filesystem & Services"

# [CIS 1.1.2] /tmp mount options
TMP_OPTS=$(findmnt -n -o OPTIONS /tmp 2>/dev/null || echo "")
if [[ -n "$TMP_OPTS" ]]; then
    TMP_OK=true
    for opt in nodev nosuid noexec; do
        if ! echo "$TMP_OPTS" | grep -q "$opt"; then
            TMP_OK=false
            break
        fi
    done
    if $TMP_OK; then
        check_pass "CIS 1.1.2" "/tmp mount: nodev,nosuid,noexec present"
    else
        check_fail "CIS 1.1.2" "/tmp mount: missing required options" \
            "Current: $TMP_OPTS | Need: nodev,nosuid,noexec"
    fi
else
    check_fail "CIS 1.1.2" "/tmp: not mounted as separate filesystem" \
        "Add tmpfs entry to /etc/fstab with nodev,nosuid,noexec"
fi

# [CIS 2.2.x] Unnecessary services disabled
section_header "5a. CIS Level 1 — Unnecessary Services (CIS 2.2)"

UNNECESSARY_SERVICES=("cups.service" "avahi-daemon.service" "bluetooth.service" "rpcbind.service" "rpcbind.socket")
for svc in "${UNNECESSARY_SERVICES[@]}"; do
    svc_name="${svc%.service}"
    svc_name="${svc_name%.socket}"
    svc_status=$(systemctl is-enabled "$svc" 2>/dev/null || echo "not-found")
    if [[ "$svc_status" == "masked" || "$svc_status" == "disabled" || "$svc_status" == "not-found" ]]; then
        check_pass "CIS 2.2" "Service $svc_name: $svc_status"
    else
        check_fail "CIS 2.2" "Service $svc_name: $svc_status" \
            "Should be disabled or masked on a server node"
    fi
done

# [CIS 6.1.x] File permissions
section_header "5b. CIS Level 1 — File Permissions (CIS 6.1)"

check_file_perms() {
    local ref="$1"
    local filepath="$2"
    local expected_perms="$3"
    local expected_owner="${4:-root:root}"

    if [[ ! -e "$filepath" ]]; then
        check_warn "$ref" "$filepath: file not found"
        return
    fi

    local actual_perms=$(stat -c '%a' "$filepath" 2>/dev/null)
    local actual_owner=$(stat -c '%U:%G' "$filepath" 2>/dev/null)

    if [[ "$actual_perms" == "$expected_perms" && "$actual_owner" == "$expected_owner" ]]; then
        check_pass "$ref" "$filepath: ${actual_perms} ${actual_owner}"
    else
        check_fail "$ref" "$filepath: expected ${expected_perms} ${expected_owner}, got ${actual_perms} ${actual_owner}"
    fi
}

check_file_perms "CIS 6.1.1" "/etc/passwd" "644"
check_file_perms "CIS 6.1.2" "/etc/shadow" "000"
check_file_perms "CIS 6.1.3" "/etc/group" "644"
check_file_perms "CIS 6.1.4" "/etc/gshadow" "000"
check_file_perms "CIS 6.1.5" "/etc/ssh/sshd_config" "600"

# [CIS 3.1.x] Network parameters
section_header "5c. CIS Level 1 — Network Parameters (CIS 3.1)"

# IPv6 disabled
IPV6_DISABLED=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)
if [[ "$IPV6_DISABLED" == "1" ]]; then
    check_pass "CIS 3.1.1" "IPv6 disabled: yes"
else
    check_fail "CIS 3.1.1" "IPv6 disabled: no (net.ipv6.conf.all.disable_ipv6 = ${IPV6_DISABLED:-unset})"
fi

# ICMP redirects disabled (accept)
ICMP_ACCEPT=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null)
if [[ "$ICMP_ACCEPT" == "0" ]]; then
    check_pass "CIS 3.1.2" "ICMP accept_redirects: disabled"
else
    check_fail "CIS 3.1.2" "ICMP accept_redirects: expected 0, got ${ICMP_ACCEPT:-unset}"
fi

# ICMP redirects disabled (send)
ICMP_SEND=$(sysctl -n net.ipv4.conf.all.send_redirects 2>/dev/null)
if [[ "$ICMP_SEND" == "0" ]]; then
    check_pass "CIS 3.1.3" "ICMP send_redirects: disabled"
else
    check_fail "CIS 3.1.3" "ICMP send_redirects: expected 0, got ${ICMP_SEND:-unset}"
fi

# Source routing disabled
SRC_ROUTE=$(sysctl -n net.ipv4.conf.all.accept_source_route 2>/dev/null)
if [[ "$SRC_ROUTE" == "0" ]]; then
    check_pass "CIS 3.1.4" "Source routing: disabled"
else
    check_fail "CIS 3.1.4" "Source routing: expected 0, got ${SRC_ROUTE:-unset}"
fi

# Reverse path filtering
RP_FILTER=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null)
if [[ "$RP_FILTER" == "1" ]]; then
    check_pass "CIS 3.1.5" "Reverse path filtering: enabled"
else
    check_fail "CIS 3.1.5" "Reverse path filtering: expected 1, got ${RP_FILTER:-unset}"
fi

# SYN cookies
SYN_COOKIES=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
if [[ "$SYN_COOKIES" == "1" ]]; then
    check_pass "CIS 3.1.6" "TCP SYN cookies: enabled"
else
    check_fail "CIS 3.1.6" "TCP SYN cookies: expected 1, got ${SYN_COOKIES:-unset}"
fi

# IP forwarding (expected ON for K8s)
IP_FWD=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
if [[ "$IP_FWD" == "1" ]]; then
    check_pass "CIS 3.1.7" "IP forwarding: enabled (required for K8s/CNI)"
else
    check_warn "CIS 3.1.7" "IP forwarding: disabled" \
        "K8s/Flannel/Cilium requires ip_forward=1"
fi

# ===================================================================
# 6. AUDITD (CIS 4.1)
# ===================================================================
section_header "6. Audit Logging (CIS 4.1)"

# [CIS 4.1.1] auditd running
if systemctl is-active --quiet auditd 2>/dev/null; then
    check_pass "CIS 4.1.1" "auditd: active and running"
else
    check_fail "CIS 4.1.1" "auditd: not running"
fi

# [CIS 4.1.2] auditd enabled at boot
if systemctl is-enabled --quiet auditd 2>/dev/null; then
    check_pass "CIS 4.1.2" "auditd: enabled at boot"
else
    check_fail "CIS 4.1.2" "auditd: not enabled at boot"
fi

# [CIS 4.1.3] Audit rules for privilege escalation / identity changes
AUDIT_RULES=$(auditctl -l 2>/dev/null || echo "")

check_audit_rule() {
    local ref="$1"
    local pattern="$2"
    local desc="$3"

    if echo "$AUDIT_RULES" | grep -q "$pattern"; then
        check_pass "$ref" "Audit rule: $desc"
    else
        check_fail "$ref" "Audit rule missing: $desc" \
            "Expected rule matching: $pattern"
    fi
}

check_audit_rule "CIS 4.1.3" "/etc/passwd"  "Monitor /etc/passwd changes"
check_audit_rule "CIS 4.1.4" "/etc/shadow"  "Monitor /etc/shadow changes"
check_audit_rule "CIS 4.1.5" "/etc/sudoers" "Monitor sudoers changes"
check_audit_rule "CIS 4.1.6" "/etc/ssh/sshd_config" "Monitor sshd_config changes"

# Total audit rules count
RULE_COUNT=$(echo "$AUDIT_RULES" | grep -c "^-" 2>/dev/null || echo "0")
if [[ "$RULE_COUNT" -ge 10 ]]; then
    check_pass "CIS 4.1.7" "Audit rules loaded: $RULE_COUNT rules"
else
    check_warn "CIS 4.1.7" "Audit rules loaded: $RULE_COUNT rules" \
        "Expected >= 10 rules for comprehensive monitoring"
fi

# ===================================================================
# 7. AUTO-UPDATES
# ===================================================================
section_header "7. Auto-Updates"

# [AU-1] dnf-automatic installed
if rpm -q dnf-automatic &>/dev/null; then
    check_pass "AU-1" "dnf-automatic: installed"
else
    check_fail "AU-1" "dnf-automatic: not installed"
fi

# [AU-2] Timer enabled
# Check both timer variants
if systemctl is-enabled --quiet dnf-automatic-install.timer 2>/dev/null; then
    check_pass "AU-2" "dnf-automatic-install.timer: enabled"
elif systemctl is-enabled --quiet dnf-automatic.timer 2>/dev/null; then
    check_pass "AU-2" "dnf-automatic.timer: enabled"
else
    check_fail "AU-2" "dnf-automatic timer: not enabled" \
        "Enable with: systemctl enable --now dnf-automatic-install.timer"
fi

# ===================================================================
# 8. CREDENTIAL HYGIENE
# ===================================================================
section_header "8. Credential Hygiene"

# [CRED-1] No secrets in shell history
CRED_FAIL=false
for histfile in /root/.bash_history /root/.sh_history /home/*/.bash_history /home/*/.sh_history; do
    if [[ -f "$histfile" ]]; then
        # Check for common secret patterns (case-insensitive)
        if grep -qiE '(password=|passwd=|secret=|api_key=|token=|AWS_SECRET|PRIVATE_KEY)' "$histfile" 2>/dev/null; then
            check_fail "CRED-1" "Potential secrets in: $histfile" \
                "Review and clear history: > $histfile"
            CRED_FAIL=true
        fi
    fi
done
if ! $CRED_FAIL; then
    check_pass "CRED-1" "No secrets detected in shell history files"
fi

# [CRED-2] No .env files in common locations
ENV_FILES=$(find /root /home /opt /srv /var/www -maxdepth 3 -name ".env" -type f 2>/dev/null)
if [[ -z "$ENV_FILES" ]]; then
    check_pass "CRED-2" "No .env files in common locations"
else
    ENV_COUNT=$(echo "$ENV_FILES" | wc -l)
    check_fail "CRED-2" "$ENV_COUNT .env file(s) found in common locations" \
        "Locations: $(echo "$ENV_FILES" | tr '\n' ' ')"
fi

# [CRED-3] No authorized_keys with weak permissions
CRED3_OK=true
for akfile in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
    if [[ -f "$akfile" ]]; then
        ak_perms=$(stat -c '%a' "$akfile" 2>/dev/null)
        if [[ "$ak_perms" != "600" && "$ak_perms" != "644" && "$ak_perms" != "400" ]]; then
            check_fail "CRED-3" "authorized_keys bad perms: $akfile ($ak_perms)" \
                "Should be 600 or 644"
            CRED3_OK=false
        fi
    fi
done
if $CRED3_OK; then
    check_pass "CRED-3" "authorized_keys permissions: OK"
fi

# ===================================================================
# 9. LISTENING PORTS (Attack Surface)
# ===================================================================
section_header "9. Attack Surface — Listening Ports"

# [SURF-1] Show all listening ports for review
echo ""
echo -e "  ${CYAN}[INFO]${NC} Currently listening TCP ports:"
ss -tlnp 2>/dev/null | grep LISTEN | while read -r line; do
    echo "        $line"
done
echo ""

# Check that port 22 is NOT listening
if ss -tlnp 2>/dev/null | grep -qE ':22\s'; then
    check_fail "SURF-1" "Port 22 is still listening" \
        "sshd should only listen on port 2222"
else
    check_pass "SURF-1" "Port 22: not listening"
fi

# Check that port 2222 IS listening
if ss -tlnp 2>/dev/null | grep -qE ':2222\s'; then
    check_pass "SURF-2" "Port 2222: listening (SSH)"
else
    check_fail "SURF-2" "Port 2222: not listening" \
        "sshd should be listening on port 2222"
fi

# ===================================================================
# SUMMARY
# ===================================================================
echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD}  AUDIT SUMMARY${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""
echo -e "  Host:     $(hostname)"
echo -e "  Date:     $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""
echo -e "  ${GREEN}PASSED:${NC}  $PASS_COUNT"
echo -e "  ${RED}FAILED:${NC}  $FAIL_COUNT"
echo -e "  ${YELLOW}WARNED:${NC}  $WARN_COUNT"
echo -e "  TOTAL:   $TOTAL_COUNT"
echo ""

CHECKED=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
echo -e "  Score:   ${PASS_COUNT}/${CHECKED} checks passed"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}RESULT: ALL CHECKS PASSED${NC}"
    echo ""
    echo -e "${BOLD}============================================================${NC}"
    exit 0
else
    echo -e "  ${RED}${BOLD}RESULT: $FAIL_COUNT CHECK(S) FAILED — REMEDIATION REQUIRED${NC}"
    echo ""
    echo -e "${BOLD}============================================================${NC}"
    exit 1
fi

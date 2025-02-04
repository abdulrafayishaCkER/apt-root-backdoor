# apt-root-backdoor
🚨 Exploiting apt install: Gaining Root Access via Malicious .deb Packages 🚨 This repository demonstrates how an attacker can exploit apt install by embedding a reverse shell in a .deb package using the preinst script. Since apt install requires sudo privileges, the shell obtained runs as root, granting full control over the system.

🔥 How It Works
1️⃣ Victim installs the .deb package (sudo apt install ./malicious.deb).
2️⃣ Before installation starts, preinst executes a reverse shell payload.
3️⃣ Attacker gains a root-privileged Meterpreter session.
4️⃣ Even if installation fails, the payload still runs.

⚠️ Why This is Dangerous
🔹 Root access – Full system control.
🔹 Silent execution – No user confirmation needed.
🔹 Bypasses security checks – Runs before verification.

💀 Proof of Concept
1️⃣ Generate a Python reverse shell with msfvenom.
2️⃣ Embed it inside the preinst script.
3️⃣ Set up a listener on the attacker's machine.
4️⃣ When the victim installs the package, the attacker gains a root shell.

🔐 How to Stay Safe
✅ Inspect .deb files before installing.
✅ Check for preinst scripts in the DEBIAN folder.
✅ Run unknown software in a sandbox/VM.
✅ Download only from trusted sources.

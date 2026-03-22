# Source from deploy/validate scripts (do not execute directly).
# Creates ${repo_root}/.lab-ssh/id_ed25519 unless SSH_PUBLIC_KEY is preset.

ensure_lab_ssh_key() {
  local root="${1:?repository root directory}"

  if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
    return 0
  fi

  LAB_SSH_DIR="${root}/.lab-ssh"
  LAB_SSH_PRIVATE_KEY="${LAB_SSH_DIR}/id_ed25519"
  LAB_SSH_PUBLIC_KEY_FILE="${LAB_SSH_PRIVATE_KEY}.pub"

  mkdir -p "${LAB_SSH_DIR}"
  chmod 700 "${LAB_SSH_DIR}" 2>/dev/null || true

  if [[ ! -f "${LAB_SSH_PRIVATE_KEY}" ]]; then
    echo "info: Generating ed25519 key pair for Linux VMs: ${LAB_SSH_PRIVATE_KEY}" >&2
    if ! command -v ssh-keygen >/dev/null 2>&1; then
      echo "error: ssh-keygen not found; install OpenSSH client tools." >&2
      return 1
    fi
    ssh-keygen -t ed25519 -f "${LAB_SSH_PRIVATE_KEY}" -N "" -C "azure-labs" -q
  fi

  if [[ ! -r "${LAB_SSH_PUBLIC_KEY_FILE}" ]]; then
    echo "error: Missing or unreadable public key: ${LAB_SSH_PUBLIC_KEY_FILE}" >&2
    return 1
  fi
}

lab_ssh_public_key_value() {
  if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
    tr -d '\r\n' <<< "${SSH_PUBLIC_KEY}"
    return 0
  fi
  tr -d '\r\n' < "${LAB_SSH_PUBLIC_KEY_FILE}"
}

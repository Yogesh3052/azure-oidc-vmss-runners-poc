#!/bin/bash
set -e -x

REPO_OWNER="Yogesh3052"
REPO_NAME="azure-oidc-vmss-runners-poc"

# 1. Setup environment
export RUNNER_ALLOW_RUNASROOT=1  # Temporary workaround
export RUNNER_ROOT="/opt/actions-runner"
export LOG_FILE="/var/log/github-runner-install.log"

# Create directories with proper permissions
sudo mkdir -p "$RUNNER_ROOT"
sudo chown $(whoami):$(whoami) "$RUNNER_ROOT"
mkdir -p "$(dirname "$LOG_FILE")"
sudo touch "$LOG_FILE"
sudo chown $(whoami):$(whoami) "$LOG_FILE"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Starting installation at $(date) ==="

# 2. Install dependencies
echo "Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y  jq
sudo apt-get install -y curl tar git jq

# 3. Download GitHub Runner
cd "$RUNNER_ROOT"
RUNNER_VERSION="2.326.0"
RUNNER_FILE="actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"
echo "Downloading runner..."
curl -L -o "$RUNNER_FILE" \
  "https://github.com/actions/runner/releases/download/v2.326.0/$RUNNER_FILE"
tar xzf "$RUNNER_FILE"

# 4. fetch Client_ID
CLIENT_ID=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=https://management.azure.com" | jq -r .client_id)

if [ -z "$CLIENT_ID" ]; then
  echo "ERROR: Failed to get Client ID from IMDS"
  exit 1
fi

# Get OIDC Token
TOKEN=$(curl -s "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=api.github.com&client_id=$CLIENT_ID" -H Metadata:true | jq -r .access_token)

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to acquire OIDC token"
  curl -v "$TOKEN_ENDPOINT?api-version=2021-02-01&resource=api.github.com&client_id=17abd2cb-8450-4ec7-9b6d-39308ed1ab6c" -H Metadata:true
  exit 1
fi

# Get PAT from Key Vault
PAT=$(curl -s "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" -H "Metadata: true" | jq -r .access_token)
PAT=$(curl -s "https://github-runner-kv.vault.azure.net/secrets/github-pat?api-version=7.3" -H "Authorization: Bearer $PAT" | jq -r .value)

# For OIDC workflow (more secure):
# First get a temporary token using your PAT:
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token $PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/Yogesh3052/azure-oidc-vmss-runners-poc/actions/runners/registration-token" \
  | jq -r .token)

# Then use the temporary token:
./config.sh --unattended --url https://github.com/Yogesh3052/azure-oidc-vmss-runners-poc --token "$REG_TOKEN"

# 6. Install service (without sudo)
echo "Starting runner..."
sudo ./svc.sh install
sudo ./svc.sh start

echo "=== Installation complete at $(date) ==="
echo "Logs available at: $LOG_FILE"

# Install termination listener
echo "Setting up termination listener..."
if ! sudo curl -sSfLo /usr/local/bin/termination-listener.sh \
    "https://raw.githubusercontent.com/Yogesh3052/azure-oidc-vmss-runners-poc/main/scripts/termination-listener.sh?_=$(date +%s)"; then
    echo "ERROR: Failed to download termination listener script" >&2
    exit 1
fi

# Verify download was successful
if [ ! -s "/usr/local/bin/termination-listener.sh" ]; then
    echo "ERROR: Downloaded file is empty" >&2
    sudo rm -f /usr/local/bin/termination-listener.sh
    exit 1
fi
sudo chmod 755 /usr/local/bin/termination-listener.sh
sudo chown root:root /usr/local/bin/termination-listener.sh

# Create systemd service file
sudo tee /etc/systemd/system/termination-listener.service >/dev/null <<'EOF'
[Unit]
Description=GitHub Runner Termination Listener
After=network.target

[Service]
ExecStart=/usr/local/bin/termination-listener.sh
Restart=always
RestartSec=10
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable termination-listener.service
sudo systemctl start termination-listener.service
#!/bin/bash
set -e -x

# Immediate logging
exec > >(tee -a /var/log/github-runner-install.log) 2>&1
echo "=== Starting installation at $(date) ==="

# 1. Install dependencies
echo "Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y curl tar git jq

# 2. Download GitHub Runner
RUNNER_VERSION="2.326.0"
echo "Downloading runner package..."
curl -o actions-runner-linux-x64-$RUNNER_VERSION.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.326.0/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
tar xzf actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

# 3. Get OIDC token using User-Assigned Identity
# Replace CLIENT_ID with your identity's client ID
CLIENT_ID="YOUR_MANAGED_IDENTITY_CLIENT_ID"
echo "Requesting OIDC token for client ID: $CLIENT_ID..."
TOKEN=$(curl -s "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=api.github.com&client_id=$CLIENT_ID" -H Metadata:true | jq -r .access_token)

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to get OIDC token"
    echo "Debug info:"
    curl -v "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=api.github.com&client_id=$CLIENT_ID" -H Metadata:true
    exit 1
fi

# 4. Configure runner
echo "Configuring GitHub runner..."
./config.sh --unattended \
  --url "https://github.com/Yogesh3052/azure-oidc-vmss-runners-poc" \
  --ephemeral \
  --jitconfig "$TOKEN" \
  --name "$(hostname)-runner" \
  --labels "vmss,oidc" \
  --runnergroup "Default"

# 5. Install service
echo "Installing service..."
sudo ./svc.sh install
sudo ./svc.sh start

echo "=== Installation completed at $(date) ==="
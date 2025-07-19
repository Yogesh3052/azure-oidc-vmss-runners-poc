#!/bin/bash
# Force all output to a known log file immediately
exec > >(tee -a /var/log/runner-install.log) 2>&1
echo "==== Starting installation at $(date) ===="

# 1. First verify basic system access
echo "Checking working directory: $(pwd)"
echo "Contents of current directory:"
ls -la
echo ""

# 2. Install minimal dependencies first
echo "Installing absolute minimum dependencies..."
sudo apt-get update -y
sudo apt-get install -y curl jq

# 3. Verify network connectivity
echo "Testing GitHub connectivity..."
curl -v https://github.com > /dev/null || {
    echo "ERROR: Cannot reach GitHub"
    exit 1
}

# 4. Download runner
RUNNER_VERSION="2.326.0"
RUNNER_FILE="actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"
echo "Downloading runner $RUNNER_VERSION..."
curl -L -o "$RUNNER_FILE" \
  "https://github.com/actions/runner/releases/download/v2.326.0/$RUNNER_FILE" || {
    echo "ERROR: Failed to download runner"
    exit 1
}

# 5. Extract
echo "Extracting runner..."
tar xzf "$RUNNER_FILE" || {
    echo "ERROR: Failed to extract runner"
    exit 1
}

# 6. Get OIDC token (using system identity)
echo "Requesting OIDC token..."
TOKEN_ENDPOINT="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=api.github.com"
TOKEN=$(curl -s -H Metadata:true "$TOKEN_ENDPOINT" | jq -r '.access_token')

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to get OIDC token"
    echo "Debug info:"
    curl -v -H Metadata:true "$TOKEN_ENDPOINT"
    exit 1
fi

# 7. Configure runner
echo "Configuring runner..."
./config.sh --unattended \
  --url "https://github.com/Yogesh3052/azure-oidc-vmss-runners-poc" \
  --ephemeral \
  --jitconfig "$TOKEN" \
  --name "$(hostname)-runner" \
  --labels "vmss,oidc" || {
    echo "ERROR: Runner configuration failed"
    exit 1
}

# 8. Install service
echo "Installing service..."
sudo ./svc.sh install || {
    echo "ERROR: Service installation failed"
    exit 1
}

sudo ./svc.sh start || {
    echo "ERROR: Service start failed"
    exit 1
}

echo "==== Installation completed successfully at $(date) ===="
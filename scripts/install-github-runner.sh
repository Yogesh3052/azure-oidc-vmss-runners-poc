#!/bin/bash

set -e

#-----------------------------#
# Configuration Variables
#-----------------------------#
VAULT_NAME="kv-dati-ghrunner"
SECRET_NAME="github-pat"
GITHUB_REPO="Yogesh3052/azure-oidc-vmss-runners-poc"
RUNNER_DIR="/opt/actions-runner"
RUNNER_VERSION="2.311.0"

echo "[INFO] Installing dependencies..."
sudo apt-get update
sudo apt-get install -y curl jq git auditd

#-----------------------------#
# Fetch GitHub PAT securely from Key Vault
#-----------------------------#
echo "[INFO] Fetching GitHub PAT from Azure Key Vault..."
PAT=$(az keyvault secret show \
  --vault-name "$VAULT_NAME" \
  --name "$SECRET_NAME" \
  --query "value" -o tsv)

if [ -z "$PAT" ]; then
  echo "[ERROR] Failed to retrieve PAT from Key Vault"
  exit 1
fi

#-----------------------------#
# Install GitHub Actions Runner
#-----------------------------#
echo "[INFO] Creating runner directory..."
sudo mkdir -p $RUNNER_DIR
cd $RUNNER_DIR

echo "[INFO] Downloading GitHub Actions runner v$RUNNER_VERSION..."
curl -o actions-runner-linux-x64.tar.gz -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
tar xzf actions-runner-linux-x64.tar.gz
sudo ./bin/installdependencies.sh

echo "[INFO] Requesting registration token from GitHub API..."
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ${PAT}" \
  https://api.github.com/repos/${GITHUB_REPO}/actions/runners/registration-token | jq -r .token)

if [ -z "$REG_TOKEN" ]; then
  echo "[ERROR] Failed to fetch runner registration token from GitHub API"
  exit 1
fi

#-----------------------------#
# Configure and Start Runner
#-----------------------------#
echo "[INFO] Configuring GitHub runner..."
sudo ./config.sh --unattended \
  --url "https://github.com/${GITHUB_REPO}" \
  --token "$REG_TOKEN" \
  --name "vmss-runner-$(hostname)" \
  --labels "vmss,linux"

echo "[INFO] Starting GitHub runner in background..."
sudo ./run.sh &

#-----------------------------#
# Enable Session Logging
#-----------------------------#
echo "[INFO] Enabling auditd for session logging..."
sudo systemctl enable auditd
sudo systemctl start auditd

echo "[SUCCESS] GitHub Runner setup complete with session logging."

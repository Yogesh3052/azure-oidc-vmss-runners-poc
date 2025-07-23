#!/bin/bash
set -e -x

REPO_OWNER="Yogesh3052"
REPO_NAME="azure-oidc-vmss-runners-poc"
RUNNER_ROOT="/opt/actions-runner"
LOG_FILE="/var/log/github-runner-uninstall.log"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Starting runner removal at $(date) ==="

# 1. Stop and uninstall service
if [ -d "$RUNNER_ROOT" ]; then
    cd "$RUNNER_ROOT"

    if [ -f "./svc.sh" ]; then
        echo "Stopping and uninstalling service..."
        sudo ./svc.sh stop || true
        sudo ./svc.sh uninstall || true
    fi

    # 2. Get PAT from Key Vault to remove runner
    echo "Getting PAT from Key Vault..."
    PAT=$(curl -s "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" -H "Metadata: true" | jq -r .access_token)
    PAT=$(curl -s "https://github-runner-kv.vault.azure.net/secrets/github-pat?api-version=7.3" -H "Authorization: Bearer $PAT" | jq -r .value)

    if [ -z "$PAT" ]; then
        echo "WARNING: Failed to get PAT from Key Vault. Runner will be removed locally but not from GitHub."
    else
        # 3. Get runner name and remove from GitHub
        RUNNER_NAME=$(hostname)
        RUNNER_ID=$(curl -s -H "Authorization: token $PAT" \
            "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runners" \
            | jq -r ".runners[] | select(.name == \"$RUNNER_NAME\") | .id")

        if [ -n "$RUNNER_ID" ]; then
            echo "Removing runner $RUNNER_NAME (ID: $RUNNER_ID) from GitHub..."
            curl -X DELETE -H "Authorization: token $PAT" \
                "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/runners/$RUNNER_ID"
        else
            echo "WARNING: Runner $RUNNER_NAME not found in GitHub repo."
        fi
    fi

    # 4. Clean up runner files
    echo "Removing runner files..."
    cd ..
    sudo rm -rf "$RUNNER_ROOT"
else
    echo "Runner directory $RUNNER_ROOT not found."
fi

echo "=== Runner removal complete at $(date) ==="
echo "Logs available at: $LOG_FILE"
#!/bin/bash

# GitHub Runner Termination Handler
LOG_FILE="/var/log/termination-listener.log"
UNINSTALLER_URL="https://raw.githubusercontent.com/Yogesh3052/azure-oidc-vmss-runners-poc/main/scripts/uninstall-github-runner.sh"

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Starting termination listener at $(date) ==="

# Check for termination notice every 10 seconds
while true; do
    # Check Azure Metadata service for scheduled events
    events=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01")
    
    # If termination event exists for this instance
    if echo "$events" | jq -e '.Events[] | select(.EventType == "Preempt" or .EventType == "Terminate")' > /dev/null; then
        echo "Termination notice detected, running uninstaller..."
        
        # Download and execute the uninstaller
        curl -s -o /tmp/uninstall-github-runner.sh "$UNINSTALLER_URL"
        chmod +x /tmp/uninstall-github-runner.sh
        /tmp/uninstall-github-runner.sh
        
        # Notify Azure we're ready for termination
        event_id=$(echo "$events" | jq -r '.Events[0].EventId')
        curl -H "Metadata:true" -X POST \
            -d "{\"StartRequests\": [{\"EventId\": \"$event_id\"}]}" \
            "http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01"
        
        exit 0
    fi
    
    sleep 2
done
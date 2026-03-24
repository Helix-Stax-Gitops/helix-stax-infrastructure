#!/bin/bash
# scripts/backup.sh - Convenience wrapper for Hetzner S3 backups

PLAYBOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../playbooks" && pwd)"

echo "Starting infrastructure backup to Hetzner Object Storage..."
ansible-playbook -i "$PLAYBOOK_DIR/../inventory/hosts.ini" "$PLAYBOOK_DIR/backup_to_hetzner.yml" "$@"

if [ $? -eq 0 ]; then
    echo "Backup process completed successfully."
else
    echo "Backup process failed. Check the logs."
    exit 1
fi

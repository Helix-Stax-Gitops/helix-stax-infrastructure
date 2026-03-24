#!/bin/bash
# Enterprise Dry-run Script
echo "Starting Ansible Dry-run..."
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --check

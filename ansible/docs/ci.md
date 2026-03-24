# Continuous Integration (CI) Documentation

This document outlines the Continuous Integration (CI) pipeline for the `infrastructure-ansible` repository.

## Overview

The CI pipeline is designed to ensure code quality, consistency, and security for all Ansible playbooks and configurations. It consists of two main components:

1.  **Local Pre-commit Hooks**: Automated checks that run on your local machine before every commit.
2.  **GitHub Actions Workflow**: A cloud-based pipeline that validates every Pull Request and Push to the `main` branch.

## GitHub Actions Workflow

The CI workflow is defined in `.github/workflows/ci.yml`.

### Jobs
- **lint**: Runs on `ubuntu-latest`.
  - **Steps**:
    - Checkouts the repository.
    - Sets up Python 3.10.
    - Installs `ansible` and `ansible-lint`.
    - Executes `ansible-lint` on the entire repository.

### Status Checks
The `lint` job is configured as a **required status check** for the `main` branch. Merging is only permitted if this check passes.

## Local Pre-commit Hooks

Pre-commit hooks are defined in `.pre-commit-config.yaml`.

### Configured Hooks
- **Standard Checks**: Trailing whitespace, end-of-file fixer, YAML syntax validation.
- **Ansible Lint**: Validates Ansible best practices.

### Installation
To enable hooks locally, run:
```bash
pre-commit install
```

### Manual Execution
To run all hooks against the entire codebase:
```bash
pre-commit run --all-files
```

## Testing Scripts

Helper scripts are available in the `scripts/` directory:
- `scripts/lint.sh`: Encapsulates the linting command.
- `scripts/dryrun.sh`: Executes an Ansible dry-run (`--check`) against the `playbooks/site.yml`.

## Expiry & Maintenance
- The CI environment uses the latest stable versions of Ansible.
- Review and update hook versions in `.pre-commit-config.yaml` quarterly.

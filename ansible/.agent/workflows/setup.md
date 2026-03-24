---
description: infrastructure-ansible repository setup and verification
---
# Infrastructure-Ansible Setup Workflow

1.  **Initialize Repository**:
    ```bash
    git clone git@github.com:KeemWilliams/infrastructure-ansible.git
    cd infrastructure-ansible
    ```

2.  **Enable CI Gates**:
    // turbo
    ```bash
    pip install pre-commit
    pre-commit install
    ```

3.  **Verify Code Quality**:
    // turbo
    ```bash
    ./scripts/lint.sh
    ```

4.  **Emergency Recovery Test**:
    // turbo
    ```bash
    ansible-playbook -i localhost, -c local playbooks/emergency_fetch.yml --check
    ```

5.  **Audit Logs**:
    Review `docs/incident_log.md` for any maintenance history.

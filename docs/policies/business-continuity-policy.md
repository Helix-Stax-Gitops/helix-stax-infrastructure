---
title: "Business Continuity Policy"
category: "policy"
classification: "INTERNAL"
version: "1.0"
last_updated: "2026-03-23"
review_cycle: "Annual"
owner: "Wakeem Williams, CEO"
policy_id: "POL-010"
status: "Approved"
effective_date: "2026-03-23"
next_review: "2027-03-23"
compliance_mapping:
  - framework: "SOC 2"
    controls: ["CC9.1", "CC7.5"]
  - framework: "ISO 27001"
    controls: ["A.5.29", "A.5.30", "A.8.14"]
  - framework: "HIPAA"
    controls: ["164.308(a)(7)(i)", "164.308(a)(7)(ii)(B)", "164.308(a)(7)(ii)(C)", "164.308(a)(7)(ii)(D)", "164.308(a)(7)(ii)(E)"]
  - framework: "NIST CSF"
    controls: ["RC.RP-1", "RC.RP-2", "RC.CO-1"]
---

# Business Continuity Policy

**Author**: Wakeem Williams
**Co-Author**: Quinn Mercer (Documentation)

## TLDR

The Business Continuity Policy defines Helix Stax's disaster recovery plan, continuity objectives, failover strategy for the 2-node K3s cluster, communication procedures during outages, and annual tabletop exercise requirements. Required by ISO 27001 A.5.29, HIPAA 164.308(a)(7). Approved by CEO.

---

## 1. Purpose

This policy ensures that Helix Stax can maintain or rapidly restore critical business functions following a disruption, whether caused by infrastructure failure, natural disaster, cyberattack, or vendor outage. It establishes continuity objectives, defines recovery procedures, and mandates regular testing.

## 2. Scope

This policy applies to:

- All critical and important Helix Stax services as defined by the service tier classification in the Backup & Recovery Policy (POL-006)
- The K3s cluster infrastructure (heart control plane, helix-worker-1 worker node)
- All supporting infrastructure (Hetzner Cloud, Cloudflare, Backblaze B2)
- Client service delivery under the Delivery workspace
- Business operations including communication, project management, and financial systems

## 3. Definitions

| Term | Definition |
|------|-----------|
| **BCP** | Business Continuity Plan; the documented procedures for maintaining business operations during and after a disruption |
| **DR** | Disaster Recovery; the process of restoring IT systems and data after a major disruption |
| **MTPD** | Maximum Tolerable Period of Disruption; the longest time a business function can be unavailable before causing unacceptable consequences |
| **Failover** | The automatic or manual transfer of workloads from a failed component to a backup component |
| **Tabletop Exercise** | A discussion-based exercise where participants walk through a simulated disaster scenario to validate the BCP |

## 4. Policy Statements

### 4.1 Continuity Objectives

**PS-010.1**: Business continuity objectives shall align with the RPO/RTO targets defined in the Backup & Recovery Policy (POL-006):

| Service Category | MTPD | Recovery Priority |
|-----------------|------|-------------------|
| **Authentication (Zitadel)** | 4 hours | P0 -- All other services depend on identity |
| **Databases (CloudNativePG)** | 4 hours | P0 -- Data layer for all applications |
| **Secrets (OpenBao)** | 4 hours | P0 -- Credential access for all services |
| **Ingress (Traefik + Cloudflare)** | 2 hours | P0 -- External access to all services |
| **CI/CD (Devtron + ArgoCD)** | 8 hours | P1 -- Deployment capability |
| **Monitoring (Prometheus + Grafana + Loki)** | 8 hours | P1 -- Observability |
| **Collaboration (Rocket.Chat, ClickUp)** | 24 hours | P2 -- Team communication |

### 4.2 K3s Cluster Failover Strategy

**PS-010.2**: The 2-node K3s cluster (heart + helix-worker-1) shall implement the following failover strategy:

**Single node failure (worker node):**
1. K3s automatically reschedules pods to the control plane node (heart)
2. Services continue with reduced capacity; performance degradation is acceptable
3. System Administrator provisions a replacement worker node within 4 hours using OpenTofu
4. Ansible applies hardening playbook to the new node
5. K3s join command adds the new node to the cluster
6. Workloads rebalance automatically

**Single node failure (control plane):**
1. Worker node retains running pods but cannot schedule new workloads or access the API
2. System Administrator provisions a new control plane node within 4 hours
3. Restore etcd from the most recent Velero backup
4. Rejoin worker node to the new control plane
5. Verify ArgoCD reconciles all applications to desired state

**Complete cluster loss:**
1. Provision both nodes from OpenTofu (Hetzner Cloud, US region)
2. Apply Ansible hardening playbook
3. Install K3s, restore etcd from Velero backup (Backblaze B2 offsite)
4. ArgoCD reconciles all applications from Git
5. Restore databases from CloudNativePG WAL archives
6. Target: full recovery within 8 hours

**PS-010.3**: All recovery procedures shall be codified in runbooks stored in `docs/runbooks/` and version-controlled in Git. Ad-hoc recovery procedures are prohibited for planned scenarios.

### 4.3 Vendor Dependency Failover

**PS-010.4**: Vendor-specific continuity measures:

| Vendor | Disruption Scenario | Mitigation |
|--------|---------------------|------------|
| **Hetzner** | Data center outage | Provision replacement nodes in alternate Hetzner region; restore from Backblaze B2 backups |
| **Cloudflare** | Edge network outage | DNS failover to direct Hetzner IP; Traefik handles TLS directly via cert-manager; degraded DDoS protection accepted |
| **Backblaze B2** | Storage outage | On-site MinIO retains 30-day backups; B2 outage does not impact production |
| **GitHub** | Platform outage | Local Git clones on cluster nodes; ArgoCD syncs from cached state; push operations deferred |

### 4.4 Communication Plan

**PS-010.5**: During a disruption, communication shall follow this escalation chain:

| Timeframe | Action | Channel | Audience |
|-----------|--------|---------|----------|
| T+0 (detection) | Incident declared | Rocket.Chat #incidents | Internal team |
| T+15 min | Initial assessment communicated | Rocket.Chat + email | Internal team |
| T+30 min | Client notification (if client services affected) | Email + client Rocket.Chat channel | Affected clients |
| T+1 hour | Status page updated | Grafana public dashboard | Public |
| Every 2 hours | Status update | All channels | All stakeholders |
| Resolution | All-clear notification | All channels | All stakeholders |

**PS-010.6**: If Rocket.Chat is unavailable, fallback communication shall use: (1) Google Workspace email, (2) Google Meet for voice, (3) mobile phone as last resort. Contact numbers for key personnel shall be maintained in a sealed, offline document stored securely.

### 4.5 Testing and Exercises

**PS-010.7**: An annual tabletop exercise shall be conducted to validate the business continuity plan. The exercise shall:

1. Simulate a realistic disaster scenario (selected from: complete cluster loss, ransomware attack, vendor outage, data center failure)
2. Walk through the recovery procedures step by step
3. Identify gaps in procedures, tooling, or communication
4. Produce an after-action report documenting findings and corrective actions

**PS-010.8**: The quarterly backup restore test required by the Backup & Recovery Policy (POL-006) shall serve as a technical validation of the DR component of this plan.

**PS-010.9**: Corrective actions identified during tabletop exercises shall be tracked as tasks in ClickUp (Folder 04: Service Management) with assigned owners and due dates not exceeding 30 days from the exercise date.

### 4.6 Plan Maintenance

**PS-010.10**: The business continuity plan shall be reviewed and updated:

1. Annually, concurrent with the tabletop exercise
2. After any significant infrastructure change (new nodes, new vendors, architecture changes)
3. After any incident that activated continuity procedures
4. After tabletop exercise findings are remediated

**PS-010.11**: The BCP document, recovery runbooks, and communication plan shall be stored in Git (version-controlled), with a printed copy of the communication plan stored offline in a secure location accessible without internet connectivity.

## 5. Roles & Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO (Wakeem Williams)** | Declares disaster; authorizes recovery spending; communicates with clients during major disruptions; approves BCP annually |
| **System Administrator** | Executes technical recovery procedures; provisions replacement infrastructure; restores services from backups |
| **Security Lead** | Assesses whether the disruption has a security dimension; preserves evidence if applicable; coordinates with Incident Response Policy |
| **Compliance Lead** | Ensures recovery actions maintain regulatory compliance; documents recovery timeline for audit evidence |

## 6. Compliance & Enforcement

Failure to conduct the annual tabletop exercise, failure to maintain recovery runbooks, or failure to notify affected clients during a disruption constitutes a serious policy violation.

## 7. Exceptions Process

Exceptions follow the process defined in the Information Security Policy (POL-001), Section 7. No exceptions are permitted for: the annual tabletop exercise, or client notification during disruptions affecting client services.

## 8. Related Documents

- Information Security Policy (POL-001)
- Backup & Recovery Policy (POL-006)
- Incident Response Policy (POL-004)
- Vendor Management Policy (POL-008)
- `docs/runbooks/` -- Recovery runbooks
- OpenTofu modules for node provisioning
- Ansible playbooks for node hardening and K3s installation

## 9. Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial policy creation |

## 10. Approval

| Role | Name | Date |
|------|------|------|
| **Policy Owner** | Wakeem Williams, CEO | 2026-03-23 |
| **Approved By** | Wakeem Williams, CEO | 2026-03-23 |

---

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer (Documentation) |
| **Policy ID** | POL-010 |
| **Version** | 1.0 |
| **Effective Date** | 2026-03-23 |
| **Next Review** | 2027-03-23 |
| **Classification** | Internal |

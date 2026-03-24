---
title: "Asset Management Policy"
policy_id: POL-019
category: policy
classification: INTERNAL
version: "1.0"
effective_date: 2026-03-23
last_updated: 2026-03-23
next_review: 2027-03-23
author: "Wakeem Williams"
co_author: "Quinn Mercer (Documentation)"
status: Draft
compliance_mapping:
  - framework: ISO 27001
    controls: ["A.5.9", "A.5.10", "A.5.13"]
  - framework: SOC 2
    controls: ["CC6.1"]
  - framework: HIPAA
    controls: ["164.310(d)"]
---

# Asset Management Policy

## TLDR

Ensures all Helix Stax information assets are identified, classified, and managed throughout their lifecycle to maintain confidentiality, integrity, and availability. Covers cloud infrastructure, K3s workloads, endpoints, and data classification. Required by ISO 27001, SOC 2, and HIPAA. Approved by CEO.

---

## Purpose

This policy ensures that all Helix Stax information assets are identified, classified, and managed throughout their lifecycle to maintain confidentiality, integrity, and availability.

## Scope

- All hardware, software, cloud services, data, and personnel handling Helix Stax information
- All locations (Hetzner Cloud, remote offices, client environments)

---

## Policy Statements

### 1. Asset Classification Schema

Assets are classified into four categories to determine protection requirements:

| Classification | Description | Examples |
|---------------|-------------|----------|
| **Restricted** | Highest sensitivity, requires strongest controls | Customer PII/PHI, encryption keys, production database backups (MinIO/B2) |
| **Confidential** | Business-sensitive, internal use only | Financial records, business strategy, source code |
| **Internal** | General internal use | Internal wikis (Outline), project management boards |
| **Public** | No sensitivity restrictions | Marketing website content (Astro), public documentation |

### 2. Cloud Infrastructure Assets

Helix Stax utilizes Infrastructure as Code (IaC) to maintain an automated inventory:

- **Hetzner Cloud and Cloudflare:** OpenTofu state files serve as the primary inventory for virtual servers, volumes, and network configurations
- **Validation:** Monthly reconciliation between `tofu state show` and the Hetzner/Cloudflare Cloud Consoles

### 3. Kubernetes (K3s) and Container Assets

- **Workloads:** `kubectl get deployments,statefulsets --all-namespaces` generates the inventory of active services
- **Images:** Harbor Container Registry serves as the inventory of authorized software versions
- **Audit:** K3s resource manifests stored in Git (ArgoCD/Devtron), providing version-controlled asset history

### 4. Endpoint Assets (Laptops)

As a remote firm, endpoints are tracked via a centralized Asset Management Database (AMDB):

- All laptops must be enrolled in the company MDM solution
- Data Points: Serial number, user assignment, encryption status, OS version

### 5. Lifecycle Management

1. **Procurement:** Assets must be purchased through approved channels
2. **Deployment:** Hardware must be encrypted before use. Software must be scanned for vulnerabilities in Harbor
3. **Maintenance:** AlmaLinux 9.7 nodes must be patched monthly via the Devtron/ArgoCD pipeline
4. **Disposal:** Cloud volumes must be cryptographically erased before deletion. Physical media must be shredded or wiped using NIST 800-88 standards

### 6. Asset Inventory Template

| Asset ID | Category | Type | Owner | Classification | Location/Provider | Last Review |
|----------|----------|------|-------|---------------|-------------------|-------------|
| HS-SRV-01 | Hardware | K3s Master | DevOps Lead | Confidential | Hetzner (178.156.233.12) | YYYY-MM-DD |
| HS-S3-01 | Data | MinIO Bucket | Data Eng | Restricted | Hetzner / B2 | YYYY-MM-DD |
| HS-LP-01 | Endpoint | Laptop | Employee | Confidential | Remote (Employee Home) | YYYY-MM-DD |
| HS-SVC-01 | Service | Zitadel | IAM Lead | Restricted | Internal K3s | YYYY-MM-DD |

---

## Roles and Responsibilities

| Role | Responsibilities |
|------|-----------------|
| **CEO / Security Officer** | Approve asset classification schema, oversee inventory completeness |
| **DevOps Lead** | Maintain cloud and K3s asset inventory, enforce lifecycle controls |
| **System Owners** | Classify assets in their domain, conduct monthly reconciliation |
| **All Personnel** | Report new or decommissioned assets, protect assigned equipment |

---

## Compliance Mapping

| Framework | Control ID | Requirement |
|-----------|-----------|-------------|
| ISO 27001 | A.5.9 | Inventory of Information and Other Associated Assets |
| ISO 27001 | A.5.10 | Acceptable Use of Information and Other Associated Assets |
| ISO 27001 | A.5.13 | Labelling of Information |
| SOC 2 | CC6.1 | Logical and Physical Access Controls |
| HIPAA | 164.310(d) | Device and Media Controls |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-23 | Wakeem Williams | Initial draft |

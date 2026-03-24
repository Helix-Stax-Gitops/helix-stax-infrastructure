---
template: operational-asset-inventory
category: operational
task_type: asset
clickup_list: "04 Service Management"
auto_tags: ["asset", "inventory", "infrastructure"]
required_fields: ["TLDR", "Asset Identification", "Location", "Status", "Security Classification", "Monitoring", "Compliance Evidence"]
classification: internal
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF", "CIS Controls"]
review_cycle: quarterly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: IT Asset Inventory Entry

Use for documenting each IT asset in the infrastructure inventory. Master inventory stored in `docs/infrastructure/asset-inventory.md`. Individual entries can be filed as `docs/infrastructure/assets/{asset-name}.md`.

---

## TLDR

<!-- One sentence: asset type, asset name, owner, purchase date, status. -->

Example: K3s control plane node "heart" (Hetzner CX41), Wakeem Williams owner, provisioned 2025-08-15, active, critical.

---

## Asset Identification

### [REQUIRED] Basic Information

| Field | Value |
|-------|-------|
| **Asset ID** | ASSET-{YYYY}-{number} |
| **Asset Name** | |
| **Asset Type** | Server / Network device / Storage / Application / License / Other |
| **Asset Category** | Compute / Network / Storage / Software / Infrastructure |
| **Asset Owner** | |
| **Cost Center** | |

### [REQUIRED] Acquisition Information

| Field | Value |
|-------|-------|
| **Vendor/Supplier** | |
| **Purchase Date** | YYYY-MM-DD |
| **Acquisition Cost** | $_____ |
| **Warranty Expiry** | YYYY-MM-DD |
| **Depreciation Schedule** | ___ years |
| **Current Book Value** | $_____ |

---

## Detailed Asset Description

### [REQUIRED] Hardware Assets

**If physical hardware:**

| Field | Value |
|-------|-------|
| **Manufacturer** | |
| **Model/SKU** | |
| **Serial Number** | |
| **Specifications** | CPU cores / RAM / Storage / Network / Other |
| **Form Factor** | Barebones / Rack mount / Desktop / Virtual / Other |

### [REQUIRED] Software/Service Assets

**If application or service:**

| Field | Value |
|-------|-------|
| **Software Name** | |
| **Version** | |
| **License Type** | Commercial / Open source / Proprietary / Freemium |
| **License Count** | ___ seats / unlimited / perpetual |
| **License Terms** | Annual / Perpetual / Trial (until YYYY-MM-DD) |
| **Deployment Mode** | Cloud SaaS / Self-hosted / Hybrid / On-premises |

---

## Location & Deployment

### [REQUIRED] Asset Location

| Field | Value |
|-------|-------|
| **Physical Location** | Hetzner Cloud / On-premises / AWS / Azure / Other |
| **Region** | US-East / US-Central / EU / Other |
| **Data Center/Facility** | Ashburn, VA / Frankfurt / Other |
| **Rack/Slot** | |
| **IP Address(es)** | |
| **Network Interface** | eth0: ___ / eth1: ___ |

### [REQUIRED] Logical Deployment

| Field | Value |
|-------|-------|
| **Environment** | Production / Staging / Development / Test |
| **Kubernetes Cluster** | heart (control plane) / helix-worker-1 / standalone |
| **Namespace** | default / {namespace} |
| **Container Image** | [if containerized] |

---

## Operational Information

### [REQUIRED] Asset Status

| Field | Value |
|-------|-------|
| **Current Status** | Active / Inactive / Maintenance / Deprecated / Retired |
| **Status Date** | YYYY-MM-DD |
| **Commissioning Date** | YYYY-MM-DD |
| **Decommissioning Date** | YYYY-MM-DD (if applicable) |
| **Criticality** | Critical / High / Medium / Low |

**Criticality definition**:
- **Critical**: System unavailability causes outage for customers/business
- **High**: System unavailability significantly impacts operations
- **Medium**: System unavailability has limited impact, alternatives exist
- **Low**: System unavailability has minimal business impact

### [REQUIRED] Operational Dependencies

**This asset depends on:**

- [ ] Asset: _____________ (parent/upstream)
- [ ] Asset: _____________
- [ ] Service: _____________

**Assets that depend on this asset:**

- [ ] Asset: _____________ (child/downstream)
- [ ] Asset: _____________

---

## Maintenance & Support

### [REQUIRED] Support & Maintenance

| Field | Value |
|-------|-------|
| **Support Provider** | Vendor / Internal / Hybrid |
| **Support Level** | 24/7 / Business hours / Community |
| **Support Contract** | Yes / No |
| **Support Ticket URL** | [vendor support portal] |
| **SLA** | __% uptime, __h response time for P1 |
| **Support Expires** | YYYY-MM-DD |

### [REQUIRED] Maintenance Schedule

| Maintenance Type | Frequency | Last Performed | Next Scheduled |
|-----------------|-----------|-----------------|-----------------|
| Firmware/OS updates | | | |
| Security patches | | | |
| Performance tuning | | | |
| Backup verification | | | |

---

## Security & Compliance

### [REQUIRED] Security Classification

| Field | Value |
|-------|-------|
| **Data Sensitivity** | Public / Internal / Confidential / Sensitive |
| **PII Stored?** | Yes / No |
| **Payment Card Data?** | Yes / No |
| **Health Information (HIPAA)?** | Yes / No |
| **Encryption Required?** | Yes / No |
| **Encryption Status** | Encrypted / Unencrypted / N/A |

### [REQUIRED] Compliance Scope

This asset is within scope of:

- [ ] SOC 2 Type II audit
- [ ] ISO 27001 certification
- [ ] NIST compliance
- [ ] PCI DSS compliance (if payment card data)
- [ ] HIPAA compliance (if health data)
- [ ] GDPR compliance (if EU data processing)

### [REQUIRED] Access Control

| Role | Access Level | Justification |
|------|--------------|---------------|
| | Admin / User / Read-only / None | |

---

## Monitoring & Health

### [REQUIRED] Monitoring Configuration

| Monitoring Type | Tool | Alert Configured? | Alert Threshold |
|-----------------|------|-------------------|-----------------|
| Availability | Prometheus / Grafana | Yes / No | Down > 5 min |
| Performance | | Yes / No | |
| Security | CrowdSec / Falco | Yes / No | |
| Cost | Hetzner dashboard | Yes / No | |

### [REQUIRED] Health Metrics

| Metric | Current | Healthy Range | Status |
|--------|---------|----------------|--------|
| CPU utilization | __% | <80% | ✓ / ✗ |
| Memory utilization | __% | <85% | ✓ / ✗ |
| Disk utilization | __% | <80% | ✓ / ✗ |
| Network connectivity | | Up | ✓ / ✗ |

**Last health check**: YYYY-MM-DD HH:MM UTC

---

## Financial & Lifecycle

### [OPTIONAL] Cost Analysis

| Cost Type | Amount | Frequency | Annual Cost |
|-----------|--------|-----------|------------|
| Acquisition | $_____ | One-time | |
| Hosting/Cloud | $_____ / month | Monthly | $_____ |
| Support/Maintenance | $_____ / month | Monthly | $_____ |
| License renewal | $_____ / year | Annual | $_____ |
| **Total Annual** | | | $_____ |

### [OPTIONAL] Retirement Plan

**End-of-life plan for this asset:**

- **Planned retirement date**: YYYY-MM-DD
- **Replacement asset**: [asset name]
- **Migration plan**: [describe how workloads move]
- **Data disposal**: Secure wipe / Return to vendor / Destroy / Archive
- **Environmental/recycling**: Proper e-waste disposal

---

## Documentation & Configuration

### [REQUIRED] Related Documentation

**Configuration and runbooks:**

- [ ] Deployment procedure: [link]
- [ ] Troubleshooting guide: [link]
- [ ] Operational runbook: [link]
- [ ] Security hardening checklist: [link]
- [ ] Monitoring dashboard: [link]

### [OPTIONAL] Configuration Export

**System configuration as of [date]:**

```
Paste configuration export here (sanitized of secrets):
- Kubernetes resource YAML
- Network configuration
- Application settings
- etc.
```

---

## Compliance Evidence

### [REQUIRED] Asset Inventory Compliance

This asset inventory entry satisfies:

| Framework | Control | Requirement | How This Entry Satisfies It |
|-----------|---------|-------------|--------------------------|
| SOC 2 | C1 | Asset inventory and management | Documented asset with specifications, ownership, status |
| ISO 27001 | A.8.1.1 | Asset inventory | Asset recorded with classification and ownership |
| NIST CSF | ID.AM-1 | Physical devices inventoried | Device tracked with specs and deployment location |
| CIS Controls | 1.1 | Hardware asset inventory | Asset details documented |

---

## Change & Update Log

### [REQUIRED] Asset History

| Date | Change | Owner | Details |
|------|--------|-------|---------|
| YYYY-MM-DD | Created | | Asset commissioned |
| | Configuration update | | |
| | Hardware upgrade | | |
| | Status change | | |

---

## Review & Validation

### [REQUIRED] Periodic Verification

**Last inventory verification**: YYYY-MM-DD

**Verification method**:
- [ ] Physical inspection
- [ ] System API query
- [ ] Network scan
- [ ] Configuration audit

**Verified by**: ___________

**Next verification due**: YYYY-MM-DD

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Asset ID** | ASSET-{ID} |
| **Last Updated** | YYYY-MM-DD |
| **Classification** | Internal |

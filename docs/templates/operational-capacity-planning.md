---
template: operational-capacity-planning
category: operational
task_type: capacity-plan
clickup_list: "04 Service Management"
auto_tags: ["capacity", "planning", "infrastructure"]
required_fields: ["TLDR", "Current State", "Growth Projections", "Scaling Strategy", "Performance Baselines", "Cost Impact", "Compliance Evidence"]
classification: internal
compliance_frameworks: ["SOC 2", "NIST CSF", "ISO 27001", "PCI DSS"]
review_cycle: quarterly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Infrastructure Capacity Planning

Use for quarterly or annual capacity reviews. Plan for growth over the next 12-24 months across compute, storage, and network. Store in `docs/planning/capacity/{YYYY-Q#}-capacity-plan.md`.

---

## TLDR

<!-- One sentence: current utilization, projected growth, recommended actions. -->

Example: Cluster at 62% CPU, projected to 78% by Q4 2026. Recommend adding 1 worker node (8-core) and increasing MinIO to 50TB by June 2026.

---

## Current State Assessment

### [REQUIRED] Cluster Resources

| Resource | Current | Allocatable | Used | Free | Utilization |
|----------|---------|------------|------|------|--------------|
| **CPU cores** | | | | | ___% |
| **Memory (GB)** | | | | | ___% |
| **Storage (GB)** | | | | | ___% |
| **Network bandwidth** | | | | | ___% |

**Measurement date**: ___________

**Data source**: `kubectl top nodes`, Prometheus metrics, MinIO dashboard

### [REQUIRED] Node Inventory

| Node | CPU Cores | Memory | Storage | Role | Status |
|------|-----------|--------|---------|------|--------|
| heart | | | | Control plane | Healthy / Degraded / Offline |
| helix-worker-1 | | | | Worker | Healthy / Degraded / Offline |
| | | | | | |

### [REQUIRED] Storage Breakdown

| Component | Allocated | Used | Free | Growth Rate |
|-----------|-----------|------|------|-------------|
| PostgreSQL | ___ GB | ___ GB | ___ GB | +___ GB/month |
| MinIO | ___ GB | ___ GB | ___ GB | +___ GB/month |
| Container images (Harbor) | ___ GB | ___ GB | ___ GB | +___ GB/month |
| Prometheus/Loki | ___ GB | ___ GB | ___ GB | +___ GB/month |
| Velero backups | ___ GB | ___ GB | ___ GB | +___ GB/month |

---

## Growth Projections (12-Month Outlook)

### [REQUIRED] Workload Forecast

| Metric | Current | 6 Months | 12 Months | CAGR |
|--------|---------|----------|-----------|------|
| **Active users** | | | | __% |
| **Daily transactions** | | | | __% |
| **Data volume (GB)** | | | | __% |
| **API requests/day** | | | | __% |

**Assumptions**:
- Client headcount growth: ___% per quarter
- Transaction volume growth: ___% per quarter
- Data retention policy: ___ months (affects storage)
- Compliance audit frequency: ___ per year (affects backup volume)

### [REQUIRED] Projected Resource Usage

| Resource | Current | 6-Month Forecast | 12-Month Forecast |
|----------|---------|------------------|-------------------|
| **CPU utilization** | ___% | ___% | ___% |
| **Memory utilization** | ___% | ___% | ___% |
| **Storage utilization** | ___% | ___% | ___% |

**Calculation method**: Historical growth rate, client pipeline growth, planned feature deployments

---

## Capacity Planning Decisions

### [REQUIRED] Scaling Strategy

- [ ] **Vertical scaling**: Add resources to existing nodes (not recommended for HA)
- [ ] **Horizontal scaling**: Add new worker nodes (recommended for HA)
- [ ] **Storage expansion**: Increase MinIO/PostgreSQL allocation
- [ ] **Network upgrade**: Increase bandwidth or optimize traffic

**Rationale for chosen strategy**:

### [REQUIRED] Planned Additions (Next 12 Months)

| Action | Timeline | Resource | Cost | Expected Benefit |
|--------|----------|----------|------|------------------|
| Add worker node | Q2 2026 | 8-core, 32GB RAM | $___/month | +60% CPU capacity, better resource distribution |
| Expand MinIO | Q2 2026 | +25TB storage | $___/month | Supports data growth, backup retention |
| Upgrade PostgreSQL | Q3 2026 | CloudNativePG HA setup | 0 (k8s native) | High availability, faster recovery |
| | | | | |

### [REQUIRED] Decommissioning Plan

| Resource | Planned Retirement | Reason |
|----------|-------------------|--------|
| | | |

---

## Performance Baselines

### [REQUIRED] Current SLI/SLO Targets

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| **API response time (p95)** | ___ ms | ___ ms | |
| **Error rate** | ___% | <0.1% | |
| **Uptime** | ___% | 99.9% | |
| **Database query time (p95)** | ___ ms | ___ ms | |

### [OPTIONAL] Bottleneck Analysis

**Current bottlenecks** (by severity):

1. _____________ (limiting factor: CPU / Memory / Disk I/O / Network / Database)
2. _____________ (limiting factor: _______)
3. _____________ (limiting factor: _______)

**Mitigation for each**:
1. _____
2. _____
3. _____

---

## Cost Impact Analysis

### [REQUIRED] Budget Impact

| Year | Fixed Cost | Variable Cost | Total | YoY Change |
|------|-----------|---------------|-------|-----------|
| 2026 (current) | $___/month | $___/month | $___/month | - |
| 2026 (projected) | $___/month | $___/month | $___/month | +___% |
| 2027 (estimated) | $___/month | $___/month | $___/month | +___% |

**Hetzner Cloud costs**:
- Control plane (heart): $___/month
- Worker nodes (current): $___/month
- Worker nodes (planned): $___/month each
- Block storage: $___/GB/month

**Backblaze B2 costs**:
- Current: $___/month for ___ GB
- Projected: $___/month for ___ GB

### [REQUIRED] Cost Optimization Opportunities

- [ ] Reserved instances vs on-demand
- [ ] Compression for backup storage
- [ ] Tiered storage (hot/warm/cold)
- [ ] Aggressive log retention policies
- [ ] Container image pruning
- [ ] Unused PVC cleanup

**Estimated savings**: $___/month

---

## Compliance & Documentation

### [REQUIRED] Capacity Planning Evidence

This document satisfies:
- **SOC 2 A1.2**: System availability supported by adequate infrastructure capacity
- **NIST CSF ID.SC-1**: Asset management including IT resource inventory
- **ISO 27001 A.12.1.1**: Documented change management including capacity planning
- **PCI DSS 12.5.1**: Policies addressing physical and logical access to cardholder data

### [REQUIRED] Stakeholder Review & Approval

| Stakeholder | Role | Date Reviewed | Approval |
|-------------|------|---------------|----------|
| | Infrastructure Lead | | ✓ / ✗ |
| | Finance/Budget Lead | | ✓ / ✗ |
| | Compliance Lead | | ✓ / ✗ |
| | Security Lead | | ✓ / ✗ |

### [OPTIONAL] Monitoring Plan

Capacity will be monitored via:
- **Prometheus**: Memory, CPU, disk utilization queries in `dashboards/capacity.json`
- **Grafana**: Weekly capacity dashboard with trend lines
- **Manual review**: Quarterly capacity review meetings
- **Alerts**: Trigger escalation if utilization exceeds 80%

---

## Review Cadence

- [ ] **Quarterly**: Update current state assessment and compare to forecast
- [ ] **Annually**: Full plan review and revision
- [ ] **Immediately**: If utilization suddenly spikes or growth accelerates

**Last updated**: ___________
**Last reviewed**: ___________
**Next review scheduled**: ___________

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Classification** | Internal |

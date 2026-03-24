---
template: operational-service-catalog-entry
category: operational
task_type: service-catalog
clickup_list: "04 Service Management"
auto_tags: ["service-catalog", "infrastructure", "documentation"]
required_fields: ["TLDR", "Service Details", "Deployment", "SLO", "Dependencies", "Monitoring", "Incident Response"]
classification: internal
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: quarterly
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Internal Service Catalog Entry

Use for documenting internal services in the service catalog. Catalog entry describes service, SLA, dependencies, and ownership. File as `docs/infrastructure/services/{service-name}-catalog.md`.

---

## TLDR

<!-- One sentence: service name, owner, SLA, key dependencies. -->

Example: Zitadel (identity service), owned by Security Lead, 99.9% uptime SLA, depends on PostgreSQL and Cloudflare.

---

## Service Identification

### [REQUIRED] Service Details

| Field | Value |
|-------|-------|
| **Service Name** | |
| **Service ID** | SVC-{name} |
| **Description** | What does this service do? |
| **Service Owner** | |
| **Service Manager** | |
| **Team** | Infrastructure / Security / Application / Platform |
| **Service Type** | Core / Supporting / Optional |

### [REQUIRED] Service Criticality

| Level | Definition | Service Impact |
|-------|-----------|-----------------|
| **CRITICAL** | Service outage impacts customer SLA | 99.9%+ uptime required |
| **HIGH** | Service outage severely impacts operations | 99.5%+ uptime |
| **MEDIUM** | Service outage impacts some users/features | 99%+ uptime |
| **LOW** | Service outage has minimal impact | Best effort availability |

**This service criticality**: [ ] Critical [ ] High [ ] Medium [ ] Low

---

## Service Capabilities & Audience

### [REQUIRED] Service Description

**What does this service do?** (2-3 paragraphs)

---

### [REQUIRED] Service Audience

**Who uses this service?**

- [ ] Internal employees only
- [ ] Contractors/partners
- [ ] External customers
- [ ] Automated systems / bots
- [ ] All of above

**Approximate user count**: ___ users / ___ applications / ___ API clients

---

## Deployment & Operations

### [REQUIRED] Deployment Information

| Field | Value |
|-------|-------|
| **Deployment Target** | Kubernetes (K3s) / Docker Compose / VMs / External SaaS / Hybrid |
| **Environment** | Production / Staging / Development / Test |
| **Cluster/Region** | heart (control plane) / helix-worker-1 / Multi-region |
| **Namespace** | default / {namespace} |
| **Number of Replicas** | ___ (production) |
| **Container Image** | registry.helixstax.net/___:___ |
| **Source Code** | GitHub repo or SaaS provider |

### [REQUIRED] Operational Metrics

| Metric | Value | Healthy Range |
|--------|-------|----------------|
| **CPU limit per pod** | ___ m | |
| **Memory limit per pod** | ___ Mi | |
| **Storage requirement** | ___ GB | |
| **Network bandwidth (typical)** | ___ Mbps | |
| **Startup time** | ___ seconds | |

---

## Service Level Objectives (SLO)

### [REQUIRED] Availability SLA

| SLA Component | Target | Measurement | Enforcement |
|---------------|--------|-------------|-------------|
| **Uptime** | ___% | Helix Stax uptime dashboard | Service credit: ___% of monthly fee |
| **Response time (p95)** | ___ ms | Prometheus query | Escalation if exceeded |
| **Error rate** | <___% | Application metrics | Alert if exceeded |
| **Maximum downtime/month** | ___ minutes | | |

**SLA measurement period**: Calendar month / Rolling 30-day window

### [REQUIRED] Planned Maintenance Windows

**Maintenance occurs:**

- [ ] Never (no maintenance)
- [ ] During announced maintenance windows: [e.g., 2nd Sunday 02:00-04:00 UTC]
- [ ] Without advance notice (maintenance mode disabled)
- [ ] Quarterly or annually: [schedule]

**Advance notice**: ___ days before maintenance

### [OPTIONAL] Performance SLA

| Performance Metric | Target | Measurement Method |
|-------------------|--------|-------------------|
| API response time (p50) | ___ ms | Prometheus histogram |
| API response time (p95) | ___ ms | |
| API response time (p99) | ___ ms | |
| Query response time | ___ ms | |
| Data ingestion throughput | ___ events/sec | |

---

## Deployment & Configuration

### [REQUIRED] How to Deploy

**Service deployment procedure:**

```bash
# Step 1: Update Helm values
vim helm/{service}/values-prod.yaml

# Step 2: Deploy via Helm
helm upgrade --install {service} helm/{service} \
  -n {namespace} \
  -f helm/values-prod.yaml

# Step 3: Verify deployment
kubectl rollout status deployment/{deployment} -n {namespace}
```

**Helm chart location**: `helm/{service}/`

**Current deployed version**: _____________

### [REQUIRED] Configuration Management

| Configuration | Location | Managed By | Frequency |
|--------------|----------|-----------|-----------|
| Service config | ConfigMap | Manual / GitOps | On change |
| Secrets | OpenBao / External Secrets | Manual / Automated | On rotation |
| Database schema | Migration scripts | CI/CD pipeline | Per deployment |
| Feature flags | Application config | Manual | On demand |

---

## Dependencies & Integrations

### [REQUIRED] Service Dependencies

**This service depends on:**

| Dependency | Type | Critical? | Failure Impact |
|-----------|------|-----------|----------------|
| PostgreSQL | Database | Yes | Service down |
| Cloudflare | DNS/CDN | Yes | External access lost |
| OpenBao | Secrets | Yes | Service won't start |
| [Service name] | Service | Yes / No | [impact] |
| [Service name] | Service | Yes / No | [impact] |

### [REQUIRED] Dependent Services

**Services that depend on this service:**

| Dependent Service | Dependency Type | Impact If Down |
|------------------|-----------------|---|
| | | |

### [REQUIRED] Integration Points

**How this service integrates with others:**

| Integration | Protocol | Frequency | Data Volume |
|-------------|----------|-----------|-------------|
| Webhook to Rocket.Chat | HTTP POST | Per event | ___ requests/day |
| n8n automation trigger | API call | Scheduled | ___ calls/day |
| Prometheus scraping | Metrics API | Every 30s | ___ series |

---

## Monitoring & Alerting

### [REQUIRED] Monitoring Setup

| Monitor Type | Tool | Query/Alert | Threshold | Notification |
|-------------|------|------------|-----------|--------------|
| **Availability** | Prometheus | up{service="{name}"} | 0 = down | Rocket.Chat #alerts |
| **Response time** | | histogram_quantile(0.95, ...) | >___ ms | Rocket.Chat #alerts |
| **Error rate** | | rate(errors_total[5m]) | >___% | Escalate to on-call |
| **Pod restarts** | | container_last_seen | >3 in 1h | Rocket.Chat #alerts |

### [REQUIRED] Dashboard

**Grafana dashboard**: [link to dashboard]

**Dashboard shows**:
- [ ] Real-time service health
- [ ] Error rates and latency
- [ ] Resource utilization
- [ ] Dependency status
- [ ] Recent deployments/changes

---

## Incident & Support

### [REQUIRED] Incident Response

**If this service is down:**

1. **Page on-call**: [on-call schedule link]
2. **Incident severity**: Assess if P1 (customer-facing) or P2 (internal)
3. **Escalation**: If down >5 min, escalate to service owner
4. **Remediation**: Check recent deployments, check logs, restart if needed
5. **Post-mortem**: After resolution, conduct incident review

**Known issues/workarounds**:

- [ ] Issue: [description] — Workaround: [temporary fix]
- [ ] Issue: [description] — Workaround: [temporary fix]

### [REQUIRED] Support Contacts

| Role | Name | Email | Phone | Availability |
|------|------|-------|-------|--------------|
| **Service Owner** | | | | |
| **On-Call Engineer** | | | | 24/7 |
| **Secondary Contact** | | | | Business hours |

---

## Maintenance & Upgrades

### [REQUIRED] Deployment Versioning

| Component | Current Version | Latest Available | Upgrade Needed? |
|-----------|-----------------|------------------|-----------------|
| Application | | | Yes / No |
| Helm chart | | | Yes / No |
| Dependencies | | | Yes / No |

### [REQUIRED] Upgrade Procedure

**To upgrade this service:**

1. Review changelog for breaking changes
2. Test upgrade in staging cluster first
3. Schedule maintenance window if needed
4. Follow deployment procedure above
5. Monitor for errors during and after upgrade
6. Verify SLA targets are still met post-upgrade

**Last upgrade**: _____________
**Upgrade testing**: Passed / Failed

---

## Cost & Licensing

### [OPTIONAL] Cost Analysis

| Component | Cost | Frequency | Notes |
|-----------|------|-----------|-------|
| Hosting (Hetzner) | $___/month | Monthly | |
| Licensing | $___/month | Monthly | |
| Support | $___/month | Monthly | |
| **Total Monthly Cost** | $_____ | | |

---

## Compliance & Security

### [REQUIRED] Security Posture

**Security controls in place:**

- [ ] TLS encryption for all traffic
- [ ] Authentication required (via Zitadel)
- [ ] Authorization (RBAC) implemented
- [ ] Audit logging enabled
- [ ] Secrets management (OpenBao)
- [ ] Vulnerability scanning enabled
- [ ] DDoS protection (Cloudflare)
- [ ] WAF rules configured

### [REQUIRED] Compliance Scope

This service is in scope of:

- [ ] SOC 2 Type II
- [ ] ISO 27001
- [ ] NIST compliance
- [ ] PCI DSS (if payment data)
- [ ] HIPAA (if health data)
- [ ] GDPR (if EU data)

---

## Documentation & Runbooks

### [REQUIRED] Available Documentation

- [ ] Deployment guide: [link]
- [ ] Troubleshooting runbook: [link]
- [ ] Incident playbook: [link]
- [ ] API documentation: [link]
- [ ] Configuration guide: [link]
- [ ] Architecture diagram: [link]

---

## Change Log

### [REQUIRED] Service History

| Date | Change | Version | Impact |
|------|--------|---------|--------|
| YYYY-MM-DD | Deployed | | New service |
| | | | |

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Service ID** | SVC-{name} |
| **Last Updated** | YYYY-MM-DD |
| **Classification** | Internal |

---
template: operational-service-deployment
category: operational
task_type: deployment
clickup_list: "04 Service Management"
auto_tags: ["deployment", "k3s", "infrastructure"]
required_fields: ["TLDR", "Service Information", "Prerequisites", "Risk Assessment", "Deployment Steps", "Post-Deployment Verification"]
classification: internal
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF"]
review_cycle: per-use
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: Service Deployment

Use this template for every production service deployment on K3s. Complete sections before, during, and after deployment. Store in `docs/runbooks/deployments/YYYY-MM-DD-{service-name}.md`.

---

## TLDR

<!-- One sentence: what service, what version, what environment, expected outcome. -->

Example: Deploy Zitadel v2.48.0 to prod cluster with PostgreSQL migration and OIDC client reconfiguration.

---

## Pre-Deployment Checklist

### [REQUIRED] Service Information

| Field | Value |
|-------|-------|
| **Service Name** | |
| **Version** | |
| **Target Cluster** | heart (control plane) / helix-worker-1 (worker) / all |
| **Namespace** | |
| **Deployment Type** | Blue-green / Canary / Rolling / In-place |
| **Estimated Duration** | ___ minutes |
| **Rollback Plan** | Version to rollback to if deployment fails |

### [REQUIRED] Prerequisites Verification

- [ ] All dependencies deployed and healthy (check `kubectl get pods -n {namespace}`)
- [ ] Database migrations tested (if applicable)
- [ ] Secrets rotated and stored in OpenBao
- [ ] New container image built and pushed to Harbor
- [ ] Helm chart updated with new image tag in `helm/values-{env}.yaml`
- [ ] Configuration changes documented in commit message
- [ ] Resource limits (CPU/memory) reviewed and adjusted
- [ ] Monitoring/alerting rules updated in Prometheus

### [REQUIRED] Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| | L/M/H | L/M/H | |
| | L/M/H | L/M/H | |

**Overall Risk Level**: [ ] Low [ ] Medium [ ] High

### [OPTIONAL] Testing Done

- [ ] Unit tests passed
- [ ] Integration tests passed
- [ ] Smoke test in staging passed
- [ ] Performance test completed
- [ ] Security scan passed (no CVEs)
- [ ] Backup created (if database changes)

---

## Deployment Execution

### [REQUIRED] Pre-Deployment Snapshot

**Current state before deployment**:

```bash
# Record pod status
kubectl get pods -n {namespace}

# Record current image
kubectl get deployment {deployment} -n {namespace} -o jsonpath='{.spec.template.spec.containers[0].image}'

# Record recent events
kubectl get events -n {namespace} --sort-by='.lastTimestamp' | tail -20
```

### [REQUIRED] Deployment Steps

**Start time (UTC)**: ___________

1. **Update Helm values**:
   ```bash
   # Edit helm/values-{env}.yaml
   # Increment image tag from X.Y.Z to A.B.C
   git diff helm/values-{env}.yaml
   ```

2. **Verify Helm chart**:
   ```bash
   helm lint helm/{service}
   helm template {release} helm/{service} -f helm/values-{env}.yaml | head -50
   ```

3. **Deploy via Helm**:
   ```bash
   helm upgrade --install {release} helm/{service} \
     -n {namespace} \
     -f helm/values-{env}.yaml \
     --timeout 5m \
     --wait
   ```

4. **Monitor rollout**:
   ```bash
   kubectl rollout status deployment/{deployment} -n {namespace} --timeout=5m
   ```

5. **Verify pod startup**:
   ```bash
   kubectl get pods -n {namespace} -o wide
   kubectl logs -n {namespace} deployment/{deployment} --tail=100
   ```

6. **Test connectivity** (if applicable):
   ```bash
   # Curl endpoint or run smoke test
   curl https://{service}.helixstax.net/health
   ```

**End time (UTC)**: ___________

**Actual duration**: ___ minutes

### [REQUIRED] Post-Deployment Verification

- [ ] Pods running and ready (not CrashLoopBackOff)
- [ ] Service responding to health checks
- [ ] No errors in logs (grep for ERROR, FATAL)
- [ ] Metrics flowing into Prometheus (check Grafana)
- [ ] No increase in error rate
- [ ] Database schema migrations completed (if applicable)
- [ ] OIDC clients functional (if auth-related)
- [ ] All dependent services still functioning

### [OPTIONAL] Performance Validation

| Metric | Baseline | Post-Deploy | Status |
|--------|----------|-------------|--------|
| Response time (p95) | ___ ms | ___ ms | ✓ / ✗ |
| Error rate | ___% | ___% | ✓ / ✗ |
| CPU usage | ___% | ___% | ✓ / ✗ |
| Memory usage | ___ Mi | ___ Mi | ✓ / ✗ |

---

## Rollback Procedure

**Use this ONLY if deployment fails and service is impaired.**

```bash
# Step 1: Identify the previous stable version
helm history {release} -n {namespace}

# Step 2: Rollback to previous release
helm rollback {release} {revision} -n {namespace} --wait

# Step 3: Verify rollback
kubectl rollout status deployment/{deployment} -n {namespace}
kubectl get pods -n {namespace}

# Step 4: Confirm service is restored
curl https://{service}.helixstax.net/health
```

**Rollback initiated at (UTC)**: ___________
**Rollback completed at (UTC)**: ___________

---

## Compliance & Logging

### [REQUIRED] Change Documentation

| Field | Value |
|-------|-------|
| **Change Type** | Emergency / Standard / Normal |
| **Approval** | [ ] CAB approved (if required) |
| **Change Ticket** | Link to ClickUp task |
| **Git Commit** | SHA of deployment commit |
| **Deployment Log** | Paste stdout/stderr below |

### [REQUIRED] Deployment Log

```
Paste full deployment output here (helm upgrade logs, kubectl events, etc.)
```

### [REQUIRED] Evidence for Compliance

This deployment document serves as evidence for:
- **SOC 2 CC8.1**: Change management and approval
- **ISO 27001 A.12.1.2**: Changes documented with rollback procedures
- **NIST CSF PR.IP-3**: Configuration change control

---

## Lessons Learned

<!-- What went well? What was surprising? What would you do differently next time? -->

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Classification** | Internal |

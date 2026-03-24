---
template: operational-certificate-management
category: operational
task_type: certificate
clickup_list: "04 Service Management"
auto_tags: ["certificate", "tls", "ssl", "security"]
required_fields: ["TLDR", "Certificate Information", "Renewal Strategy", "Monitoring", "Renewal History", "Compliance"]
classification: internal
compliance_frameworks: ["SOC 2", "ISO 27001", "NIST CSF", "PCI DSS"]
review_cycle: per-use
author: "Wakeem Williams"
version: 1.0
---

# TEMPLATE: TLS/SSL Certificate Management and Renewal

Use for tracking and managing all TLS certificates in the infrastructure. Store master list in `docs/infrastructure/certificate-inventory.md` and renewal tracking in `docs/runbooks/certificates/{domain}-renewal-log.md`.

---

## TLDR

<!-- One sentence: certificate domain, issuer, expiry, renewal status, automation level. -->

Example: helixstax.com TLS cert issued by Let's Encrypt, expires 2026-06-15, auto-renewed via cert-manager every 60 days before expiry.

---

## Certificate Information

### [REQUIRED] Certificate Details

| Field | Value |
|-------|-------|
| **Domain(s)** | |
| **Wildcard?** | Yes / No |
| **Issuer** | Let's Encrypt / DigiCert / AWS ACM / Other |
| **Algorithm** | RSA-2048 / RSA-4096 / ECDSA / Other |
| **Issue Date** | YYYY-MM-DD |
| **Expiry Date** | YYYY-MM-DD |
| **Days Until Expiry** | ___ days |
| **Renewal Needed?** | ✓ Yes (>60 days before expiry) / ✗ No |

### [REQUIRED] Certificate Location

| Component | Location | Secret/Config Name | Namespace |
|-----------|----------|-------------------|-----------|
| **K3s ingress** | Kubernetes secret | tls-{domain}-secret | default / ingress-nginx |
| **Application config** | Mount path | /etc/tls/certs/ | |
| **Backup location** | S3 bucket | s3://helix-stax-backups/certs/ | |

### [REQUIRED] Service Dependencies

**Services using this certificate:**

- [ ] helixstax.com (main website)
- [ ] *.helixstax.net (internal subdomains)
- [ ] api.helixstax.com (API endpoints)
- [ ] admin.helixstax.com (admin portal)
- [ ] Other: ___________

---

## Renewal & Automation

### [REQUIRED] Renewal Strategy

**Certificate renewal method:**

- [ ] **Automated (cert-manager)**: Kubernetes cert-manager renews automatically
  - Renewal trigger: 30 days before expiry
  - Validation method: DNS-01 via Cloudflare API
  - Monitoring: Prometheus alert if renewal fails

- [ ] **Semi-automated (acme.sh)**: Script-based renewal, manual upload to K3s
  - Renewal trigger: 30 days before expiry
  - Run schedule: Cron job at 02:00 UTC weekly
  - Validation method: DNS-01 / HTTP-01

- [ ] **Manual renewal**: Administrator-initiated
  - Renewal date: ___ days before expiry
  - Process: [describe manual renewal process]
  - Owner: _________

### [REQUIRED] Renewal Automation Configuration

**If automated via cert-manager:**

```yaml
# cert-manager Certificate resource
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {domain-cert}
  namespace: default
spec:
  secretName: {secret-name}
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - {domain}
    - *.{domain}
  renewBefore: 720h  # Renew 30 days before expiry
```

**Certificate status check:**

```bash
kubectl get certificate {domain-cert} -o wide
kubectl describe certificate {domain-cert}
```

### [OPTIONAL] Renewal Testing

- [ ] Staging certificate renewed successfully: [date]
- [ ] Production certificate renewal tested in dev cluster: [date]
- [ ] Renewal time observed: ___ minutes
- [ ] Downtime during renewal: [ ] None [ ] <1 second [ ] <30 seconds

---

## Certificate Chain & Validation

### [REQUIRED] Certificate Chain Verification

```bash
# Verify certificate details
openssl x509 -in cert.pem -text -noout

# Verify certificate chain completeness
openssl verify -CAfile chain.pem cert.pem

# Check certificate expiry
openssl x509 -in cert.pem -noout -dates
```

**Verification results**:

- [ ] Certificate valid
- [ ] Chain complete (root, intermediate, leaf)
- [ ] No self-signed certificates in chain
- [ ] Key size adequate (RSA 2048+ or ECDSA)

### [REQUIRED] Certificate Pinning (if applicable)

**Is this certificate pinned in any application?**

- [ ] Yes — List applications: ___________
- [ ] No

If pinned, **renewal procedure requires**:
1. Issue new certificate
2. Update application with new certificate fingerprint/pin
3. Deploy application update
4. Verify application connectivity with new cert
5. Only then decommission old certificate

---

## Monitoring & Alerts

### [REQUIRED] Expiration Monitoring

**Monitoring configured via:**

- [ ] **Prometheus**:
  ```promql
  (certExpiry{domain="{domain}"} - time()) / 86400 < 30
  ```
  Alert fires if <30 days to expiry

- [ ] **cert-manager**: Native prometheus metrics
  ```promql
  certmanager_certificate_expiration_timestamp_seconds
  ```

- [ ] **Manual calendar reminder**: Renewal date tracked in [location]

### [REQUIRED] Alert Configuration

| Alert | Trigger | Action | Owner |
|-------|---------|--------|-------|
| Cert expires in 30 days | Query fires | Review renewal logs, verify automation working | |
| Cert expires in 7 days | Query fires | Manual intervention if auto failed | |
| Cert expired (0 days) | Critical | Page on-call immediately | |

**Alert destination**: [Rocket.Chat channel / Slack / PagerDuty / Email]

---

## Renewal History & Audit Trail

### [REQUIRED] Certificate Renewal Log

| Renewal # | Renewal Date | Previous Cert Expiry | New Cert Expiry | Method | Status | Notes |
|-----------|--------------|-------------------|-----------------|--------|--------|-------|
| 1 | YYYY-MM-DD | YYYY-MM-DD | YYYY-MM-DD | Automated / Manual | Success / Failed | |
| 2 | | | | | | |

### [REQUIRED] Incidents & Issues

**Any certificate-related incidents:**

| Date | Issue | Root Cause | Resolution | Lessons Learned |
|------|-------|-----------|-----------|-----------------|
| | | | | |

---

## Compliance & Documentation

### [REQUIRED] Certificate Lifecycle Compliance

This certificate management process satisfies:

| Framework | Control | Requirement | Evidence |
|-----------|---------|-------------|----------|
| SOC 2 | CC6.1 | Cryptographic controls | Certificate details, renewal log |
| ISO 27001 | A.10.1.2 | Encryption key management | Certificate tracking |
| NIST CSF | PR.DS-2 | Data security | Certificate expiry monitoring |
| PCI DSS | 4.1 | Encryption of data in transit | Certificate validity |

### [REQUIRED] Certificate Backup & Recovery

**Certificates backed up to:**

- [ ] MinIO (encrypted): s3://helix-stax-backups/certs/{domain}/
- [ ] GitHub (secret, encrypted): [reference]
- [ ] OpenBao (secure vault): [reference]

**Recovery procedure** (if cert is lost):

1. Issue new certificate via cert-manager or Let's Encrypt
2. Wait for DNS validation (if DNS-01 validation used)
3. Upload new cert to K3s: `kubectl create secret tls {secret} --cert=cert.pem --key=key.pem`
4. Redeploy affected ingresses

---

## Renewal Checklist (Before Expiry)

### [REQUIRED] Pre-Renewal Tasks

**30 days before expiry:**

- [ ] Verify automation is configured correctly
- [ ] Check monitoring/alerts are active
- [ ] Test renewal process in staging (if manual)
- [ ] Brief operations team on renewal status
- [ ] Verify backup of current certificate exists

**7 days before expiry:**

- [ ] Confirm renewal occurred or is in progress
- [ ] Check certificate appears valid and accessible
- [ ] Verify all services using certificate are healthy
- [ ] Test service connectivity with new certificate

**On expiry date (or after successful renewal):**

- [ ] Confirm certificate has been renewed
- [ ] All services using new certificate
- [ ] No certificate-related errors in logs
- [ ] Update certificate inventory document
- [ ] Close renewal tracking in ClickUp

### [REQUIRED] Post-Renewal Verification

```bash
# Check certificate in use by service
kubectl get secret {secret-name} -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates

# Verify service is healthy
curl -I https://{domain}
echo | openssl s_client -servername {domain} -connect {domain}:443 2>/dev/null | openssl x509 -noout -dates
```

**Verification checklist:**

- [ ] Certificate is valid (not expired)
- [ ] Certificate matches domain
- [ ] Service responds on HTTPS
- [ ] Certificate chain complete
- [ ] No SSL/TLS errors in logs

---

## Certificate Decommissioning

### [REQUIRED] End-of-Life Process

**When certificate is no longer needed:**

1. [ ] Identify reason for decommissioning (domain discontinued, certificate rotated, etc.)
2. [ ] Verify no services using this certificate
3. [ ] Archive certificate details to `docs/compliance/retired-certificates/`
4. [ ] Securely delete private key (if applicable)
5. [ ] Remove from monitoring
6. [ ] Update inventory document

**Retention**: Keep certificate archive for 3+ years (regulatory requirement)

---

## Contact & Escalation

| Role | Name | Email | Phone |
|------|------|-------|-------|
| **Certificate Owner** | | | |
| **Infrastructure Lead** | | | |
| **On-Call SRE** | | | |

**Escalation**: If certificate expires without renewal, page on-call immediately.

---

## Footer

| Field | Value |
|-------|-------|
| **Author** | Wakeem Williams |
| **Co-Author** | Quinn Mercer L1 (Documentation) |
| **Date** | YYYY-MM-DD |
| **Version** | 1.0 |
| **Certificate ID** | {domain-cert} |
| **Last Updated** | YYYY-MM-DD |
| **Classification** | Internal |

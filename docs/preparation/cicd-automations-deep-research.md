# CI/CD Event Automations -- Deep Research

> **NOTE (2026-03-21): "ArgoCD" in this document refers to Devtron's internal ArgoCD, NOT a standalone ArgoCD installation. Devtron bundles ArgoCD and manages it as part of its CI/CD platform.**

> **Author**: Remy Alcazar, Research Analyst
> **Date**: 2026-03-20
> **Stack**: Devtron (CI) -> Harbor (registry + Trivy) -> ArgoCD (GitOps deploy) -> K3s
> **Automation Engine**: n8n
> **Targets**: ClickUp, Rocket.Chat, Postal (email), Grafana (annotations)
> **Compatibility**: K3s, AlmaLinux 9, Flannel CNI, Traefik, Helm

---

## Table of Contents

1. [Devtron Events](#1-devtron-events)
2. [ArgoCD Events](#2-argocd-events)
3. [Harbor Events](#3-harbor-events)
4. [GitHub Events](#4-github-events)
5. [Full CI/CD Event Chain](#5-full-cicd-event-chain)
6. [n8n Workflow Designs](#6-n8n-workflow-designs)
7. [Monitoring the Automations](#7-monitoring-the-automations)
8. [Risks and Gotchas](#8-risks-and-gotchas)
9. [Open Questions](#9-open-questions)

---

## 1. Devtron Events

### 1.1 Event Catalog

Devtron exposes notifications for CI and CD pipelines. Each pipeline supports three event types: **Trigger** (start), **Success**, and **Failure**. Devtron sends these via configured notification channels (Slack, Email/SES/SMTP, or custom Webhook).

**Webhook Template Variables Available**:
- `{{devtronAppName}}` -- application name
- `{{eventType}}` -- trigger/success/failure
- `{{devtronContainerImageRepo}}` -- image repository
- `{{devtronContainerImageTag}}` -- image tag
- `{{devtronTriggeredByEmail}}` -- who triggered it

**Webhook Payload Format**: Devtron sends a JSON POST to the configured webhook URL. The payload structure depends on the channel type (Teams AdaptiveCard, Slack Blocks, Discord embed, or generic webhook). For n8n integration, configure a **generic webhook** channel pointing to n8n's webhook trigger URL.

Source: [Devtron Notifications Docs](https://docs.devtron.ai/docs/user-guide/integrations/notifications), [Devtron Manage Notifications](https://docs.devtron.ai/docs/user-guide/app-management/configurations/manage-notification)

#### 1.1.1 CI Pipeline Events

| Event | Devtron eventType | When It Fires | Webhook Payload Fields |
|-------|-------------------|---------------|----------------------|
| **Build Started** | `trigger` (CI) | CI pipeline triggered (manual or webhook) | `devtronAppName`, `eventType=trigger`, `devtronTriggeredByEmail` |
| **Build Success** | `success` (CI) | CI pipeline completes with image built and pushed | `devtronAppName`, `eventType=success`, `devtronContainerImageRepo`, `devtronContainerImageTag` |
| **Build Failure** | `fail` (CI) | CI pipeline fails at any stage (tests, build, push) | `devtronAppName`, `eventType=fail`, `devtronTriggeredByEmail` |

**Note on Build Timeout**: Devtron does not emit a distinct "timeout" event. A build that times out will fire as a `fail` event. The timeout itself is configured per CI pipeline (default: 3600s). To distinguish timeouts from other failures, n8n would need to correlate the failure with elapsed time or parse error messages from Devtron's API.

**Note on Pipeline Stage Completion**: Devtron does not emit per-stage webhooks. The entire CI pipeline is treated as one unit -- you get trigger/success/fail for the whole pipeline, not per-step. Pre-build and post-build scripts run within the CI pipeline as a single execution unit.

#### 1.1.2 CD Pipeline Events

| Event | Devtron eventType | When It Fires | Webhook Payload Fields |
|-------|-------------------|---------------|----------------------|
| **Deployment Triggered** | `trigger` (CD) | CD pipeline triggered (auto or manual) | `devtronAppName`, `eventType=trigger`, `devtronContainerImageTag` |
| **Deployment Success** | `success` (CD) | Application successfully deployed to environment | `devtronAppName`, `eventType=success`, `devtronContainerImageTag` |
| **Deployment Failure** | `fail` (CD) | Deployment fails (pod crash, resource error, etc.) | `devtronAppName`, `eventType=fail`, `devtronContainerImageTag` |

**Events Devtron Does NOT Natively Emit** (must be achieved via workarounds):

| Desired Event | Workaround |
|---------------|------------|
| Deployment rollback | Monitor via ArgoCD notifications (Devtron embeds ArgoCD). ArgoCD's `on-sync-running` fires on rollback sync. |
| Config change detected | Not a Devtron event. Use GitHub webhook on config repo changes. |
| New app registered | Use Devtron REST API polling or ArgoCD `on-created` trigger. |
| Pipeline created/modified/deleted | Not exposed as webhook events. Must poll Devtron API. |
| Resource quota exceeded | Not a Devtron event. Use Kubernetes resource quota alerts via Prometheus/Grafana. |
| Pre/post-deploy hook success/failure | These run as part of the CD pipeline. Success/failure rolls up into the CD pipeline's success/fail event. Individual hook status is not sent as a separate webhook. |
| Image pushed to registry | Harbor handles this -- see Section 3. Devtron CI success implies image was pushed. |

### 1.2 Devtron Event Automation Matrix

For each Devtron event, here is the complete automation response:

#### Build Started (CI Trigger)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to linked task: "Build started for [appName] by [triggeredBy] at [timestamp]" |
| **Rocket.Chat** | Post to `#ci-builds`: "[appName] Build started by [triggeredBy]" |
| **Postal** | No email (too noisy for routine builds) |
| **Grafana** | Add annotation: tags=["build","started","ci"], text="CI build started: [appName]" |

#### Build Success (CI Success)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to linked task: "Build successful. Image: [imageRepo]:[imageTag]" |
| **Rocket.Chat** | Post to `#ci-builds`: "[appName] Build SUCCESS -- image [imageTag] pushed to Harbor" |
| **Postal** | No email (routine success) |
| **Grafana** | Add annotation: tags=["build","success","ci"], text="CI build success: [appName]:[imageTag]" |

#### Build Failure (CI Fail)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to linked task: "BUILD FAILED for [appName]. Triggered by [triggeredBy]." + Update task status to "Blocked" |
| **Rocket.Chat** | Post to `#ci-builds` with `@here`: "ALERT: [appName] Build FAILED. Triggered by [triggeredBy]. Check Devtron for details." |
| **Postal** | Send email to Wakeem (admin@helixstax.com): Subject "CI Build Failed: [appName]", body with link to Devtron pipeline |
| **Grafana** | Add annotation: tags=["build","failure","ci","alert"], text="CI build FAILED: [appName]" |

#### Deployment Triggered (CD Trigger)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to linked task: "Deployment started for [appName] v[imageTag]" + Update status to "Deploying" |
| **Rocket.Chat** | Post to `#deploys`: "[appName] Deploying v[imageTag] to [environment]" |
| **Postal** | No email (routine) |
| **Grafana** | Add annotation: tags=["deploy","started","cd"], text="Deploy started: [appName] v[imageTag]" |

#### Deployment Success (CD Success)

| Target | Action |
|--------|--------|
| **ClickUp** | Update linked task status to "Complete". Add comment: "Deployed [appName] v[imageTag] successfully." |
| **Rocket.Chat** | Post to `#deploys`: "[appName] v[imageTag] deployed SUCCESSFULLY to [environment]" |
| **Postal** | Send email to stakeholders IF client-visible deployment. Subject: "[appName] v[imageTag] deployed" |
| **Grafana** | Add annotation: tags=["deploy","success","cd","production"], text="Deploy success: [appName] v[imageTag]" |

#### Deployment Failure (CD Fail)

| Target | Action |
|--------|--------|
| **ClickUp** | Create new task: "INCIDENT: Deploy failed -- [appName] v[imageTag]" in Incidents list. Link to original task. Priority: Urgent. |
| **Rocket.Chat** | Post to `#deploys` AND `#incidents` with `@here`: "DEPLOY FAILED: [appName] v[imageTag]. Rollback may be required." |
| **Postal** | Send email to Wakeem immediately. Subject: "DEPLOY FAILED: [appName]". Body: deployment details, link to Devtron. |
| **Grafana** | Add annotation: tags=["deploy","failure","cd","incident"], text="DEPLOY FAILED: [appName] v[imageTag]" |

---

## 2. ArgoCD Events

### 2.1 Event Catalog

ArgoCD has a built-in notifications controller with a catalog of triggers. Configuration lives in the `argocd-notifications-cm` ConfigMap. ArgoCD can send to webhooks, Slack, email, Grafana, and more.

**Install the default catalog**:
```bash
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/notifications_catalog/install.yaml
```

Source: [ArgoCD Triggers Catalog](https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/catalog/), [ArgoCD Webhook Service](https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/services/webhook/), [ArgoCD Triggers](https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/triggers/)

#### 2.1.1 Built-in Trigger Catalog

| Trigger Name | Condition | When It Fires |
|-------------|-----------|---------------|
| `on-created` | Application resource created | New ArgoCD Application is registered |
| `on-deleted` | Application resource deleted | ArgoCD Application is removed |
| `on-deployed` | `app.status.operationState.phase in ['Succeeded'] AND app.status.health.status == 'Healthy'` | Application is synced and healthy (the "golden" deploy event) |
| `on-health-degraded` | `app.status.health.status == 'Degraded'` | Application health degrades (pods crashing, readiness failing) |
| `on-sync-failed` | `app.status.operationState.phase in ['Error', 'Failed']` | Sync operation failed |
| `on-sync-running` | `app.status.operationState.phase in ['Running']` | Sync operation started |
| `on-sync-status-unknown` | `app.status.sync.status == 'Unknown'` | Sync status becomes unknown |
| `on-sync-succeeded` | `app.status.operationState.phase in ['Succeeded']` | Sync completed (but app may not be healthy yet) |

**Custom triggers you should add**:

| Custom Trigger | Condition | Purpose |
|---------------|-----------|---------|
| `on-sync-out-of-sync` | `app.status.sync.status == 'OutOfSync'` | Detect when git state differs from cluster state |
| `on-health-missing` | `app.status.health.status == 'Missing'` | Detect when resources are missing |
| `on-health-suspended` | `app.status.health.status == 'Suspended'` | Detect suspended apps (e.g., scaled to 0) |

#### 2.1.2 ArgoCD Webhook Configuration

In `argocd-notifications-cm` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.webhook.n8n: |
    url: https://n8n.helixstax.com/webhook/argocd-events
    headers:
      - name: Content-Type
        value: application/json
      - name: X-Webhook-Secret
        value: $webhook-secret
    insecureSkipVerify: false

  template.n8n-notification: |
    webhook:
      n8n:
        method: POST
        body: |
          {
            "source": "argocd",
            "trigger": "{{.trigger}}",
            "app": {
              "name": "{{.app.metadata.name}}",
              "namespace": "{{.app.spec.destination.namespace}}",
              "project": "{{.app.spec.project}}",
              "repoURL": "{{.app.spec.source.repoURL}}",
              "targetRevision": "{{.app.spec.source.targetRevision}}",
              "syncStatus": "{{.app.status.sync.status}}",
              "healthStatus": "{{.app.status.health.status}}",
              "operationPhase": "{{.app.status.operationState.phase}}"
            },
            "timestamp": "{{.app.status.operationState.finishedAt}}"
          }

  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
      oncePer: app.status.operationState.syncResult.revision
      send: [n8n-notification]

  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [n8n-notification]

  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [n8n-notification]

  trigger.on-sync-running: |
    - when: app.status.operationState.phase in ['Running']
      oncePer: app.status.operationState.syncResult.revision
      send: [n8n-notification]

  trigger.on-created: |
    - oncePer: app.metadata.name
      send: [n8n-notification]

  trigger.on-deleted: |
    - oncePer: app.metadata.name
      send: [n8n-notification]

  trigger.on-sync-status-unknown: |
    - when: app.status.sync.status == 'Unknown'
      send: [n8n-notification]
```

**Application annotation to subscribe**:
```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-deployed.n8n: ""
    notifications.argoproj.io/subscribe.on-sync-failed.n8n: ""
    notifications.argoproj.io/subscribe.on-health-degraded.n8n: ""
    notifications.argoproj.io/subscribe.on-sync-running.n8n: ""
    notifications.argoproj.io/subscribe.on-created.n8n: ""
    notifications.argoproj.io/subscribe.on-deleted.n8n: ""
    notifications.argoproj.io/subscribe.on-sync-status-unknown.n8n: ""
```

**Retry configuration**: ArgoCD webhook service supports `retryMax` (default: 3), `retryWaitMin` (default: 1s), `retryWaitMax` (default: 5s). These are configured at the service level.

### 2.2 ArgoCD Event Automation Matrix

#### Application Synced Successfully (on-deployed)

| Target | Action |
|--------|--------|
| **ClickUp** | Update task status to "Complete". Add comment: "ArgoCD deployed [appName] revision [rev] -- healthy and synced." |
| **Rocket.Chat** | Post to `#deploys`: "[appName] DEPLOYED and HEALTHY. Revision: [rev]. Namespace: [namespace]." |
| **Postal** | Email to stakeholders IF client-visible. Subject: "[appName] deployed successfully." |
| **Grafana** | Annotation: tags=["deploy","argocd","healthy","production"], text="ArgoCD deployed: [appName] rev [rev]" |

#### Sync Failed (on-sync-failed)

| Target | Action |
|--------|--------|
| **ClickUp** | Create incident task: "SYNC FAILED: [appName]". Priority: Urgent. Add error details in description. |
| **Rocket.Chat** | Post to `#deploys` AND `#incidents` with `@here`: "SYNC FAILED: [appName]. Phase: [phase]. Check ArgoCD." |
| **Postal** | Email to Wakeem. Subject: "ArgoCD Sync Failed: [appName]". Include operation details. |
| **Grafana** | Annotation: tags=["sync","failed","argocd","incident"], text="ArgoCD sync FAILED: [appName]" |

#### Health Degraded (on-health-degraded)

| Target | Action |
|--------|--------|
| **ClickUp** | Create task: "Health Degraded: [appName]" in Incidents list. Priority: High. |
| **Rocket.Chat** | Post to `#incidents` with `@here`: "HEALTH DEGRADED: [appName]. Pods may be crashing." |
| **Postal** | Email to Wakeem. Subject: "App Health Degraded: [appName]". |
| **Grafana** | Annotation: tags=["health","degraded","argocd","alert"], text="Health degraded: [appName]" |

#### Out of Sync Detected (on-sync-status-unknown OR custom on-sync-out-of-sync)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to app task: "Application [appName] is out of sync. Git state does not match cluster." |
| **Rocket.Chat** | Post to `#deploys`: "WARNING: [appName] is out of sync. Manual intervention may be needed." |
| **Postal** | No email (informational unless prolonged) |
| **Grafana** | Annotation: tags=["sync","outofsync","argocd"], text="Out of sync: [appName]" |

#### Application Created (on-created)

| Target | Action |
|--------|--------|
| **ClickUp** | Create task: "New ArgoCD App: [appName]" in Infrastructure list. Add repo URL, namespace details. |
| **Rocket.Chat** | Post to `#infrastructure`: "New ArgoCD application registered: [appName] in namespace [namespace]." |
| **Postal** | No email. |
| **Grafana** | Annotation: tags=["app","created","argocd"], text="New app: [appName]" |

#### Application Deleted (on-deleted)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to app task: "ArgoCD application [appName] has been DELETED." Update task status. |
| **Rocket.Chat** | Post to `#infrastructure`: "ArgoCD application DELETED: [appName]." |
| **Postal** | Email to Wakeem (deletion is significant). Subject: "ArgoCD App Deleted: [appName]". |
| **Grafana** | Annotation: tags=["app","deleted","argocd"], text="App deleted: [appName]" |

#### Sync Running (on-sync-running)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment: "Sync in progress for [appName]..." |
| **Rocket.Chat** | Post to `#deploys`: "[appName] sync in progress..." |
| **Postal** | No email. |
| **Grafana** | Annotation: tags=["sync","running","argocd"], text="Sync started: [appName]" |

#### Rollback Triggered

ArgoCD does not have a dedicated "rollback" trigger. A rollback is just another sync to a previous revision. To detect rollbacks:

**Strategy**: Compare the target revision in `on-sync-running` with the previous revision. If the new revision is older than the current one, it is a rollback. This requires n8n to maintain state (store last-deployed revision per app in a database or n8n's static data).

**Alternative**: Use the `oncePer` field. If the same revision appears in consecutive syncs after a failure, it may indicate a rollback.

| Target | Action (when rollback detected) |
|--------|--------|
| **ClickUp** | Create incident task: "ROLLBACK: [appName] rolled back from [oldRev] to [newRev]". Priority: High. |
| **Rocket.Chat** | Post to `#incidents` with `@here`: "ROLLBACK EXECUTED: [appName] reverted to [newRev]." |
| **Postal** | Email to Wakeem. Subject: "Rollback Executed: [appName]". |
| **Grafana** | Annotation: tags=["rollback","argocd","incident"], text="Rollback: [appName] to [rev]" |

---

## 3. Harbor Events

### 3.1 Event Catalog

Harbor supports 10 webhook event types, configurable per project. Payloads can be sent in **Default** or **CloudEvents** format. For n8n, use **Default** format (simpler to parse).

Source: [Harbor Webhook Configuration](https://goharbor.io/docs/main/working-with-projects/project-configuration/configure-webhooks/)

| Event Type | When It Fires | Key Payload Fields |
|------------|---------------|-------------------|
| `PUSH_ARTIFACT` | Image pushed to registry | `type`, `occur_at`, `operator`, `event_data.resources[].tag`, `event_data.resources[].digest`, `event_data.resources[].resource_url`, `event_data.repository.name`, `event_data.repository.namespace` |
| `PULL_ARTIFACT` | Image pulled from registry | Same as PUSH_ARTIFACT |
| `DELETE_ARTIFACT` | Image deleted from registry | Same as PUSH_ARTIFACT + deletion timestamp |
| `SCANNING_COMPLETED` | Trivy scan finishes (any result) | Vulnerability counts (critical, high, medium, low), scan timestamp, artifact details |
| `SCANNING_STOPPED` | Scan manually stopped | Scan status, artifact details |
| `SCANNING_FAILED` | Scan encountered errors | Error details, artifact details |
| `QUOTA_EXCEED` | Project storage quota exceeded | Storage usage details, project info |
| `QUOTA_WARNING` | Quota at 85% threshold | Current usage percentage, project info |
| `REPLICATION` | Replication status changes | Source/destination registry, replication results |
| `TAG_RETENTION` | Tag retention policy executed | Retained/deleted artifact counts, policy rules |

**Harbor Default Payload Structure**:
```json
{
  "type": "PUSH_ARTIFACT",
  "occur_at": 1679900000,
  "operator": "admin",
  "event_data": {
    "resources": [
      {
        "digest": "sha256:abc123...",
        "tag": "v1.2.3",
        "resource_url": "harbor.helixstax.com/helix/myapp:v1.2.3"
      }
    ],
    "repository": {
      "date_created": 1679800000,
      "name": "myapp",
      "namespace": "helix",
      "repo_full_name": "helix/myapp",
      "repo_type": "private"
    }
  }
}
```

**Harbor Webhook Configuration**:
- Navigate to Project -> Configuration -> Webhooks
- Add endpoint: `https://n8n.helixstax.com/webhook/harbor-events`
- Select events to subscribe to (select ALL for comprehensive automation)
- Payload format: Default
- Enable HTTPS certificate verification

### 3.2 Harbor Event Automation Matrix

#### Image Pushed (PUSH_ARTIFACT)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to linked task: "Image pushed to Harbor: [namespace]/[name]:[tag]" |
| **Rocket.Chat** | Post to `#ci-builds`: "Image pushed: [namespace]/[name]:[tag] by [operator]" |
| **Postal** | No email (routine). |
| **Grafana** | Annotation: tags=["harbor","push","image"], text="Image pushed: [repoFullName]:[tag]" |

#### Image Pulled (PULL_ARTIFACT)

| Target | Action |
|--------|--------|
| **ClickUp** | No action (too noisy -- every deploy pulls). |
| **Rocket.Chat** | No action (too noisy). |
| **Postal** | No email. |
| **Grafana** | No annotation (use only for audit log queries via Harbor API). |

**Exception**: If image is pulled by an unknown/unexpected operator, flag it as a security event.

#### Image Deleted (DELETE_ARTIFACT)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to infrastructure task: "Image deleted from Harbor: [namespace]/[name]:[tag]" |
| **Rocket.Chat** | Post to `#infrastructure`: "Image deleted: [namespace]/[name]:[tag] by [operator]" |
| **Postal** | No email unless manual deletion of production image. |
| **Grafana** | Annotation: tags=["harbor","delete","image"], text="Image deleted: [repoFullName]:[tag]" |

#### Scan Complete -- Clean (SCANNING_COMPLETED, critical=0, high=0)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment: "Trivy scan CLEAN for [namespace]/[name]:[tag]. No critical or high vulnerabilities." |
| **Rocket.Chat** | Post to `#security`: "[namespace]/[name]:[tag] scan CLEAN." |
| **Postal** | No email. |
| **Grafana** | Annotation: tags=["trivy","scan","clean","security"], text="Scan clean: [repoFullName]:[tag]" |

#### Scan Found CRITICAL CVEs (SCANNING_COMPLETED, critical > 0)

| Target | Action |
|--------|--------|
| **ClickUp** | Create task: "SECURITY: Critical CVEs in [namespace]/[name]:[tag]". Priority: Urgent. List: Security Advisories. Add CVE count in description. |
| **Rocket.Chat** | Post to `#security` AND `#incidents` with `@here`: "CRITICAL VULNERABILITY: [count] critical CVEs found in [namespace]/[name]:[tag]. DEPLOYMENT SHOULD BE BLOCKED." |
| **Postal** | Email to Wakeem immediately. Subject: "CRITICAL CVEs: [namespace]/[name]:[tag]". Body: CVE count, link to Harbor scan results. |
| **Grafana** | Annotation: tags=["trivy","scan","critical","security","incident"], text="CRITICAL CVEs: [repoFullName]:[tag] ([count] critical)" |

#### Scan Found HIGH CVEs (SCANNING_COMPLETED, critical=0, high > 0)

| Target | Action |
|--------|--------|
| **ClickUp** | Create task: "Security: High CVEs in [namespace]/[name]:[tag]". Priority: High. Add note: "Manual approval required before deploy." |
| **Rocket.Chat** | Post to `#security`: "HIGH VULNERABILITY: [count] high CVEs in [namespace]/[name]:[tag]. Manual approval required." |
| **Postal** | Email to Wakeem. Subject: "High CVEs: [namespace]/[name]:[tag] -- approval needed". |
| **Grafana** | Annotation: tags=["trivy","scan","high","security"], text="High CVEs: [repoFullName]:[tag] ([count] high)" |

#### Scan Failed (SCANNING_FAILED)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment: "Trivy scan FAILED for [namespace]/[name]:[tag]. Error: [details]." |
| **Rocket.Chat** | Post to `#security`: "Scan FAILED for [namespace]/[name]:[tag]. Manual scan may be needed." |
| **Postal** | No email (operational issue, not security event). |
| **Grafana** | Annotation: tags=["trivy","scan","failed"], text="Scan failed: [repoFullName]:[tag]" |

#### Quota Exceeded (QUOTA_EXCEED)

| Target | Action |
|--------|--------|
| **ClickUp** | Create task: "Harbor Quota Exceeded: [project]". Priority: High. Assign to Kit (DevOps). |
| **Rocket.Chat** | Post to `#infrastructure` with `@here`: "Harbor quota EXCEEDED for project [project]. Image pushes may fail." |
| **Postal** | Email to Wakeem. Subject: "Harbor Storage Quota Exceeded". |
| **Grafana** | Annotation: tags=["harbor","quota","exceeded","alert"], text="Quota exceeded: [project]" |

#### Quota Warning (QUOTA_WARNING)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to Infrastructure task: "Harbor quota at [percentage]% for project [project]." |
| **Rocket.Chat** | Post to `#infrastructure`: "Harbor quota warning: [project] at [percentage]% capacity." |
| **Postal** | No email. |
| **Grafana** | Annotation: tags=["harbor","quota","warning"], text="Quota warning: [project] at [percentage]%" |

#### Replication Completed (REPLICATION)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment: "Harbor replication complete: [source] -> [destination]. [count] artifacts replicated." |
| **Rocket.Chat** | Post to `#infrastructure`: "Replication complete: [source] -> [destination]." |
| **Postal** | No email. |
| **Grafana** | Annotation: tags=["harbor","replication"], text="Replication: [source] -> [destination]" |

#### Tag Retention Executed (TAG_RETENTION)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment: "Tag retention ran on [project]. Retained: [count]. Deleted: [count]." |
| **Rocket.Chat** | Post to `#infrastructure`: "Tag retention executed on [project]. [deleted] artifacts cleaned up." |
| **Postal** | No email. |
| **Grafana** | Annotation: tags=["harbor","retention","cleanup"], text="Tag retention: [project] -- [deleted] removed" |

#### Scan Stopped (SCANNING_STOPPED)

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment: "Scan stopped for [namespace]/[name]:[tag]." |
| **Rocket.Chat** | Post to `#security`: "Scan stopped for [namespace]/[name]:[tag]. Was it intentional?" |
| **Postal** | No email. |
| **Grafana** | No annotation. |

---

## 4. GitHub Events

### 4.1 Event Catalog

GitHub webhook events are configured per repository. The relevant events for CI/CD automation:

| GitHub Event | Webhook Event Type | Key Payload Fields |
|-------------|-------------------|-------------------|
| PR opened | `pull_request` (action: `opened`) | `pull_request.title`, `pull_request.html_url`, `pull_request.user.login`, `pull_request.head.ref` |
| PR merged | `pull_request` (action: `closed`, `merged: true`) | Same + `pull_request.merge_commit_sha` |
| PR review requested | `pull_request` (action: `review_requested`) | `requested_reviewer.login` |
| PR review approved | `pull_request_review` (action: `submitted`, state: `approved`) | `review.user.login`, `review.body` |
| PR checks failed | `check_suite` (action: `completed`, conclusion: `failure`) | `check_suite.head_sha`, `check_suite.app.name` |
| Issue created | `issues` (action: `opened`) | `issue.title`, `issue.body`, `issue.html_url`, `issue.labels` |
| Release published | `release` (action: `published`) | `release.tag_name`, `release.name`, `release.body`, `release.html_url` |
| Push to main | `push` (ref: `refs/heads/main`) | `commits[]`, `pusher.name`, `head_commit.message` |
| Push to any branch | `push` | `ref`, `commits[]`, `pusher.name` |

### 4.2 GitHub Event Automation Matrix

#### PR Opened

| Target | Action |
|--------|--------|
| **ClickUp** | Find linked task (from branch name convention `feature/CU-[taskId]-description`). Update status to "In Review". Add comment with PR link. |
| **Rocket.Chat** | Post to `#code-review`: "PR opened: [title] by [user]. [PR URL]. Please review." |
| **Postal** | No email. |
| **Grafana** | No annotation. |

#### PR Merged

| Target | Action |
|--------|--------|
| **ClickUp** | Update linked task to "Complete". Add comment: "PR merged. Merge SHA: [sha]. ArgoCD will sync shortly." |
| **Rocket.Chat** | Post to `#code-review`: "PR MERGED: [title] by [user]." Post to `#deploys`: "Merge to main -- ArgoCD sync expected for affected apps." |
| **Postal** | No email (deploy notification comes from ArgoCD success). |
| **Grafana** | Annotation: tags=["github","merge","pr"], text="PR merged: [title]" |

#### PR Review Requested

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment: "Review requested from [reviewer]." |
| **Rocket.Chat** | DM to reviewer via Rocket.Chat: "You have been requested to review: [PR title] [PR URL]." |
| **Postal** | No email (Rocket.Chat DM suffices). |
| **Grafana** | No annotation. |

#### PR Review Approved

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment: "Approved by [reviewer]: [review body snippet]." |
| **Rocket.Chat** | Post to `#code-review`: "[PR title] approved by [reviewer]." |
| **Postal** | No email. |
| **Grafana** | No annotation. |

#### PR Checks Failed

| Target | Action |
|--------|--------|
| **ClickUp** | Add comment to linked task: "CI checks FAILED for PR [title]. Check [check suite URL]." Update status to "Blocked". |
| **Rocket.Chat** | Post to `#ci-builds` with `@here`: "CI checks FAILED on PR: [title]. Commit: [sha]." |
| **Postal** | No email (Rocket.Chat alert suffices). |
| **Grafana** | Annotation: tags=["github","checks","failed","ci"], text="Checks failed: [pr title]" |

#### Issue Created

| Target | Action |
|--------|--------|
| **ClickUp** | Create new task in appropriate list (map GitHub labels to ClickUp lists). Title: "[issue title]". Description: "[issue body]". Link: "[issue URL]". |
| **Rocket.Chat** | Post to `#development`: "New GitHub issue: [title] [URL]." |
| **Postal** | No email. |
| **Grafana** | No annotation. |

#### Release Published

| Target | Action |
|--------|--------|
| **ClickUp** | Create task: "Release Notes: [tag_name]" in Marketing/Communications list. Add release body. |
| **Rocket.Chat** | Post to `#general`: "Release [tag_name] published: [name]. [URL]." |
| **Postal** | Email to stakeholder list. Subject: "[appName] [tag_name] Released". Body: release notes. |
| **Grafana** | Annotation: tags=["release","github"], text="Release: [tag_name]" |

#### Push to Main (Direct or Fast-Forward Merge)

| Target | Action |
|--------|--------|
| **ClickUp** | No action (merge via PR is preferred; direct pushes get flagged). |
| **Rocket.Chat** | Post to `#code-review`: "Direct push to main by [pusher]: [commit message]. Was this intentional?" |
| **Postal** | No email. |
| **Grafana** | Annotation: tags=["github","push","main"], text="Push to main: [commit message]" |

---

## 5. Full CI/CD Event Chain

This maps the ENTIRE flow from code push to production deploy with every automation at each step.

```
DEVELOPER PUSHES CODE TO GITHUB
|
+---> [GitHub Webhook: push] ---> n8n
|     |
|     +---> n8n: Parse branch name for ClickUp task ID
|     +---> n8n: IF push to feature branch
|     |     +---> Rocket.Chat #development: "New commits on [branch] by [author]"
|     |
|     +---> n8n: IF push to main (direct push, not PR merge)
|           +---> Rocket.Chat #code-review: "WARNING: Direct push to main by [author]"
|
+---> [GitHub Webhook: pull_request opened] ---> n8n
|     |
|     +---> n8n: Extract ClickUp task ID from branch name
|     +---> ClickUp: Update task status -> "In Review"
|     +---> ClickUp: Add comment with PR link
|     +---> Rocket.Chat #code-review: "PR opened: [title] by [author] [URL]"
|
+---> [GitHub Actions CI starts automatically]
|     |
|     +---> Gitleaks scans for secrets
|     |     |
|     |     +---> IF SECRETS FOUND:
|     |     |     +---> GitHub: Fail the check
|     |     |     +---> [GitHub Webhook: check_suite failed] ---> n8n
|     |     |           +---> ClickUp: Create task "SECURITY INCIDENT: Secrets found in [repo]:[branch]"
|     |     |                 Priority: Urgent. List: Security Incidents.
|     |     |           +---> Rocket.Chat #security with @here: "SECRETS DETECTED in [repo]:[branch]"
|     |     |           +---> Postal: Email to Wakeem "SECRET EXPOSURE: [repo]"
|     |     |           +---> Grafana: Annotation tags=["security","gitleaks","incident"]
|     |     |
|     |     +---> IF CLEAN: continue
|     |
|     +---> Run tests (unit, lint, type-check)
|     |     |
|     |     +---> IF FAIL:
|     |     |     +---> [GitHub Webhook: check_suite failed] ---> n8n
|     |     |           +---> ClickUp: Comment "Tests failed: [details]" + status "Blocked"
|     |     |           +---> Rocket.Chat #ci-builds: "Tests FAILED on [branch]"
|     |     |
|     |     +---> IF PASS: continue
|     |
|     +---> Build Docker image
|     +---> Push image to Harbor
|     |     (triggers Harbor PUSH_ARTIFACT webhook -- see below)
|     |
|     +---> Syft generates SBOM
|     |     +---> n8n: Archive SBOM to MinIO bucket (via MinIO S3 API)
|     |     +---> ClickUp: Comment "SBOM generated for [image]:[tag]"
|     |
|     +---> Cosign signs image
|           +---> ClickUp: Comment "Image signed: [image]:[tag]"
|
+---> [Harbor Webhook: PUSH_ARTIFACT] ---> n8n
|     |
|     +---> ClickUp: Comment "Image pushed to Harbor: [repo]:[tag]"
|     +---> Rocket.Chat #ci-builds: "Image pushed: [repo]:[tag]"
|     +---> Grafana: Annotation tags=["harbor","push"]
|
+---> [Harbor auto-scan triggers Trivy]
|     |
|     +---> [Harbor Webhook: SCANNING_COMPLETED] ---> n8n
|           |
|           +---> n8n: Parse vulnerability counts
|           |
|           +---> IF CRITICAL CVEs (critical > 0):
|           |     +---> ClickUp: Create "SECURITY: Critical CVEs in [image]:[tag]"
|           |           Priority: Urgent. List: Security Advisories.
|           |     +---> Rocket.Chat #security with @here: "CRITICAL CVEs in [image]:[tag]"
|           |     +---> Postal: Email to Wakeem "CRITICAL CVEs FOUND"
|           |     +---> Grafana: Annotation tags=["trivy","critical","block"]
|           |     +---> n8n: SET FLAG -- block deployment (store in n8n static data or Redis)
|           |
|           +---> IF HIGH CVEs ONLY (critical=0, high > 0):
|           |     +---> ClickUp: Create task "High CVEs in [image]:[tag] -- approval needed"
|           |     +---> Rocket.Chat #security: "HIGH CVEs in [image]:[tag]. Manual approval required."
|           |     +---> Postal: Email to Wakeem "High CVEs -- approval needed"
|           |     +---> n8n: SET FLAG -- require manual approval before deploy
|           |
|           +---> IF CLEAN (critical=0, high=0):
|                 +---> ClickUp: Comment "Scan clean: [image]:[tag]"
|                 +---> Rocket.Chat #security: "Scan clean: [image]:[tag]"
|                 +---> n8n: CLEAR any block flags
|
+---> [PR Merged to main]
|     |
|     +---> [GitHub Webhook: pull_request closed+merged] ---> n8n
|           +---> ClickUp: Update task -> "Complete"
|           +---> Rocket.Chat #code-review: "PR merged: [title]"
|           +---> Grafana: Annotation tags=["merge","pr"]
|
+---> [Devtron CI triggers on merge (if configured)]
|     |
|     +---> [Devtron Webhook: CI trigger] ---> n8n
|     |     +---> ClickUp: Comment "Devtron CI started for [app]"
|     |     +---> Grafana: Annotation tags=["devtron","ci","started"]
|     |
|     +---> [Devtron Webhook: CI success] ---> n8n
|     |     +---> ClickUp: Comment "Devtron CI passed: [app]:[tag]"
|     |     +---> Rocket.Chat #ci-builds: "Devtron CI passed: [app]:[tag]"
|     |
|     +---> [Devtron Webhook: CI fail] ---> n8n
|           +---> ClickUp: Comment "Devtron CI FAILED" + status "Blocked"
|           +---> Rocket.Chat #ci-builds with @here: "Devtron CI FAILED: [app]"
|           +---> Postal: Email to Wakeem
|
+---> [ArgoCD detects new image/manifests]
|     |
|     +---> [ArgoCD: on-sync-running] ---> n8n
|     |     +---> n8n: CHECK -- is this image blocked by Trivy scan?
|     |     |     +---> IF BLOCKED:
|     |     |           +---> n8n: Call ArgoCD API to abort sync (if possible)
|     |     |           +---> ClickUp: Comment "Deploy BLOCKED by security scan"
|     |     |           +---> Rocket.Chat #deploys: "Deploy BLOCKED for [app] -- critical CVEs"
|     |     |
|     |     +---> ClickUp: Comment "Sync in progress: [app]"
|     |     +---> Rocket.Chat #deploys: "[app] sync started..."
|     |     +---> Grafana: Annotation tags=["argocd","sync","running"]
|     |
|     +---> [Kyverno validates admission policies]
|     |     |
|     |     +---> IF POLICY VIOLATION:
|     |     |     (ArgoCD sync will fail, triggering on-sync-failed)
|     |     |     +---> ClickUp: Comment "Policy violation: [details]"
|     |     |     +---> Rocket.Chat #security: "Kyverno policy violation for [app]"
|     |     |
|     |     +---> IF PASS: continue
|     |
|     +---> [ArgoCD: on-deployed (sync succeeded + healthy)] ---> n8n
|     |     |
|     |     +---> ClickUp: Update task -> "Complete"
|     |     +---> ClickUp: Comment "Deployed: [app] revision [rev]"
|     |     +---> Rocket.Chat #deploys: "[app] v[tag] DEPLOYED and HEALTHY"
|     |     +---> Grafana: Annotation tags=["deploy","success","production"]
|     |     +---> Postal: IF client-visible -> email stakeholders "[app] deployed"
|     |
|     +---> [ArgoCD: on-sync-failed] ---> n8n
|           |
|           +---> n8n: Trigger auto-rollback? (configurable per app)
|           |     +---> IF auto-rollback enabled:
|           |           +---> n8n: Call ArgoCD API to sync to previous known-good revision
|           |           +---> ClickUp: Create incident "Deploy failed + rollback: [app]"
|           |           +---> Rocket.Chat #incidents: "DEPLOY FAILED. Auto-rollback initiated for [app]."
|           |           +---> Postal: Email Wakeem "Deploy failed, rollback executed for [app]"
|           |
|           +---> IF no auto-rollback:
|                 +---> ClickUp: Create incident "DEPLOY FAILED: [app]"
|                 +---> Rocket.Chat #incidents with @here: "DEPLOY FAILED: [app]. Manual intervention needed."
|                 +---> Postal: Email Wakeem "DEPLOY FAILED: [app]"
|                 +---> Grafana: Annotation tags=["deploy","failed","incident"]
|
+---> [Post-deploy health check (Prometheus/Grafana)]
      |
      +---> Prometheus monitors pod health after deploy
      |
      +---> IF UNHEALTHY after 5 minutes:
      |     |
      |     +---> [ArgoCD: on-health-degraded] ---> n8n
      |           +---> n8n: Check if this app has auto-rollback enabled
      |           +---> IF auto-rollback:
      |           |     +---> n8n: Call ArgoCD API to rollback
      |           |     +---> ClickUp: Create incident "Post-deploy health failure + rollback: [app]"
      |           |     +---> Rocket.Chat #incidents: "POST-DEPLOY FAILURE: [app] health degraded. Rollback initiated."
      |           |     +---> Postal: Email Wakeem
      |           |
      |           +---> IF no auto-rollback:
      |                 +---> ClickUp: Create incident "Post-deploy health failure: [app]"
      |                 +---> Rocket.Chat #incidents with @here: "POST-DEPLOY FAILURE: [app] health degraded."
      |                 +---> Postal: Email Wakeem
      |
      +---> IF HEALTHY after 5 minutes:
            +---> (No action needed -- on-deployed already fired)
```

---

## 6. n8n Workflow Designs

### 6.1 Master Workflow Architecture

Rather than one monolithic workflow, use a **hub-and-spoke** pattern:

```
[Webhook Receiver Workflows]     [Router Workflow]     [Action Workflows]

GitHub Webhook ----+                                +--- ClickUp Actions
Harbor Webhook ----+---> Central Event Router ---+--- Rocket.Chat Actions
ArgoCD Webhook ----+         (n8n)              +--- Postal Actions
Devtron Webhook ---+                            +--- Grafana Actions
                                                +--- MinIO Actions
```

**Why hub-and-spoke**:
- Each webhook receiver is a separate n8n workflow (isolates failures)
- Central router normalizes events into a standard schema
- Action workflows are reusable (one ClickUp workflow handles all event sources)
- Easier debugging -- each workflow has a single responsibility

### 6.2 Workflow 1: GitHub Webhook Receiver

**Trigger**: Webhook node (POST) at `/webhook/github-events`
**Authentication**: Verify GitHub webhook signature (HMAC-SHA256 with secret)

```
Webhook (POST /webhook/github-events)
  |
  +-> Verify Signature (Function node: validate X-Hub-Signature-256)
  |   +-> IF invalid: Respond 401, stop
  |
  +-> Switch node on event type (X-GitHub-Event header)
  |
  +-> Branch: pull_request
  |   +-> Switch on action: opened / closed / review_requested
  |   +-> IF opened: Extract task ID from branch name
  |   |   +-> HTTP Request: POST to Router Workflow webhook
  |   |     Body: { source: "github", event: "pr_opened", taskId, prUrl, author, title }
  |   +-> IF closed+merged:
  |   |   +-> HTTP Request: POST to Router { source: "github", event: "pr_merged", ... }
  |   +-> IF review_requested:
  |       +-> HTTP Request: POST to Router { source: "github", event: "review_requested", reviewer, ... }
  |
  +-> Branch: pull_request_review
  |   +-> IF approved:
  |       +-> HTTP Request: POST to Router { source: "github", event: "pr_approved", reviewer, ... }
  |
  +-> Branch: check_suite
  |   +-> IF completed + failure:
  |       +-> HTTP Request: POST to Router { source: "github", event: "checks_failed", ... }
  |
  +-> Branch: issues
  |   +-> IF opened:
  |       +-> HTTP Request: POST to Router { source: "github", event: "issue_created", title, body, labels, ... }
  |
  +-> Branch: release
  |   +-> IF published:
  |       +-> HTTP Request: POST to Router { source: "github", event: "release_published", tag, name, body, ... }
  |
  +-> Branch: push
      +-> IF ref == refs/heads/main:
          +-> HTTP Request: POST to Router { source: "github", event: "push_to_main", ... }
```

### 6.3 Workflow 2: Harbor Webhook Receiver

**Trigger**: Webhook node (POST) at `/webhook/harbor-events`

```
Webhook (POST /webhook/harbor-events)
  |
  +-> Switch node on $.body.type
  |
  +-> Branch: PUSH_ARTIFACT
  |   +-> HTTP Request: POST to Router
  |     { source: "harbor", event: "image_pushed", repo, tag, digest, operator }
  |
  +-> Branch: SCANNING_COMPLETED
  |   +-> Function node: Parse vulnerability counts from event_data
  |   +-> Switch on severity:
  |       +-> critical > 0: POST to Router { event: "scan_critical", ... }
  |       +-> high > 0 (no critical): POST to Router { event: "scan_high", ... }
  |       +-> clean: POST to Router { event: "scan_clean", ... }
  |
  +-> Branch: SCANNING_FAILED
  |   +-> POST to Router { source: "harbor", event: "scan_failed", ... }
  |
  +-> Branch: QUOTA_EXCEED
  |   +-> POST to Router { source: "harbor", event: "quota_exceeded", project, ... }
  |
  +-> Branch: QUOTA_WARNING
  |   +-> POST to Router { source: "harbor", event: "quota_warning", project, percentage, ... }
  |
  +-> Branch: DELETE_ARTIFACT
  |   +-> POST to Router { source: "harbor", event: "image_deleted", ... }
  |
  +-> Branch: REPLICATION
  |   +-> POST to Router { source: "harbor", event: "replication_complete", ... }
  |
  +-> Branch: TAG_RETENTION
  |   +-> POST to Router { source: "harbor", event: "tag_retention", ... }
  |
  +-> Branch: SCANNING_STOPPED
      +-> POST to Router { source: "harbor", event: "scan_stopped", ... }
```

### 6.4 Workflow 3: ArgoCD Webhook Receiver

**Trigger**: Webhook node (POST) at `/webhook/argocd-events`
**Authentication**: Verify X-Webhook-Secret header

```
Webhook (POST /webhook/argocd-events)
  |
  +-> Verify Secret (compare X-Webhook-Secret header)
  |
  +-> Extract: trigger, app.name, app.namespace, syncStatus, healthStatus, operationPhase
  |
  +-> Switch on $.body.trigger
  |
  +-> Branch: on-deployed
  |   +-> POST to Router { source: "argocd", event: "deployed", app, namespace, revision, ... }
  |
  +-> Branch: on-sync-failed
  |   +-> POST to Router { source: "argocd", event: "sync_failed", app, namespace, phase, ... }
  |
  +-> Branch: on-health-degraded
  |   +-> POST to Router { source: "argocd", event: "health_degraded", app, namespace, ... }
  |
  +-> Branch: on-sync-running
  |   +-> POST to Router { source: "argocd", event: "sync_running", app, namespace, revision, ... }
  |
  +-> Branch: on-created
  |   +-> POST to Router { source: "argocd", event: "app_created", app, namespace, repoURL, ... }
  |
  +-> Branch: on-deleted
  |   +-> POST to Router { source: "argocd", event: "app_deleted", app, ... }
  |
  +-> Branch: on-sync-status-unknown
      +-> POST to Router { source: "argocd", event: "sync_unknown", app, ... }
```

### 6.5 Workflow 4: Devtron Webhook Receiver

**Trigger**: Webhook node (POST) at `/webhook/devtron-events`

```
Webhook (POST /webhook/devtron-events)
  |
  +-> Extract: devtronAppName, eventType, devtronContainerImageRepo,
  |   devtronContainerImageTag, devtronTriggeredByEmail
  |
  +-> Function node: Determine if CI or CD event (from pipeline context or URL path)
  |
  +-> Switch on eventType + pipeline type
  |
  +-> Branch: CI trigger
  |   +-> POST to Router { source: "devtron", event: "ci_started", app, triggeredBy, ... }
  |
  +-> Branch: CI success
  |   +-> POST to Router { source: "devtron", event: "ci_success", app, imageRepo, imageTag, ... }
  |
  +-> Branch: CI fail
  |   +-> POST to Router { source: "devtron", event: "ci_failed", app, triggeredBy, ... }
  |
  +-> Branch: CD trigger
  |   +-> POST to Router { source: "devtron", event: "cd_started", app, imageTag, ... }
  |
  +-> Branch: CD success
  |   +-> POST to Router { source: "devtron", event: "cd_success", app, imageTag, ... }
  |
  +-> Branch: CD fail
      +-> POST to Router { source: "devtron", event: "cd_failed", app, imageTag, ... }
```

### 6.6 Workflow 5: Central Event Router

**Trigger**: Webhook node (POST) at `/webhook/route-event` (internal only)

This is the brain. It receives normalized events from all receivers and routes to action workflows.

```
Webhook (POST /webhook/route-event)
  |
  +-> Function node: Deduplication check
  |   - Generate event fingerprint: hash(source + event + app + timestamp_rounded_to_minute)
  |   - Check n8n static data for recent fingerprints
  |   - IF duplicate: log and stop
  |   - ELSE: store fingerprint with TTL (5 minutes)
  |
  +-> Function node: Rate limiting / alert batching
  |   - Check n8n static data for recent alerts from same source+app
  |   - IF more than 5 alerts in last 10 minutes for same app:
  |     - Batch into single alert: "[app] has [N] events in last 10 min"
  |     - Skip individual notifications
  |   - ELSE: proceed normally
  |
  +-> Function node: Severity classification
  |   - Map event to severity: critical / high / medium / low / info
  |   - critical: scan_critical, deploy_failed + health_degraded, secret_exposure
  |   - high: scan_high, ci_failed, sync_failed, quota_exceeded
  |   - medium: health_degraded (alone), quota_warning, scan_failed
  |   - low: deploy_started, ci_started, image_pushed
  |   - info: pr_opened, pr_merged, pr_approved, scan_clean
  |
  +-> Parallel branch: ClickUp Actions
  |   +-> HTTP Request: POST to ClickUp Action Workflow
  |     { event, severity, app, details, taskAction: "comment|create|update_status" }
  |
  +-> Parallel branch: Rocket.Chat Actions
  |   +-> HTTP Request: POST to Rocket.Chat Action Workflow
  |     { event, severity, channel, message, mentionHere: true/false }
  |
  +-> Parallel branch: Postal Actions (only for critical/high severity)
  |   +-> IF severity in [critical, high]:
  |       +-> HTTP Request: POST to Postal Action Workflow
  |         { event, severity, recipient: "admin@helixstax.com", subject, body }
  |
  +-> Parallel branch: Grafana Actions
      +-> HTTP Request: POST to Grafana Action Workflow
        { event, tags, text, dashboardUID }
```

### 6.7 Workflow 6: ClickUp Action Workflow

**Trigger**: Webhook node (POST) at `/webhook/action-clickup` (internal only)

```
Webhook (POST /webhook/action-clickup)
  |
  +-> Switch on taskAction
  |
  +-> Branch: comment
  |   +-> Function node: Look up ClickUp task ID
  |   |   - Check incoming payload for taskId
  |   |   - IF not present: Search ClickUp API by app name / custom field
  |   |   - IF still not found: Create new task first, then comment
  |   +-> HTTP Request: POST to ClickUp API
  |     POST https://api.clickup.com/api/v2/task/{taskId}/comment
  |     Body: { comment_text: "[formatted message]" }
  |
  +-> Branch: create
  |   +-> Function node: Map event to ClickUp list
  |   |   - Security events -> Security Advisories list
  |   |   - Deploy failures -> Incidents list
  |   |   - Infrastructure events -> Infrastructure list
  |   |   - General -> Development list
  |   +-> HTTP Request: POST to ClickUp API
  |     POST https://api.clickup.com/api/v2/list/{listId}/task
  |     Body: { name, description, priority, status, custom_fields }
  |
  +-> Branch: update_status
      +-> HTTP Request: PUT to ClickUp API
        PUT https://api.clickup.com/api/v2/task/{taskId}
        Body: { status: "[new status]" }
  |
  +-> Error handler (catch all branches):
      +-> IF ClickUp API returns error:
          +-> Retry (3 attempts, exponential backoff: 2s, 4s, 8s)
          +-> IF all retries fail:
              +-> Log error to n8n execution log
              +-> POST to Dead Letter Workflow
              +-> Rocket.Chat #automation-alerts: "ClickUp API down -- events being queued"
```

### 6.8 Workflow 7: Rocket.Chat Action Workflow

**Trigger**: Webhook node (POST) at `/webhook/action-rocketchat` (internal only)

```
Webhook (POST /webhook/action-rocketchat)
  |
  +-> Function node: Format message based on severity
  |   - critical: Red emoji prefix, bold text, @here mention
  |   - high: Orange prefix, bold text, @here mention
  |   - medium: Yellow prefix, normal text
  |   - low/info: No prefix, normal text
  |
  +-> HTTP Request: POST to Rocket.Chat API
  |   POST https://rocketchat.helixstax.com/api/v1/chat.postMessage
  |   Headers: X-Auth-Token, X-User-Id
  |   Body: { channel: "#[channel]", text: "[formatted message]", alias: "CI/CD Bot" }
  |
  +-> Error handler:
      +-> Retry (3 attempts, 2s backoff)
      +-> IF all fail: POST to Dead Letter Workflow
```

### 6.9 Workflow 8: Postal Action Workflow

**Trigger**: Webhook node (POST) at `/webhook/action-postal` (internal only)

```
Webhook (POST /webhook/action-postal)
  |
  +-> Function node: Build email
  |   - From: noreply@helixstax.com
  |   - To: recipient (default: admin@helixstax.com)
  |   - Subject: [severity prefix] + subject
  |   - Body: HTML template with event details, links, timestamps
  |
  +-> HTTP Request: POST to Postal API
  |   POST https://postal.helixstax.com/api/v1/send/message
  |   Headers: X-Server-API-Key
  |   Body: { to, from, subject, html_body }
  |
  +-> Error handler:
      +-> Retry (3 attempts, 5s backoff)
      +-> IF all fail: POST to Dead Letter Workflow
      +-> NOTE: Email failures are critical -- if Postal is down,
      |   also try backup notification via Rocket.Chat DM to Wakeem
```

### 6.10 Workflow 9: Grafana Annotation Workflow

**Trigger**: Webhook node (POST) at `/webhook/action-grafana` (internal only)

```
Webhook (POST /webhook/action-grafana)
  |
  +-> Function node: Build annotation
  |   - time: current epoch in milliseconds
  |   - tags: from incoming payload
  |   - text: from incoming payload
  |   - dashboardUID: (optional, for dashboard-specific annotations)
  |
  +-> HTTP Request: POST to Grafana Annotations API
  |   POST https://grafana.helixstax.com/api/annotations
  |   Headers: Authorization: Bearer [GRAFANA_API_KEY]
  |   Content-Type: application/json
  |   Body: {
  |     "time": [epoch_ms],
  |     "tags": ["deploy", "argocd", "production"],
  |     "text": "Deployed myapp v1.2.3"
  |   }
  |
  +-> Error handler:
      +-> Retry (2 attempts, 1s backoff)
      +-> IF fail: Log only (annotations are nice-to-have, not critical)
```

### 6.11 Workflow 10: Dead Letter Queue Workflow

**Trigger**: Webhook node (POST) at `/webhook/dead-letter`

```
Webhook (POST /webhook/dead-letter)
  |
  +-> Function node: Log failed event
  |   - Store in n8n static data with timestamp
  |   - Include: original event, target service, error message, retry count
  |
  +-> HTTP Request: Store in MinIO (S3 API)
  |   PUT to MinIO bucket: dead-letter/[date]/[event-id].json
  |
  +-> IF first DLQ entry in last hour:
  |   +-> Rocket.Chat #automation-alerts:
  |       "Dead letter queue active -- [service] is experiencing failures"
  |
  +-> Schedule trigger (separate workflow): Every 15 minutes
      +-> Read DLQ entries from MinIO
      +-> For each entry older than 5 minutes:
          +-> Attempt to replay to original action workflow
          +-> IF success: Delete from DLQ
          +-> IF fail after 3 replays: Mark as permanently failed
              +-> Rocket.Chat: "Permanently failed event: [summary]"
```

### 6.12 Workflow 11: SBOM Archive Workflow

**Trigger**: Called by GitHub Actions CI (via n8n webhook) after Syft generates SBOM

```
Webhook (POST /webhook/sbom-archive)
  |
  +-> Receive SBOM JSON/SPDX from CI pipeline
  |
  +-> HTTP Request: PUT to MinIO S3 API
  |   Bucket: sbom-archive
  |   Key: [app]/[tag]/sbom-[timestamp].json
  |
  +-> ClickUp: Comment on linked task "SBOM archived for [app]:[tag]"
  |
  +-> IF SBOM contains known-vulnerable packages:
      +-> Rocket.Chat #security: "SBOM alert: [app]:[tag] contains [package] with known CVEs"
```

### 6.13 Normalized Event Schema

All events flowing through the router use this standard schema:

```json
{
  "id": "uuid-v4",
  "source": "github|harbor|argocd|devtron|prometheus",
  "event": "pr_opened|ci_started|image_pushed|scan_critical|deployed|...",
  "severity": "critical|high|medium|low|info",
  "timestamp": "2026-03-20T15:30:00Z",
  "app": {
    "name": "myapp",
    "namespace": "production",
    "imageTag": "v1.2.3",
    "imageRepo": "harbor.helixstax.com/helix/myapp"
  },
  "actor": {
    "name": "Wakeem",
    "email": "admin@helixstax.com"
  },
  "details": {
    "message": "Human-readable description",
    "url": "Link to relevant dashboard/PR/pipeline",
    "metadata": {}
  },
  "taskId": "CU-abc123",
  "targets": {
    "clickup": { "action": "comment|create|update_status", "taskId": "...", "listId": "..." },
    "rocketchat": { "channel": "#deploys", "mentionHere": false },
    "postal": { "send": true, "recipients": ["admin@helixstax.com"] },
    "grafana": { "tags": ["deploy","success"], "dashboardUID": "..." }
  }
}
```

---

## 7. Monitoring the Automations

### 7.1 n8n Self-Monitoring

#### Error Trigger Workflow

Every n8n workflow should have an **Error Workflow** configured in Workflow Settings.

```
Error Workflow (global):
  |
  +-> Error Trigger node (fires when ANY workflow fails)
  |
  +-> Function node: Extract error details
  |   - Workflow name
  |   - Node that failed
  |   - Error message
  |   - Execution ID
  |   - Timestamp
  |
  +-> Rocket.Chat #automation-alerts:
  |   "n8n workflow FAILED: [workflow name] at node [node]. Error: [message]. Execution: [id]"
  |
  +-> ClickUp: Create task "Automation Failed: [workflow name]"
  |   List: Infrastructure. Priority: High.
  |
  +-> IF same workflow has failed 3+ times in 1 hour:
      +-> Postal: Email Wakeem "Recurring n8n failure: [workflow name]"
```

#### Execution Log Retention

Configure n8n to retain execution data:
- **Success executions**: Keep for 7 days (for audit trail)
- **Failed executions**: Keep for 30 days (for debugging)
- **Set via**: `EXECUTIONS_DATA_PRUNE=true`, `EXECUTIONS_DATA_MAX_AGE=168` (hours for success)

### 7.2 Dead Man's Switch (n8n is Down)

If n8n itself goes down, it cannot self-alert. Use a Prometheus/Grafana-based dead man's switch:

**Strategy**: n8n sends a heartbeat to Prometheus Pushgateway every 5 minutes. If the heartbeat stops, Grafana alerting triggers directly to Postal (bypassing n8n entirely).

```
n8n Heartbeat Workflow (runs every 5 minutes via Schedule trigger):
  |
  +-> HTTP Request: POST to Prometheus Pushgateway
      POST http://pushgateway:9091/metrics/job/n8n_heartbeat
      Body: n8n_alive 1

Grafana Alert Rule:
  - Query: absent(n8n_alive{job="n8n_heartbeat"}) OR
           (time() - n8n_alive_timestamp) > 600
  - Condition: fires if n8n heartbeat missing for >10 minutes
  - Action: Grafana sends alert DIRECTLY to Postal SMTP
            (Grafana native email alerting, not through n8n)
  - Subject: "CRITICAL: n8n automation engine is DOWN"
  - Also: Grafana can send to Rocket.Chat via incoming webhook
          (direct integration, not through n8n)
```

### 7.3 Alert Fatigue Prevention

#### Batching Similar Alerts

The Central Event Router (Workflow 5) implements batching:

```
Function node: Alert batching logic

// Check static data for recent alerts
const recentAlerts = $staticData.recentAlerts || {};
const key = `${source}_${event}_${app}`;
const now = Date.now();
const WINDOW = 10 * 60 * 1000; // 10 minutes
const MAX_PER_WINDOW = 5;

// Clean old entries
for (const k in recentAlerts) {
  if (now - recentAlerts[k].lastSeen > WINDOW) {
    delete recentAlerts[k];
  }
}

// Check if we should batch
if (recentAlerts[key]) {
  recentAlerts[key].count++;
  recentAlerts[key].lastSeen = now;

  if (recentAlerts[key].count === MAX_PER_WINDOW) {
    // Send a batched summary instead
    return {
      ...event,
      message: `${app} has generated ${MAX_PER_WINDOW}+ ${event} events in the last 10 min. Suppressing individual alerts.`,
      batched: true
    };
  } else if (recentAlerts[key].count > MAX_PER_WINDOW) {
    // Suppress entirely (already sent batch notification)
    return null; // stop execution
  }
} else {
  recentAlerts[key] = { count: 1, lastSeen: now };
}

$staticData.recentAlerts = recentAlerts;
return event;
```

#### Severity-Based Routing

Not every event goes everywhere:

| Severity | ClickUp | Rocket.Chat | Postal | Grafana |
|----------|---------|-------------|--------|---------|
| critical | Create task (Urgent) | @here mention in #incidents | Email immediately | Annotation |
| high | Create task (High) | @here mention in channel | Email (batched, max 1/hour per app) | Annotation |
| medium | Comment on existing task | Post to channel | No email | Annotation |
| low | Comment on existing task | Post to channel | No email | Annotation |
| info | Comment (if task exists) | No message (log only) | No email | Optional annotation |

### 7.4 Automation Health Dashboard (Grafana)

Create a Grafana dashboard "Automation Health" with:

| Panel | Data Source | Query |
|-------|------------|-------|
| n8n Heartbeat | Prometheus | `n8n_alive{job="n8n_heartbeat"}` |
| Workflow Executions (24h) | n8n API / Prometheus | Count of executions by status |
| Failed Workflows (24h) | n8n API / Prometheus | Count of failed executions |
| Dead Letter Queue Depth | MinIO / Prometheus | Count of items in DLQ bucket |
| Webhook Response Times | Prometheus | Histogram of webhook processing time |
| Events by Source (24h) | Prometheus (custom metrics) | Count of events by source label |
| Alert Volume (24h) | Prometheus | Count of alerts sent by severity |

### 7.5 Periodic Health Check Workflow

```
Schedule Trigger (every 6 hours):
  |
  +-> HTTP Request: Test ClickUp API (GET /team)
  |   +-> IF fail: flag
  |
  +-> HTTP Request: Test Rocket.Chat API (GET /api/v1/info)
  |   +-> IF fail: flag
  |
  +-> HTTP Request: Test Postal API (health endpoint)
  |   +-> IF fail: flag
  |
  +-> HTTP Request: Test Grafana API (GET /api/health)
  |   +-> IF fail: flag
  |
  +-> IF any flags:
      +-> Rocket.Chat #automation-alerts: "Health check failed: [services]"
      +-> IF critical services (ClickUp, Rocket.Chat) down:
          +-> Postal: Email Wakeem "Automation targets down: [services]"
```

---

## 8. Risks and Gotchas

### 8.1 Devtron-Specific Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Devtron does not emit per-stage CI events** | Cannot track individual stages (test, build, push) separately | Parse Devtron API or CI logs post-hoc for stage-level detail. Or use GitHub Actions as CI with more granular events. |
| **Devtron webhook payload is minimal** | Only 5 template variables available (`devtronAppName`, `eventType`, `devtronContainerImageRepo`, `devtronContainerImageTag`, `devtronTriggeredByEmail`) | Supplement with Devtron REST API calls from n8n to get additional context (pipeline ID, environment, duration). |
| **Devtron embedded ArgoCD** | Devtron embeds its own ArgoCD instance. Configuring ArgoCD notifications directly may conflict with Devtron's management of ArgoCD. | Test carefully. Use Devtron's notification system first; only add direct ArgoCD notification config if Devtron's built-in coverage is insufficient. |
| **No rollback event from Devtron** | Cannot distinguish rollback from normal deploy | Detect rollbacks via revision comparison in ArgoCD events (see Section 2.2). |

### 8.2 ArgoCD-Specific Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **`on-deployed` can fire on Progressing** | Known issue (GitHub issue #9070): `on-deployed` sometimes triggers when health is still `Progressing` instead of `Healthy` | Use the explicit condition `app.status.operationState.phase in ['Succeeded'] AND app.status.health.status == 'Healthy'` (the catalog default). Monitor for false positives. |
| **`on-deleted` trigger is unreliable** | Known issue (GitHub issue #18203): `on-deleted` trigger result can be empty | Test extensively. Consider polling ArgoCD API as backup for detecting deletions. |
| **`oncePer` deduplication can miss events** | If `oncePer` field doesn't change between syncs, duplicate notifications may be suppressed | Choose `oncePer` field carefully. For deploys: `app.status.operationState.syncResult.revision`. For health: omit `oncePer` (health can toggle). |
| **ConfigMap size limits** | With many triggers and templates, `argocd-notifications-cm` can get large | Keep templates minimal (just send to n8n, let n8n handle formatting). |

### 8.3 Harbor-Specific Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **No image signature verification event** | Harbor does not emit a webhook for Cosign signature verification pass/fail | Handle Cosign verification in CI pipeline (GitHub Actions). Emit a custom event to n8n from the CI workflow. |
| **No robot account created/expired event** | Harbor does not webhook on robot account lifecycle | Poll Harbor API periodically from n8n for robot account status. |
| **SCANNING_COMPLETED does not distinguish severity** | The event fires for any scan completion -- you must parse the payload to determine severity | n8n Function node must parse vulnerability counts from `event_data` and classify (critical/high/clean). |
| **Harbor webhook delivery is fire-and-forget** | If n8n is down when Harbor sends a webhook, the event is lost | Harbor does have a retry mechanism (configurable). Also, run periodic reconciliation: n8n polls Harbor API for recent scan results and compares against processed events. |

### 8.4 n8n-Specific Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **n8n single point of failure** | If n8n goes down, ALL automations stop | Deploy n8n in HA mode with queue mode (requires Redis). Use Prometheus dead man's switch (Section 7.2). |
| **n8n static data is per-workflow, in-memory** | Deduplication and batching state is lost on n8n restart | Use Redis or PostgreSQL for state persistence instead of n8n static data for critical state (dedup fingerprints, blocked image flags). |
| **Webhook URL changes on n8n redeploy** | All source systems would need reconfiguration | Use a stable Traefik IngressRoute for n8n webhooks. Never use n8n's auto-generated webhook URLs. Configure a fixed path prefix: `https://n8n.helixstax.com/webhook/[fixed-path]`. |
| **Alert storms during incidents** | A cascading failure generates dozens of events | Implement batching in the Central Router (Section 7.3). Set rate limits per source+app. |
| **n8n execution timeouts** | Complex workflows may timeout | Set appropriate timeouts per workflow. Keep individual workflows lightweight (hub-and-spoke). |

### 8.5 General / Cross-Cutting Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **ClickUp API rate limits** | 100 requests per minute per workspace | Implement request queuing in n8n. Batch ClickUp updates. Use n8n's built-in rate limiting. |
| **Rocket.Chat API rate limits** | Configurable per server (default varies) | Check Rocket.Chat admin settings. Implement backoff in n8n. |
| **Webhook secret management** | Secrets for webhook validation must be stored securely | Store in OpenBao / Kubernetes secrets. Reference in n8n via environment variables, not hardcoded in workflows. |
| **Event ordering** | Webhooks may arrive out of order | Include timestamps in all events. n8n router should sort/validate event order before processing. |
| **Duplicate events from multiple sources** | Same deploy might trigger events from both Devtron and ArgoCD | Deduplication in Central Router using event fingerprinting. Prefer ArgoCD events for deploy status (more granular). |

### 8.6 K3s / AlmaLinux / Infrastructure Compatibility

| Item | Compatible? | Notes |
|------|-------------|-------|
| **n8n Helm chart** | Yes | `n8n/n8n` Helm chart available. Works on K3s. Requires PostgreSQL for execution data. |
| **Grafana Annotations API** | Yes | Standard HTTP API, no K3s-specific issues. |
| **Prometheus Pushgateway** | Yes | `prometheus-community/prometheus-pushgateway` Helm chart. |
| **ArgoCD notifications controller** | Yes | Built into ArgoCD, no separate deployment. ConfigMap-based configuration. |
| **Harbor webhooks** | Yes | Native feature, no K3s-specific issues. |
| **Devtron notifications** | Yes | Built into Devtron. Webhook channel is a native feature. |
| **Flannel CNI** | No issues | All webhook traffic is HTTP between pods -- Flannel handles this fine. |
| **Traefik ingress** | Verify | n8n webhook endpoints need Traefik IngressRoutes. Ensure webhook paths are routed correctly and not blocked by middleware (rate limiting, auth). Webhook endpoints should NOT be behind Zitadel/Cloudflare Access auth. |

---

## 9. Open Questions

### 9.1 Requiring User Input

1. **ClickUp workspace/list IDs**: What are the exact ClickUp list IDs for:
   - Development tasks
   - Security Advisories
   - Incidents
   - Infrastructure
   - Marketing/Communications (for release notes)

2. **ClickUp task ID convention**: What branch naming convention maps to ClickUp tasks? Proposed: `feature/CU-[taskId]-description` or `fix/CU-[taskId]-description`.

3. **Rocket.Chat channels**: Confirm the channel names. Proposed:
   - `#ci-builds` -- CI pipeline events
   - `#deploys` -- CD/deployment events
   - `#code-review` -- PR and review events
   - `#security` -- vulnerability and secret events
   - `#incidents` -- deployment failures, health degradation
   - `#infrastructure` -- quota, replication, retention
   - `#automation-alerts` -- n8n self-monitoring
   - `#general` -- release announcements

4. **Postal email recipients**: Who besides Wakeem should receive:
   - Critical security alerts?
   - Deploy failure notifications?
   - Release announcements?
   - Client-visible deployment notifications?

5. **Auto-rollback policy**: Which apps should have auto-rollback enabled on deploy failure or health degradation? All apps? Only production? Configurable per-app?

6. **Devtron vs ArgoCD event overlap**: Since Devtron embeds ArgoCD, should we:
   - Use only Devtron's webhook events (simpler, less granular)
   - Configure ArgoCD notifications directly too (more events, potential conflict)
   - Use Devtron for CI events and ArgoCD directly for CD events (best of both)

7. **Deploy blocking mechanism**: How should n8n block a deployment when critical CVEs are found?
   - Option A: ArgoCD sync window (block syncs during vulnerability review)
   - Option B: Kyverno policy that checks a "cleared" label on images
   - Option C: n8n calls ArgoCD API to set app sync policy to "manual"

8. **Grafana dashboard UIDs**: What are the dashboard UIDs for deployment annotation targeting? Or should annotations be global (no dashboard filter)?

9. **n8n deployment model**: Should n8n run in:
   - Single-instance mode (simpler, SPOF)
   - Queue mode with Redis (HA, more complex, requires Redis)

10. **Webhook authentication**: Confirm approach for securing n8n webhook endpoints:
    - GitHub: HMAC-SHA256 signature verification
    - Harbor: Shared secret in header
    - ArgoCD: X-Webhook-Secret header
    - Devtron: ???(needs investigation -- may need API key or IP allowlisting)

### 9.2 Open Technical Questions

1. **Devtron webhook differentiation**: Devtron sends the same `eventType` (trigger/success/fail) for both CI and CD pipelines. How does the webhook payload differentiate between them? Need to test actual payload or check Devtron source code.

2. **ArgoCD notification controller in Devtron**: Does Devtron's embedded ArgoCD ship with the notifications controller enabled? Or does it need to be enabled separately?

3. **Harbor scan auto-trigger**: Is Harbor configured to auto-scan images on push? If not, the SCANNING_COMPLETED event will never fire automatically.

4. **Cosign verification events**: Since Harbor does not emit webhook events for signature verification, should we:
   - Add a custom CI step that verifies the signature and sends a custom event to n8n
   - Use Kyverno to enforce image signatures (and rely on ArgoCD sync failure if signature is missing)

5. **n8n-as-code (GitOps for workflows)**: The `n8n-as-code` repo is already cloned to `07_Technology/n8n-as-code/`. Should workflow definitions be stored as TypeScript code in Git and deployed via the pipeline? This aligns with the GitOps philosophy.

---

## Appendix A: API Endpoints Reference

### ClickUp API
- Create task: `POST https://api.clickup.com/api/v2/list/{listId}/task`
- Update task: `PUT https://api.clickup.com/api/v2/task/{taskId}`
- Add comment: `POST https://api.clickup.com/api/v2/task/{taskId}/comment`
- Search tasks: `GET https://api.clickup.com/api/v2/team/{teamId}/task?custom_fields=[...]`
- Rate limit: 100 requests/minute/workspace
- Auth: `Authorization: [API_KEY]`

### Rocket.Chat API
- Post message: `POST https://rocketchat.helixstax.com/api/v1/chat.postMessage`
- DM user: `POST https://rocketchat.helixstax.com/api/v1/chat.postMessage` (with `channel: @username`)
- Auth: `X-Auth-Token` + `X-User-Id` headers

### Postal API
- Send message: `POST https://postal.helixstax.com/api/v1/send/message`
- Auth: `X-Server-API-Key` header

### Grafana Annotations API
- Create annotation: `POST https://grafana.helixstax.com/api/annotations`
- Body: `{ "time": epoch_ms, "tags": [...], "text": "..." }`
- Auth: `Authorization: Bearer [SERVICE_ACCOUNT_TOKEN]`

### MinIO S3 API
- Put object: Standard S3 `PUT /{bucket}/{key}`
- Auth: AWS Signature V4 with MinIO credentials

### ArgoCD API (for rollback)
- Sync app: `POST https://argocd.helixstax.com/api/v1/applications/{name}/sync`
- Rollback: `PUT https://argocd.helixstax.com/api/v1/applications/{name}` (set targetRevision to previous)
- Auth: Bearer token or ArgoCD API key

### Devtron API
- Get pipeline status: `GET https://devtron.helixstax.com/orchestrator/api/v1/applications`
- Auth: API token

---

## Appendix B: Webhook URL Registry

All n8n webhook endpoints in one place for configuration reference:

| Endpoint Path | Source System | Purpose |
|--------------|---------------|---------|
| `/webhook/github-events` | GitHub | Receives all GitHub webhook events |
| `/webhook/harbor-events` | Harbor | Receives all Harbor webhook events |
| `/webhook/argocd-events` | ArgoCD | Receives all ArgoCD notification webhooks |
| `/webhook/devtron-events` | Devtron | Receives all Devtron notification webhooks |
| `/webhook/route-event` | Internal only | Central event router (not exposed externally) |
| `/webhook/action-clickup` | Internal only | ClickUp action handler |
| `/webhook/action-rocketchat` | Internal only | Rocket.Chat action handler |
| `/webhook/action-postal` | Internal only | Postal email action handler |
| `/webhook/action-grafana` | Internal only | Grafana annotation handler |
| `/webhook/dead-letter` | Internal only | Dead letter queue handler |
| `/webhook/sbom-archive` | GitHub Actions CI | SBOM archive handler |
| `/webhook/n8n-heartbeat` | n8n (self) | Heartbeat for dead man's switch |

**External endpoints** (exposed via Traefik): github-events, harbor-events, argocd-events, devtron-events, sbom-archive
**Internal endpoints** (cluster-internal only): route-event, action-*, dead-letter, n8n-heartbeat

---

## Appendix C: n8n Workflow Inventory

| # | Workflow Name | Trigger Type | Purpose | Priority |
|---|--------------|-------------|---------|----------|
| 1 | GitHub Webhook Receiver | Webhook | Parse GitHub events | P0 (first to build) |
| 2 | Harbor Webhook Receiver | Webhook | Parse Harbor events | P0 |
| 3 | ArgoCD Webhook Receiver | Webhook | Parse ArgoCD events | P0 |
| 4 | Devtron Webhook Receiver | Webhook | Parse Devtron events | P1 |
| 5 | Central Event Router | Webhook (internal) | Route, deduplicate, batch, classify | P0 |
| 6 | ClickUp Action Handler | Webhook (internal) | Create/update/comment on ClickUp tasks | P0 |
| 7 | Rocket.Chat Action Handler | Webhook (internal) | Post messages to Rocket.Chat channels | P0 |
| 8 | Postal Action Handler | Webhook (internal) | Send emails via Postal | P1 |
| 9 | Grafana Annotation Handler | Webhook (internal) | Create Grafana annotations | P1 |
| 10 | Dead Letter Queue | Webhook (internal) + Schedule | Handle failed events, replay | P1 |
| 11 | SBOM Archive | Webhook | Archive SBOMs to MinIO | P2 |
| 12 | n8n Error Handler | Error Trigger | Self-monitoring for workflow failures | P0 |
| 13 | n8n Heartbeat | Schedule (5 min) | Dead man's switch heartbeat | P0 |
| 14 | Health Check | Schedule (6 hours) | Verify all downstream services are up | P1 |
| 15 | DLQ Replay | Schedule (15 min) | Retry dead letter queue items | P1 |

**Build order**: 12, 13 (self-monitoring first), then 5 (router), then 6, 7 (primary actions), then 1, 2, 3 (receivers), then 8, 9, 10 (secondary actions), then 4, 11, 14, 15.

---

## Appendix D: Helm Chart and Pipeline Compatibility

| Component | Helm-chartable? | Testable in vCluster? | GitHub Actions workflow needed? |
|-----------|----------------|----------------------|-------------------------------|
| n8n | Yes (`n8n/n8n` chart, latest: 0.249.x) | Yes -- deploy n8n in vCluster for testing | Yes -- deploy workflow JSONs via ConfigMap |
| n8n workflows (JSON) | Deployed as ConfigMap or volume mount in n8n Helm chart | Yes | Yes -- CI validates workflow JSON syntax |
| ArgoCD notification config | Yes -- ConfigMap in ArgoCD chart values | Yes -- test in vCluster ArgoCD instance | No -- managed by Helm values |
| Harbor webhook config | Configured via Harbor UI or API (not Helm) | Partial -- Harbor in vCluster is complex | Possibly -- `curl` to Harbor API in CI |
| Grafana service account | Provisioned via Grafana Helm values or Terraform | Yes | No -- one-time setup |
| Prometheus Pushgateway | Yes (`prometheus-community/prometheus-pushgateway`) | Yes | No |

---

## Appendix E: Event-to-Severity Classification Table

Complete mapping of every event to its severity classification:

| Event | Severity | Justification |
|-------|----------|---------------|
| `scan_critical` | critical | Production security risk |
| `secret_exposure` (gitleaks) | critical | Credential compromise risk |
| `deploy_failed` + `health_degraded` | critical | Production outage |
| `scan_high` | high | Security risk requiring review |
| `ci_failed` | high | Blocks delivery |
| `sync_failed` | high | Deploy attempt failed |
| `quota_exceeded` | high | Blocks future pushes |
| `cd_failed` | high | Deploy failed |
| `health_degraded` (alone) | medium | App unhealthy but not from deploy |
| `quota_warning` | medium | Approaching limit |
| `scan_failed` | medium | Scan broken, unknown security state |
| `sync_unknown` | medium | Unknown state requires attention |
| `ci_started` | low | Informational |
| `cd_started` | low | Informational |
| `sync_running` | low | Informational |
| `image_pushed` | low | Informational |
| `image_deleted` | low | Routine maintenance |
| `replication_complete` | low | Routine |
| `tag_retention` | low | Routine cleanup |
| `pr_opened` | info | Informational |
| `pr_merged` | info | Informational |
| `pr_approved` | info | Informational |
| `review_requested` | info | Informational |
| `issue_created` | info | Informational |
| `release_published` | info | Informational |
| `scan_clean` | info | Good news |
| `deployed` | info | Good news |
| `app_created` | info | Informational |
| `app_deleted` | info | Informational |
| `scan_stopped` | info | Informational |

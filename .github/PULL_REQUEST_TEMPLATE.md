## What Changed

<!-- Describe the change clearly. What was the state before, and what is it now? -->

## Why

<!-- What problem does this solve? Link to issue if applicable. Closes #??? -->

## Testing Done

<!-- What did you do to verify this works? -->

- [ ] Helm lint passed: `helm lint helm/<chart>/`
- [ ] kubectl dry-run passed: `kubectl apply --dry-run=client -f <manifest>`
- [ ] Deployed to staging and verified
- [ ] Shell scripts tested in dry-run mode

## Checklist

- [ ] No secrets or credentials in this PR
- [ ] Resource limits set on all new containers
- [ ] Liveness and readiness probes configured on new Deployments
- [ ] IngressRoutes use `traefik.io/v1alpha1` (NOT `traefik.containo.us`)
- [ ] TLS via Cloudflare Origin CA (no cert-manager, no Let's Encrypt)
- [ ] Domain is helixstax.net for internal apps (NOT helixstax.com)
- [ ] CLAUDE.md updated if this adds new patterns or decisions

## Rollback Plan

<!-- How do we undo this if something goes wrong? -->

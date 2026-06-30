# Incident Report: nginx-app CrashLoopBackOff - Sentinel Command Misconfiguration

## Executive Summary

**Pod:** `kube-system/nginx-app-79cf5d7f98-ffqff`  
**Container:** `monitor`  
**Status:** CrashLoopBackOff (5 restarts)  
**Root Cause:** Incomplete sentinel command - `sleep` without duration argument  
**Action Required:** Manual configuration fix (command or image)

---

## Problem Description

The container is configured with the command `["sleep"]` without any arguments. The `sleep` command requires a duration argument to function correctly. Without it, the process exits immediately with an error, causing Kubernetes to restart the container repeatedly.

This is a **configuration issue**, not a resource limit problem. The allocated resources (256Mi memory / 20m CPU limit) are more than sufficient for a sleep process.

---

## Current Configuration Analysis

### From Helm Values (`ubuntu-chart/values.yaml`)

```yaml
replicaCount: 1

image:
  repository: ubuntu
  tag: latest
  pullPolicy: Always

command:
  - sleep    # ❌ MISSING DURATION ARGUMENT

resources:
  limits:
    cpu: 20m
    memory: 256Mi
  requests:
    cpu: 10m
    memory: 128Mi
```

### Container Specification

- **Image:** `ubuntu:latest`
- **Command:** `["sleep"]` 
- **Args:** `null`
- **Result:** Process exits immediately → CrashLoopBackOff

---

## Why Resource Limits Are NOT the Problem

The current resource allocation is appropriate for a sleep/test container:
- **Memory:** 256Mi limit, 128Mi request
- **CPU:** 20m limit, 10m request

A `sleep` process consumes virtually no resources (typically < 1Mi memory, < 1m CPU). The crash is occurring because the command itself is invalid, not because of resource exhaustion.

---

## Recommended Solutions

### Solution 1: Fix the Sleep Command (Keep as Test Pod)

Update `ubuntu-chart/values.yaml`:

```yaml
command:
  - sleep
  - infinity  # or any number like "3600"
```

**Use case:** Development testing, placeholder pod, debugging

---

### Solution 2: Deploy an Actual Application

The pod name suggests this should be an nginx application. Update `ubuntu-chart/values.yaml`:

```yaml
image:
  repository: nginx
  tag: stable
  pullPolicy: IfNotPresent

# Remove command field to use nginx's default entrypoint
# command:
#   - sleep

resources:
  limits:
    cpu: 100m      # nginx needs more CPU than sleep
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 128Mi
```

**Use case:** Production workload, actual nginx web server

---

### Solution 3: Ubuntu with Long-Running Shell Loop

```yaml
command:
  - /bin/bash
  - -c
  - "while true; do sleep 3600; done"
```

**Use case:** Debug container, manual troubleshooting, temporary workload

---

## Fields Requiring Manual Update

The following fields in `ubuntu-chart/values.yaml` need to be changed:

1. **`command:`** - Add proper argument(s) or remove entirely
2. **`image.repository:`** (optional) - Change to `nginx` if deploying real app
3. **`image.tag:`** (optional) - Use a specific version tag for stability

**Do NOT change:**
- ❌ `resources.limits.memory` - current value is sufficient
- ❌ `resources.requests.memory` - current value is sufficient  
- ❌ `resources.limits.cpu` - current value is sufficient
- ❌ `resources.requests.cpu` - current value is sufficient

---

## Implementation Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ajithshah/k8s-agent.git
   cd k8s-agent
   ```

2. **Edit the values file:**
   ```bash
   vim ubuntu-chart/values.yaml
   ```

3. **Apply one of the recommended solutions** (see above)

4. **Commit and push:**
   ```bash
   git add ubuntu-chart/values.yaml
   git commit -m "fix: Add duration argument to sleep command in nginx-app"
   git push origin main
   ```

5. **Wait for ArgoCD sync** or trigger manually:
   ```bash
   argocd app sync nginx-app
   ```

6. **Verify the fix:**
   ```bash
   kubectl get pods -n kube-system -l app=nginx-app
   kubectl logs -n kube-system -l app=nginx-app -c monitor
   ```

---

## Expected Outcome

After applying the fix:

✅ Container starts successfully  
✅ No immediate exit/crash  
✅ Pod status changes from CrashLoopBackOff to Running  
✅ Restart count stops increasing  
✅ Container remains stable for extended period  

---

## Monitoring Post-Fix

After deployment, monitor:

```bash
# Watch pod status
kubectl get pods -n kube-system -w | grep nginx-app

# Check restart count (should remain at 0)
kubectl get pods -n kube-system nginx-app-<pod-id> -o jsonpath='{.status.containerStatuses[0].restartCount}'

# View logs for errors
kubectl logs -n kube-system -l app=nginx-app -c monitor --tail=50
```

---

## Conclusion

This incident is caused by an **incomplete sentinel command configuration**, not resource constraints. Automated resource limit adjustments would not resolve the issue. Manual intervention is required to either:

1. Complete the sleep command with proper arguments, or
2. Replace the test configuration with a real application workload

The agent has created this informational report instead of attempting an ineffective resource limit increase.

---

**Report Generated By:** Kubernetes SRE Agent  
**Timestamp:** {{ timestamp }}  
**ArgoCD Application:** nginx-app  
**Repository:** https://github.com/ajithshah/k8s-agent.git  
**Values File:** ubuntu-chart/values.yaml
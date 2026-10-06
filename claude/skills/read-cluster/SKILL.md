---
name: read-cluster
description: Read-only inspection of the k3s homelab cluster with kubectl and the flux CLI. Use when checking whether Flux applied a revision, or debugging an unhealthy app, pod, or Kustomization in the homelab cluster.
---

# Reading the k3s cluster

The cluster runs k3s and Flux applies everything from `github.com/chivta/homelab` and the app repos it points at. This skill reads the cluster. It never changes it.

## Credential

Use `~/.kube/agent.kubeconfig` and nothing else. Check it first:

```bash
test -f ~/.kube/agent.kubeconfig && echo present
```

If the file is missing, stop: this machine has no cluster access. Tell the user and hand them the commands below to run themselves. Do not look for another kubeconfig, and do not use `~/.kube/config`, which may hold a wider credential.

Prefix every command with the kubeconfig, since the shell does not keep exported variables between calls:

```bash
KUBECONFIG=~/.kube/agent.kubeconfig kubectl get pods -A
KUBECONFIG=~/.kube/agent.kubeconfig flux get kustomizations -A
```

The credential is bound to `get list watch` on workloads, services, configmaps, PVCs, nodes, namespaces, events, CRDs, and every `*.toolkit.fluxcd.io` type. It cannot read secrets. If a command fails on auth or connection, stop and report it. Do not try to fix it.

Hard boundaries:

- Never write to the cluster. No `apply`, `patch`, `edit`, `delete`, `scale`, `rollout restart`, `exec`, `port-forward`, `cp`, `flux reconcile`, `flux suspend`, `flux resume`, `helm install`, `helm upgrade`. RBAC denies them, but do not attempt them.
- Do not edit, regenerate, or copy the kubeconfig, and do not add or switch contexts.
- Do not SSH to the node.

When a read shows a problem, the fix is a commit to the app repo or to homelab. If a change needs to land before the next Flux interval, ask the user to run `flux reconcile`.

## Commands

```bash
flux get kustomizations -A            # per-app revision, SUSPENDED, READY, and the failure message
flux get sources git                  # did the GitRepository fetch the new commit
flux events --for Kustomization/<app> # why a Kustomization went NotReady
flux tree kustomization <app>         # what the Kustomization actually owns
flux logs --level=error --since=30m   # flux-system controller errors
kubectl -n <ns> get pods,svc,ingress
kubectl -n <ns> describe pod <pod>    # events at the bottom explain most failures
kubectl -n <ns> logs deploy/<app> --tail=50
kubectl -n <ns> get events --sort-by=.lastTimestamp
```

Read the `REVISION` column first. If it does not match the SHA that was pushed, the problem is upstream of the cluster: CD has not run, or the commit is not on `main`. If it matches and `READY` is False, the `MESSAGE` column names the failure and the commands above fill in the detail.

Flux polls app repos every 1m and `clusters/main` every 10m, so wait one interval before calling something broken.

## Failure modes

In the order they usually bite:

- `Kustomization` stuck on a decryption error: the secret was encrypted with the wrong recipient, or `secrets.enc.yaml` is not in the app's `kustomization.yaml`.
- `ImagePullBackOff`: CD never pinned a real tag, or the image name is wrong. Pulls from `ghcr.io` authenticate through k3s `registries.yaml` on the node, so a 401 or 403 means that PAT was revoked.
- `CreateContainerConfigError`: `app-secrets` is missing a key the manifest references. You cannot read secrets, so compare the keys the manifest references against the key names in the app's `k8s/secrets.enc.yaml`, which stay readable.
- Pod crashlooping on a write: `readOnlyRootFilesystem` with no `emptyDir` for its scratch path.
- Ingress resolves but times out: DNS record for the host is missing.
- New app never appears at all: its files are not listed in homelab's `clusters/main/apps/kustomization.yaml`.

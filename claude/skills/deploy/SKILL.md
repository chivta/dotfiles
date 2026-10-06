---
name: deploy
description: Deploy an application to the k3s homelab cluster through Flux, covering manifests, SOPS secrets, CI/CD, and registration in the homelab repo.
disable-model-invocation: true
---

# Deploying to the k3s cluster

The cluster runs k3s and is driven entirely by Flux from `github.com/chivta/homelab`. A deploy means: the app repo carries its own manifests under `k8s/`, CI/CD pushes images to GHCR and pins the tag back into those manifests, and the homelab repo points Flux at the app repo.

Work in this order. The gate before section 4 is hard: do not open the homelab repo until everything above it is done and pushed.

## Access

Everything in this skill runs with GitHub access alone:

- `git` over SSH with push rights to the app repo and to `git@github.com:chivta/homelab.git`.
- `gh` authenticated, for reading workflow runs.
- `sops` installed. Encryption needs only the public age key in section 2, so no private key is needed on this machine.

The only way to change what runs is a commit to the app repo or to homelab, and Flux applies it. Reading the cluster is optional and goes through the `read-cluster` skill.

## What already exists in the cluster

Do not rebuild any of this.

| Thing | Where it lives | How to use it |
|---|---|---|
| Flux | `clusters/main/flux-system` (generated, do not edit) | Watches `clusters/main` every 10m |
| App registry | `clusters/main/apps/<app>/` + an entry in `apps/kustomization.yaml` | One `GitRepository` + one `Kustomization` per app |
| Traefik | `clusters/main/infrastructure/traefik` | `ingressClassName: traefik` |
| TLS | Traefik `letsencrypt` resolver, DNS-01 via Cloudflare, wildcard `*.chivtar.dev` | Set the host to `<app>.chivtar.dev` and omit the `tls:` block entirely |
| Prometheus | kube-prometheus-stack in `monitoring` | Add a `ServiceMonitor` next to the service |
| Pushgateway | `http://prometheus-pushgateway.monitoring.svc.cluster.local:9091` | For one-shot jobs that exit before a scrape |
| Image pulls | k3s `/etc/rancher/k3s/registries.yaml` on the node holds a `read:packages` PAT for `ghcr.io` | Nothing. Pods pull public and private GHCR images without `imagePullSecrets` |
| Git auth | Flux secret `github-app` in `flux-system`, a GitHub App with read-only Contents on all `chivta` repos | `provider: github` + `secretRef` on every `GitRepository` |
| SOPS decryption | Flux secret `apps-sops-age` in `flux-system`, the private half of the shared app key | Reference it from the app's Flux `Kustomization` |

Storage is local-path (k3s default), so every volume is `ReadWriteOnce` and effectively pinned to the node.

## 1. Manifests in the app repo

Everything goes under `k8s/` in the application's own repo, one directory per component, with a `kustomization.yaml` at the root. Flux is pointed at `./k8s`.

```
k8s/
  kustomization.yaml
  namespace.yaml
  secrets.enc.yaml        # committed, SOPS-encrypted
  secrets.yaml            # gitignored plaintext source
  api/deployment.yaml
  api/service.yaml
  api/service-monitor.yaml
  ingress.yaml
```

The root kustomization sets the namespace once so component files stay portable:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <app>
resources:
  - namespace.yaml
  - secrets.enc.yaml
  - api/pvc.yaml
  - api/deployment.yaml
```

Rules for workload manifests:

- `revisionHistoryLimit: 3`, `replicas: 1`.
- Pod `securityContext` with `runAsNonRoot`, an explicit uid/gid, and `fsGroup` when a volume is mounted. Container `securityContext` with `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`.
- A read-only root filesystem needs an `emptyDir` at `/tmp` for anything that writes scratch files.
- Config comes from `envFrom.secretRef: app-secrets` for secret values, plain `env` for non-secret values such as `GIN_MODE` or a DB path.
- `resources.requests` and `resources.limits` on every container. This is a small single node, so keep requests honest.
- Liveness and readiness probes on `GET /health`. Add a `startupProbe` when first boot does slow work, and let it cover that time instead of inflating `initialDelaySeconds`.
- Anything holding a `ReadWriteOnce` volume needs `strategy.type: Recreate`. A rolling update deadlocks on the mount.
- Stateful dependencies (postgres, redis, rabbitmq) are `StatefulSet` + headless `Service` with a `volumeClaimTemplates` entry, deployed inside the app's namespace.
- Cron work is a `CronJob` with `concurrencyPolicy: Forbid`, `restartPolicy: OnFailure`, `backoffLimit`, and `activeDeadlineSeconds`.

Ingress, when the app is public:

```yaml
spec:
  ingressClassName: traefik
  rules:
    - host: <app>.chivtar.dev
```

Wildcard TLS is already issued, so no `tls:` block and no cert-manager. The DNS record for the host is a human step, see the gate.

The image tag in the manifest is the ground truth for what runs. Commit it with a real SHA or a `placeholder` tag that CD overwrites on the first run.

## 2. Secrets

Two files, one committed and one not:

- `k8s/secrets.yaml` holds plaintext, is listed in `.gitignore`, and is the file you edit.
- `k8s/secrets.enc.yaml` is `sops -e k8s/secrets.yaml > k8s/secrets.enc.yaml` and is the file listed in `kustomization.yaml`.

`.sops.yaml` in the app repo encrypts to the shared app key. Its private half lives only in the cluster as `apps-sops-age`:

```yaml
creation_rules:
  - path_regex: k8s/secrets.yaml
    encrypted_regex: ^(data|stringData)$
    age: age10d00xrpljw4cga37ad0gt7se4nsehp5uv8yy3grkfqygd4pzyffqj3gr46
```

`encrypted_regex` keeps `metadata` readable so kustomize and a human reviewer can still see what the secret is. Comments above each key survive encryption as separate ENC blocks, so document what a value is and where it came from.

No machine outside the cluster can decrypt `secrets.enc.yaml`. If `k8s/secrets.yaml` is missing locally, changing any secret means rebuilding the whole plaintext file: list the keys the manifests reference, ask the user for every value, write `k8s/secrets.yaml`, and encrypt it. Never guess or leave a value empty to fill in later.

The infrastructure directory uses a different key (`age1nrfs0cgysk6tpxq04l2yzhgm9edaklqsfmfdfzftrq8phx5hrgqq3ax5qq`, Flux secret `infra-sops-age`). Do not mix the two.

Re-encrypt after every plaintext edit. A stale `secrets.enc.yaml` is silent: Flux applies the old values and nothing fails.

## 3. CI and CD

Two workflows. CI tests, CD builds and pins. CD runs on `workflow_run` after CI so an untested commit never ships.

CI (`.github/workflows/ci.yaml`): checkout, set up the toolchain with cache, then format check, vet, test, build. For a monorepo, one job per component with `defaults.run.working-directory`.

CD (`.github/workflows/cd.yaml`):

```yaml
on:
  workflow_run:
    workflows: [CI]
    types: [completed]
    branches: [main]
```

- Guard with `if: ${{ github.event.workflow_run.conclusion == 'success' }}`.
- `permissions: contents: write, packages: write`.
- Log in to `ghcr.io` with `secrets.GITHUB_TOKEN` and `github.actor`.
- Tag images with the full `github.event.workflow_run.head_sha`, plus `latest`.
- Build the `production` target of the Dockerfile with `cache-from`/`cache-to: type=gha`, with a separate `scope` per image in a monorepo.
- Commit the manifest change as `deploy: <what> <sha>` from `github-actions[bot]`.

Pin the tag according to how many images the repo ships:

- One image: `sed -i -E "s|image: ${REGISTRY}/${IMAGE_NAME}:.*|image: ${IMAGE}|"` on the deployment file, then `git diff --quiet && exit 0` so a no-op run does not commit.
- Several images: list every image in an `images:` block in `k8s/kustomization.yaml` (`name` plus `newTag`), and run `kustomize edit set image <name>=<name>:<sha>` for each image that was built.

Stop the deploy commit from looping back into CI with a head-SHA guard: check out `main` (not the detached SHA, so the commit has a branch to land on) and fail the job if `git rev-parse HEAD` differs from `github.event.workflow_run.head_sha`. The guard also stops a stale run from overwriting a newer deploy. Adding the pinned file to CI's `paths-ignore` stops the loop too, but misses the race, so it does not replace the guard.

In a monorepo, build only the components that changed. Read each image's current `newTag` from `kustomization.yaml` and `git diff --name-only <old> <new>` against that component's directory, setting one step output per component. A missing tag, or one equal to the new SHA, forces a build. CD needs `fetch-depth: 0` for that diff. Skip the deploy job when nothing was built.

## Gate before touching homelab

All of these must be true and pushed to the app repo's `main`:

- [ ] `k8s/` manifests complete: namespace, root kustomization listing every resource, workloads with probes, resources, and security contexts.
- [ ] `k8s/secrets.enc.yaml` committed, `k8s/secrets.yaml` gitignored, `.sops.yaml` present with the shared app recipient, and the encrypted file re-generated from the current plaintext.
- [ ] `.github/workflows/ci.yaml` and `cd.yaml` present, CD gated on CI, images pushed to `ghcr.io/chivta/<repo>[/<component>]`, tag pinned back into the manifest with a `deploy:` commit.
- [ ] At least one green CD run (`gh run list --repo chivta/<repo> --workflow CD`), so the manifest holds a real SHA rather than `placeholder`.

Human steps you cannot do yourself. Stop and ask:

- DNS record for `<app>.chivtar.dev` pointing at the cluster.
- Any third-party credential going into `secrets.yaml`.

## 4. Register in homelab

Clone a fresh copy into your scratch directory so local state on this machine never leaks into the commit:

```bash
git clone git@github.com:chivta/homelab.git
```

Create `clusters/main/apps/<app>/gitrepository.yaml`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: <app>
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/chivta/<repo>
  ref:
    branch: main
  provider: github
  secretRef:
    name: github-app
```

The same template works for public and private repos. `github-app` holds the credentials of a GitHub App installed on every `chivta` repository with read-only Contents access, so a new repo needs no extra setup.

Create `clusters/main/apps/<app>/<app>.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <app>
  namespace: flux-system
spec:
  interval: 1m
  path: ./k8s
  prune: true
  sourceRef:
    kind: GitRepository
    name: <app>
  decryption:
    provider: sops
    secretRef:
      name: apps-sops-age
```

Then append both files to `clusters/main/apps/kustomization.yaml`. Flux ignores a file that is not listed there, and this is the most common reason a new app never appears.

Commit to homelab as `feat: deploy <app>` and push.

## 5. Verify

Confirm Flux applied the app with the `read-cluster` skill. Every failure is fixed by a commit to the app repo or to homelab.

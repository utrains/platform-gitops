# platform-gitops: deploy your app on the EKS platform

This repository is how app teams deploy on the shared EKS platform. You do **not** write Kubernetes YAML: you create one folder and one small file, open a pull request, and the platform does the rest (namespace, Deployment, Service, HTTPS certificate, public URL, DNS, mutual TLS).

```
platform-gitops/
├── apps/                      <- app requests, one folder per app
│   └── whoami/
│       └── prod.yaml          <- folder = app name, file = environment
├── examples/myapp/dev.yaml    <- the template to copy
├── app-template/              <- Helm chart used for every app (platform team)
├── scripts/validate.sh        <- the check that runs on every pull request
└── .github/                   <- CODEOWNERS + CI workflow
```

## 1. What you get

For a folder `apps/shop/` with a file `dev.yaml`:

| You get | Value |
|---|---|
| Public URL | **https://shop-dev.afriqhome.com** (file `prod.yaml`: **https://shop.afriqhome.com**) |
| HTTPS certificate | Let's Encrypt, trusted by every browser, renewed automatically |
| HTTP | redirected to HTTPS |
| Namespace | `shop-dev` |
| Deployment / Service | `shop` / `shop` |
| Security | mutual TLS between all the pods of the platform, no privilege escalation |
| Availability | 2 replicas by default, spread across availability zones, PodDisruptionBudget (node upgrades never take your app down) |
| Health | readiness + liveness probes on your health path |

## 2. Requirements for your container

- It listens on **plain HTTP** (no TLS: the platform does TLS for you) on one port (default 80).
- It answers **200** on a health path (default `/`) when it is ready.
- The image is in a registry the cluster can pull from (public, or the ECR of the platform account), with a **pinned tag** (`shop:1.4.2`, never `latest`).

## 3. Deploy a new app

```bash
git clone https://github.com/utrains/platform-gitops.git
cd platform-gitops
git checkout -b add-shop-dev

mkdir apps/shop                                   # folder = your app name
cp examples/myapp/dev.yaml apps/shop/dev.yaml     # file = the environment: dev, staging or prod
```
Edit `apps/shop/dev.yaml`. Usually you only set the image and the port:
```yaml
image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/shop:1.4.2
port: 8080
healthPath: /healthz
```
Check it, commit, push, open a pull request:
```bash
./scripts/validate.sh            # needs helm; the same check runs on the pull request
git add apps/shop
git commit -m "Add shop (dev)"
git push -u origin add-shop-dev
```
After the merge, wait about **5 minutes** (Git poll, certificate, DNS), then open **https://shop-dev.afriqhome.com**.

Rules:
- **Folder name = app name**: 2 to 30 characters, lowercase letters, digits and `-`, starting with a letter.
- **File name = environment**: `dev.yaml`, `staging.yaml` or `prod.yaml`. Same app in several environments = several files in the same folder.
- Do **not** write `name:` or `env:` in the file: they come from the path.

### All the options

| Field | Default | Meaning |
|---|---|---|
| `image` | `nginx:1.27` | container image with a pinned tag |
| `port` | `80` | port your container listens on |
| `replicas` | `2` | number of pods (ignored when autoscaling is on) |
| `healthPath` | `/` | HTTP path for the readiness and liveness probes, must answer 200 |
| `env_vars` | `{}` | extra environment variables, e.g. `{LOG_LEVEL: info}` (no secrets here: ask the platform team) |
| `resources.requests` | `cpu: 50m, memory: 64Mi` | what your pod needs (used for scheduling and autoscaling) |
| `resources.limits` | `memory: 256Mi` | your pod is restarted (OOMKilled) above this memory |
| `autoscaling.enabled` | `false` | scale on CPU between `minReplicas` and `maxReplicas` |
| `autoscaling.minReplicas` / `maxReplicas` / `cpuTarget` | `2` / `6` / `70` | |

Your pods also get the environment variables `APP_NAME` and `APP_ENV`.

## 4. Update your app

Change the file (new `image` tag, more `replicas`...) through a pull request. After the merge, the change is applied within ~3 minutes with a rolling update: new pods must pass the readiness probe before the old ones stop, so a broken version never replaces a working one.

## 5. Check the status

Argo CD: **https://argocd.afriqhome.com** (read access: ask the platform team), application `<name>-<env>`.
- **Synced / Healthy**: deployed and running.
- **OutOfSync** / **Progressing**: being deployed.
- **Degraded** / **Unknown**: open it, the message tells you why (wrong image, failing probe, invalid name...).

With kubectl (read access to your namespace):
```bash
kubectl get pods -n shop-dev
kubectl logs -n shop-dev deploy/shop
kubectl describe pod -n shop-dev <pod>             # events: image pull errors, probe failures
```
From your laptop:
```bash
curl -I https://shop-dev.afriqhome.com             # HTTP/1.1 200, server: istio-envoy
nslookup shop-dev.afriqhome.com 8.8.8.8            # the DNS record exists
```

## 6. Remove your app

Delete the file (or the whole folder) through a pull request. After the merge, everything is deleted within a few minutes: pods, namespace, certificate, URL and DNS record.

## 7. Troubleshooting

| Symptom | Cause | What to do |
|---|---|---|
| The pull request check fails: `invalid app name` | folder name has uppercase, `_`, ... | rename the folder: `shop-api`, not `Shop_API` |
| The check fails: `invalid environment` | file is not `dev.yaml`, `staging.yaml` or `prod.yaml` | rename the file |
| Argo CD: `ImagePullBackOff` | wrong image name or tag, or private registry | check `image:`, ask the platform team for registry access |
| Pods `Running` but `0/2` / not ready | the health path does not answer 200, or wrong `port` | check `healthPath` and `port` |
| Pods restart, `OOMKilled` | memory limit too low | raise `resources.limits.memory` |
| The URL does not resolve after 5 min | your laptop cached "not found" because you opened it too early | `nslookup <host> 8.8.8.8`, flush your DNS cache (`ipconfig /flushdns` on Windows) |
| `https://...` shows a certificate warning | the certificate is still being issued (first 1-2 minutes) | wait and reload |
| `502` / `503` from `istio-envoy` | no ready pod behind the route | see "not ready" above |

## 8. Ask the platform team

- Secrets (database passwords, API keys).
- A custom domain, a path-based route, a non-HTTP protocol (gRPC streaming, TCP).
- Persistent storage, databases, queues.
- AWS access from your app (S3, SQS...): the platform gives your app an IAM role.

---
Platform team: the cluster and this repository are created and operated with Terraform, see `eks-full-infra/docs/platform-guide.md` in [kubernetes-practice2](https://github.com/utrains/kubernetes-practice2).

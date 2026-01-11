# Questify GitOps

GitOps configuration for deploying Questify on Kubernetes via ArgoCD.

## Features

- **App of Apps Pattern** - Single entry point manages all applications
- **Automatic Image Updates** - ArgoCD Image Updater watches registry for new tags
- **Sealed Secrets** - Encrypted secrets safe to commit to Git
- **Persistent Storage** - PostgreSQL and MinIO data survives redeployments

## Structure

```
├── apps/
│   └── root.yaml                    # App of Apps entry point
├── projects/
│   └── questify-project.yaml        # ArgoCD AppProject
├── applications/
│   ├── argocd-config.yaml           # Image Updater configuration
│   ├── backend.yaml                 # Spring Boot API
│   ├── frontend.yaml                # React Frontend
│   ├── landing.yaml                 # Landing Page
│   ├── infra.yaml                   # Namespace + Secrets
│   ├── minio.yaml                   # Object Storage
│   └── postgresql.yaml              # Database
└── manifests/
    ├── argocd/                      # ArgoCD namespace manifests
    │   ├── argocd-image-updater-config.yaml
    │   └── sealed-regcred.yaml
    └── infra/                       # Questify namespace manifests
        ├── namespace.yaml
        └── sealed-*.yaml            # SealedSecrets (JWT, MinIO, PostgreSQL)
```

## Initial Deployment

```bash
# 1. Install ArgoCD Image Updater
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/v0.14.0/manifests/install.yaml

# 2. Apply the project
kubectl apply -f projects/questify-project.yaml

# 3. Apply the root App of Apps
kubectl apply -f apps/root.yaml
```

## Related Repositories

| Repository | Description |
|------------|-------------|
| [questify](https://github.com/axelfrache/questify) | Main app (backend + frontend + Helm charts) |
| [questify-landing](https://github.com/axelfrache/questify-landing) | Landing page |

## License

[MIT](LICENSE)
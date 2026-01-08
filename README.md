# Questify GitOps

Ce repository contient la configuration GitOps pour le déploiement de Questify sur Kubernetes via ArgoCD.

## Structure

```
├── apps/
│   └── root.yaml              # App of Apps (point d'entrée)
├── projects/
│   └── questify-project.yaml  # AppProject ArgoCD
├── applications/
│   ├── backend.yaml           # API Spring Boot
│   ├── frontend.yaml          # Frontend React
│   ├── infra.yaml             # Namespace + Secrets
│   ├── minio.yaml             # Object Storage
│   ├── postgresql.yaml        # Database
│   └── landing.yaml           # Landing page
└── manifests/
    └── infra/                 # Manifests Kubernetes raw
        ├── namespace.yaml
        └── sealed-*.yaml      # SealedSecrets
```

## Déploiement initial

```bash
# Appliquer le root App of Apps
kubectl apply -f apps/root.yaml --namespace argocd
```

## Repos associés

| Repo | Description |
|------|-------------|
| [questify](https://github.com/axelfrache/questify) | Application principale (backend + frontend + charts Helm) |
| [questify-landing](https://github.com/axelfrache/questify-landing) | Landing page |

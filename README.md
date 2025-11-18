# ArgoCD Hub-Spoke Multi-Cluster Architecture on AWS EKS

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-v2.12+-E94E77?logo=argo&logoColor=white)](https://argo-cd.readthedocs.io)
[![AWS EKS](https://img.shields.io/badge/AWS_EKS-Managed-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eks/)
[![cert-manager](https://img.shields.io/badge/cert--manager-automated-green?logo=letsencrypt&logoColor=white)](https://cert-manager.io)

> **Production-grade GitOps implementation** featuring automated TLS certificate management, multi-cluster orchestration, and zero-downtime deployments using ArgoCD ApplicationSets.


---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Key Features](#key-features)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup Guide](#detailed-setup-guide)
- [Validation & Testing](#validation--testing)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [Technologies](#technologies)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

This project implements a **hub-spoke topology** for managing multiple Kubernetes clusters using ArgoCD. The architecture centralizes GitOps operations in a single hub cluster while maintaining full control over multiple spoke clusters without requiring ArgoCD installation on each spoke.

### What This Solves

- **Centralized GitOps Management:** Single ArgoCD instance controls multiple clusters
- **Automated TLS:** Let's Encrypt integration with cert-manager for production-ready HTTPS
- **Enterprise Scalability:** Add unlimited spoke clusters without additional overhead
- **Zero Manual Configuration:** Everything is declarative and version-controlled
- **Production Security:** SSL passthrough, gRPC support, and proper ingress configuration

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GitHub Repository                    │
│                    (Single Source of Truth)                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ GitOps Sync
                         ▼
┌────────────────────────────────────────────────────────────┐
│                      Hub Cluster (EKS)                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              ArgoCD Control Plane                    │  │
│  │  • ApplicationSet Controller                         │  │
│  │  • Multi-Cluster Management                          │  │
│  │  • Policy Enforcement                                │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  NGINX Ingress Controller + cert-manager             │  │
│  │  • SSL Passthrough (gRPC support)                    │  │
│  │  • Let's Encrypt Auto TLS                            │  │
│  └──────────────────────────────────────────────────────┘  │
└───────────┬────────────────────────────┬───────────────────┘
            │                            │
    ┌───────▼────────┐          ┌───────▼────────┐
    │ Spoke Cluster 1│          │ Spoke Cluster 2│
    │     (EKS)      │          │     (EKS)      │
    │                │          │                │
    │  No ArgoCD     │          │  No ArgoCD     │
    │  Managed Apps  │          │  Managed Apps  │
    └────────────────┘          └────────────────┘
```

### Traffic Flow

```
User/CLI → HTTPS → AWS ALB → NGINX Ingress → ArgoCD Server (gRPC/HTTPS)
                                  ↓
                          Let's Encrypt (TLS)
```

---

## ✨ Key Features

- **Hub-Spoke Topology:** Centralized ArgoCD managing multiple worker clusters
- **ApplicationSet Pattern:** Automatic deployment to multiple clusters with label selectors
- **Automated TLS Certificates:** cert-manager with Let's Encrypt production issuer
- **Full gRPC Support:** SSL passthrough for ArgoCD CLI operations
- **Infrastructure as Code:** All configurations version-controlled in Git
- **Production-Ready Ingress:** NGINX with proper annotations for ArgoCD
- **One-Command Setup:** Automated tooling installation script
- **Zero-Downtime Updates:** GitOps-based continuous deployment

---

## 📁 Repository Structure

```
.
├── applicationsets/
│   └── applicationset-color-palette.yaml    # Multi-cluster app deployment
│
├── manifests/
│   └── color-palette/                       # Sample application
│       ├── deployment.yaml                  # Pod specification
│       ├── service.yaml                     # Service exposure
│       └── configmap.yaml                   # Configuration data
│
├── tools-installation.sh                    # Automated dependency installer                          
└── README.md                                # This file
```

### Directory Purpose

| Directory | Purpose |
|-----------|---------|
| `applicationsets/` | ArgoCD ApplicationSet definitions for multi-cluster deployments |
| `manifests/` | Kubernetes manifests organized by application |
| `Root` | Setup scripts, documentation, and configuration |

---

## 🔧 Prerequisites

### Required Tools

- AWS CLI v2.x
- kubectl v1.30+
- eksctl v0.175+
- Helm v3.x
- ArgoCD CLI v2.12+

### AWS Requirements

- AWS Account with EKS permissions
- IAM user/role with sufficient privileges
- Route53 hosted zone (for custom domain)
- Valid domain name for ArgoCD ingress

### System Requirements

- Ubuntu 20.04+ / macOS / WSL2
- Minimum 8GB RAM for local testing
- 20GB free disk space

---

## 🚀 Quick Start

### Automated Tool Installation

Run this on any fresh Ubuntu machine (EC2, local, or WSL):

```bash
curl -sL https://raw.githubusercontent.com/SrinivasSarkar/argocd-hub-spoke-eks/main/tools-installation.sh | bash
```

This installs all required tools automatically. Verify installation:

```bash
aws --version && kubectl version --client && eksctl version && helm version && argocd version --client
```

---

## 📖 Detailed Setup Guide

Note: Before creating this cluster I had added the admin IAM role to the EC2 manually.
### Step 1: Create Hub Cluster

Deploy the central ArgoCD control plane cluster:

```bash
eksctl create cluster \
  --name hub-cluster \
  --region us-east-1 \
  --node-type t2.medium \
  --nodes 2 \
  --managed \
  --version 1.30
```

**Wait time:** ~15-20 minutes

Verify cluster creation:

```bash
kubectl get nodes
```

---

### Step 2: Install NGINX Ingress Controller

Deploy NGINX with AWS Load Balancer integration:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```
```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
  --wait --timeout 300s
```

Get the Load Balancer URL:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Action Required:** Create a DNS CNAME record pointing `argocd.randomtechy.tech` to this Load Balancer hostname in Route53.

---

### Step 3: Install cert-manager

Deploy cert-manager for automated TLS certificate management:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.yaml
```

Wait for cert-manager to be ready:

```bash
kubectl wait --for=condition=available deployment/cert-manager -n cert-manager --timeout=300s
```

---

### Step 4: Install ArgoCD

Deploy ArgoCD in the hub cluster:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for all ArgoCD pods:

```bash
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

---

### Step 5: Configure Let's Encrypt Issuer

Create a certificate issuer:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@randomtechy.tech
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

**Important:** Replace `admin@randomtechy.tech` with your actual email address.

---

### Step 6: Expose ArgoCD with Automated TLS

Create an Ingress resource with SSL passthrough for full gRPC support:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.randomtechy.tech
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              name: https
  tls:
  - hosts:
    - argocd.randomtechy.tech
    secretName: argocd-tls
EOF
```

Monitor certificate issuance:

```bash
kubectl get certificate -n argocd -w
```

Wait for `READY: True` status (10-15 minutes).

---

### Step 7: Access ArgoCD UI

Retrieve the initial admin password:

```bash
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
echo "ArgoCD Password: $ARGOCD_PASSWORD"
```

Access the UI:

```bash
open https://argocd.randomtechy.tech
```

**Credentials:**
- Username: `admin`
- Password: (from above command)

---

### Step 8: Create and Register Spoke Clusters

Deploy spoke clusters:

```bash
# Spoke Cluster 1
eksctl create cluster --name spoke-cluster-1 --region us-east-1 --nodes 2 --node-type t2.medium
# Spoke Cluster 2
eksctl create cluster --name spoke-cluster-2 --region us-east-1 --nodes 2 --node-type t2.medium
```

**Wait time:** ~30-40 minutes total (both clusters)

Do this immediately after spoke-cluster-2 finishes so that you remain hub-cluster's context
```bash
kubectl config get-contexts
kubectl config use-context <hub-cluster-context>
kubectl config current-context
```
or you can try this command too to save time:
```bash
kubectl config use-context $(kubectl config get-contexts -o name | grep hub-cluster)
```

Login to ArgoCD CLI:

```bash
argocd login argocd.randomtechy.tech --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d) --insecure
```

Register spoke clusters with ArgoCD:

```bash
# Add spoke-cluster-1
argocd cluster add spoke-cluster-1 --name spoke-1 --label environment=spoke

# Add spoke-cluster-2
argocd cluster add spoke-cluster-2 --name spoke-2 --label environment=spoke
```

Verify cluster registration:

```bash
argocd cluster list
```

---

### Step 9: Deploy Application via ApplicationSet

Deploy the sample application to all spoke clusters automatically:

```bash
kubectl apply -f applicationsets/applicationset-color-palette.yaml
```

Monitor deployment status:

```bash
argocd app list
```

You should see applications created for each spoke cluster automatically.

Verify deployment in spoke clusters:

```bash
# Switch to spoke-cluster-1
kubectl config use-context spoke-cluster-1
kubectl get pods -n color-palette

# Switch to spoke-cluster-2
kubectl config use-context spoke-cluster-2
kubectl get pods -n color-palette
```

---

## ✅ Validation & Testing

### Health Checks

```bash
# ArgoCD server health
kubectl get pods -n argocd

# Certificate status
kubectl get certificate -n argocd argocd-tls -o yaml

# Ingress status
kubectl get ingress -n argocd

# ApplicationSet status
kubectl get applicationset -n argocd
```

### Functional Tests

1. **UI Access:** Visit `https://argocd.randomtechy.tech` (should show valid certificate)
2. **CLI Operations:** Run `argocd app list` (should work without errors)
3. **Sync Test:** Modify a manifest in Git and watch ArgoCD sync automatically
4. **Multi-cluster:** Verify apps deployed to all spoke clusters

---

## 🔍 Troubleshooting

### Certificate Not Issuing

```bash
# Check certificate status
kubectl describe certificate argocd-tls -n argocd

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Verify DNS propagation
nslookup argocd.randomtechy.tech
```

### ArgoCD Server Not Accessible

```bash
# Check ingress
kubectl get ingress -n argocd
kubectl describe ingress argocd-server -n argocd

# Check NGINX logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Verify service
kubectl get svc -n argocd argocd-server
```

### Cluster Registration Issues

```bash
# Verify kubeconfig
kubectl config get-contexts

# Check ArgoCD cluster secrets
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster

# Re-add cluster
argocd cluster add <cluster-context> --name <cluster-name> --upsert
```

### ApplicationSet Not Creating Apps

```bash
# Check ApplicationSet status
kubectl get applicationset -n argocd
kubectl describe applicationset color-palette -n argocd

# Verify cluster labels
argocd cluster list

# Check ArgoCD ApplicationSet controller logs
kubectl logs -n argocd deployment/argocd-applicationset-controller
```

---

## 🧹 Cleanup

To avoid AWS charges, delete all resources:

```bash
# Delete spoke clusters
eksctl delete cluster --name spoke-cluster-1 --region us-east-1
eksctl delete cluster --name spoke-cluster-2 --region us-east-1

# Delete hub cluster
eksctl delete cluster --name hub-cluster --region us-east-1
```

**Note:** This will delete all Load Balancers, volumes, and associated AWS resources.

---

## 🛠 Technologies

| Technology | Purpose | Version |
|------------|---------|---------|
| **AWS EKS** | Managed Kubernetes clusters | Latest |
| **ArgoCD** | GitOps continuous delivery | v2.12+ |
| **ApplicationSet** | Multi-cluster app deployment | v2.12+ |
| **cert-manager** | Automated TLS certificate management | v1.16+ |
| **Let's Encrypt** | Free SSL/TLS certificates | ACME v2 |
| **NGINX Ingress** | Kubernetes ingress controller | Latest |
| **Helm** | Kubernetes package manager | v3.x |
| **eksctl** | EKS cluster provisioning | v0.175+ |

---
## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🌟 Acknowledgments

- ArgoCD community for excellent documentation
- cert-manager maintainers for seamless TLS automation
- AWS EKS team for managed Kubernetes excellence

---

<div align="center">

**⭐ Star this repository if you find it helpful!**

Built with ❤️ for the DevOps community

</div>
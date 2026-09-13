# 🚀 End-to-End DevSecOps Kubernetes Project

[![GitHub](https://img.shields.io/github/stars/iam-aniket-dutta/DevSecOps_Project_React_Jenkins_EKS_Terraform_AWS.svg?style=social)](https://github.com/iam-aniket-dutta/DevSecOps_Project_React_Jenkins_EKS_Terraform_AWS)
![DevSecOps](https://img.shields.io/badge/DevSecOps-Mastery-brightgreen)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Orchestration-blueviolet)
![Jenkins](https://img.shields.io/badge/Jenkins-Automation-orange)
![ArgoCD](https://img.shields.io/badge/ArgoCD-Continuous%20Delivery-blue)
![Docker](https://img.shields.io/badge/Docker-Containerization-blue)
![Terraform](https://img.shields.io/badge/Terraform-Infrastructure%20as%20Code-9cf)

---

## 📌 Project Overview

This project is an end-to-end **DevSecOps** implementation that deploys a **Tetris React** application on **AWS EKS** (Elastic Kubernetes Service) using a fully automated CI/CD pipeline. It demonstrates how to integrate security scanning, code quality analysis, containerization, and GitOps-based continuous deployment into a single, cohesive workflow.

**The core flow is:**

1. **Provision Infrastructure** — Terraform creates a Jenkins EC2 server with all DevSecOps tools pre-installed, and provisions an EKS cluster on AWS.
2. **CI Pipeline (Jenkins)** — Builds, scans, and pushes Docker images of the Tetris application with security gates at every stage.
3. **CD Pipeline (ArgoCD)** — Watches the Git repository for Kubernetes manifest changes and automatically deploys the updated application to EKS.

![Infrastructure Diagram](assets/Infra.gif)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            DEVELOPER WORKSTATION                            │
│   git push ──► GitHub Repository                                            │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │  Webhook / Poll
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      JENKINS SERVER (EC2 - t3a.xlarge)                      │
│                                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────┐  ┌──────────────────────┐ │
│  │   Jenkins    │  │  SonarQube   │  │  Docker   │  │  DevSecOps Tools     │ │
│  │   :8080      │  │  :9000       │  │  Engine   │  │  Trivy, OWASP, TF,  │ │
│  │             │  │  (Container) │  │           │  │  kubectl, AWS CLI    │ │
│  └──────┬──────┘  └──────────────┘  └─────┬─────┘  └──────────────────────┘ │
│         │                                  │                                 │
│   CI Pipeline Stages:                      │                                 │
│   1. Checkout Code                         │                                 │
│   2. SonarQube Analysis ───────────────────┘                                │
│   3. Quality Gate Check                                                      │
│   4. npm install                                                             │
│   5. OWASP Dependency-Check                                                  │
│   6. Trivy Filesystem Scan                                                   │
│   7. Docker Build & Push ──────────────────► Docker Hub                      │
│   8. Trivy Image Scan                       (aniketnitu2026/tetris)          │
│   9. Update K8s Manifest ──────────────────► GitHub (k8s-manifests/)         │
└─────────────────────────────────────────────────────────────────────────────┘
                                                        │
                                                        │  GitOps Sync
                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AWS EKS CLUSTER (Tetris-EKS-Cluster)                 │
│                                                                             │
│   ┌───────────────┐     ┌──────────────────────────────────────────┐        │
│   │    ArgoCD      │────►│  Tetris Deployment (3 replicas)          │        │
│   │  (GitOps CD)   │     │  Image: aniketnitu2026/tetris:<BUILD_#> │        │
│   └───────────────┘     │  Service: LoadBalancer :80 → :3000       │        │
│                          └──────────────────────────────────────────┘        │
│                                                                             │
│   Node Group: Tetris-Node-Group (t3a.medium, 1–3 nodes, 20 GB disk)        │
│   VPC: Reuses Jenkins-vpc | Subnets: us-east-1a, us-east-1b               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📂 Project Structure

```
DevSecOps_Project_EKS_Jenkins_Terraform_ArgoCD/
│
├── frontend/                      # Tetris React Application (source code)
│   ├── v1/                        #   Version 1 — Classic Tetris (React 17)
│   │   ├── Dockerfile             #     Node 16-Alpine container, exposes :3000
│   │   ├── nginx.conf             #     Nginx config (SPA routing, gzip, security headers)
│   │   ├── package.json           #     Dependencies: react, react-dom, react-scripts
│   │   ├── src/                   #     Application source code
│   │   └── public/                #     Static assets
│   └── v2/                        #   Version 2 — Enhanced Tetris (React 16 + animations)
│       ├── Dockerfile             #     Node 16-Alpine container, exposes :3000
│       ├── nginx.conf             #     Nginx config (identical to v1)
│       ├── package.json           #     Dependencies: react, styled-components, react-spring
│       ├── src/                   #     Application source code
│       └── public/                #     Static assets
│
├── jenkins-server/                # Terraform module: Jenkins EC2 Server
│   ├── backend.tf                 #   S3 remote state configuration
│   ├── provider.tf                #   AWS provider (us-east-1)
│   ├── vpc.tf                     #   VPC, Subnet, IGW, Route Table, Security Group
│   ├── ec2.tf                     #   EC2 instance (t3a.xlarge, 50GB gp3, IMDSv2)
│   ├── iam-role.tf                #   IAM Role with EC2 trust policy
│   ├── iam-policy.tf              #   IAM Policy attachment (AdministratorAccess)
│   ├── iam-instance-profile.tf    #   IAM Instance Profile for EC2
│   ├── output.tf                  #   Outputs: IP, URLs, SSH commands
│   ├── variables.tf               #   Variable declarations
│   ├── variables.tfvars           #   Variable values (AMI, names, key pair)
│   ├── tools-install.sh           #   User Data script (Java, Jenkins, Docker, SonarQube,
│   │                              #     Terraform, kubectl, AWS CLI, Trivy)
│   └── PROVISIONING_GUIDE.md      #   Detailed provisioning walkthrough
│
├── eks/                           # Terraform module: AWS EKS Cluster
│   ├── backend.tf                 #   S3 remote state configuration
│   ├── provider.tf                #   AWS provider (us-east-1)
│   ├── vpc.tf                     #   Data sources for existing Jenkins VPC + new subnet
│   ├── eks-cluster.tf             #   EKS Cluster resource (Kubernetes v1.33)
│   ├── eks-node-group.tf          #   Managed Node Group (t3a.medium, 1–3 nodes)
│   ├── iam-role.tf                #   IAM Roles (EKSClusterRole, EKSNodeGroupRole)
│   ├── iam-policy.tf              #   IAM Policy attachments (EKS, EC2, CNI)
│   ├── variables.tf               #   Variable declarations
│   └── variables.tfvars           #   Variable values (cluster name, node group, IAM)
│
├── jenkins/                       # Jenkins Declarative Pipeline Definitions
│   ├── Jenkinsfile-TetrisV1       #   CI/CD pipeline for frontend/v1
│   ├── Jenkinsfile-TetrisV2       #   CI/CD pipeline for frontend/v2
│   └── Jenkinsfile-EKS-Terraform  #   Parameterized pipeline for EKS provisioning
│
├── k8s-manifests/                 # Kubernetes Deployment Manifests
│   ├── deployment-service.yml     #   Deployment (3 replicas) + LoadBalancer Service
│   └── ingress.yaml               #   ALB Ingress resource (commented out — optional)
│
├── assets/                        # Documentation assets
│   └── Infra.gif                  #   Infrastructure architecture diagram
│
├── Process.md                     # Step-by-step setup & deployment process
├── README.md                      # This file
└── .gitignore                     # Git ignore rules (Terraform state, node_modules, etc.)
```

---

## 🛠️ Tools & Technologies

| Category | Tool | Purpose |
|---|---|---|
| **CI/CD** | Jenkins | Declarative pipeline automation for build, test, scan, and deploy |
| **GitOps CD** | ArgoCD | Watches Git for K8s manifest changes and auto-syncs to EKS |
| **IaC** | Terraform (≥ 1.13.3) | Provisions Jenkins EC2, VPC, EKS Cluster, IAM Roles |
| **Cloud** | AWS (EC2, EKS, S3, IAM, VPC) | Compute, Kubernetes, state storage, networking |
| **Containerization** | Docker | Builds and packages the Tetris app as container images |
| **Container Registry** | Docker Hub | Stores versioned Docker images (`aniketnitu2026/tetris`) |
| **Code Quality** | SonarQube (Community) | Static analysis, code smells, quality gates |
| **Vulnerability Scanning** | Trivy (Aqua Security) | Filesystem and container image vulnerability scanning |
| **Dependency Audit** | OWASP Dependency-Check | Scans npm dependencies for known CVEs |
| **Orchestration** | Kubernetes (EKS v1.33) | Runs the Tetris app with Deployments, Services, and Ingress |
| **Frontend** | React (v1: React 17, v2: React 16) | Tetris game application |
| **CLI Tools** | kubectl v1.33.5, AWS CLI v2 | Cluster management and AWS interaction |

---

## 🔧 Component Deep Dive

### `jenkins-server/` — Jenkins EC2 Infrastructure

Provisions a **t3a.xlarge** Ubuntu 22.04 EC2 instance in a dedicated VPC with all DevSecOps tools pre-installed via `tools-install.sh` (Cloud-Init User Data). The instance gets an IAM Instance Profile with the necessary permissions for EKS and Terraform operations.

**Key resources created:**
- VPC (`10.0.0.0/16`) with public subnet, IGW, and route table
- Security Group allowing ports `22` (SSH), `8080` (Jenkins), `9000` (SonarQube)
- 50 GB `gp3` encrypted root volume with IMDSv2 enforcement
- SonarQube running as a Docker container with persistent volumes

> 📖 See [`jenkins-server/PROVISIONING_GUIDE.md`](jenkins-server/PROVISIONING_GUIDE.md) for the complete provisioning walkthrough.

---

### `eks/` — EKS Cluster Infrastructure

Provisions an **Amazon EKS cluster** (Kubernetes v1.33) that **reuses the Jenkins VPC** by referencing existing networking resources via Terraform `data` sources. Creates a second public subnet in `us-east-1b` for multi-AZ availability.

**Key resources created:**
- EKS Cluster (`Tetris-EKS-Cluster`) with two IAM roles:
  - `EKSClusterRole` — for the EKS control plane
  - `EKSNodeGroupRole` — for worker nodes (with EKS Worker, CNI, and ECR policies)
- Managed Node Group (`Tetris-Node-Group`): `t3a.medium` instances, scaling 1–3 nodes, 20 GB disk

---

### `jenkins/` — CI/CD Pipeline Definitions

Three Jenkins Declarative Pipelines:

| Pipeline | Purpose |
|---|---|
| **`Jenkinsfile-TetrisV1`** | Full CI/CD for `frontend/v1` — scan, build, push, update K8s manifest |
| **`Jenkinsfile-TetrisV2`** | Full CI/CD for `frontend/v2` — scan, build, push, update K8s manifest |
| **`Jenkinsfile-EKS-Terraform`** | Parameterized pipeline to `plan`, `apply`, or `destroy` the EKS cluster |

**CI/CD Pipeline Stages (V1/V2):**

```
Clean Workspace → Git Checkout → SonarQube Analysis → Quality Gate →
npm Install → OWASP Dependency-Check → Trivy FS Scan → Docker Build →
Docker Push → Trivy Image Scan → Update K8s Deployment Manifest → Git Push
```

The final stage uses `sed` to update the image tag in `k8s-manifests/deployment-service.yml` to the current `BUILD_NUMBER`, then commits and pushes to GitHub — triggering ArgoCD to sync.

---

### `k8s-manifests/` — Kubernetes Manifests

- **`deployment-service.yml`** — Defines a Tetris `Deployment` (3 replicas) pulling from `aniketnitu2026/tetris:<tag>`, exposed via a `LoadBalancer` Service on port `80 → 3000`.
- **`ingress.yaml`** — Optional ALB Ingress resource (currently commented out). Can be enabled for AWS ALB-based routing.

---

### `frontend/` — Tetris React Application

Two versions of a Tetris game built with React:

| Version | React | Key Libraries | Description |
|---|---|---|---|
| **v1** | 17.0.2 | react-scripts 4.x | Classic Tetris implementation |
| **v2** | 16.12.0 | styled-components, react-spring, react-use-gesture | Enhanced Tetris with animations and touch support |

Both versions use identical Dockerfiles (`node:16-alpine`, exposes port `3000`) and include Nginx configuration for production-grade SPA serving with gzip, caching, and security headers.

---

## 🚀 Getting Started

### Prerequisites

- AWS account with programmatic access configured (`aws configure`)
- Terraform CLI ≥ 1.13.3 installed locally
- An EC2 Key Pair created in `us-east-1`
- An S3 bucket for Terraform remote state

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/iam-aniket-dutta/DevSecOps_Project_React_Jenkins_EKS_Terraform_AWS.git
cd DevSecOps_Project_React_Jenkins_EKS_Terraform_AWS

# 2. Provision the Jenkins server
cd jenkins-server
terraform init
terraform apply -var-file="variables.tfvars" --auto-approve

# 3. Access Jenkins at http://<EC2_PUBLIC_IP>:8080
#    Access SonarQube at http://<EC2_PUBLIC_IP>:9000

# 4. Configure Jenkins (plugins, credentials, tools) — see Process.md

# 5. Run the EKS Terraform pipeline from Jenkins to create the cluster

# 6. Run the TetrisV1 or TetrisV2 pipeline to deploy the application

# 7. Install ArgoCD on EKS and point it to the k8s-manifests/ directory
```

> 📖 For the complete step-by-step setup and deployment process, see **[`Process.md`](Process.md)**.

---

## 📝 Documentation

| Document | Description |
|---|---|
| [`README.md`](README.md) | Project overview, architecture, and structure (this file) |
| [`Process.md`](Process.md) | Complete step-by-step setup and deployment process |
| [`jenkins-server/PROVISIONING_GUIDE.md`](jenkins-server/PROVISIONING_GUIDE.md) | Detailed Jenkins server Terraform provisioning guide |

---

## ⚠️ Security Notes

- The Jenkins IAM role uses `AdministratorAccess` for demonstration purposes. **In production, use least-privilege IAM policies.**
- SonarQube default credentials (`admin`/`admin`) should be changed immediately after first login.
- Security Group allows ingress from `0.0.0.0/0` — restrict to your IP range in production.
- Sensitive tokens (SonarQube, GitHub, Docker Hub) are stored as Jenkins Credentials, never hardcoded.

---

## 📄 License

This project is licensed under the Apache-2.0 License — see the [LICENSE](http://www.apache.org/licenses/) for details.
# Process.md — Complete Setup & Deployment Guide

This document covers the **end-to-end process** for setting up and deploying the DevSecOps Tetris project, from provisioning infrastructure to running the CI/CD pipeline and deploying on AWS EKS.

---

## Table of Contents

1. [Phase 1: Provision the Jenkins Server](#phase-1-provision-the-jenkins-server)
2. [Phase 2: Access & Initialize Jenkins](#phase-2-access--initialize-jenkins)
3. [Phase 3: Install Jenkins Plugins](#phase-3-install-jenkins-plugins)
4. [Phase 4: Configure Jenkins Tools](#phase-4-configure-jenkins-tools)
5. [Phase 5: Configure SonarQube](#phase-5-configure-sonarqube)
6. [Phase 6: Configure Jenkins Credentials](#phase-6-configure-jenkins-credentials)
7. [Phase 7: Configure SonarQube Webhook](#phase-7-configure-sonarqube-webhook)
8. [Phase 8: Provision the EKS Cluster via Jenkins](#phase-8-provision-the-eks-cluster-via-jenkins)
9. [Phase 9: Configure kubectl & EKS Access](#phase-9-configure-kubectl--eks-access)
10. [Phase 10: Run the CI/CD Pipeline (TetrisV1/V2)](#phase-10-run-the-cicd-pipeline-tetrisv1v2)
11. [Phase 11: Install & Configure ArgoCD](#phase-11-install--configure-argocd)
12. [Phase 12: Verify the Deployment](#phase-12-verify-the-deployment)
13. [Phase 13: Teardown & Cleanup](#phase-13-teardown--cleanup)

---

## Phase 1: Provision the Jenkins Server

The Jenkins server is provisioned as an EC2 instance using Terraform. The `tools-install.sh` User Data script automatically installs all required tools on first boot.

### Prerequisites

| Requirement | Details |
|---|---|
| AWS CLI | Configured with IAM credentials (`aws configure`) |
| Terraform | Version ≥ 1.13.3 installed locally |
| EC2 Key Pair | Created in `us-east-1` (default name: `cicd` — configured in `variables.tfvars`) |
| S3 Bucket | For Terraform remote state (configured in `backend.tf`) |

### Steps

```bash
# Navigate to the jenkins-server Terraform module
cd jenkins-server

# Initialize Terraform (downloads providers, connects to S3 backend)
terraform init

# Validate the configuration
terraform validate

# Preview the execution plan
terraform plan -var-file="variables.tfvars"

# Apply and provision the infrastructure
terraform apply -var-file="variables.tfvars" --auto-approve
```

### What Gets Provisioned

| Resource | Details |
|---|---|
| **VPC** | `Jenkins-vpc` (`10.0.0.0/16`) |
| **Subnet** | `Jenkins-subnet` (`10.0.1.0/24`) in `us-east-1a`, public IP enabled |
| **Internet Gateway** | `Jenkins-igw` attached to the VPC |
| **Route Table** | `Jenkins-route-table` with `0.0.0.0/0 → IGW` |
| **Security Group** | `Jenkins-sg` — allows inbound on ports `22`, `8080`, `9000` |
| **IAM Role** | `Jenkins-iam-role` with EC2 trust policy |
| **IAM Policy** | `AdministratorAccess` attached (demo only — use least-privilege in production) |
| **EC2 Instance** | `t3a.xlarge`, Ubuntu 22.04, 50 GB `gp3` encrypted, IMDSv2 enforced |

### Tools Installed via User Data (`tools-install.sh`)

The following tools are automatically installed when the instance boots:

| # | Tool | Version / Source | Purpose |
|---|---|---|---|
| 1 | **Java (OpenJDK 21)** | `openjdk-21-jre` | Jenkins runtime dependency |
| 2 | **Jenkins** | Latest LTS from `pkg.jenkins.io` | CI/CD automation server (port `8080`) |
| 3 | **Docker** | `docker.io` from Ubuntu repos | Container build and runtime engine |
| 4 | **SonarQube** | `sonarqube:community` Docker image | Code quality analysis server (port `9000`) |
| 5 | **Terraform** | Latest from HashiCorp APT repo | Infrastructure as Code CLI |
| 6 | **kubectl** | v1.33.5 | Kubernetes cluster management CLI |
| 7 | **AWS CLI** | v2 (official bundle) | AWS service interaction |
| 8 | **Trivy** | Latest from Aqua Security repo | Container/filesystem vulnerability scanner |

### Terraform Outputs

After a successful apply, note these outputs:

```
ec2_public_ip                        = "<IP_ADDRESS>"
jenkins_url                          = "http://<IP_ADDRESS>:8080"
sonarqube_url                        = "http://<IP_ADDRESS>:9000"
ssh_connection_command               = "ssh -i \"cicd.pem\" ubuntu@<IP_ADDRESS>"
jenkins_initial_admin_password_command = "ssh -i \"cicd.pem\" ubuntu@<IP_ADDRESS> \"sudo cat /var/lib/jenkins/secrets/initialAdminPassword\""
```

> ⏳ **Wait 3–5 minutes** after `terraform apply` completes for all tools to finish installing (monitor with `tail -f /var/log/cloud-init-output.log` on the instance).

> 📖 For a deeper dive into the provisioning process, see [`jenkins-server/PROVISIONING_GUIDE.md`](jenkins-server/PROVISIONING_GUIDE.md).

---

## Phase 2: Access & Initialize Jenkins

### Step 1: Get the Initial Admin Password

```bash
# Option A: SSH into the instance and read the file
ssh -i "cicd.pem" ubuntu@<EC2_PUBLIC_IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Option B: Use the Terraform output command directly
ssh -i "cicd.pem" ubuntu@<EC2_PUBLIC_IP> "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
```

### Step 2: Unlock Jenkins

1. Open your browser and navigate to `http://<EC2_PUBLIC_IP>:8080`.
2. Paste the initial admin password from Step 1.
3. Click **"Install suggested plugins"** and wait for installation to complete.
4. Create your first admin user when prompted.
5. Confirm the Jenkins URL and click **"Start using Jenkins"**.

---

## Phase 3: Install Jenkins Plugins

Navigate to **Manage Jenkins → Plugins → Available Plugins** and install the following:

### Required Plugins

| Plugin | Purpose |
|---|---|
| **AWS Credentials** | Securely store and use AWS access keys in pipelines |
| **Pipeline: AWS Steps** | Provides the `withAWS` step for Terraform/EKS pipelines |
| **Pipeline Stage View** | Visual pipeline stage execution view |
| **Rebuilder** | Adds "Rebuild" button to re-run builds with same parameters |
| **Docker** | Docker integration for Jenkins |
| **Docker Commons** | Shared Docker functionality across plugins |
| **Docker API** | Docker API client for Jenkins |
| **Docker Build Step** | Build Docker images as a build step |
| **Docker Pipeline** | Use Docker in Jenkins pipelines (`withDockerRegistry`) |
| **NodeJS** | Manage Node.js installations and use `npm` in pipelines |
| **SonarQube Scanner** | SonarQube integration for code quality analysis |
| **OWASP Dependency-Check** | Dependency vulnerability scanning |

> 💡 After installing all plugins, **restart Jenkins** when prompted.

---

## Phase 4: Configure Jenkins Tools

Navigate to **Manage Jenkins → Tools** and configure the following global tool installations:

### 4.1 — NodeJS Installation

1. Scroll to **NodeJS** section, click **"Add NodeJS"**.
2. **Name**: `nodejs`  
   *(Must match `tools { nodejs 'nodejs' }` in the Jenkinsfiles)*
3. **Install automatically**: ✅ Checked
4. Select a Node.js version (e.g., `16.x` to match the Dockerfiles).

### 4.2 — SonarQube Scanner Installation

1. Scroll to **SonarQube Scanner** section, click **"Add SonarQube Scanner"**.
2. **Name**: `sonar-scanner`  
   *(Must match `tool 'sonar-scanner'` in the Jenkinsfiles)*
3. **Install automatically**: ✅ Checked
4. Select the latest version.

### 4.3 — OWASP Dependency-Check Installation

1. Scroll to **Dependency-Check** section, click **"Add Dependency-Check"**.
2. **Name**: `DP-Check`  
   *(Must match `odcInstallation: 'DP-Check'` in the Jenkinsfiles)*
3. **Install automatically**: ✅ Checked
4. Select **"Install from GitHub"** with the latest version.

> 💾 Click **Save** at the bottom of the Tools page.

---

## Phase 5: Configure SonarQube

### Step 1: Access SonarQube

1. Open your browser and navigate to `http://<EC2_PUBLIC_IP>:9000`.
2. Log in with default credentials:
   - **Username**: `admin`
   - **Password**: `admin`
3. **Change the password** when prompted (mandatory on first login).

### Step 2: Generate a SonarQube Authentication Token

1. Click on your profile icon (top-right) → **My Account** → **Security** tab.
2. Under **Generate Tokens**:
   - **Name**: `jenkins`
   - **Type**: `Global Analysis Token`
   - **Expires in**: No expiration (or choose a suitable duration).
3. Click **Generate** and **copy the token immediately** (it won't be shown again).
   - Example: `squ_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### Step 3: Configure SonarQube Server in Jenkins

1. Go to **Manage Jenkins → System** (or **Configure System**).
2. Scroll to **SonarQube Servers** section.
3. Check **"Environment variables"**.
4. Click **"Add SonarQube"**:
   - **Name**: `sonar-server`  
     *(Must match `SONAR_SERVER = 'sonar-server'` in the Jenkinsfiles)*
   - **Server URL**: `http://<EC2_PUBLIC_IP>:9000`
   - **Server authentication token**: Select the `sonar-token` credential (created in Phase 6).
5. Click **Save**.

---

## Phase 6: Configure Jenkins Credentials

Navigate to **Manage Jenkins → Credentials → System → Global credentials (unrestricted)** and add the following credentials:

### 6.1 — SonarQube Token

| Field | Value |
|---|---|
| **Kind** | Secret text |
| **Secret** | `<SonarQube token from Phase 5>` |
| **ID** | `sonar-token` |
| **Description** | SonarQube authentication token |

### 6.2 — Docker Hub Credentials

| Field | Value |
|---|---|
| **Kind** | Username with password |
| **Username** | Your Docker Hub username (e.g., `aniketnitu2026`) |
| **Password** | Your Docker Hub password or access token |
| **ID** | `docker` |
| **Description** | Docker Hub registry credentials |

### 6.3 — GitHub Personal Access Token

| Field | Value |
|---|---|
| **Kind** | Secret text |
| **Secret** | Your GitHub PAT (with `repo` scope for pushing manifest updates) |
| **ID** | `github` |
| **Description** | GitHub personal access token for K8s manifest updates |

### 6.4 — AWS Credentials

| Field | Value |
|---|---|
| **Kind** | AWS Credentials |
| **Access Key ID** | Your AWS access key ID |
| **Secret Access Key** | Your AWS secret access key |
| **ID** | `aws-key` |
| **Description** | AWS credentials for Terraform EKS provisioning |

> ⚠️ **Security**: Never hardcode tokens or credentials in pipeline scripts. Always use Jenkins Credentials.

---

## Phase 7: Configure SonarQube Webhook

A webhook allows SonarQube to notify Jenkins when a quality gate analysis is complete (used by the `waitForQualityGate` step).

### Steps

1. In **SonarQube**, go to **Administration → Configuration → Webhooks**.
2. Click **Create**.
3. Configure:
   - **Name**: `jenkins`
   - **URL**: `http://<EC2_PUBLIC_IP>:8080/sonarqube-webhook/`
   - **Secret**: *(leave blank or set a shared secret)*
4. Click **Create**.

---

## Phase 8: Provision the EKS Cluster via Jenkins

The EKS cluster is provisioned through a **parameterized Jenkins pipeline** using the `Jenkinsfile-EKS-Terraform`.

### Step 1: Create the Jenkins Pipeline Job

1. In Jenkins, click **New Item**.
2. **Name**: `EKS-Terraform` (or any descriptive name).
3. **Type**: Select **Pipeline**.
4. Click **OK**.

### Step 2: Configure the Pipeline

1. In the pipeline configuration:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/iam-aniket-dutta/DevSecOps_Project_React_Jenkins_EKS_Terraform_AWS.git`
   - **Branch**: `*/main`
   - **Script Path**: `jenkins/Jenkinsfile-EKS-Terraform`
2. Click **Save**.

### Step 3: Run the Pipeline

1. Click **"Build with Parameters"**.
2. Set:
   - **File-Name**: `variables.tfvars` (default)
   - **Terraform-Action**: `apply`
3. Click **Build**.

The pipeline will:
1. Checkout the repository.
2. Run `terraform init` in the `eks/` directory.
3. Run `terraform validate`.
4. Run `terraform plan -var-file=variables.tfvars`.
5. Run `terraform apply -auto-approve -var-file=variables.tfvars`.

> ⏳ EKS cluster provisioning typically takes **10–15 minutes**.

---

## Phase 9: Configure kubectl & EKS Access

After the EKS cluster is provisioned, configure `kubectl` on the Jenkins server to interact with it.

### Step 1: SSH into the Jenkins Server

```bash
ssh -i "cicd.pem" ubuntu@<EC2_PUBLIC_IP>
```

### Step 2: Update kubeconfig

```bash
aws eks update-kubeconfig --name Tetris-EKS-Cluster --region us-east-1
```

### Step 3: Verify Cluster Access

```bash
kubectl get nodes
kubectl cluster-info
```

You should see the worker nodes in `Ready` status.

---

## Phase 10: Run the CI/CD Pipeline (TetrisV1/V2)

### Step 1: Create the Pipeline Job

1. In Jenkins, click **New Item**.
2. **Name**: `Tetris-V1` (or `Tetris-V2`).
3. **Type**: Select **Pipeline**.
4. Click **OK**.

### Step 2: Configure the Pipeline

1. In the pipeline configuration:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/iam-aniket-dutta/DevSecOps_Project_React_Jenkins_EKS_Terraform_AWS.git`
   - **Branch**: `*/main`
   - **Script Path**: `jenkins/Jenkinsfile-TetrisV1` (or `jenkins/Jenkinsfile-TetrisV2`)
2. Click **Save**.

### Step 3: Run the Pipeline

Click **"Build Now"**. The pipeline executes the following stages:

| # | Stage | Description |
|---|---|---|
| 1 | **Cleaning Workspace** | Wipes the Jenkins workspace for a clean build |
| 2 | **Checkout from Git** | Clones the repository from GitHub |
| 3 | **SonarQube Analysis** | Runs `sonar-scanner` against `frontend/v1` (or `v2`) |
| 4 | **Quality Check** | Waits for SonarQube quality gate result |
| 5 | **Installing Dependencies** | Runs `npm install` in the frontend directory |
| 6 | **OWASP Dependency-Check** | Scans npm dependencies for known CVEs |
| 7 | **Trivy File Scan** | Scans the filesystem for vulnerabilities |
| 8 | **Docker Image Build** | Builds the Docker image (`tetrisv1`/`tetrisv2`) |
| 9 | **Docker Image Push** | Tags and pushes to Docker Hub as `aniketnitu2026/tetris:<BUILD_NUMBER>` |
| 10 | **Trivy Image Scan** | Scans the pushed Docker image for vulnerabilities |
| 11 | **Checkout Code** | Re-clones the repo (fresh state for manifest update) |
| 12 | **Update Deployment File** | Uses `sed` to update the image tag in `k8s-manifests/deployment-service.yml`, commits, and pushes to GitHub |

> 💡 The final stage triggers **ArgoCD** to detect the manifest change and auto-deploy the new version to EKS.

---

## Phase 11: Install & Configure ArgoCD

ArgoCD is installed on the EKS cluster and configured to watch the `k8s-manifests/` directory for changes.

### Step 1: Install ArgoCD on EKS

SSH into the Jenkins server and run:

```bash
# Create the ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all ArgoCD pods to be running
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

### Step 2: Expose the ArgoCD Server

```bash
# Expose ArgoCD server via LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get the ArgoCD external URL
kubectl get svc argocd-server -n argocd
```

Note the `EXTERNAL-IP` from the output — this is your ArgoCD dashboard URL.

### Step 3: Get the ArgoCD Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 4: Log in to ArgoCD

1. Open `https://<ARGOCD_EXTERNAL_IP>` in your browser.
2. **Username**: `admin`
3. **Password**: *(from Step 3)*

### Step 5: Create the ArgoCD Application

1. In the ArgoCD UI, click **"+ NEW APP"**.
2. Configure:

| Field | Value |
|---|---|
| **Application Name** | `tetris` |
| **Project** | `default` |
| **Sync Policy** | `Automatic` |
| **Repository URL** | `https://github.com/iam-aniket-dutta/DevSecOps_Project_React_Jenkins_EKS_Terraform_AWS.git` |
| **Revision** | `main` |
| **Path** | `k8s-manifests` |
| **Cluster URL** | `https://kubernetes.default.svc` (in-cluster) |
| **Namespace** | `default` |

3. Click **Create**.

ArgoCD will now automatically sync changes pushed to `k8s-manifests/` by the Jenkins pipeline.

---

## Phase 12: Verify the Deployment

### Step 1: Check Kubernetes Resources

```bash
# Verify the deployment
kubectl get deployments

# Verify the pods (should show 3 replicas)
kubectl get pods

# Verify the service
kubectl get svc tetris-service
```

### Step 2: Access the Application

The `tetris-service` is of type `LoadBalancer`. Get the external URL:

```bash
kubectl get svc tetris-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open the URL in your browser to play Tetris! 🎮

### Step 3: Verify ArgoCD Sync Status

In the ArgoCD dashboard, the `tetris` application should show:
- **Sync Status**: `Synced` ✅
- **Health Status**: `Healthy` 💚

---

## Phase 13: Teardown & Cleanup

When done, destroy the infrastructure to avoid ongoing AWS costs.

### Step 1: Delete ArgoCD Application

In the ArgoCD UI, delete the `tetris` application (or delete resources via `kubectl`):

```bash
kubectl delete -f k8s-manifests/deployment-service.yml
kubectl delete namespace argocd
```

### Step 2: Destroy the EKS Cluster

Run the `EKS-Terraform` Jenkins pipeline with:
- **Terraform-Action**: `destroy`

Or manually from the Jenkins server:

```bash
cd eks
terraform destroy -var-file="variables.tfvars" --auto-approve
```

### Step 3: Destroy the Jenkins Server

From your **local machine**:

```bash
cd jenkins-server
terraform destroy -var-file="variables.tfvars" --auto-approve
```

> ⚠️ **Important**: Destroy the EKS cluster **before** destroying the Jenkins server, since the Jenkins VPC is shared with EKS.

---

## Quick Reference: Credentials Summary

| Credential ID | Type | Used By | Purpose |
|---|---|---|---|
| `sonar-token` | Secret text | Jenkinsfile-TetrisV1/V2 | SonarQube quality gate authentication |
| `docker` | Username/Password | Jenkinsfile-TetrisV1/V2 | Docker Hub push authentication |
| `github` | Secret text | Jenkinsfile-TetrisV1/V2 | GitHub push for K8s manifest updates |
| `aws-key` | AWS Credentials | Jenkinsfile-EKS-Terraform | AWS access for Terraform operations |

## Quick Reference: Jenkins Tool Names

| Tool | Configured Name | Used In |
|---|---|---|
| NodeJS | `nodejs` | `tools { nodejs 'nodejs' }` in Jenkinsfiles |
| SonarQube Scanner | `sonar-scanner` | `tool 'sonar-scanner'` in Jenkinsfiles |
| OWASP Dependency-Check | `DP-Check` | `odcInstallation: 'DP-Check'` in Jenkinsfiles |
| SonarQube Server | `sonar-server` | `withSonarQubeEnv('sonar-server')` in Jenkinsfiles |

## Quick Reference: Port Mapping

| Service | Port | Host |
|---|---|---|
| Jenkins | `8080` | Jenkins EC2 instance |
| SonarQube | `9000` | Jenkins EC2 instance (Docker container) |
| SSH | `22` | Jenkins EC2 instance |
| Tetris App | `3000` | EKS pods (internal) |
| Tetris Service | `80` | EKS LoadBalancer (external) |
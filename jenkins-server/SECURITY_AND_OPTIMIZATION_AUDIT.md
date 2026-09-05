# Jenkins Server Infrastructure - Architecture & Security Audit Report

## 1. Executive Summary & Overview

The `jenkins-server` folder contains Terraform configurations and bootstrap scripts designed to provision a standalone CI/CD and DevSecOps controller on AWS. 

### Architecture Summary
- **Cloud Provider**: AWS (`us-east-1`)
- **Compute**: Single EC2 instance (`t3a.2xlarge` with 8 vCPUs, 32 GB RAM, 30 GB EBS root volume).
- **Networking**: Dedicated VPC (`10.0.0.0/16`), single public subnet (`10.0.1.0/24` in `us-east-1a`), Internet Gateway, Route Table, and Public Security Group.
- **IAM**: EC2 Instance Profile with an IAM Role assumed by `ec2.amazonaws.com`.
- **State Management**: Terraform Remote S3 backend (`dev-aman-tf-bucket`) with S3 native locking (`use_lockfile = true`) and server-side encryption.
- **Bootstrap Automation (`tools-install.sh`)**: Installs OpenJDK 21, Jenkins LTS, Docker CE, SonarQube (via container), Terraform CLI, Kubectl (v1.33.5), AWS CLI v2, and Trivy.

---

## 2. File-by-File Technical Breakdown

| File | Purpose & Technical Details |
| :--- | :--- |
| [`provider.tf`](./provider.tf) | Configures AWS provider in `us-east-1`. |
| [`backend.tf`](./backend.tf) | Sets S3 backend (`dev-aman-tf-bucket`), S3 native state locking (`use_lockfile = true`), and Terraform / AWS provider minimum version constraints. |
| [`gather.tf`](./gather.tf) | Data source querying the latest Ubuntu 22.04 LTS AMI (`ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*`). |
| [`vpc.tf`](./vpc.tf) | Provisions VPC, Internet Gateway, 1 public subnet, Route Table, Route Table Association, and Security Group opening ports 22, 8080, and 9000 to `0.0.0.0/0`. |
| [`ec2.tf`](./ec2.tf) | Provisions the `t3a.2xlarge` EC2 instance, associates IAM instance profile, configures 30GB root volume, and attaches `tools-install.sh` as `user_data`. |
| [`iam-role.tf`](./iam-role.tf) | Creates IAM Role with trust relationship for EC2 (`sts:AssumeRole`). |
| [`iam-policy.tf`](./iam-policy.tf) | Attaches `AdministratorAccess` managed policy to the IAM Role. |
| [`iam-instance-profile.tf`](./iam-instance-profile.tf) | Wraps the IAM role into an instance profile for EC2 association. |
| [`variables.tf`](./variables.tf) | Declares variable definitions (VPC name, Subnet name, SG name, Instance name, Key name, etc.). |
| [`variables.tfvars`](./variables.tfvars) | Supplies runtime parameter values for variables. |
| [`tools-install.sh`](./tools-install.sh) | User-data script bootstrapping all DevSecOps pipeline tooling. |

---

## 3. Security Vulnerabilities & Risks Analysis

### 🔴 Critical Security Issues

#### 1. Full AWS Account Takeover Risk via `AdministratorAccess`
- **Location**: `iam-policy.tf:4`
- **Issue**: Attaching `arn:aws:iam::aws:policy/AdministratorAccess` to an EC2 instance profile means any malicious code, compromised Jenkins plugin, vulnerable build script, or container breakout grants complete control over your AWS account (including IAM, billing, deletion of clusters/databases).
- **Remediation**: Replace with a scoped least-privilege IAM policy granting only required permissions (e.g., ECR push/pull, EKS cluster description, S3 artifact access).

#### 2. Open Ingress to Public Internet (`0.0.0.0/0` and `::/0`)
- **Location**: `vpc.tf:49-61`
- **Issue**: Ports `22` (SSH), `8080` (Jenkins Web UI), and `9000` (SonarQube Web UI) are completely open to the world.
  - Port 22 invites automated brute-force attacks.
  - Jenkins & SonarQube initialization wizards and login forms are directly exposed to the public internet, creating an immediate hijack risk prior to setting admin credentials.
- **Remediation**:
  - Restrict Port 22 / 8080 / 9000 ingress to specific trusted IPs (e.g., your office/home IP: `x.x.x.x/32`).
  - Or eliminate SSH Port 22 entirely and use **AWS Systems Manager (SSM) Session Manager**.
  - Place Jenkins/SonarQube behind an Application Load Balancer (ALB) with HTTPS and AWS WAF.

#### 3. Insecure Docker Socket Permissions (`chmod 777 /var/run/docker.sock`)
- **Location**: `tools-install.sh:24`
- **Issue**: Giving `777` permissions to `/var/run/docker.sock` allows any local user or low-privilege process to communicate directly with the Docker daemon. Anyone can spawn a container mounting the host root filesystem (`-v /:/host`) and gain root access to the EC2 host.
- **Remediation**: Remove `chmod 777`. Since `jenkins` and `ubuntu` users are already added to the `docker` group (`usermod -aG docker`), standard `0660` socket permissions are sufficient.

#### 4. Missing IMDSv2 Enforcement (SSRF IAM Credential Theft)
- **Location**: `ec2.tf` (missing `metadata_options`)
- **Issue**: When IMDSv2 is not enforced (`http_tokens = "required"`), any Server-Side Request Forgery (SSRF) flaw in Jenkins plugins, SonarQube, or webhooks can be leveraged to query `http://169.254.169.254/latest/meta-data/iam/security-credentials/` and steal AWS IAM credentials without authentication tokens.
- **Remediation**: Add `metadata_options { http_tokens = "required", http_endpoint = "enabled" }` in `aws_instance.ec2`.

---

### 🟡 Medium Security Issues

#### 5. Unencrypted EBS Root Volume
- **Location**: `ec2.tf:8-10`
- **Issue**: The root EBS volume is created without explicit KMS encryption (`encrypted = true`), violating security compliance standards.
- **Remediation**: Add `encrypted = true` and optionally specify a customer-managed KMS key.

#### 6. Unverified / Hardcoded AMI Owner ID
- **Location**: `gather.tf:9`
- **Issue**: `owners = ["084828561354"]`. Official Canonical owner ID for Ubuntu in AWS is `099720109477`. Using an unverified third-party account ID poses a potential supply-chain vulnerability.
- **Remediation**: Change `owners` to `["099720109477"]` (Canonical).

#### 7. SonarQube In-Memory / Ephemeral Execution
- **Location**: `tools-install.sh:30`
- **Issue**: SonarQube is executed without volume bindings (`-v sonarqube_data:/opt/sonarqube/data`) and uses the embedded H2 database by default. Any container restart or crash wipes all user accounts, projects, and scan history.
- **Remediation**: Attach persistent Docker volumes or connect SonarQube to an external PostgreSQL database.

#### 8. Malformed Shebang in Bootstrap Script
- **Location**: `tools-install.sh:1`
- **Issue**: `# !/bin/bash` contains a space between `#` and `!`. On standard POSIX interpreters, this can cause the system to ignore the shebang and execute under a fallback shell (like `/bin/sh`).
- **Remediation**: Correct to `#!/bin/bash`.

---

## 4. Architectural & Operational Optimizations

### 1. Root Volume Sizing & Type (`gp3` vs default `gp2`)
- **Current**: 30 GB standard disk.
- **Problem**: Running Jenkins, Docker images, SonarQube, Kubernetes tools, and downloading Trivy vulnerability databases (multiple GBs) will rapidly exhaust 30 GB during multi-stage CI builds.
- **Recommendation**: Increase disk size to at least 50–100 GB and explicitly set `volume_type = "gp3"` with `iops = 3000` and `throughput = 125` for improved I/O throughput at lower cost.

### 2. Static Public IP (Elastic IP vs Ephemeral IP)
- **Current**: Direct public IP assigned on launch (`map_public_ip_on_launch = true`).
- **Problem**: Whenever the EC2 instance is stopped and started, AWS reassigns a new dynamic public IP address. This will break your Jenkins URL, SonarQube bookmarks, GitHub webhook payloads, and SSH configs.
- **Recommendation**: Allocate an `aws_eip` and attach it to the EC2 instance or its ENI.

### 3. Instance Sizing & Cost Efficiency
- **Current**: `t3a.2xlarge` (8 vCPU, 32 GB RAM) costs ~$220+/month if left running 24/7.
- **Recommendation**: For Dev/Test environments, `t3a.xlarge` (4 vCPU, 16 GB RAM) or `t3.large` (2 vCPU, 8 GB RAM) is sufficient. Additionally, Jenkins build executors can be dynamically spawned as ephemeral Kubernetes pods on EKS rather than running directly on the controller node.

### 4. Terraform Code Quality & Best Practices
- **Variable Definitions (`variables.tf`)**: Variables lack type definitions (`type = string`), descriptions, and defaults.
- **Missing Outputs (`outputs.tf`)**: There are no output definitions for `ec2_public_ip`, `jenkins_url` (`http://<ip>:8080`), `sonarqube_url` (`http://<ip>:9000`), or `ssh_command`.
- **Single AZ Subnet**: Only 1 subnet in `us-east-1a` is created. While sufficient for a single EC2 instance, note that AWS EKS will require at least two subnets across two distinct Availability Zones if deploying a cluster in this VPC.

---

## 5. Recommended Action Plan & Reference Fixes

### A. Improved Security Group Definition (`vpc.tf`)
```hcl
variable "allowed_admin_cidr" {
  type        = string
  description = "Your personal/office IP address for secure access"
  default     = "YOUR_PUBLIC_IP/32" # Replace with your IP
}

resource "aws_security_group" "security-group" {
  vpc_id      = aws_vpc.vpc.id
  description = "Restricted ingress for Jenkins, SonarQube, and SSH"

  ingress {
    description = "SSH Access from trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  ingress {
    description = "Jenkins UI from trusted IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  ingress {
    description = "SonarQube UI from trusted IP"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_admin_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.sg-name
  }
}
```

### B. Hardened EC2 Definition (`ec2.tf`)
```hcl
resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id
  instance_type          = "t3a.xlarge" # Or t3a.2xlarge
  key_name               = var.key-name
  subnet_id              = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = aws_iam_instance_profile.instance-profile.name

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # Enforces IMDSv2
  }

  user_data = templatefile("./tools-install.sh", {})

  tags = {
    Name = var.instance-name
  }
}
```

### C. Persistent SonarQube Container (`tools-install.sh`)
```bash
# Run SonarQube with persistent Docker volumes
docker volume create sonarqube_data
docker volume create sonarqube_extensions
docker volume create sonarqube_logs

docker run -d --name sonarqube \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  -v sonarqube_logs:/opt/sonarqube/logs \
  --restart unless-stopped \
  sonarqube:community
```

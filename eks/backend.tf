terraform {
  backend "s3" {
    bucket       = "devsecops-demo-084828561354-us-east-1-an"
    region       = "us-east-1"
    key          = "End-to-End-Kubernetes-DevSecOps-Tetris-Project/EKS-TF/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
  required_version = ">=1.14.0"
  required_providers {
    aws = {
      version = ">= 5.49.0"
      source  = "hashicorp/aws"
    }
  }
}

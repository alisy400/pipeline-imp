# device-monitor-ci-cd

CI/CD pipeline for a Flask system-monitoring web app using:
- Python (Flask)
- Bash scripts
- Docker
- Jenkins pipeline
- Terraform (AWS)
- ECR (Amazon Elastic Container Registry)
- EKS (Amazon Elastic Kubernetes Service)

## Repo layout
(see top-level README in repo)

## Quick start (local)
1. Build and run locally:
   ```bash
   docker build -t device-monitor:local .
   docker run -p 5000:5000 device-monitor:local
   # visit http://localhost:5000

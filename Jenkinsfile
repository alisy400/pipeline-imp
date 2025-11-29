pipeline {
  agent any

  environment {
    TF_DIR = "${env.WORKSPACE ?: '/var/jenkins_home/workspace/full-pipe'}/infra"
    KUBE_CONFIG_INSIDE = '/root/.kube/config'
  }
  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
  
    stage('System Requirements Check') {
      steps {
        sh '''
          set -euo pipefail
          echo "[syscheck] Print PATH and tools versions"
          echo "WORKSPACE=${WORKSPACE:-/var/jenkins_home/workspace/full-pipe}"
          which docker || true; docker --version || true
          which minikube || true; minikube version || true
          which kubectl || true; kubectl version --client --short || true
          which terraform || true; terraform version || true
          echo "[syscheck] minikube status (if available)"
          minikube status -p minikube || true
        '''
      }
    }

    stage('Terraform Init & Plan') {
      steps {
        sh '''
          set -euo pipefail
          echo "[tf] cd to infra: ${TF_DIR}"
          cd "${TF_DIR}"
          echo "[tf] terraform init"
          terraform init -input=false -no-color
          echo "[tf] terraform validate"
          terraform validate -no-color || true
          echo "[tf] terraform plan (saved as plan.tfplan)"
          terraform plan -input=false -out=plan.tfplan -no-color
          echo "[tf] show plan summary"
          terraform show -no-color -summary plan.tfplan || true
        '''
      }
    }



    stage('Build & Deploy to Minikube') {
      steps {
        sh '''
          set -euo pipefail

          echo "[0] go to workspace"
          cd "${WORKSPACE:-/var/jenkins_home/workspace/full-pipe}" || exit 1
          pwd
          ls -la | sed -n '1,120p'

          echo "[1] Ensure minikube is available"
          minikube status -p minikube

          echo "[2] Build image inside minikube's docker daemon"
          eval "$(minikube -p minikube docker-env)"
          docker build -t device-monitor:latest .

          echo "[3] Deploy to kubernetes (use container kubeconfig)"
          export KUBECONFIG=/root/.kube/config
          kubectl apply -f k8s/service.yaml
          kubectl apply -f k8s/deployment.yaml

          echo "[4] Wait for rollout"
          kubectl rollout status deployment/device-monitor --timeout=120s || kubectl get pods -o wide
        '''
      }
    }
  }
  post {
    always {
      echo "Pipeline finished"
    }
  }
}

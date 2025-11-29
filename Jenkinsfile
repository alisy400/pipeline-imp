pipeline {
  agent any
  stages {
    stage('Checkout') {
      steps {
        checkout scm
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

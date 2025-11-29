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
        '''
      }
    }

    stage('Terraform Init & Plan') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'your-aws-creds-id']]) {
          sh '''
            set -euo pipefail
            cd "${TF_DIR}"
            export AWS_REGION="${AWS_REGION:-us-east-1}"

            terraform init -input=false -no-color
            terraform plan -input=false -out=plan.tfplan -no-color
            echo "[tf] plan written to plan.tfplan"
          '''
        }
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

    stage('kubectl Apply Manifests') {
      steps {
        sh '''
          set -euo pipefail

          # use the kubeconfig we fixed inside the container (fallback to /root/.kube/config)
          export KUBECONFIG="${KUBE_CONFIG_INSIDE:-/root/.kube/config}"

          # ensure we're in the workspace with k8s manifests
          cd "${WORKSPACE:-/var/jenkins_home/workspace/full-pipe}" || { echo "Workspace not found"; exit 1; }

          # only apply if k8s dir exists
          if [ ! -d "k8s" ]; then
            echo "No k8s directory found, skipping kubectl apply."
            exit 0
          fi

          # safe apply: iterate each manifest so errors show which file failed
          for f in k8s/*.yaml; do
            [ -f "$f" ] || continue
            echo "[kubectl] applying $f"
            kubectl apply -f "$f"
          done

          # wait for deployment (if present) — will show pods if rollout check times out
          if kubectl get deployment device-monitor >/dev/null 2>&1; then
            kubectl rollout status deployment/device-monitor --timeout=120s || kubectl get pods -o wide
          else
            echo "deployment/device-monitor not found; skipping rollout wait."
          fi
        '''
      }
    }


  post {
    always {
      echo "Pipeline finished"
    }
  }
}

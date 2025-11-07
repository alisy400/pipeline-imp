pipeline {
  agent any

  environment {
    AWS_REGION = "us-east-1"
    APP_NAME = "device-monitor"
    ECR_REPO = "device-monitor"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Validate Tools') {
      steps {
        sh '''
          echo "Checking required CLIs..."
          aws --version || true
          terraform --version || true
          kubectl version --client || true
          minikube version || true
        '''
      }
    }

    stage('Unit tests & lint') {
      steps {
        sh '''
        python3 -m venv .venv
        . .venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        # run tests if any
        '''
      }
    }

    stage('Terraform Init & Apply (AWS resources)') {
      steps {
        dir('infra') {
          sh '''
            terraform init -reconfigure
            terraform apply -auto-approve
          '''
        }
      }
    }

    stage('Build Docker Image for Minikube') {
      steps {
        sh '''
          # Make sure minikube is running on the agent (managed separately or via local dev)
          # Switch docker env to minikube so image is built into minikube's Docker daemon
          eval $(minikube docker-env)
          docker build -t ${APP_NAME}:latest .
        '''
      }
    }

    stage('Deploy to Minikube') {
      steps {
        sh '''
          # Ensure kubectl context points to minikube cluster
          kubectl config use-context minikube || true
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
        '''
      }
    }

    stage('Post-Deployment Info') {
      steps {
        sh '''
          echo "Minikube service URL (if available):"
          minikube service device-monitor-svc --url || true
        '''
      }
    }

    stage('Terraform Destroy') {
      when {
        expression { return env.DESTROY == 'true' } // or keep input() flow below if preferred
      }
      steps {
        input message: "⚠️ Are you sure you want to destroy all AWS infra?", ok: "Yes, destroy"
        dir('infra') {
          sh '''
            terraform destroy -auto-approve
          '''
        }
      }
    }
  }

  post {
    success { echo "Pipeline succeeded" }
    failure { echo "Pipeline failed" }
  }
}

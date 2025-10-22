pipeline {
  agent any

  environment {
    AWS_REGION = "us-east-1"
    ECR_REPO = "device-monitor"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Unit tests & lint') {
      steps {
          sh '''
          python3 -m venv .venv
          . .venv/bin/activate
          pip install --upgrade pip
          pip install -r requirements.txt
          pip install pytest flake8 autopep8
          flake8 . || true
          pytest -q tests/ || true
          '''
      }
    }

    stage('Install AWS CLI') {
      steps {
          sh '''
            if ! command -v aws &> /dev/null; then
              echo "Installing AWS CLI..."
              apt-get update && apt-get install -y curl unzip
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              unzip awscliv2.zip && ./aws/install
              rm -rf awscliv2.zip ./aws
            else
              echo "AWS CLI already installed."
            fi
            aws --version
            '''
        
      }
    }



    stage('Build & Push to ECR') {
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          sh '''
            export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            export ECR_REPO_NAME=${ECR_REPO}
            chmod +x scripts/build_and_push_ecr.sh
            ./scripts/build_and_push_ecr.sh
          '''
          archiveArtifacts artifacts: 'image.env', fingerprint: true
        }
      }
    }

    stage('Terraform Plan') {
      when { branch 'main' }
      steps {
        dir('infra') {
          withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
            sh '''
              terraform init -input=false
              terraform plan -out=tfplan -input=false
            '''
          }
        }
      }
    }

    stage('Terraform Apply') {
      when { branch 'main' }
      input {
        message "Apply Terraform to create/update AWS infra?"
        ok "Apply"
      }
      steps {
        dir('infra') {
          withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
            sh '''
              terraform apply -input=false tfplan
            '''
          }
        }
      }
    }

    stage('Configure kubectl') {
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          sh '''
            CLUSTER_NAME=$(cd infra && terraform output -raw cluster_name)
            aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"
            kubectl get nodes
          '''
        }
      }
    }

    stage('Deploy to EKS') {
      steps {
        sh '''
          IMAGE=$(cat image.env | cut -d'=' -f2)
          export IMAGE
          chmod +x scripts/deploy_k8s.sh
          ./scripts/deploy_k8s.sh
        '''
      }
    }
  }

  post {
    success { echo "Pipeline succeeded" }
    failure { echo "Pipeline failed" }
  }
}

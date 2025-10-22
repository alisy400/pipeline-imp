pipeline {
  agent any
  environment {
    AWS_REGION = "us-east-1"
    ECR_REPO = "device-monitor"
  }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Unit tests & lint') {
      steps {
        sh '''
          python3 -m venv .venv
          . .venv/bin/activate
          pip install --upgrade pip
          pip install -r requirements.txt
          pip install pytest flake8
          flake8 || true
          pytest -q
        '''
      }
    }

    stage('Build & Push to ECR') {
      steps {
        withCredentials([string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                         string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            export AWS_REGION=${AWS_REGION}
            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
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
          withCredentials([string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                           string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh '''
              export AWS_REGION=${AWS_REGION}
              export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
              export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
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
          withCredentials([string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                           string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
            sh '''
              export AWS_REGION=${AWS_REGION}
              export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
              export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
              terraform apply -input=false tfplan
            '''
          }
        }
      }
    }

    stage('Configure kubectl') {
      steps {
        withCredentials([string(credentialsId: 'aws-access-key', variable: 'AWS_ACCESS_KEY_ID'),
                         string(credentialsId: 'aws-secret-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            export AWS_REGION=${AWS_REGION}
            export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
            export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
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





// This shit is supposed to be uploaded but dont know...
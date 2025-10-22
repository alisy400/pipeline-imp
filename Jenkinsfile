pipeline {
  agent {
      docker {
            image '<your-dockerhub-username>/jenkins-agent:latest'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
  }

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

    stage('Bootstrap Environment') {
          steps {
                sh '''
                echo "Setting up build environment..."

                # Install basic dependencies
                apt-get update -y || true
                apt-get install -y unzip curl python3 python3-pip docker.io jq || true

                # Install AWS CLI v2 if not found
                if ! command -v aws &> /dev/null; then
                    echo "Installing AWS CLI..."
                    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                    unzip -q awscliv2.zip
                    ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
                    rm -rf aws awscliv2.zip
                fi

                # Install Terraform if not found
                if ! command -v terraform &> /dev/null; then
                    echo "Installing Terraform..."
                    curl -fsSL https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_amd64.zip -o terraform.zip
                    unzip -q terraform.zip
                    mv terraform /usr/local/bin/
                    rm terraform.zip
                fi

                # Install kubectl if not found
                if ! command -v kubectl &> /dev/null; then
                    echo "Installing kubectl..."
                    curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
                    chmod +x kubectl
                    mv kubectl /usr/local/bin/
                fi

                echo "Environment setup complete ✅"
                aws --version || true
                terraform --version || true
                kubectl version --client || true
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
          pip install pytest flake8 autopep8
          flake8 . || true
          pytest -q tests/ || true
          '''
      }
    }

    stage('Install AWS CLI') {
      steps {
            sh '''
            echo "Installing AWS CLI..."
            apt-get update && apt-get install -y curl unzip sudo
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip -o awscliv2.zip
            sudo ./aws/install --update
            rm -rf awscliv2.zip ./aws
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

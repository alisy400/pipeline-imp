pipeline {
  agent none   // We will define agents per stage

  environment {
    AWS_REGION = "us-east-1"
    APP_NAME  = "device-monitor"
    ECR_REPO  = "device-monitor"
    AGENT_IMAGE = "local-jenkins-agent:latest"
  }

  stages {

    /* ---------------------- */
    /* Build Jenkins Agent    */
    /* ---------------------- */
    stage('Build Jenkins Agent Image') {
      agent any
      steps {
        sh '''
          echo "---- Building local Jenkins agent image ----"
          docker build -t ${AGENT_IMAGE} -f Dockerfile.jenkins-agent .
        '''
      }
    }

    /* ---------------------- */
    /* Checkout Source        */
    /* ---------------------- */
    stage('Checkout') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged"
        }
      }
      steps {
        checkout scm
      }
    }

    /* ---------------------- */
    /* Validate Tools         */
    /* ---------------------- */
    stage('Validate Tools Installed') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged"
        }
      }
      steps {
        sh '''
          echo "---- Checking required CLIs ----"
          aws --version
          terraform --version
          kubectl version --client
          minikube version
          docker --version
        '''
      }
    }

    /* ---------------------- */
    /* Python Unit Tests      */
    /* ---------------------- */
    stage('Unit tests & lint') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged"
        }
      }
      steps {
        sh '''
          echo "---- Creating virtual env ----"
          python3 -m venv .venv
          . .venv/bin/activate

          pip install --upgrade pip
          pip install -r requirements.txt

          echo "---- Run tests here ----"
          # pytest
        '''
      }
    }

    /* ---------------------- */
    /* Terraform Apply        */
    /* ---------------------- */
    stage('Terraform Init & Apply (AWS)') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock"
        }
      }

      environment {
        AWS_REGION = "us-east-1"
      }

      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
          dir('infra') {
            sh '''
              echo "---- Terraform Init ----"
              terraform init -reconfigure

              echo "---- Terraform Apply ----"
              terraform apply -auto-approve
            '''
          }
        }
      }
    }

    /* ---------------------- */
    /* Build Docker inside Minikube */
    /* ---------------------- */
    stage('Build Docker Image for Minikube') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged"
        }
      }
      steps {
        sh '''
          echo "---- Switching to Minikube Docker daemon ----"
          eval $(minikube docker-env)

          echo "---- Building app image inside Minikube ----"
          docker build -t ${APP_NAME}:latest .
        '''
      }
    }

    /* ---------------------- */
    /* Deploy to Minikube     */
    /* ---------------------- */
    stage('Deploy to Minikube') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged"
        }
      }
      steps {
        sh '''
          kubectl config use-context minikube

          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
        '''
      }
    }

    /* ---------------------- */
    /* Post-Deployment        */
    /* ---------------------- */
    stage('Post Deployment Info') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged"
        }
      }
      steps {
        sh '''
          echo "---- Minikube Service URL ----"
          minikube service ${APP_NAME}-svc --url || true
        '''
      }
    }

    /* ---------------------- */
    /* Terraform Destroy      */
    /* ---------------------- */
    stage('Terraform Destroy') {
      when { expression { env.DESTROY == 'true' } }

      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged"
        }
      }

      steps {
        input message: "⚠️ Destroy AWS infra?", ok: "Destroy"

        dir('infra') {
          sh '''
            terraform destroy -auto-approve
          '''
        }
      }
    }
  }

  post {
    success { echo "✅ Pipeline succeeded!" }
    failure { echo "❌ Pipeline failed!" }
  }
  
}
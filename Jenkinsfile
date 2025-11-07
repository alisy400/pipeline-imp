pipeline {
  agent none   // Use per-stage agents

  environment {
    AWS_REGION  = "us-east-1"
    APP_NAME    = "device-monitor"
    ECR_REPO    = "device-monitor"
    AGENT_IMAGE = "local-jenkins-agent:latest"
  }

  stages {

    /* ---------------------- */
    /* Build Jenkins Agent Image */
    /* ---------------------- */
    stage('Build Jenkins Agent Image') {
      agent any
      steps {
        sh '''
          echo "---- Building Jenkins Agent Image ----"
          docker build -t ${AGENT_IMAGE} -f Dockerfile.jenkins-agent .
        '''
      }
    }

    /* ---------------------- */
    /* Checkout Code          */
    /* ---------------------- */
    stage('Checkout') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock"
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
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock"
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
    stage('Unit Tests & Lint') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock"
        }
      }
      steps {
        sh '''
          echo "---- Creating Python venv ----"
          python3 -m venv .venv
          . .venv/bin/activate

          pip install --upgrade pip
          pip install -r requirements.txt

          echo "Run pytest or other tests here"
        '''
      }
    }

    /* ---------------------- */
    /* Terraform Apply (AWS)  */
    /* ---------------------- */
  stage('Terraform Init & Apply') {
    agent any

    environment {
      AWS_REGION = "us-east-1"
    }

    steps {
      withCredentials([
        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']
      ]) {
        dir('infra') {
          sh '''
            set -e
            echo "PWD=$(pwd)"
            echo "Listing infra dir:"
            ls -la

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
    /* Build Container for Minikube */
    /* ---------------------- */
    stage('Build Docker Image for Minikube') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock"
        }
      }
      steps {
        sh '''
          echo "---- Using Minikube Docker ----"
          eval $(minikube docker-env)

          echo "---- Building Docker Image ----"
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
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock"
        }
      }
      steps {
        sh '''
          echo "---- Switching to Minikube context ----"
          kubectl config use-context minikube

          echo "---- Applying manifests ----"
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
        '''
      }
    }

    /* ---------------------- */
    /* Post Deployment Info   */
    /* ---------------------- */
    stage('Post Deployment Info') {
      agent {
        docker {
          image "${AGENT_IMAGE}"
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock"
        }
      }
      steps {
        sh '''
          echo "---- Getting Minikube Service URL ----"
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
          args "-u root --privileged -v /var/run/docker.sock:/var/run/docker.sock"
        }
      }
      steps {
        input message: "⚠️ Destroy AWS infrastructure?", ok: "Destroy"
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
          dir('infra') {
            sh '''
              terraform destroy -auto-approve
            '''
          }
        }
      }
    }

  } /* END OF stages */

  post {
    success { echo "✅ Pipeline succeeded!" }
    failure { echo "❌ Pipeline failed!" }
  }

} /* END OF pipeline */

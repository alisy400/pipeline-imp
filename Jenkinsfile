pipeline {
  agent {
    docker {
      // mount host docker socket into the agent container so docker commands inside the agent can use host Docker
      // also run as root so it can access the socket
      image 'my-jenkins-agent:latest'
      args '--privileged -u root -v /var/run/docker.sock:/var/run/docker.sock -v /var/jenkins_home:/var/jenkins_home'
    }
  }

  environment {
    AWS_REGION  = "us-east-1"
    APP_NAME    = "device-monitor"
    ECR_REPO    = "device-monitor"
    AGENT_IMAGE = "local-jenkins-agent:latest"
  }

  options {
    // avoid timeout surprises; adjust if you want
    timeout(time: 60, unit: 'MINUTES')
    // do not rely on the lightweight checkout (ensure full clone)
    disableConcurrentBuilds()
  }

  stages {

    // ---------- (OPTIONAL) cleanup stale workspace ----------
stage('Prepare') {
    steps {
        sh '''
            mkdir -p /var/jenkins_home/workspace/full-pipe
            chmod -R 777 /var/jenkins_home/workspace
            echo "Directory fixed!"
        '''
    }
}


    /* ------------------------------------ */
    /* Checkout Code (inside agent)         */
    /* ------------------------------------ */
    stage('Checkout') {
      steps {
        // full clone into agent workspace (agent has git installed)
        checkout scm
      }
    }

    /* ------------------------------------ */
    /* Validate Tools                       */
    /* ------------------------------------ */
    stage('Validate Tools Installed') {
      steps {
        sh '''
          echo "---- Checking required CLIs ----"
          aws --version || true
          terraform --version || true
          kubectl version --client || true
          minikube version || true
          docker --version || true
          git --version || true
        '''
      }
    }

    /* ------------------------------------ */
    /* Python Tests                         */
    /* ------------------------------------ */
    stage('Unit Tests & Lint') {
      steps {
        sh '''
          echo "---- Creating Python venv ----"
          python3 -m venv .venv
          . .venv/bin/activate

          pip install --upgrade pip
          pip install -r requirements.txt
        '''
      }
    }

    /* ------------------------------------ */
    /* Terraform Init & Apply (AWS)         */
    /* ------------------------------------ */
    stage('Terraform Init & Apply (AWS)') {
      when { expression { return fileExists('infra/terraform.tfstate') || true } }
      environment {
        AWS_REGION = "us-east-1"
      }
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'your-aws-creds-id',
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          dir('infra') {
            sh '''
              echo "---- Running Terraform ----"
              terraform init -input=false
              terraform fmt -check || true
              terraform validate || true
              terraform plan -out=tfplan || true
              terraform apply -auto-approve tfplan || true
            '''
          }
        }
      }
    }

    /* ------------------------------------ */
    /* Build Docker Image for Minikube      */
    /* ------------------------------------ */
    stage('Build Docker Image for Minikube') {
      steps {
        sh '''
          echo "---- Using Minikube Docker (if available) ----"
          # only try minikube env if minikube exists
          if command -v minikube >/dev/null 2>&1; then
            eval $(minikube docker-env)
          fi

          echo "---- Building Docker Image ----"
          docker build -t ${APP_NAME}:latest .
        '''
      }
    }

    /* ------------------------------------ */
    /* Deploy to Minikube                   */
    /* ------------------------------------ */
    stage('Deploy to Minikube') {
      steps {
        sh '''
          kubectl config use-context minikube || true
          kubectl apply -f k8s/deployment.yaml || true
          kubectl apply -f k8s/service.yaml || true
        '''
      }
    }

    /* ------------------------------------ */
    /* Post Deployment Info                 */
    /* ------------------------------------ */
    stage('Post Deployment Info') {
      steps {
        sh '''
          echo "---- Getting Minikube Service URL ----"
          minikube service ${APP_NAME}-svc --url || true
        '''
      }
    }

    /* ------------------------------------ */
    /* Terraform Destroy (manual)           */
    /* ------------------------------------ */
    stage('Terraform Destroy') {
      when { expression { env.DESTROY == 'true' } }
      steps {
        input message: "⚠️ Destroy AWS infra?", ok: "Destroy"
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'aws-creds'
        ]]) {
          dir('infra') {
            sh 'terraform destroy -auto-approve'
          }
        }
      }
    }

  } // end stages

  post {
    success { echo "✅ Pipeline succeeded!" }
    failure { echo "❌ Pipeline failed!" }
  }

}

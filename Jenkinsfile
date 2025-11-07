pipeline {

  agent {
    docker {
      image 'my-jenkins-agent:latest'
      args '--privileged -u root'
    }
  }

  environment {
    AWS_REGION  = "us-east-1"
    APP_NAME    = "device-monitor"
    ECR_REPO    = "device-monitor"
    AGENT_IMAGE = "local-jenkins-agent:latest"
  }

  stages {

    /* ------------------------------------ */
    /* Build Jenkins Agent Image            */
    /* ------------------------------------ */
    stage('Build Jenkins Agent Image') {
      steps {
        sh '''
          echo "---- Building Jenkins Agent Image ----"
          docker build -t ${AGENT_IMAGE} -f Dockerfile.jenkins-agent .
        '''
      }
    }

    /* ------------------------------------ */
    /* Checkout Code                        */
    /* ------------------------------------ */
    stage('Checkout') {
      steps {
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
          aws --version
          terraform --version
          kubectl version --client
          minikube version
          docker --version
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
    /* Terraform Apply                      */
    /* ------------------------------------ */
    stage('Terraform Init & Apply (AWS)') {
        steps {
            withEnv([
                "AWS_REGION=us-east-1"
            ]) {
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
                            terraform fmt -check
                            terraform validate
                            terraform plan -out=tfplan
                            terraform apply -auto-approve tfplan
                        '''
                    }

                }
            }
        }
    }

    /* ------------------------------------ */
    /* Build Image in Minikube Docker       */
    /* ------------------------------------ */
    stage('Build Docker Image for Minikube') {
      steps {
        sh '''
          echo "---- Using Minikube Docker ----"
          eval $(minikube docker-env)

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
          kubectl config use-context minikube
          kubectl apply -f k8s/deployment.yaml
          kubectl apply -f k8s/service.yaml
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
    /* Terraform Destroy                    */
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

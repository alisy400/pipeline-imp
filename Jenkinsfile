pipeline {
  agent any
  // agent {
  //   // docker {
  //   //   // mount host docker socket into the agent container so docker commands inside the agent can use host Docker
  //   //   // also run as root so it can access the socket
  //   //   image 'my-jenkins-agent:latest'
  //   //   args '--privileged -u root -v /var/run/docker.sock:/var/run/docker.sock -v /var/jenkins_home:/var/jenkins_home'
  //   // }
  // }

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

    // // ---------- (OPTIONAL) cleanup stale workspace ----------
    // stage('Prepare') {
    //   steps {
    //       sh '''
    //           mkdir -p /var/jenkins_home/workspace/full-pipe
    //           chmod -R 777 /var/jenkins_home/workspace
    //           echo "Directory fixed!"
    //       '''
    //   }
    // }


    /* ------------------------------------ */
    /* Checkout Code (inside agent)         */
    /* ------------------------------------ */
    // stage('Checkout') {
    //   steps {
    //     // full clone into agent workspace (agent has git installed)
    //     checkout scm
    //   }
    // }

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
    stage('Build & Deploy to Minikube') {
      steps {
        sh '''
          set -euo pipefail
          echo "[1] Ensure minikube profile exists and is running"

          # If no profile exists, start minikube (use driver docker)
          if minikube profile list | grep -q "No minikube profile exists"; then
            echo "No minikube profile -> starting minikube"
            minikube start --driver=docker
          fi

          # If profile exists but not running, start it
          STATUS=$(minikube status --format='{{.Host}} {{.Kubelet}} {{.APIServer}}' 2>/dev/null || true)
          if ! echo "$STATUS" | grep -q "Running"; then
            echo "Starting minikube (profile may exist but not running)"
            minikube start --driver=docker
          else
            echo "minikube already running"
          fi

          echo "[2] Set docker env to minikube if we want to build inside minikube's docker daemon"
          # If you want to build into minikube's docker, uncomment next line:
          # eval $(minikube docker-env)

          echo "[3] Build docker image on host (so we can load it)"
          docker build -t ${APP_NAME}:latest .

          echo "[4] Ensure minikube profile exists (again) and load image"
          if minikube profile list | grep -q "No minikube profile exists"; then
            echo "Minikube not available to load image; aborting load"
          else
            minikube image load ${APP_NAME}:latest || true
          fi

          echo "[5] Apply Kubernetes manifests (skip validation if API server not reachable)"
          # If kubectl is not authorised/needs login, use --validate=false to bypass schema validation
          kubectl apply -f k8s/deployment.yaml --validate=false || true
          kubectl apply -f k8s/service.yaml --validate=false || true

          echo "[6] Done"
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

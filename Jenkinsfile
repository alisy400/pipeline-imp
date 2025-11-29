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

          echo "[1] Ensure minikube is started (will use --force if running as root)"
          # Start minikube (force if running as root, which is required in your CI)
          if ! minikube profile list 2>&1 | grep -q "minikube"; then
            echo "No minikube profile found — starting minikube (forced for CI)"
            minikube start --driver=docker --force
          else
            # if profile exists but not running, start it (force if root)
            if ! minikube status --format='{{.Host}}' 2>/dev/null | grep -q "Running"; then
              if [ "$(id -u)" -eq 0 ]; then
                minikube start --driver=docker --force
              else
                minikube start --driver=docker
              fi
            else
              echo "minikube already running"
            fi
          fi

          echo "[wait] Waiting up to 300s for minikube to be Ready..."
          i=0; while ! minikube status --format='{{.Host}} {{.Kubelet}} {{.APIServer}}' 2>/dev/null | grep -q "Running"; do
            sleep 5
            i=$((i+5))
            if [ $i -ge 300 ]; then
              echo "ERROR: minikube not ready after 300s" >&2
              minikube status || true
              exit 2
            fi
            echo "waiting... ${i}s"
          done

          echo "[2] Build docker image with name expected by k8s manifests (device-monitor)"
          docker build -t device-monitor:latest .

          echo "[3] Load image into minikube"
          minikube image load device-monitor:latest || true

          echo "[4] Apply Kubernetes manifests (skip strict validation)"
          kubectl apply -f k8s/deployment.yaml --validate=false
          kubectl apply -f k8s/service.yaml --validate=false

          echo "[5] Wait for deployment rollout (120s)"
          kubectl rollout status deployment/device-monitor --timeout=120s || true

          # quick smoke test (try service url, fallback to port-forward)
          set +e
          URL=$(minikube service device-monitor-svc --url 2>/dev/null || true)
          if [ -n "$URL" ]; then
            echo "Service URL: $URL"
            curl -fsS "$URL" || echo "service not responding yet"
          else
            echo "No service URL; port-forwarding for quick check"
            kubectl port-forward svc/device-monitor-svc 5000:5000 >/tmp/portfwd.log 2>&1 &
            sleep 3
            curl -fsS http://127.0.0.1:5000/ || echo "service not responding on port-forward"
            pkill -f "kubectl port-forward" || true
          fi
          set -e

          echo "[done] Build & deploy finished"
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

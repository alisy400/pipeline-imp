pipeline {
  agent any

  environment {
    TF_DIR = "${env.WORKSPACE ?: '/var/jenkins_home/workspace/full-pipe'}/infra"
    KUBE_CONFIG_INSIDE = '/root/.kube/config'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
  
    stage('System Requirements Check') {
      steps {
        sh '''
          set -euo pipefail
          echo "[syscheck] Print PATH and tools versions"
          echo "WORKSPACE=${WORKSPACE:-/var/jenkins_home/workspace/full-pipe}"
          which docker || true; docker --version || true
          which minikube || true; minikube version || true
          which kubectl || true; kubectl version --client --short || true
          which terraform || true; terraform version || true
          echo "[syscheck] minikube status (if available)"
        '''
      }
    }

    stage('Terraform Init & Plan') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'your-aws-creds-id']]) 
          {
            sh '''
              set -euo pipefail
              cd "${TF_DIR}"
              export AWS_REGION="${AWS_REGION:-us-east-1}"

              terraform init -input=false -no-color
              terraform plan -input=false -out=plan.tfplan -no-color
              echo "[tf] plan written to plan.tfplan"
            '''
          }
      }
    }

    stage('Build & Deploy to Minikube') {
      steps {
        script {
          // adjust these to your names if different
          def MINIKUBE_PROFILE = 'minikube'
          def IMAGE_NAME = 'device-monitor:latest'
          def K8S_DIR = "${WORKSPACE}/k8s"
          def DEPLOYMENT_NAME = 'device-monitor'
          def NAMESPACE = 'default'

          sh """
            set -euo pipefail
            echo "[ci] ensure we run as Jenkins HOME inside container"
            export HOME=/var/jenkins_home
            export MINIKUBE_HOME=/var/jenkins_home/.minikube
            export KUBECONFIG=/var/jenkins_home/.kube/config

            echo "[ci] sanity: show minikube & kube files that Jenkins will use"
            ls -la \$MINIKUBE_HOME || true
            ls -la \$(dirname \$KUBECONFIG) || true
            echo "KUBECONFIG=\$KUBECONFIG"

            echo "[ci] check minikube status (using MINIKUBE_HOME)"
            minikube -p ${MINIKUBE_PROFILE} status || true

            echo "[ci] point docker to minikube's docker daemon"
            eval \$((minikube -p ${MINIKUBE_PROFILE} docker-env) | sed 's/^/export /' ) >/dev/null 2>&1 || true
            # the above is robust to different shells: it will export DOCKER_HOST/DOCKER_CERT_PATH etc.

            echo "[ci] docker info (should connect to minikube daemon)"
            docker info >/dev/null || echo "docker info failed - check minikube docker-env"

            echo "[ci] build image into minikube's docker daemon"
            cd ${WORKSPACE}
            docker build -t ${IMAGE_NAME} .

            echo "[ci] ensure deployment will use local image: set imagePullPolicy to IfNotPresent"
            # if your manifest includes imagePullPolicy: Always, this patch will override to IfNotPresent
            kubectl --kubeconfig=\$KUBECONFIG -n ${NAMESPACE} patch deployment ${DEPLOYMENT_NAME} --type='json' -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]' || true

            # set the container image to the one we built
            CON=\$(kubectl --kubeconfig=\$KUBECONFIG -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} -o jsonpath='{.spec.template.spec.containers[0].name}')
            if [ -n "\$CON" ]; then
              kubectl --kubeconfig=\$KUBECONFIG -n ${NAMESPACE} set image deployment/${DEPLOYMENT_NAME} \$CON=${IMAGE_NAME} --record || true
            else
              echo "[ci] warning: couldn't discover container name in deployment; applying manifests directly"
            fi

            echo "[ci] apply k8s manifests (deployment + service) from workspace if present"
            if [ -d "${K8S_DIR}" ]; then
              kubectl --kubeconfig=\$KUBECONFIG -n ${NAMESPACE} apply -f ${K8S_DIR}
            else
              echo "[ci] ${K8S_DIR} not present; skipping kubectl apply"
            fi

            echo "[ci] rollout status (deployment)"
            kubectl --kubeconfig=\$KUBECONFIG -n ${NAMESPACE} rollout status deployment/${DEPLOYMENT_NAME} --timeout=120s || true

            echo "[ci] pods (wide) and describe failing pods (if any)"
            kubectl --kubeconfig=\$KUBECONFIG -n ${NAMESPACE} get pods -o wide
            # print last 200 lines for pods not ready
            for p in \$(kubectl --kubeconfig=\$KUBECONFIG -n ${NAMESPACE} get pods --no-headers -o custom-columns=:metadata.name,:status.phase | awk '\$2 != "Running" {print \$1}'); do
              echo "---- logs for pod: \$p ----"
              kubectl --kubeconfig=\$KUBECONFIG -n ${NAMESPACE} logs --tail=200 \$p || true
              kubectl --kubeconfig=\$KUBECONFIG -n ${NAMESPACE} describe pod \$p || true
            done

            echo "[ci] done"
          """
        }
      }
    }

    post {
        always {
            echo "Pipeline finished"
        }
    }
}

pipeline {
    agent any

    parameters {
        // Taken from the Terraform output after `terraform apply`.
        string(name: 'ACR_NAME', defaultValue: '', description: 'Azure Container Registry name (from terraform output)')
    }

    environment {
    ACR_LOGIN_SERVER = "${params.ACR_NAME}.azurecr.io"

    RESOURCE_GROUP = 'python-library-rg'
    AKS_CLUSTER = 'python-library-aks'

    // Azure AD tenant ID is supplied by a Jenkins credential, not committed.
    AZURE_TENANT_ID = credentials('azure-tenant-id')

    IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {
        stage('CleanWorkspace') {
            steps {
                cleanWs ()
            }
        }
        stage ('CODE') {
            steps {
                 git branch: 'main',
                    url: 'https://github.com/dinesh4567/python-library-azure.git'
            }
        }
        stage('Verify Repository') {
            steps {
                sh '''
                echo "Current Directory:"
                pwd

                echo ""
                echo "Repository Contents:"
                ls -la

                echo ""
                echo "Kubernetes Folder:"
                ls -R k8s
                '''
            }
        }
        stage ('sonar analysis') {
            environment{
                SCANNER_HOME = tool 'sonar'
            }
            
            steps {
                withSonarQubeEnv('sonar') {
                    sh "${SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=python-library -Dsonar.projectName=python-library -Dsonar.sources=. -Dsonar.python.version=3.9"
                }
            }
        }
        stage ('quality Gates') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        stage ('Build Images') {
            steps {
                sh '''
                docker build -t ${ACR_LOGIN_SERVER}/database:${IMAGE_TAG} ./database
                docker build -t ${ACR_LOGIN_SERVER}/auth-service:${IMAGE_TAG} ./auth-service
                docker build -t ${ACR_LOGIN_SERVER}/book-service:${IMAGE_TAG} ./book-service
                docker build -t ${ACR_LOGIN_SERVER}/borrow-service:${IMAGE_TAG} ./borrow-service
                docker build -t ${ACR_LOGIN_SERVER}/frontend:${IMAGE_TAG} ./frontend

                docker images | grep ${ACR_NAME}
            '''
            }
        }
        stage ('TrivySCAN') {
            steps {
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 ${ACR_LOGIN_SERVER}/database:${IMAGE_TAG}'
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 ${ACR_LOGIN_SERVER}/auth-service:${IMAGE_TAG}'
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 ${ACR_LOGIN_SERVER}/book-service:${IMAGE_TAG}'
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 ${ACR_LOGIN_SERVER}/borrow-service:${IMAGE_TAG}'
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 ${ACR_LOGIN_SERVER}/frontend:${IMAGE_TAG}'
            }
        }
        stage('Azure Login') {
            steps {
                withCredentials([
                    usernamePassword(
                    credentialsId: 'jenkins-sp',
                    usernameVariable: 'CLIENT_ID',
                    passwordVariable: 'CLIENT_SECRET'
                )
            ]) {
                sh '''
                az login --service-principal \
                    --username "$CLIENT_ID" \
                    --password "$CLIENT_SECRET" \
                    --tenant "$AZURE_TENANT_ID"

                az account show -o table

                az acr login --name ${ACR_NAME}
                '''
                }
            }
        }
        stage('Push Images to ACR') {
            steps {
            sh '''
                docker push ${ACR_LOGIN_SERVER}/database:${IMAGE_TAG}
                docker push ${ACR_LOGIN_SERVER}/auth-service:${IMAGE_TAG}

                docker push ${ACR_LOGIN_SERVER}/book-service:${IMAGE_TAG}

                docker push ${ACR_LOGIN_SERVER}/borrow-service:${IMAGE_TAG}

                docker push ${ACR_LOGIN_SERVER}/frontend:${IMAGE_TAG}
                '''
            }
        }
        stage('Connect to AKS') {
            steps {
                sh '''
                az aks get-credentials \
                    --resource-group ${RESOURCE_GROUP} \
                    --name ${AKS_CLUSTER} \
                    --overwrite-existing

                kubectl config current-context

                kubectl get nodes
                '''
            }
        }
        stage('Prepare Kubernetes Manifests') {
            steps {
                sh '''
                find k8s -name "deployment.yaml" -type f \
                    -exec sed -i "s|ACR_LOGIN_SERVER|${ACR_LOGIN_SERVER}|g" {} +

                find k8s -name "deployment.yaml" -type f \
                    -exec sed -i "s|:latest|:${IMAGE_TAG}|g" {} +

                echo "Updated image references:"
                grep -R "image:" k8s
                '''
            }
        }
        stage('Deploy to AKS') {
            steps {
                sh '''
                kubectl apply -f k8s/namespace.yaml

                kubectl apply -f k8s/database/

                kubectl apply -f k8s/application/

                kubectl apply -f k8s/auth/

                kubectl apply -f k8s/book/

                kubectl apply -f k8s/borrow/

                kubectl apply -f k8s/frontend/

                # Ingress is not enabled yet - see "Known limitations" in the README.
                # kubectl apply -f k8s/ingress/
                '''
            }
        }
        stage('Verify Deployment') {
            steps {
                sh '''
                echo "Namespaces"
                kubectl get ns

                echo "Pods"
                kubectl get pods -n library

                echo "Services"
                kubectl get svc -n library

                echo "Deployments"
                kubectl get deployment -n library

                # echo "Ingress"
                # kubectl get ingress -n library
                '''
            }
        }
    }
}
pipeline {
    agent any

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
                sh 'docker build -t devsecops1acr.azurecr.io/database:latest ./database'
                sh 'docker build -t devsecops1acr.azurecr.io/auth-service:latest ./auth-service'
                sh 'docker build -t devsecops1acr.azurecr.io/book-service:latest ./book-service'
                sh 'docker build -t devsecops1acr.azurecr.io/borrow-service:latest ./borrow-service'
                sh 'docker build -t devsecops1acr.azurecr.io/frontend:latest ./frontend'
                sh 'docker images | grep devsecops1acr'
            }
        }
        stage ('TrivySCAN') {
            steps {
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 devsecops1acr.azurecr.io/database:latest'
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 devsecops1acr.azurecr.io/auth-service:latest'
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 devsecops1acr.azurecr.io/book-service:latest'
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 devsecops1acr.azurecr.io/borrow-service:latest'
                sh 'trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 0 devsecops1acr.azurecr.io/frontend:latest'
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
                    --tenant "f6c19515-e853-499d-b534-fa6e6e59387e"

                az account show -o table

                az acr login --name devsecops1acr
                '''
                }
            }
        }
        stage('Push Images to ACR') {
            steps {
            sh '''
                docker push devsecops1acr.azurecr.io/database:latest
                docker push devsecops1acr.azurecr.io/auth-service:latest

                docker push devsecops1acr.azurecr.io/book-service:latest

                docker push devsecops1acr.azurecr.io/borrow-service:latest

                docker push devsecops1acr.azurecr.io/frontend:latest
                '''
            }
        }
        stage('Connect to AKS') {
            steps {
                sh '''
                az aks get-credentials \
                    --resource-group devsecops-rg \
                    --name devsecopsaks \
                    --overwrite-existing

                kubectl config current-context

                kubectl get nodes
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

                kubectl apply -f k8s/ingress/
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

                echo "Ingress"
                kubectl get ingress -n library
                '''
            }
        }
    }
}

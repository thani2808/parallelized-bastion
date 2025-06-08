pipeline {
    agent any

    parameters {
        choice(name: 'APP_TYPE', choices: ['springboot', 'nginx'], description: 'Type of app to deploy')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
        string(name: 'BASTION_IP', defaultValue: '225.225.225.225', description: 'Bastion Host IP Address')
        string(name: 'BASTION_USER', defaultValue: 'ubuntu', description: 'Bastion Host SSH Username')
    }

    environment {
        DOCKERHUB_USERNAME = "thanigai2808"
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    def portMap = [
                        dev: '9004',
                        staging: '9005',
                        prod: '9006'
                    ]

                    def isNginx = params.APP_TYPE == 'nginx'
                    def dockerPort = isNginx ? '80' : portMap[params.ENVIRONMENT]
                    def hostPort = portMap[params.ENVIRONMENT]

                    env.IMAGE_NAME = "${params.APP_TYPE}-bastion-app"
                    env.CONTAINER_NAME = "${params.APP_TYPE}-bastion-container-${params.ENVIRONMENT}"
                    env.DOCKER_PORT = dockerPort
                    env.HOST_PORT = hostPort
                    env.DOCKERHUB_REPO = "${env.DOCKERHUB_USERNAME}/${env.IMAGE_NAME}"
                }
            }
        }

        stage('Print Config') {
            steps {
                script {
                    echo "App Type      : ${params.APP_TYPE}"
                    echo "Environment   : ${params.ENVIRONMENT}"
                    echo "Bastion IP    : ${params.BASTION_IP}"
                    echo "Bastion User  : ${params.BASTION_USER}"
                    echo "Docker Repo   : ${env.DOCKERHUB_REPO}"
                    echo "Container     : ${env.CONTAINER_NAME}"
                    echo "Port Mapping  : ${env.HOST_PORT}:${env.DOCKER_PORT}"
                }
            }
        }

        stage('Clone the Repo') {
            steps {
                script {
                    def repoMap = [
                        'nginx': 'dan-p81-bastion',
                        'springboot': 'hello-world-bastion'
                    ]
                    def selectedRepo = repoMap[params.APP_TYPE]

                    if (!selectedRepo) {
                        error "Unknown APP_TYPE: ${params.APP_TYPE}"
                    }

                    checkout([
                        $class: 'GitSCM',
                        branches: [[name: '*/feature']],
                        userRemoteConfigs: [[
                            url: "git@github.com:thani2808/${selectedRepo}.git",
                            credentialsId: 'private-key-jenkins'
                        ]]
                    ])
                }
            }
        }

        stage('Build App') {
            when { expression { return params.APP_TYPE == 'springboot' } }
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    if (!fileExists('Dockerfile')) {
                        error "❌ Dockerfile not found!"
                    }
                    sh "docker build -t ${env.IMAGE_NAME} ."
                }
            }
        }

        stage('Tag & Push Docker Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                    sh """
                        echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin
                        docker tag ${env.IMAGE_NAME} ${env.DOCKERHUB_REPO}:${params.ENVIRONMENT}
                        docker push ${env.DOCKERHUB_REPO}:${params.ENVIRONMENT}
                        docker logout
                    """
                }
            }
        }

        stage('Deploy to Bastion') {
            steps {
                echo "🚀 Deploying container on Bastion..."
                withCredentials([sshUserPrivateKey(credentialsId: 'testing', keyFileVariable: 'keyf', usernameVariable: 'username')]) {
                    sh """
                        ssh-keyscan -H ${params.BASTION_IP} >> ~/.ssh/known_hosts
                        ssh -i ${keyf} ${params.BASTION_USER}@${params.BASTION_IP} << EOF
docker stop ${env.CONTAINER_NAME} || true
docker rm ${env.CONTAINER_NAME} || true
docker rmi ${env.DOCKERHUB_REPO}:${params.ENVIRONMENT} || true
docker pull ${env.DOCKERHUB_REPO}:${params.ENVIRONMENT}
docker run -d --name ${env.CONTAINER_NAME} -p ${env.HOST_PORT}:${env.HOST_PORT} ${env.DOCKERHUB_REPO}:${params.ENVIRONMENT} java -jar app.jar --server.port=${env.HOST_PORT}
EOF
                    """
                }
            }
        }

        stage('Health Check') {
            steps {
                echo "🩺 Health checking app on Bastion..."
                withCredentials([sshUserPrivateKey(credentialsId: 'testing', keyFileVariable: 'keyf', usernameVariable: 'username')]) {
                    sh """
                        ssh -i ${keyf} ${params.BASTION_USER}@${params.BASTION_IP} << 'EOF'
set -x
retries=10
for i in \$(seq 1 \$retries); do
  RESPONSE_CODE=\$(curl -o /dev/null -s -w "%{http_code}" http://localhost:${env.HOST_PORT})
  if [[ "\$RESPONSE_CODE" == "200" ]]; then
    echo "✅ App is up!"
    exit 0
  else
    echo "Retry \$i/\$retries - Not ready"
    sleep 5
  fi
done
echo "❌ App failed to start"
exit 1
EOF
                    """
                }
            }
        }

        stage('Success') {
            steps {
                echo "🎉 Deployment of ${params.APP_TYPE} app to ${params.ENVIRONMENT} succeeded!"
            }
        }
    }

    post {
        failure {
            echo '🚨 Pipeline failed!'
        }
        always {
            echo '📋 Pipeline finished.'
        }
    }
}

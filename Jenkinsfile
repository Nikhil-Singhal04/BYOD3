pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION      = 'true'
        TF_CLI_ARGS           = '-no-color'
        AWS_CREDENTIALS_ID    = 'AWS-CREDS'
        SSH_CREDENTIALS_ID    = 'ssh-key'
        TERRAFORM_DIR         = '.'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Show Branch Info') {
            steps {
                echo "Running on branch: ${env.BRANCH_NAME}"
            }
        }

        stage('Resolve TFVARS') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'dev') {
                        env.TFVARS_FILE = 'dev.tfvars'
                    } else if (env.BRANCH_NAME in ['prod', 'main', 'master']) {
                        env.TFVARS_FILE = 'prod.tfvars'
                    } else {
                        env.TFVARS_FILE = "${env.BRANCH_NAME}.tfvars"
                    }
                }

                dir("${TERRAFORM_DIR}") {
                    script {
                        if (!fileExists(env.TFVARS_FILE)) {
                            error "TFVARS file not found: ${env.TFVARS_FILE}"
                        }
                    }
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: env.AWS_CREDENTIALS_ID]
                    ]) {
                        sh 'terraform init -input=false'
                    }
                }
            }
        }

        stage('Inspect TFVARS') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    sh 'cat "${TFVARS_FILE}"'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: env.AWS_CREDENTIALS_ID]
                    ]) {
                        sh '''#!/bin/bash
                        set -euo pipefail
                        terraform plan \
                          -input=false \
                          -var-file="${TFVARS_FILE}" \
                          -out=tfplan
                        '''
                    }
                }
            }
        }

        stage('Manual Approval (DEV only)') {
            when {
                branch 'dev'
            }
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: 'Approve Terraform Apply for DEV?'
                }
            }
        }

        stage('Terraform Apply (DEV only)') {
            when {
                branch 'dev'
            }
            steps {
                dir("${TERRAFORM_DIR}") {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: env.AWS_CREDENTIALS_ID]
                    ]) {
                        sh '''#!/bin/bash
                        set -euo pipefail
                        terraform apply -auto-approve tfplan
                        '''
                    }
                }
            }
        }

        stage('Capture Instance IP (DEV only)') {
            when {
                branch 'dev'
            }
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        env.INSTANCE_IP = sh(
                            script: 'terraform output -raw instance_public_ip',
                            returnStdout: true
                        ).trim()
                    }
                    echo "EC2 Instance IP: ${env.INSTANCE_IP}"
                }
            }
        }

        stage('Install Grafana (DEV only)') {
            when {
                branch 'dev'
            }
            steps {
                withCredentials([sshUserPrivateKey(
                    credentialsId: SSH_CREDENTIALS_ID,
                    keyFileVariable: 'SSH_KEY'
                )]) {
                    sh '''#!/bin/bash
                    set -euo pipefail

                    ssh -o StrictHostKeyChecking=no \
                        -o ConnectTimeout=10 \
                        -i "$SSH_KEY" ubuntu@"$INSTANCE_IP" << EOF
                    sudo apt update
                    sudo apt install -y grafana
                    sudo systemctl enable grafana-server
                    sudo systemctl start grafana-server
                    EOF
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline finished successfully for branch ${env.BRANCH_NAME}"
        }
        failure {
            echo "Pipeline failed for branch ${env.BRANCH_NAME}"
        }
    }
}

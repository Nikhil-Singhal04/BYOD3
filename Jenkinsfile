pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
        AWS_CREDENTIALS_ID = 'AWS-CREDS'
        SSH_CREDENTIALS_ID = 'SSH_CRED_ID'
        // Terraform files live in the repo root in this workspace
        TERRAFORM_DIR = '.'
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
                echo "hello"
                echo "world"
                echo "world"
            }
        }

        stage('Resolve TFVARS') {
            steps {
                script {
                    def defaultTfvars = "${env.BRANCH_NAME}.tfvars"
                    def mappedTfvars = defaultTfvars

                    if (env.BRANCH_NAME == 'dev') {
                        mappedTfvars = 'dev.tfvars'
                    } else if (env.BRANCH_NAME in ['prod', 'main', 'master']) {
                        mappedTfvars = 'prod.tfvars'
                    }

                    env.TFVARS_FILE = mappedTfvars
                }

                dir("${TERRAFORM_DIR}") {
                    script {
                        if (!fileExists(env.TFVARS_FILE)) {
                            error "TFVARS file not found: ${env.TFVARS_FILE} (branch: ${env.BRANCH_NAME})"
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
                        sh '''
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
                        sh 'terraform apply -auto-approve tfplan'
                    }
                }
            }
        }
        stage('Install Grafana') {
            when { branch 'dev' }
            steps {
                script {
                    def sshUser = env.GRAFANA_SSH_USER ?: 'ec2-user'
                    withCredentials([
                        sshUserPrivateKey(credentialsId: env.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY')
                    ]) {
                        sh """
                            set -euo pipefail

                            IP=\$(terraform output -raw instance_public_ip)
                            echo "Installing Grafana on \${IP} as ${sshUser}"

                            if ! command -v ansible-playbook >/dev/null 2>&1; then
                                echo "ansible-playbook not found; attempting install..."
                                if command -v python3 >/dev/null 2>&1; then
                                    python3 -m pip --version >/dev/null 2>&1 || python3 -m ensurepip --upgrade
                                    python3 -m pip install --user ansible
                                    export PATH=\"\$HOME/.local/bin:\$PATH\"
                                elif command -v apt-get >/dev/null 2>&1; then
                                    sudo apt-get update
                                    sudo apt-get install -y ansible
                                else
                                    echo "No supported installer found for Ansible on this agent. Install ansible-playbook on the Jenkins agent and retry."
                                    exit 1
                                fi
                            fi

                            ansible-playbook -i \"\${IP},\" ansible/install_grafana.yml \
                                -u ${sshUser} \
                                --private-key \"\$SSH_KEY\" \
                                --ssh-common-args='-o StrictHostKeyChecking=no'
                        """
                    }
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

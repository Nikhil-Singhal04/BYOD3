pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'

        AWS_CREDENTIALS_ID = 'AWS-CREDS'
        SSH_CREDENTIALS_ID = 'ssh-key'
        SPLUNK_ADMIN_PASSWORD_CREDENTIALS_ID = 'SPLUNK-ADMIN-PASSWORD'

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
            }
        }

        stage('Resolve TFVARS') {
            steps {
                script {
                    def tfvars = "${env.BRANCH_NAME}.tfvars"

                    if (env.BRANCH_NAME == 'dev') {
                        tfvars = 'dev.tfvars'
                    } else if (env.BRANCH_NAME in ['prod', 'main', 'master']) {
                        tfvars = 'prod.tfvars'
                    }

                    env.TFVARS_FILE = tfvars
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

        stage('Terraform Apply') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: env.AWS_CREDENTIALS_ID]
                    ]) {
                        sh 'terraform apply -input=false -auto-approve tfplan'
                    }
                }
            }
        }

        stage('Capture Terraform Outputs') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        env.INSTANCE_IP = sh(
                            script: 'terraform output -raw instance_public_ip',
                            returnStdout: true
                        ).trim()

                        env.INSTANCE_ID = sh(
                            script: 'terraform output -raw instance_id',
                            returnStdout: true
                        ).trim()
                    }

                    echo "INSTANCE_IP = ${env.INSTANCE_IP}"
                    echo "INSTANCE_ID = ${env.INSTANCE_ID}"
                }
            }
        }

        stage('Write Dynamic Inventory') {
            steps {
                sh '''
                cat > dynamic_inventory.ini <<EOF
[splunk]
${INSTANCE_IP}

[splunk:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/splunk.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
                '''
                sh 'cat dynamic_inventory.ini'
            }
        }

        stage('Wait for EC2 Health Checks') {
            steps {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: env.AWS_CREDENTIALS_ID]
                ]) {
                    sh 'aws ec2 wait instance-status-ok --instance-ids "${INSTANCE_ID}"'
                }
            }
        }

        stage('Ansible: Install Splunk') {
            steps {
                withCredentials([
                    string(credentialsId: env.SPLUNK_ADMIN_PASSWORD_CREDENTIALS_ID,
                           variable: 'SPLUNK_ADMIN_PASSWORD')
                ]) {
                    ansiblePlaybook(
                        playbook: 'playbooks/splunk.yml',
                        inventory: 'dynamic_inventory.ini',
                        credentialsId: env.SSH_CREDENTIALS_ID,
                        extras: "-e splunk_admin_password='${SPLUNK_ADMIN_PASSWORD}'"
                    )
                }
            }
        }

        stage('Ansible: Test Splunk') {
            steps {
                ansiblePlaybook(
                    playbook: 'playbooks/test-splunk.yml',
                    inventory: 'dynamic_inventory.ini',
                    credentialsId: env.SSH_CREDENTIALS_ID
                )
            }
        }

        stage('Validate Destroy') {
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: 'Approve Terraform Destroy?'
                }
            }
        }

        stage('Terraform Destroy') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: env.AWS_CREDENTIALS_ID]
                    ]) {
                        sh 'terraform destroy -input=false -auto-approve -var-file="${TFVARS_FILE}"'
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f dynamic_inventory.ini || true'
        }

        success {
            echo "Pipeline completed successfully for branch ${env.BRANCH_NAME}"
        }

        failure {
            echo "Pipeline failed — infrastructure retained for debugging"
        }

        aborted {
            echo "Pipeline aborted — destroying infrastructure"

            dir("${TERRAFORM_DIR}") {
                withCredentials([
                    [$class: 'AmazonWebServicesCredentialsBinding',
                     credentialsId: env.AWS_CREDENTIALS_ID]
                ]) {
                    sh 'terraform destroy -input=false -auto-approve -var-file="${TFVARS_FILE}" || true'
                }
            }
        }
    }
}

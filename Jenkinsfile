pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
        AWS_CREDENTIALS_ID = 'AWS-CREDS'
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

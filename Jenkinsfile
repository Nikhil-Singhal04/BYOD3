pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_CLI_ARGS      = '-no-color'
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

        stage('Terraform Init') {
            steps {
                {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'AWS-CREDS']
                    ]) {
                        sh 'terraform init'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
               {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'AWS-CREDS']
                    ]) {
                        sh '''
                            terraform plan \
                              -var-file=terraform.tfvars \
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
                {
                    withCredentials([
                        [$class: 'AmazonWebServicesCredentialsBinding',
                         credentialsId: 'AWS-CREDS']
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
    }
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
  # Credentials injected via Jenkins
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "splunk" {
  name        = "splunk-sg"
  description = "Allow SSH and Splunk Web"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Splunk Web"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_splunk_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami           = "ami-0ecb62995f68bb549"   # Ubuntu AMI
  instance_type = var.instance_type

  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.splunk.id]

  # 🔥 CRITICAL FIX — DO NOT REMOVE
  root_block_device {
    volume_size = 30        # Required for Splunk Docker
    volume_type = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "SplunkInstance"
  }
}

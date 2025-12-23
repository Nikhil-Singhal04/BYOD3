terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region # Use the variable for region
  # Credentials will be supplied via e
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "grafana" {
  name        = "grafana-sg"
  description = "Allow SSH and Grafana"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_grafana_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami           = "ami-0ecb62995f68bb549" # Replace with a suitable AMI
  instance_type = var.instance_type # Use the variable for instance type

  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.grafana.id]

  tags = {
    Name = "ExampleInstance"
  }
}
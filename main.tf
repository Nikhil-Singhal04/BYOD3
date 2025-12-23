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

resource "aws_instance" "example" {
  ami           = "ami-0ecb62995f68bb549" # Replace with a suitable AMI
  instance_type = var.instance_type # Use the variable for instance type

  tags = {
    Name = "ExampleInstance"
  }
}
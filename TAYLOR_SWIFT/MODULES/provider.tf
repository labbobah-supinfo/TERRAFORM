terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.26.0"
    }
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

# Configure the AWS Provider
provider "aws" { 
  region = "eu-west-3"
}

# Configure the Docker Provider
provider "docker" {
}
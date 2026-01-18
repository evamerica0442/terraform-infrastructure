terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.28.0"
    }
  }
}

provider "aws" {
  # Configuration options
}

resource "aws_s3_bucket" "example" {
  bucket = "my-tf-pipeline-test-buck"
  region = "us-east-1"

  tags = {
    Name        = "eatest bucket"
    Environment = "Dev"
  }
}
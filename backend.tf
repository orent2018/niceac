terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
#      version = "~>3.27"
    }
  }

#  required_version = ">=0.14.0"

  #   backend "s3" {
  #     bucket = "niceac-state"
  #     key    = "k8sinfra/terraform.tfstate"
  #     region = "eu-north-1"
  #    }

}

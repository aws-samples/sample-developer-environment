terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94.1"
    }
  }

  backend "s3" {  
    key          = "terraform/statefile.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
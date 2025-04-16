provider "aws" {
  region = var.region

  default_tags {
    tags = {
      environment = var.environment_tag
      provisioner = "Terraform"
      solution    = var.solution_tag
    }
  }
}
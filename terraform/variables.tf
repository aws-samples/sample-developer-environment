variable "region" {
  type        = string
  description = "AWS region for resource deployment"
}
variable "vpc_cidr_prefix" {
  type        = string
  description = "Network addressing prefix (first two octets) for VPC and subnet CIDR blocks, e.g., '10.180'"
}
variable "github_repo" {
  type        = string
  description = "GitHub repository URL to clone as initial workspace content for code-server"
}
variable "s3_asset_bucket" {
  type        = string
  description = "(Optional) S3 path for initial workspace content in format 'my-bucket-name'. If provided, this OVERWRITES GitHubRepo parameter."
}
variable "s3_asset_prefix" {
  type        = string
  description = "(Optional) Asset prefix path. Only required when S3AssetBucket is specified. Must end in '/' e.g. 'assets/' or 'assets/solution/'"
}
variable "deploy_pipeline" {
  type        = bool
  description = "Deploy AWS CodePipeline with CodeBuild to automatically build/destroy infrastructure using Terraform"
}
variable "rotate_secret" {
  type        = bool
  description = "Rotate code-server secret every 30 days"
}
variable "auto_set_developer_profile" {
  type        = bool
  description = "Automatically set Developer profile as default in code-server terminal sessions without requiring elevation"
}
variable "code_server_version" {
  type        = string
  description = "Version of code-server to install. See available versions at github.com/coder/code-server/releases"
}
variable "instance_architecture" {
  type        = string
  description = "Choose amd64 for AMD/Intel instances or arm64 for Graviton instances"

  validation {
    condition     = var.instance_architecture == "amd64" || var.instance_architecture == "arm64"
    error_message = "Instance architecture must be either amd64 or arm64"
  }
}
variable "instance_type" {
  type        = string
  description = "EC2 instance type MUST match architecture. amd64= t3.small, t3a.large, c6i.xlarge, m6a.2xlarge, etc. arm64= t4g.large, c7g.xlarge, m6g.2xlarge, etc."
}
variable "ami_x86_code_server" {
  type        = string
  description = "SSM parameter path for x86_64 AMI (used for AMD/Intel instances)"
}
variable "ami_arm_code_server" {
  type        = string
  description = "SSM parameter path for arm64 AMI (used for Graviton instances)"
}
variable "prefix_code" {
  type        = string
  description = "Resource naming prefix for uniqueness and organization. Six characters or less. Cannot start with 'aws'"
}
variable "environment_tag" {
  type        = string
  description = "Environment identifier for resource tagging e.g. dev, prod"
}
variable "solution_tag" {
  type        = string
  description = "Solution identifier for resource tagging and grouping. Use alphanumeric characters only"
}
variable "region_alb_account_ids" {
  type        = map(string)
  description = "ALB account IDs by region for S3 bucket policy"
  default = {
    "ap-northeast-1" = "582318560864"
    "ap-northeast-2" = "600734575887"
    "ap-northeast-3" = "383597477331"
    "ap-south-1"     = "718504428378"
    "ap-southeast-1" = "114774131450"
    "ap-southeast-2" = "783225319266"
    "ca-central-1"   = "985666609251"
    "eu-central-1"   = "054676820928"
    "eu-north-1"     = "897822967062"
    "eu-west-1"      = "156460612806"
    "eu-west-2"      = "652711504416"
    "eu-west-3"      = "009996457667"
    "sa-east-1"      = "507241528517"
    "us-east-1"      = "127311923021"
    "us-east-2"      = "033677994240"
    "us-west-1"      = "027434742980"
    "us-west-2"      = "797873946194"
  }
}
variable "cloudfront_prefix_lists" {
  type        = map(string)
  description = "CloudFront Prefix List IDs by region"
  default = {
    "ap-northeast-1" = "pl-58a04531"
    "ap-northeast-2" = "pl-22a6434b"
    "ap-northeast-3" = "pl-31a14458"
    "ap-south-1"     = "pl-9aa247f3"
    "ap-southeast-1" = "pl-31a34658"
    "ap-southeast-2" = "pl-b8a742d1"
    "ca-central-1"   = "pl-38a64351"
    "eu-central-1"   = "pl-a3a144ca"
    "eu-north-1"     = "pl-fab65393"
    "eu-west-1"      = "pl-4fa04526"
    "eu-west-2"      = "pl-93a247fa"
    "eu-west-3"      = "pl-75b1541c"
    "sa-east-1"      = "pl-5da64334"
    "us-east-1"      = "pl-3b927c52"
    "us-east-2"      = "pl-b6a144df"
    "us-west-1"      = "pl-4ea04527"
    "us-west-2"      = "pl-82a045eb"
  }
}
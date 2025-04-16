variable "prefix_code" {
  type        = string
  description = "Resource naming prefix for uniqueness"
}
variable "region" {
  type        = string
  description = "AWS region for resource deployment"
}
variable "solution_tag" {
  type        = string
  description = "Solution identifier for resource tagging"
}
variable "environment_tag" {
  type        = string
  description = "Environment identifier for resource tagging"
}
variable "kms_key_arn" {
  type        = string
  description = "ARN of KMS key for encryption"
}
variable "vpc_id" {
  type        = string
  description = "VPC ID for CodeBuild VPC configuration"
}
variable "subnet_id" {
  type        = string
  description = "Private subnet ID for CodeBuild VPC configuration"
}
variable "security_group_id" {
  type        = string
  description = "Security group ID for CodeBuild VPC configuration"
}
variable "source_bucket" {
  type        = string
  description = "S3 bucket containing source code and used for artifacts/state"
}
variable "source_key" {
  type        = string
  description = "S3 key path to source code zip file"
}
variable "developer_role_name" {
  type        = string
  description = "Name of the developer role"
}
variable "developer_role_arn" {
  type        = string
  description = "ARN of developer role used by CodeBuild"
}
variable "buildspec_build" {
  type        = string
  description = "Buildspec content for the build/apply action"
}
variable "buildspec_destroy" {
  type        = string
  description = "Buildspec content for the destroy action"
}
variable "name" {
  type        = string
  description = "Unique name for this pipeline"
}
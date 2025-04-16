variable "prefix_code" {
  type        = string
  description = "Resource naming prefix"
}
variable "kms_key_arn" {
  type        = string
  description = "ARN of KMS key for encryption"
}
variable "logs_bucket_id" {
  type        = string
  description = "ID of central logging bucket"
}
variable "name" {
  type        = string
  description = "Name of the git repository"
}
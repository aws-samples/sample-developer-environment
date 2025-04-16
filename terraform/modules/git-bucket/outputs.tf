output "bucket_id" {
  value = aws_s3_bucket.git.id
}

output "bucket_arn" {
  value = aws_s3_bucket.git.arn
}

output "bucket_name" {
  value = aws_s3_bucket.git.bucket
}

output "access_policy_arn" {
  value = aws_iam_policy.git_bucket_access.arn
}
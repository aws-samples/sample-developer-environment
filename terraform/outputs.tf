output "cloudfront_url" {
  description = "URL to access code-server through CloudFront"
  value       = "https://${aws_cloudfront_distribution.code_server.domain_name}"
}

output "code_server_password" {
  description = "Retrieve your initial code-server password from AWS Secrets Manager. If rotation is enabled, check the 'rotating-codeserver' secret instead"
  value       = "https://${var.region}.console.aws.amazon.com/secretsmanager/secret?name=${aws_secretsmanager_secret.code_server.name}"
}
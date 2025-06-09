### Resource Group - Groups all AWS resources for easy management and tracking
resource "aws_resourcegroups_group" "main" {
  name        = "${var.prefix_code}-resources"
  description = "Sample Developer Environment Resources"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "solution"
          Values = [var.solution_tag]
        }
      ]
    })
    type = "TAG_FILTERS_1_0"
  }

  tags = {
    Name         = "${var.prefix_code}-resources"
    resourcetype = "management"
  }
}

### KMS - Central encryption key for CloudWatch Logs, Secrets Manager, and other AWS services
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "main" {
  description             = "Shared encryption key for AWS services"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Enable Cloudwatch access to KMS Key for VPC log group"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = {
    resourcetype = "security"
  }
}

# KMS Alias
resource "aws_kms_alias" "main" {
  name          = "alias/${var.prefix_code}-kms-cmk"
  target_key_id = aws_kms_key.main.key_id
}

### Network Infrastructure - VPC with public/private subnets and flow logs for developer environment
resource "aws_vpc" "main" {
  cidr_block           = "${var.vpc_cidr_prefix}.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name         = "${var.prefix_code}-vpc01"
    resourcetype = "network"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name        = "${var.prefix_code}-iamrole-vpcflowlogs"
  description = "Publish flow logs to CloudWatch Logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name         = "${var.prefix_code}-iamrole-VpcFlowLogs"
    resourcetype = "security"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.prefix_code}-iampolicy-VpcFlowLogsPermissions"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = [
        "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/events/${var.prefix_code}-vpcflowlog:*",
        "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/events/${var.prefix_code}-vpcflowlog:*:*"
      ]
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.prefix_code}-flowlog"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name         = "${var.prefix_code}-vpcflowloggroup"
    resourcetype = "monitoring"
  }
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Name         = "${var.prefix_code}-vpcflowlog"
    resourcetype = "monitoring"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name         = "${var.prefix_code}-internetgateway"
    resourcetype = "network"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_01" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "${var.vpc_cidr_prefix}.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name         = "${var.prefix_code}-subnet-public01-${data.aws_availability_zones.available.names[0]}"
    resourcetype = "network"
  }
}

resource "aws_subnet" "public_02" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "${var.vpc_cidr_prefix}.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name         = "${var.prefix_code}-subnet-public02-${data.aws_availability_zones.available.names[1]}"
    resourcetype = "network"
  }
}

resource "aws_subnet" "private_01" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "${var.vpc_cidr_prefix}.3.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name         = "${var.prefix_code}-subnet-private01-${data.aws_availability_zones.available.names[0]}"
    resourcetype = "network"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name         = "${var.prefix_code}-eip-${data.aws_availability_zones.available.names[0]}"
    resourcetype = "network"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_01.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name         = "${var.prefix_code}-nat-public01-${data.aws_availability_zones.available.names[0]}"
    resourcetype = "network"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name         = "${var.prefix_code}-routetable-public"
    resourcetype = "network"
  }
}

resource "aws_route_table_association" "public_01" {
  subnet_id      = aws_subnet.public_01.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_02" {
  subnet_id      = aws_subnet.public_02.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name         = "${var.prefix_code}-routetable-private1"
    resourcetype = "network"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_01.id
  route_table_id = aws_route_table.private.id
}

### Centralized logging bucket for CloudFront and S3 access logs
resource "aws_s3_bucket" "logs" {
  bucket_prefix = "${var.prefix_code}-git-logs"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "DeleteOldLogs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }
  }
}

data "aws_iam_policy_document" "logs_bucket" {
  statement {
    sid    = "EnforceSecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "Allow TLS 1.2 and above"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*"
    ]

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }

  statement {
    sid    = "Allow ALB logging access regions available as of August 2022 or later"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*"
    ]
  }

  statement {
    sid    = "Allow ALB logging access regions available before August 2022"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.region_alb_account_ids[var.region]}:root"]
    }

    actions = ["s3:PutObject"]

    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*"
    ]
  }

  statement {
    sid    = "Allow S3 Logging Service for git and artifact buckets"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.logs.arn}/s3-logs/git/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:s3:::${terraform.workspace}-git-*"]
    }
  }

  statement {
    sid    = "Allow ALB Logging"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.region_alb_account_ids[var.region]}:root"]
    }

    actions = ["s3:PutObject"]

    resources = ["${aws_s3_bucket.logs.arn}/alb-logs/*"]
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket.json
}

### Access Layer - ALB and CloudFront distribution for secure access to code-server
resource "aws_lb" "code_server" {
  name               = "${var.prefix_code}-alb-codeserver"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_01.id, aws_subnet.public_02.id]

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = "alb-logs"
    enabled = true
  }

  tags = {
    Name         = "${var.prefix_code}-alb-codeserver"
    resourcetype = "network"
  }

  # checkov:skip=CKV_AWS_131: "ALB uses HTTP for internal AWS traffic. Security handled by CloudFront HTTPS and origin verification"
}

resource "aws_lb_target_group" "code_server" {
  name        = "${var.prefix_code}-targetgroup-codeserver"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path = "/login"
    port = 8080
  }

  tags = {
    Name         = "${var.prefix_code}-targetgroup-codeserver"
    resourcetype = "network"
  }
}

resource "aws_lb_target_group_attachment" "code_server" {
  target_group_arn = aws_lb_target_group.code_server.arn
  target_id        = aws_instance.code_server.id
  port             = 8080
}

resource "aws_lb_listener" "code_server" {
  load_balancer_arn = aws_lb.code_server.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Access Denied"
      status_code  = "403"
    }
  }

  # checkov:skip=CKV_AWS_2: "ALB uses HTTP for internal AWS traffic. Security handled by CloudFront HTTPS and origin verification"
  # checkov:skip=CKV_AWS_103: "TLS check not applicable - ALB uses HTTP internally. External TLS 1.2 enforced at CloudFront"
}

# Allow traffic only if secret header from CloudFront is present
resource "aws_lb_listener_rule" "code_server" {
  listener_arn = aws_lb_listener.code_server.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.code_server.arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Verify"
      values           = [random_password.cloudfront_header.result]
    }
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.prefix_code}-securitygroup-alb"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP inbound from CloudFront"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [var.cloudfront_prefix_lists[var.region]]
  }

  egress {
    description     = "Allow to EC2"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.code_server.id]
  }

  tags = {
    Name         = "${var.prefix_code}-securitygroup-alb"
    resourcetype = "security"
  }
}

resource "aws_cloudfront_cache_policy" "code_server" {
  name        = "${var.prefix_code}-cloudfront-policy"
  comment     = "Cache policy for VS code-server allows caching with cookie/header/query string forwarding"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "all"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Host", "Origin", "Authorization"]
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }
    enable_accept_encoding_gzip = true
  }
}

# CloudFront distribution adds secret header to all requests to ALB
resource "aws_cloudfront_distribution" "code_server" {
  enabled = true

  origin {
    domain_name = aws_lb.code_server.dns_name
    origin_id   = "CodeServerOrigin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443 # Required even if not used
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"] # Required even if not used
    }

    custom_header {
      name  = "X-Origin-Verify"
      value = random_password.cloudfront_header.result
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "CodeServerOrigin"
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = aws_cloudfront_cache_policy.code_server.id
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3" # Managed AllViewer Policy
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "cloudfront-logs/"
  }

  tags = {
    Name         = "${var.prefix_code}-cloudfrontdistribution-alb"
    resourcetype = "network"
  }

  # checkov:skip=CKV_AWS_174: "Using CloudFront default certificate with TLS 1.2"
  # checkov:skip=CKV_AWS_68: "WAF not implemented for development environment"
}

# CloudFront Secret Header
resource "aws_secretsmanager_secret" "cloudfront_header" {
  name        = "${var.prefix_code}-secret-cloudfrontheader"
  description = "Origin verification header for code-server CloudFront distribution"
  kms_key_id  = aws_kms_key.main.arn

  tags = {
    Name         = "${var.prefix_code}-secret-cloudfrontheader"
    resourcetype = "security"
  }
}

resource "aws_secretsmanager_secret_version" "cloudfront_header" {
  secret_id = aws_secretsmanager_secret.cloudfront_header.id

  secret_string = jsonencode({
    HeaderName  = "X-Origin-Verify"
    HeaderValue = random_password.cloudfront_header.result
  })
}

resource "random_password" "cloudfront_header" {
  length      = 32
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

resource "aws_security_group" "code_server" {
  name        = "${var.prefix_code}-securitygroup-codeserver"
  description = "code-server security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name         = "${var.prefix_code}-securitygroup-codeserver"
    resourcetype = "security"
  }
}

resource "aws_security_group_rule" "code_server_ingress" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.code_server.id
  description              = "Allow inbound from ALB"
}

resource "aws_security_group_rule" "code_server_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.code_server.id
  description       = "Allow all outbound traffic"
}

resource "aws_secretsmanager_secret" "code_server" {
  name        = "${var.prefix_code}-secret-codeserver"
  description = "Initial code-server password. If rotation enabled, refer to the rotating secret after 30 days."
  kms_key_id  = aws_kms_key.main.arn

  tags = {
    Name         = "${var.prefix_code}-secret-codeserver"
    resourcetype = "security"
  }
}

resource "aws_secretsmanager_secret_version" "code_server" {
  secret_id = aws_secretsmanager_secret.code_server.id

  secret_string = jsonencode({
    username = "ec2-user"
    password = random_password.code_server.result
  })
}

resource "random_password" "code_server" {
  length      = 16
  special     = false
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

### Source Control Storage - S3 bucket configured as a git remote for version control, acting as a serverless git repository with encryption and access controls
module "git_repo_main" {
  source         = "./modules/git-bucket"
  prefix_code    = var.prefix_code
  kms_key_arn    = aws_kms_key.main.arn
  logs_bucket_id = aws_s3_bucket.logs.id
  name           = "main"
}

resource "aws_iam_role_policy_attachment" "devbox_repo" {
  policy_arn = module.git_repo_main.access_policy_arn
  role       = aws_iam_role.code_server.name
}

### Development Environment - EC2 instance running code-server with developer tools and git integration
resource "aws_iam_role" "code_server" {
  name        = "${var.prefix_code}-iamrole-codeserver"
  description = "Code-server EC2 Instance Profile"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name         = "${var.prefix_code}-iamrole-codeserver"
    resourcetype = "security"
  }
}

resource "aws_iam_role_policy" "ec2" {
  name = "${var.prefix_code}-iampolicy-EC2"
  role = aws_iam_role.code_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:DescribeTags"
      ]
      Resource = "*"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ssm" {
  name = "${var.prefix_code}-iampolicy-codeserver-SystemsManager"
  role = aws_iam_role.code_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:StartSession"]
      Resource = [
        "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:*",
        "arn:aws:ssm:${var.region}::document/AWS-StartPortForwardingSession"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "${var.prefix_code}-iampolicy-codeserver-CloudWatch"
  role = aws_iam_role.code_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = [
        "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/code-server/${var.prefix_code}",
        "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/code-server/${var.prefix_code}:*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "kms" {
  name = "${var.prefix_code}-iampolicy-codeserver-KMS"
  role = aws_iam_role.code_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey"
      ]
      Resource = [aws_kms_key.main.arn]
    }]
  })
}

resource "aws_iam_role_policy" "secrets" {
  name = "${var.prefix_code}-iampolicy-codeserver-secretsmanager"
  role = aws_iam_role.code_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [aws_secretsmanager_secret.code_server.arn]
    }]
  })
}

resource "aws_iam_role_policy" "ssm_params" {
  name = "${var.prefix_code}-iampolicy-codeserver-SSM"
  role = aws_iam_role.code_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = ["arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.prefix_code}/config/AmazonCloudWatch-linux"]
    }]
  })
}

# Policy allowing code-server user to assume the developer role
resource "aws_iam_role_policy" "assume_developer" {
  name = "${var.prefix_code}-iampolicy-assume-Developer"
  role = aws_iam_role.code_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.developer.arn
    }]
  })
}

resource "aws_iam_instance_profile" "code_server" {
  name = "${var.prefix_code}-iamprofile-ec2admin"
  role = aws_iam_role.code_server.name
}

resource "tls_private_key" "code_server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "code_server" {
  key_name   = "${var.prefix_code}-ec2-keypair"
  public_key = tls_private_key.code_server.public_key_openssh
}

resource "aws_ssm_parameter" "code_server_private_key" {
  name  = "/${var.prefix_code}/ec2/keypair"
  type  = "SecureString"
  value = tls_private_key.code_server.private_key_pem
}

resource "aws_cloudwatch_log_group" "code_server" {
  name              = "/aws/ec2/${var.prefix_code}-codeserver"
  retention_in_days = 14

  tags = {
    Name         = "${var.prefix_code}-ec2loggroup"
    resourcetype = "monitoring"
  }
}

resource "aws_ssm_parameter" "cloudwatch_linux" {
  name        = "/${var.prefix_code}/config/AmazonCloudWatch-linux"
  type        = "String"
  description = "CloudWatch Agent configuration for linux instances"

  value = jsonencode({
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/cloud-init-output.log"
              log_group_name  = "/aws/code-server/${var.prefix_code}"
              log_stream_name = "setup"
            }
          ]
        }
      }
    }
  })

  tags = {
    Name         = "${var.prefix_code}-ssm-cloudwatch-linux"
    resourcetype = "monitoring"
  }
}

data "aws_ssm_parameter" "ami_arm" {
  name = var.ami_arm_code_server
}

data "aws_ssm_parameter" "ami_x86" {
  name = var.ami_x86_code_server
}

resource "aws_instance" "code_server" {
  ami           = var.instance_architecture == "arm64" ? data.aws_ssm_parameter.ami_arm.value : data.aws_ssm_parameter.ami_x86.value
  instance_type = var.instance_type
  key_name      = aws_key_pair.code_server.key_name

  subnet_id              = aws_subnet.private_01.id
  iam_instance_profile   = aws_iam_instance_profile.code_server.name
  monitoring             = true
  private_ip             = "${var.vpc_cidr_prefix}.3.101"
  vpc_security_group_ids = [aws_security_group.code_server.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    iops                  = 3000
    encrypted             = true
    kms_key_id            = aws_kms_key.main.arn
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/instance_user_data.sh", {
    prefix              = var.prefix_code
    region              = var.region
    code_server_version = var.code_server_version
    instance_arch       = var.instance_architecture
    secret_id           = aws_secretsmanager_secret.code_server.id
    auto_set_profile    = var.auto_set_developer_profile
    account_id          = data.aws_caller_identity.current.account_id
    github_repo         = var.github_repo
    s3_asset_bucket     = var.s3_asset_bucket
    s3_asset_prefix     = var.s3_asset_prefix
    git_bucket_main     = module.git_repo_main.bucket_name
  }))

  tags = {
    Name         = "${var.prefix_code}-ec2-codeserver"
    resourcetype = "compute"
  }

  # checkov:skip=CKV_AWS_88: "Development instance uses S3 for code and state persistence"
}
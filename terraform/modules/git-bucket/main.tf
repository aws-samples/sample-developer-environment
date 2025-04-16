resource "aws_s3_bucket" "git" {
  bucket_prefix = "${var.prefix_code}-git-${var.name}"
  force_destroy = true

  tags = {
    resourcetype = "storage"
    repository   = var.name
  }
}

resource "aws_s3_bucket_versioning" "git" {
  bucket = aws_s3_bucket.git.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "git" {
  bucket = aws_s3_bucket.git.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "git" {
  bucket = aws_s3_bucket.git.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "git" {
  bucket = aws_s3_bucket.git.id

  target_bucket = var.logs_bucket_id
  target_prefix = "s3-logs/git/${var.name}/"
}

resource "aws_s3_bucket_notification" "git" {
  bucket = aws_s3_bucket.git.id

  eventbridge = true
}

data "aws_iam_policy_document" "git_bucket" {
  statement {
    sid    = "EnforceSecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    
    resources = [
      aws_s3_bucket.git.arn,
      "${aws_s3_bucket.git.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

resource "aws_s3_bucket_policy" "git" {
  bucket = aws_s3_bucket.git.id
  policy = data.aws_iam_policy_document.git_bucket.json
}

resource "aws_iam_policy" "git_bucket_access" {
  name        = "${var.prefix_code}-git-${var.name}-access"
  description = "Allow EC2 instance to access git repository bucket ${var.name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = ["${aws_s3_bucket.git.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.git.arn]
      }
    ]
  })
}
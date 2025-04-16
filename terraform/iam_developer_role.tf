resource "aws_iam_role" "developer" {
  name        = "${var.prefix_code}-iamrole-developer"
  description = "Elevated permissions for AWS infrastructure deployment and resource management"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
        AWS     = aws_iam_role.code_server.arn
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name         = "${var.prefix_code}-iamrole-developer"
    resourcetype = "security"
  }
}

resource "aws_iam_role_policy" "developer_kms" {
  name = "${var.prefix_code}-iampolicy-terraform-kms-key"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateKey",
          "kms:ListAliases"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:EnableKeyRotation",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:ListResourceTags",
          "kms:PutKeyPolicy",
          "kms:RetireGrant",
          "kms:ScheduleKeyDeletion",
          "kms:TagResource"
        ]
        Resource = "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:DeleteAlias"
        ]
        Resource = [
          "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:alias/*",
          "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "developer_s3" {
  name = "${var.prefix_code}-iampolicy-terraform-s3"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          "arn:aws:s3:::${var.prefix_code}-*",
          "arn:aws:s3:::${var.prefix_code}-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "developer_cloudfront" {
  name = "${var.prefix_code}-iampolicy-terraform-cloudfront"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["cloudfront:*"]
      Resource = [
        "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/*",
        "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:origin-access-control/*",
        "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:response-headers-policy/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "developer_waf" {
  name = "${var.prefix_code}-iampolicy-terraform-waf"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["wafv2:ListWebACLs"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:CreateWebACL",
          "wafv2:DeleteWebACL",
          "wafv2:GetWebACL",
          "wafv2:UpdateWebACL",
          "wafv2:ListTagsForResource",
          "wafv2:TagResource",
          "wafv2:UntagResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "wafv2:GetManagedRuleSet",
          "wafv2:ListAvailableManagedRuleGroups"
        ]
        Resource = [
          "arn:aws:wafv2:us-east-1:${data.aws_caller_identity.current.account_id}:global/webacl/*",
          "arn:aws:wafv2:us-east-1:${data.aws_caller_identity.current.account_id}:global/managedruleset/*",
          "arn:aws:wafv2:us-east-1:${data.aws_caller_identity.current.account_id}:global/managedruleset/*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "developer_ec2_codebuild" {
  name = "${var.prefix_code}-iampolicy-ec2codebuild"
  role = aws_iam_role.developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeInstances",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs",
        "ec2:DeleteNetworkInterface",
        "ec2:CreateNetworkInterface"
      ]
      Resource = "*"
    }]
  })
}
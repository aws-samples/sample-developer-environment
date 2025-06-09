### CI/CD - CodeBuild and CodePipeline for automated infrastructure deployment
data "aws_caller_identity" "current" {}

locals {
  pipeline_name = "${var.prefix_code}-pipeline-${var.name}"
}

resource "aws_iam_role_policy" "developer_pipeline_logs" {
  name = "${local.pipeline_name}-logs"
  role = var.developer_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/codebuild/*"
    }]
  })
}

resource "aws_iam_role_policy" "developer_pipeline_network" {
  name = "${local.pipeline_name}-network"
  role = var.developer_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "ec2:CreateNetworkInterfacePermission"
      Resource = "arn:aws:ec2:${var.region}:*:network-interface/*"
      Condition = {
        StringEquals = {
          "ec2:AuthorizedService" = "codebuild.amazonaws.com"
        }
        ArnEquals = {
          "ec2:Subnet" = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:subnet/${var.subnet_id}"
        }
      }
    }]
  })
}

resource "aws_codebuild_project" "build" {
  name         = "${local.pipeline_name}-build"
  description  = "Deploy ${var.name} AWS resources"
  service_role = var.developer_role_arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "NO_SOURCE"
    buildspec = var.buildspec_build
  }

  vpc_config {
    vpc_id             = var.vpc_id
    subnets           = [var.subnet_id]
    security_group_ids = [var.security_group_id]
  }

  tags = {
    Name         = "${local.pipeline_name}-build"
    resourcetype = "devops"
  }
}

resource "aws_codebuild_project" "destroy" {
  name         = "${local.pipeline_name}-destroy"
  description  = "Destroy ${var.name} AWS resources"
  service_role = var.developer_role_arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "NO_SOURCE"
    buildspec = var.buildspec_destroy
  }

  vpc_config {
    vpc_id             = var.vpc_id
    subnets           = [var.subnet_id]
    security_group_ids = [var.security_group_id]
  }

  tags = {
    Name         = "${local.pipeline_name}-destroy"
    resourcetype = "devops"
  }
}

resource "aws_iam_role" "pipeline" {
  name = "${local.pipeline_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })

  tags = {
    Name         = "${local.pipeline_name}-role"
    resourcetype = "security"
  }
}

resource "aws_iam_role_policy" "pipeline_codebuild" {
  name = "${local.pipeline_name}-codebuild"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "codebuild:StopBuild"
      ]
      Resource = [
        aws_codebuild_project.build.arn,
        aws_codebuild_project.destroy.arn
      ]
    }]
  })
}

resource "aws_iam_role_policy" "pipeline_s3" {
  name = "${local.pipeline_name}-s3"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${var.source_bucket}",
        "arn:aws:s3:::${var.source_bucket}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy" "pipeline_kms" {
  name = "${local.pipeline_name}-kms"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:ReEncrypt*"
      ]
      Resource = [var.kms_key_arn]
    }]
  })
}

resource "aws_iam_role" "eventbridge" {
  name = "${local.pipeline_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name         = "${local.pipeline_name}-eventbridge-role"
    resourcetype = "security"
  }
}

resource "aws_iam_role_policy" "eventbridge_pipeline" {
  name = "${local.pipeline_name}-pipeline-trigger"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "codepipeline:StartPipelineExecution"
      Resource = aws_codepipeline.build.arn
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_logs" {
  name = "${local.pipeline_name}-logs"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.eventbridge.arn}:*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "eventbridge" {
  name              = "/aws/codepipeline/${var.prefix_code}-pipeline"
  retention_in_days = 14

  tags = {
    Name         = "${var.prefix_code}-pipelineloggroup"
    resourcetype = "monitoring"
  }
}

resource "aws_cloudwatch_event_rule" "pipeline_trigger" {
  name = "${local.pipeline_name}-trigger"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [var.source_bucket]
      }
      object = {
        key = [var.source_key]
      }
    }
  })

  tags = {
    Name         = "${local.pipeline_name}-trigger"
    resourcetype = "devops"
  }
}

resource "aws_cloudwatch_event_target" "pipeline_trigger" {
  rule      = aws_cloudwatch_event_rule.pipeline_trigger.name
  target_id = "CodePipelineTarget"
  arn       = aws_codepipeline.build.arn
  role_arn  = aws_iam_role.eventbridge.arn
}

resource "aws_codepipeline" "build" {
  name     = "${local.pipeline_name}-build"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = var.source_bucket
    type     = "S3"

    encryption_key {
      id   = var.kms_key_arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceCode"]

      configuration = {
        S3Bucket             = var.source_bucket
        S3ObjectKey          = var.source_key
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceCode"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  tags = {
    Name         = "${local.pipeline_name}-build"
    resourcetype = "devops"
  }
}

resource "aws_codepipeline" "destroy" {
  name     = "${local.pipeline_name}-destroy"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = var.source_bucket
    type     = "S3"

    encryption_key {
      id   = var.kms_key_arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceCode"]

      configuration = {
        S3Bucket             = var.source_bucket
        S3ObjectKey          = var.source_key
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "Approve"

    action {
      name     = "ApproveDestroy"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "WARNING: This will destroy all ${var.name} pipeline deployed AWS resources. Are you sure?"
      }
    }
  }

  stage {
    name = "Destroy"

    action {
      name            = "Destroy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceCode"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.destroy.name
      }
    }
  }

  tags = {
    Name         = "${local.pipeline_name}-destroy"
    resourcetype = "devops"
  }
}
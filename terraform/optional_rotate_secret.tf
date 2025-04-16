### Lambda-based rotation of code-server password
resource "aws_secretsmanager_secret" "rotating" {
  count       = var.rotate_secret ? 1 : 0
  name        = "${var.prefix_code}-secret-rotating-codeserver"
  description = "Rotating code-server password that updates automatically every 30 days"
  kms_key_id  = aws_kms_key.main.arn

  tags = {
    Name         = "${var.prefix_code}-secret-rotating-codeserver"
    resourcetype = "security"
  }
}

resource "aws_secretsmanager_secret_version" "rotating" {
  count      = var.rotate_secret ? 1 : 0
  secret_id  = aws_secretsmanager_secret.rotating[0].id
  
  secret_string = jsonencode({
    username = "ec2-user"
    password = random_password.rotating[0].result
  })
}

resource "random_password" "rotating" {
  count            = var.rotate_secret ? 1 : 0
  length           = 16
  special          = false
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
}

resource "aws_secretsmanager_secret_rotation" "rotating" {
  count               = var.rotate_secret ? 1 : 0
  secret_id           = aws_secretsmanager_secret.rotating[0].id
  rotation_lambda_arn = aws_lambda_function.rotation[0].arn

  rotation_rules {
    automatically_after_days = 30
  }
}

# https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_lambda-functions.html
data "archive_file" "lambda" {
  count       = var.rotate_secret ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/lambda_rotation.zip"

  source {
    content = <<EOF
import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    # Setup the client
    service_client = boto3.client('secretsmanager', endpoint_url=os.environ['SECRETS_MANAGER_ENDPOINT'])

    # Make sure the version is staged correctly
    metadata = service_client.describe_secret(SecretId=arn)
    if not metadata['RotationEnabled']:
        logger.error("Secret %s is not enabled for rotation" % arn)
        raise ValueError("Secret %s is not enabled for rotation" % arn)
    versions = metadata['VersionIdsToStages']
    if token not in versions:
        logger.error("Secret version %s has no stage for rotation of secret %s." % (token, arn))
        raise ValueError("Secret version %s has no stage for rotation of secret %s." % (token, arn))
    if "AWSCURRENT" in versions[token]:
        logger.info("Secret version %s already set as AWSCURRENT for secret %s." % (token, arn))
        return
    elif "AWSPENDING" not in versions[token]:
        logger.error("Secret version %s not set as AWSPENDING for rotation of secret %s." % (token, arn))
        raise ValueError("Secret version %s not set as AWSPENDING for rotation of secret %s." % (token, arn))

    if step == "createSecret":
        create_secret(service_client, arn, token)
    elif step == "setSecret":
        set_secret(service_client, arn, token)
    elif step == "testSecret":
        test_secret(service_client, arn, token)
    elif step == "finishSecret":
        finish_secret(service_client, arn, token)
    else:
        raise ValueError("Invalid step parameter")

def create_secret(service_client, arn, token):
    current_secret = service_client.get_secret_value(
        SecretId=arn,
        VersionStage="AWSCURRENT"
    )
    current_dict = json.loads(current_secret['SecretString'])

    passwd = service_client.get_random_password(
        ExcludeCharacters='\[]{}>|*&!%#`@,."$:+=-~^()',
        PasswordLength=16,
        RequireEachIncludedType=True
    )

    new_secret = {
        'username': current_dict['username'],
        'password': passwd['RandomPassword']
    }

    service_client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=json.dumps(new_secret),
        VersionStages=['AWSPENDING']
    )
    logger.info(f"createSecret: Successfully put secret for ARN {arn} and version {token}")

def set_secret(service_client, arn, token):
    pending_secret = service_client.get_secret_value(
        SecretId=arn,
        VersionStage="AWSPENDING"
    )
    pending_dict = json.loads(pending_secret['SecretString'])

    ssm = boto3.client('ssm')
    instance_id = os.environ['INSTANCE_ID']

    response = ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName='AWS-RunShellScript',
        Parameters={
            'commands': [
                'cat > /home/ec2-user/.config/code-server/config.yaml << EOL\n'
                'bind-addr: 0.0.0.0:8080\n'
                'auth: password\n'
                f'password: {pending_dict["password"]}\n'
                'cert: false\n'
                'EOL',
                'systemctl restart code-server'
            ]
        }
    )
    logger.info(f"setSecret: Updated code-server config for instance {instance_id}")

def test_secret(service_client, arn, token):
    ssm = boto3.client('ssm')
    instance_id = os.environ['INSTANCE_ID']

    response = ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName='AWS-RunShellScript',
        Parameters={
            'commands': ['systemctl is-active code-server']
        }
    )
    logger.info(f"testSecret: Verified code-server is running on {instance_id}")

def finish_secret(service_client, arn, token):
    metadata = service_client.describe_secret(SecretId=arn)
    current_version = None
    for version in metadata["VersionIdsToStages"]:
        if "AWSCURRENT" in metadata["VersionIdsToStages"][version]:
            if version == token:
                logger.info("finishSecret: Version %s already marked as AWSCURRENT for %s" % (version, arn))
                return
            current_version = version
            break

    service_client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSPENDING",
        RemoveFromVersionId=token
    )
    service_client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version
    )
    logger.info("finishSecret: Successfully set AWSCURRENT stage to version %s for secret %s." % (token, arn))
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "rotation" {
  count         = var.rotate_secret ? 1 : 0
  filename      = data.archive_file.lambda[0].output_path
  function_name = "${var.prefix_code}-lambda-rotation-codeserver"
  role         = aws_iam_role.lambda[0].arn
  handler      = "index.lambda_handler"
  runtime      = "python3.12"

  source_code_hash = data.archive_file.lambda[0].output_base64sha256
  timeout         = 300
  memory_size     = 128

  environment {
    variables = {
      INSTANCE_ID             = aws_instance.code_server.id
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${var.region}.amazonaws.com"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name         = "${var.prefix_code}-lambda-rotation-codeserver"
    resourcetype = "compute"
  }
}

resource "aws_lambda_permission" "rotation" {
  count         = var.rotate_secret ? 1 : 0
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation[0].function_name
  principal     = "secretsmanager.amazonaws.com"
}

resource "aws_iam_role" "lambda" {
  count = var.rotate_secret ? 1 : 0
  name  = "${var.prefix_code}-role-secretrotation-codeserver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name         = "${var.prefix_code}-role-secretrotation-codeserver"
    resourcetype = "security"
  }
}

resource "aws_iam_role_policy" "lambda" {
  count = var.rotate_secret ? 1 : 0
  name  = "${var.prefix_code}-policy-rotation-secret-access"
  role  = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.prefix_code}-lambda-rotation-codeserver:*"]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [aws_secretsmanager_secret.rotating[0].arn]
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetRandomPassword"]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = [aws_kms_key.main.arn]
        Condition = {
          StringEquals = {
            "kms:EncryptionContext:SecretARN" = aws_secretsmanager_secret.rotating[0].arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = [
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.code_server.id}",
          "arn:aws:ssm:${var.region}:*:document/AWS-RunShellScript"
        ]
      }
    ]
  })
}
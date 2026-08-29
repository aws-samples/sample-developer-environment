# sample-developer-environment

> 📢 **v2.0.0 released:** now fully self-contained in a single CloudFormation template, with CodeCommit version control. Using v1? See the [v1.0.0 release notes](https://github.com/aws-samples/sample-developer-environment/releases/tag/v1.0.0).

This solution deploys a complete browser-based development environment with [Kiro IDE](https://kiro.dev/docs/), [Kiro CLI](https://kiro.dev/docs/cli) and VS Code, plus version control and automated deployments, all from a single self-contained AWS CloudFormation template.

## Quick Navigation
- [Repository Structure](#repository-structure)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [Configuration Options](#configuration-options)
- [Useful File Locations](#useful-file-locations)
- [Kiro Setup](#kiro-setup)
- [AWS IAM Roles](#aws-iam-roles)
- [Architecture](#architecture)
- [Sample Application](#sample-application)
- [Security Considerations](#security-considerations)

## Repository Structure

```
.
├── .kiro/                            # Kiro workspace configuration directory
│   └── agents/                       # Agent configuration directory
│       ├── platform-engineer.json    # Platform engineering agent with MCP servers
│       └── data-engineer.json        # Data engineering agent with MCP servers
├── dev/                              # Development workspace
│   └── README.md                     # Development guide
├── release/                          # Sample Terraform application
│   ├── main.tf                       # Core infrastructure
│   ├── provider.tf                   # AWS provider configuration
│   ├── variables.tf                  # Input variables
│   ├── versions.tf                   # Provider versions and backend
│   ├── website.tf                    # Sample static website
│   └── terraform.tfvars              # Variable defaults
└── sample-developer-environment.yml  # Main CloudFormation template (includes the EC2 setup script as an SSM document)
```

## Key Features

- Browser-based VS Code using [code-server](https://github.com/coder/code-server) accessed through Amazon CloudFront
- [Kiro CLI](https://kiro.dev/docs/cli) with the [Agent Toolkit for AWS](https://docs.aws.amazon.com/agent-toolkit/latest/userguide/what-is-agent-toolkit.html) providing the AWS MCP Server and curated AWS skills
- Optional desktop environment with [Kiro IDE](https://kiro.dev/docs/) accessed through DCV
- Git version control using [AWS CodeCommit](https://docs.aws.amazon.com/codecommit/latest/userguide/welcome.html) with native CodePipeline integration
- Automated deployments using AWS CodePipeline and AWS CodeBuild
- Password rotation using AWS Secrets Manager (30-day automatic rotation)
- Pre-configured AWS development environment:
  - AWS Toolkit for VS Code
  - Terraform infrastructure deployment
  - Docker support
  - Git integration

## Quick Start

1. Launch the AWS CloudFormation template `sample-developer-environment.yml`
2. Choose your initial workspace content:
   - Provide a GitHub repository URL in `GitHubRepo` parameter, OR
   - Provide S3 bucket name `S3AssetBucket` and `S3AssetPrefix` parameters
3. Access VS Code through the provided CloudFormation output URL
4. Get your password from AWS Secrets Manager (link in outputs)
5. code-server opens directly in `/home/ec2-user/workspace/my-workspace`, the CodeCommit-backed project directory
6. Test code in `dev`, copy to `release`, commit and push to trigger deployment


## Configuration Options

| Parameter | Description |
|-----------|-------------|
| `AwsCliVersion` | Version of the AWS CLI v2 to install (official installer, replaces the older AL2023 packaged CLI) |
| `CodeServerVersion` | Version of code-server to install |
| `UvVersion` | Version of the uv Python package manager to install (provides uvx for running MCP servers) |
| `TerraformExtensionVersion` | Version of the HashiCorp Terraform code-server extension |
| `DotNetVersion` | .NET SDK version installed when `InstallDotNet` is enabled (8.0 or 10.0) |
| `GitHubRepo` | Public repository to clone as initial workspace. Note: Using a custom repository will not include the sample application |
| `S3AssetBucket` | (Optional) S3 bucket containing initial workspace content. Overwrites GitHubRepo if provided |
| `S3AssetPrefix` | (Optional) S3 bucket asset prefix path. Only required when S3AssetBucket is specified. Needs to end with `/` |
| `DeployPipeline` | Enable AWS CodePipeline deployments |
| `RotateSecret` | Enable AWS Secrets Manager rotation |
| `AutoSetDeveloperProfile` | Automatically set Developer profile as default in code-server terminal sessions without requiring manual elevation |
| `EnableKiroIDE` | Enable Kiro IDE desktop application with DCV |
| `InstallDotNet` | Install .NET SDK (version set by `DotNetVersion`) |
| `InstanceArchitecture` | Choose between ARM (arm64) and x86 (amd64) architecture (Kiro IDE requires x86) |
| `InstanceType` | Pick Amazon EC2 instance type (t3a.large and up recommended for Kiro IDE) |

## Useful File Locations

Here are some handy files you'll find on the EC2 instance:

| File | Description |
|------|-------------|
| `/etc/devbox-env.sh` | Environment variables file |
| `/var/lib/cloud/instance/setup-status.log` | Installation status tracking file |
| `/var/lib/cloud/scripts/per-boot/setup.sh` | Setup script location (runs on every boot) |
| `/var/log/devbox-setup.log` | Log file for setup script output |

The setup script is embedded in the CloudFormation template as an AWS Systems Manager (SSM) document, so the solution is fully self-contained with no external downloads at boot. The instance fetches the script from the document on every boot and skips completed steps. To re-run it on a live instance:

```bash
aws ssm send-command --document-name <PrefixCode>-document-devbox-setup --instance-ids <instance-id>
```

## Kiro Setup

### Prerequisites

1. [Enable IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/confirm-identity-source.html) if you haven't already
2. [Create an IAM Identity Center user](https://docs.aws.amazon.com/singlesignon/latest/userguide/addusers.html) if needed
3. Follow the [Subscribing your team to Kiro](https://kiro.dev/docs/enterprise/subscribe/) guide

### Kiro CLI

From the code-server terminal:

1. Run `kiro-cli login --use-device-flow` and follow prompts for headless authentication

    ![Kiro Setup](img/qsetup.png)

2. Navigate to workspace: `cd /home/ec2-user/workspace/my-workspace`
3. (optional) Set the default agent: `kiro-cli settings chat.defaultAgent platform-engineer`
4. Start with `kiro-cli` or `kiro-cli --agent platform-engineer`
5. Use `/model` to select AI model, `/tools` to see available MCP tools
6. Discover additional AWS skills with `aws agent-toolkit search-skills --search-query <text>`
7. Create additional agents by adding new files to `.kiro/agents/`
8. Use Kiro CLI to accelerate your development 🚀

### Kiro IDE (Desktop Application)

When `EnableKiroIDE=true`, access the full desktop environment through DCV using either a web browser or Amazon DCV Client:

### Browser Access
1. Get the DCV connection URL from CloudFormation stack outputs (`03KiroIDEURL`)
2. Login with username and password from Secrets Manager
3. Launch Kiro IDE from the applications menu (opens in the workspace folder) or run `kiro-ide` in terminal
4. Firefox opens automatically for IAM Identity Center authentication (may take ~10 seconds)

ℹ️ **Tip:** Having issues with copy/paste? See the [DCV copy/paste documentation](https://docs.aws.amazon.com/dcv/latest/userguide/using-copy-paste.html).

### Amazon DCV Client
For better performance and additional features, use the Amazon DCV Client:

1. [Download Amazon DCV Client](https://download.nice-dcv.com/) for your operating system
2. Get the DCV connection URL from CloudFormation stack outputs (`03KiroIDEURL`)
3. Open the DCV Client and connect using the URL
4. Login with username and password from Secrets Manager
5. Launch Kiro IDE from the applications menu (opens in the workspace folder) or run `kiro-ide` in terminal
6. Firefox opens automatically for IAM Identity Center authentication if required (may take ~10 seconds)

## AWS IAM Roles

The environment is configured with two IAM roles:
1. EC2 instance role - Basic permissions for the instance
2. Developer role - Elevated permissions for AWS operations

The developer role has the permissions needed to deploy the sample application. To view or modify these permissions, search for "iamroledeveloper" in the CloudFormation template.

This separation ensures the EC2 instance runs with minimal permissions by default, while allowing controlled elevation of privileges when needed.

ℹ️ **Tip**: Run `echo 'export AWS_PROFILE=developer' >> ~/.bashrc && source ~/.bashrc` to make the developer profile default for all terminal sessions.

If you wish to have elevated AWS permissions automatically enabled in all new terminal sessions without requiring manual profile switching, set `AutoSetDeveloperProfile` to true. While convenient, this bypasses the security practice of explicit privilege elevation.

## Architecture

The environment runs in a private subnet with CloudFront access, using CodeCommit for git storage and CodePipeline for automated deployments.

![Architecture Diagram](img/architecture.png)

## Sample Application

ℹ️ **Note**: The sample application is only available when using the default value for `GitHubRepo`. If you specify either a custom `GitHubRepo` or `S3AssetBucket`, you will need to provide your own Terraform application code.

The repository includes a Terraform application that deploys:
- Static website hosted on Amazon S3
- Amazon CloudFront distribution with AWS WAF protection
- Security headers and AWS KMS encryption
- Amazon CloudWatch logging

![Sample Application](img/sampleapplication.png)

The application deploys automatically when you set the CloudFormation parameter `DeployPipeline` to true. Once deployment completes, you can locate the website URL in the final output of the CodeBuild job.

![CodeBuild Output Screenshot](img/codebuildoutput.png)

⚠️ **WARNING**: If using CodePipeline (DeployPipeline=true), before removing the CloudFormation stack:
1. Run the 'terraform-destroy' pipeline in CodePipeline
2. Approve the manual approval step when prompted
3. Wait for pipeline completion

Failing to run and approve the destroy pipeline will leave orphaned infrastructure resources in your AWS account that were created by Terraform and will need to be cleaned up manually.

## Security Considerations

⚠️ **IMPORTANT**: This sample uses HTTP for internal traffic between the Application Load Balancer and code-server Amazon EC2 instance. While external traffic is secured through CloudFront HTTPS, it is strongly recommended to:
- Configure end-to-end HTTPS using custom SSL certificates on the ALB
- Update ALB listener and target group to use HTTPS/443
- Use a custom domain name with AWS Certificate Manager (ACM) certificates

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

## Disclaimer

**This repository is intended for demonstration and learning purposes only.**
It is **not** intended for production use. The code provided here is for educational purposes and should not be used in a live environment without proper testing, validation, and modifications.
Use at your own risk. The authors are not responsible for any issues, damages, or losses that may result from using this code in production.
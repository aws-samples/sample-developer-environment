module "terraform_pipeline" {
  count  = var.deploy_pipeline ? 1 : 0
  source = "./modules/git-pipeline"

  prefix_code       = var.prefix_code
  region           = var.region
  solution_tag     = var.solution_tag
  environment_tag  = var.environment_tag
  kms_key_arn      = aws_kms_key.main.arn
  vpc_id           = aws_vpc.main.id
  subnet_id        = aws_subnet.private_01.id
  security_group_id = aws_security_group.code_server.id
  source_bucket    = module.git_repo_main.bucket_name
  source_key       = "my-workspace/refs/heads/main/repo.zip"
  developer_role_name = aws_iam_role.developer.name
  developer_role_arn = aws_iam_role.developer.arn
  name             = "sample-application"

  buildspec_build = templatefile("buildspec/sample_application/build.yml", {
    prefix_code = var.prefix_code
    region     = var.region
    bucket     = module.git_repo_main.bucket_name
  })

  buildspec_destroy = templatefile("buildspec/sample_application/destroy.yml", {
    prefix_code = var.prefix_code
    region     = var.region
    bucket     = module.git_repo_main.bucket_name
  })
}
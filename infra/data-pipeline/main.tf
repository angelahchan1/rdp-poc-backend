# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 6.0"

#   name                 = "${local.project_prefix}-vpc"
#   cidr                 = "10.0.0.0/16"
#   azs                  = ["ap-southeast-2a", "ap-southeast-2b"]
#   private_subnets      = ["10.0.3.0/24", "10.0.4.0/24"]
#   public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
#   enable_dns_hostnames = true
#   enable_dns_support   = true
# }

# module "datasync_sg" {
#   source  = "terraform-aws-modules/security-group/aws"
#   version = "~> 5.0"

#   name   = "${local.project_prefix}-datasync-sg"
#   vpc_id = module.vpc.vpc_id

#   ingress_with_cidr_blocks = [
#     {
#       from_port   = 443
#       to_port     = 443
#       protocol    = "tcp"
#       cidr_blocks = module.vpc.vpc_cidr_block
#     },
#     {
#       from_port   = 1024
#       to_port     = 1062
#       protocol    = "tcp"
#       cidr_blocks = module.vpc.vpc_cidr_block
#     }
#   ]

#   egress_rules = ["all-all"]
# }

# module "vpc_endpoints" {
#   source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
#   version = "~> 6.0"

#   vpc_id             = module.vpc.vpc_id
#   security_group_ids = [module.datasync_sg.security_group_id]

#   endpoints = {
#     datasync = {
#       service             = "datasync"
#       private_dns_enabled = true
#       subnet_ids          = module.vpc.private_subnets
#     }
#   }
# }

resource "aws_datasync_agent" "smb_agent" {
  name           = "${local.project_prefix}-smb-agent"
  activation_key = var.datasync_activation_key
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = "${local.project_prefix}-datasync-destination"

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  versioning = {
    enabled = true
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "datasync_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 5.0"

  name        = "${local.project_prefix}-datasync-s3-policy"
  path        = "/"
  description = "Policy for DataSync to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads"
        ]
        Effect   = "Allow"
        Resource = module.s3_bucket.s3_bucket_arn
      },
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ]
        Effect   = "Allow"
        Resource = "${module.s3_bucket.s3_bucket_arn}/*"
      }
    ]
  })
}

module "datasync_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role       = true
  role_name         = "${local.project_prefix}-datasync-s3-role"
  role_requires_mfa = false

  trusted_role_services   = ["datasync.amazonaws.com"]
  custom_role_policy_arns = [module.datasync_iam_policy.arn]
}

resource "aws_datasync_agent" "smb_agent" {
  name           = "${local.project_prefix}-smb-agent"
  activation_key = var.datasync_activation_key
}

resource "aws_datasync_location_smb" "source" {
  server_hostname = var.smb_server_ip
  subdirectory    = "/shared_images"
  user            = "hchan4"
  password        = var.smb_password
  agent_arns      = [aws_datasync_agent.smb_agent.arn]
}

resource "aws_datasync_location_s3" "destination" {
  s3_bucket_arn = module.s3_bucket.s3_bucket_arn
  subdirectory  = "/"

  s3_config {
    bucket_access_role_arn = module.datasync_iam_role.iam_role_arn
  }
}

resource "aws_cloudwatch_log_group" "datasync_logs" {
  name              = "/aws/datasync/${local.project_prefix}-task"
  retention_in_days = 7
}

resource "aws_datasync_task" "sync_task" {
  name                     = "${local.project_prefix}-smb-to-s3"
  source_location_arn      = aws_datasync_location_smb.source.arn
  destination_location_arn = aws_datasync_location_s3.destination.arn
  cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.datasync_logs.arn}:*"

  options {
    bytes_per_second = -1                       # no throttling
    verify_mode      = "ONLY_FILES_TRANSFERRED" # only check the new files transferred
    log_level        = "BASIC"
  }
}

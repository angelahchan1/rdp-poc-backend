module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

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

module "datasync_s3_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name = "${local.project_prefix}-datasync-s3-role"

  trust_policy_permissions = {
    DataSyncService = {
      actions = ["sts:AssumeRole"]
      principals = [
        {
          type        = "Service"
          identifiers = ["datasync.amazonaws.com"]
        }
      ]
      condition = [
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [local.account_id]
        },
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values = [
            "arn:aws:datasync:${local.region_id}:${local.account_id}:*"
          ]
        }
      ]
    }
  }
  create_inline_policy = true
  inline_policy_permissions = {
    DataSyncS3BucketAccess = {
      effect = "Allow"
      actions = [
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads"
      ]
      resources = [
        module.s3_bucket.s3_bucket_arn
      ]
    }

    DataSyncS3ObjectAccess = {
      effect = "Allow"
      actions = [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:GetObjectTagging",
        "s3:GetObjectVersion",
        "s3:GetObjectVersionTagging",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:PutObjectTagging"
      ]
      resources = [
        "${module.s3_bucket.s3_bucket_arn}/*"
      ]
    }
  }
}

resource "aws_datasync_agent" "smb_agent" {
  name           = "${local.project_prefix}-smb-agent"
  activation_key = var.datasync_activation_key
}

resource "aws_datasync_location_smb" "source" {
  server_hostname = var.smb_server_ip
  subdirectory    = var.smb_subdirectory
  user            = var.smb_username
  password        = var.smb_password
  agent_arns      = [aws_datasync_agent.smb_agent.arn]
}

resource "aws_datasync_location_s3" "destination" {
  s3_bucket_arn = module.s3_bucket.s3_bucket_arn
  subdirectory  = "/"

  s3_config {
    bucket_access_role_arn = module.datasync_s3_role.arn
  }
  depends_on = [
    module.datasync_s3_role,
    module.s3_bucket
  ]

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
    bytes_per_second  = -1
    verify_mode       = "ONLY_FILES_TRANSFERRED"
    log_level         = "BASIC"
    gid               = "NONE"
    posix_permissions = "NONE"
    uid               = "NONE"
  }

  # runs the task once daily at 00:00 UTC
  schedule {
    schedule_expression = "cron(0 0 * * ? *)"
  }
}

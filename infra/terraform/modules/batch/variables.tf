variable "project_prefix" { type = string }
variable "vpc_security_group_ids" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "account_id" { type = string }
variable "region_id" { type = string }
variable "repository_name" { type = string }
variable "source_bucket_id" {
  type        = string
  description = "The ID/Name of the S3 bucket to watch"
}

variable "source_bucket_arn" {
  type        = string
  description = "The ARN of the S3 bucket"
}

variable "datasync_task_arn" {
  type = string
}


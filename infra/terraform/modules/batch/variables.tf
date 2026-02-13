variable "project_prefix" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "vpc_security_group_ids" { type = list(string) }
variable "destination_bucket_id" {
  type        = string
  description = "The ID/Name of the S3 bucket to watch"
}

variable "destination_bucket_arn" {
  type        = string
  description = "The ARN of the S3 bucket"
}
variable "batch_job_queue_arn" {
  type = string
}

variable "batch_job_definition_arn" {
  type = string
}

variable "datasync_task_arn" {
  type = string
}

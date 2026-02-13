output "s3_bucket_id" {
  description = "The name of the bucket"
  value       = module.s3_bucket.s3_bucket_id
}

output "s3_bucket_arn" {
  description = "The ARN of the bucket"
  value       = module.s3_bucket.s3_bucket_arn
}

output "datasync_task_arn" {
  description = "The ARN of the DataSync Task"
  value       = aws_datasync_task.sync_task.arn
}

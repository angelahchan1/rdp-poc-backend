

output "state_machine_arn" {
  description = "The ARN of the Step Function state machine"
  value       = module.step_function.state_machine_arn
}

output "state_machine_id" {
  description = "The ID (ARN) of the Step Function state machine"
  value       = module.step_function.state_machine_id
}

output "state_machine_name" {
  description = "The name of the Step Function state machine"
  value       = module.step_function.state_machine_name
}

output "batch_job_queue_arn" {
  description = "The ARN of the Batch job queue"
  value       = module.batch.job_queues["fargate_queue"].arn
}

output "batch_job_definition_arn" {
  description = "The ARN of the Batch job definition"
  value       = module.batch.job_definitions["inference_job"].arn
}

output "eventbridge_rule_arns" {
  description = "The EventBridge rule ARNs"
  value       = module.eventbridge.eventbridge_rule_arns
}



module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "~> 4.0"

  create_bus = false

  rules = {
    datasync_trigger = {
      description = "Trigger StepFumction after DataSync task success"
      enabled     = true

      event_pattern = jsonencode({
        "source" : ["aws.datasync"],
        "detail-type" : ["DataSync Task Execution State Change"],
        "resources" : [var.datasync_task_arn],
        "detail" : {
          "State" : ["SUCCESS"]
        }
      })
    }
  }

  targets = {
    datasync_trigger = [
      {
        name            = "trigger-batch-step-function"
        arn             = module.inference_orchestrator.state_machine_arn
        attach_role_arn = true
      }
    ]
  }
  attach_sfn_policy = true
  sfn_target_arns   = [module.inference_orchestrator.state_machine_arn]
}


module "inference_orchestrator" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "~> 5.0"

  name = "${var.project_prefix}-image-processor-flow"

  definition = jsonencode({
    StartAt = "RunInferenceJob"
    States = {
      RunInferenceJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::batch:submitJob.sync"
        Parameters = {
          JobDefinition = aws_batch_job_definition.inference.arn
          JobName       = "daily-inference-job"
          JobQueue      = aws_batch_job_queue.fargate_queue.arn
        }
        Retry = [{
          ErrorEquals     = ["Batch.AWSBatchException", "InternalWaitError"]
          IntervalSeconds = 30
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        End = true
      }
    }
  })

  attach_policy_statements = true
  policy_statements = {
    batch = {
      effect    = "Allow"
      actions   = ["batch:SubmitJob", "batch:DescribeJobs", "batch:TerminateJob"]
      resources = ["*"] # NEED TO SCOPE THIS
    }
    events = {
      effect    = "Allow"
      actions   = ["events:PutTargets", "events:PutRule", "events:DescribeRule"]
      resources = ["*"]
    }
  }
}

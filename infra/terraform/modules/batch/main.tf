

module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "~> 4.0"

  create_bus = false

  rules = {
    datasync_trigger = {
      description = "Trigger StepFunction after DataSync task success"
      enabled     = true

      event_pattern = jsonencode({
        "source" : ["aws.datasync"],
        "detail-type" : ["DataSync Task Execution State Change"],
        "resources" : [{ "prefix" : var.datasync_task_arn }],
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
        arn             = module.step_function.state_machine_arn
        attach_role_arn = true
      }
    ]
  }
  attach_sfn_policy = true
  sfn_target_arns   = [module.step_function.state_machine_arn]
}

module "step_function" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "~> 5.0"

  name = "${var.project_prefix}-image-processing-pipeline"
  type = "STANDARD"

  definition = jsonencode({
    StartAt = "ProcessImagesInBatches"
    States = {
      ProcessImagesInBatches = {
        Type = "Map"
        ItemReader = {
          Resource = "arn:aws:states:::s3:listObjectsV2"
          Parameters = {
            Bucket = var.source_bucket_id
            Prefix = "incoming/"
          }
        }
        ItemBatcher = {
          MaxItemsPerBatch = 10
        }
        ItemProcessor = {
          ProcessorConfig = {
            Mode          = "DISTRIBUTED"
            ExecutionType = "STANDARD"
          }
          StartAt = "SubmitToBatch"
          States = {
            SubmitToBatch = {
              Type     = "Task"
              Resource = "arn:aws:states:::batch:submitJob.sync"
              Parameters = {
                JobName                    = "ImageProcessor"
                JobQueue                   = module.batch.job_queues["fargate_queue"].arn
                JobDefinition              = module.batch.job_definitions["inference_job"].arn
                SchedulingPriorityOverride = 1,
                ShareIdentifier            = "default"
                ContainerOverrides = {
                  Environment = [
                    {
                      Name      = "BATCH_FILES"
                      "Value.$" = "States.JsonToString($)"
                    }
                  ]
                }
              }
              End = true
            }
          }
        }
        MaxConcurrency = 50
        End            = true
      }
    }
  })

  attach_policy_statements = true
  policy_statements = {
    s3_read = {
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetObject"]
      resources = [var.source_bucket_arn, "${var.source_bucket_arn}/*"]
    }
    batch_submit = {
      effect    = "Allow"
      actions   = ["batch:SubmitJob", "batch:DescribeJobs", "batch:TerminateJob"]
      resources = ["*"]
    }
    states_run = {
      effect    = "Allow"
      actions   = ["states:StartExecution", "states:DescribeExecution", "states:StopExecution"]
      resources = ["*"]
    }
  }

  service_integrations = {
    batch_Sync = {
      events = true
    }
  }
}




module "batch" {
  source  = "terraform-aws-modules/batch/aws"
  version = "~> 3.0"

  instance_iam_role_name = "${var.project_prefix}-batch-role"
  service_iam_role_name  = "${var.project_prefix}-batch-service"

  compute_environments = {
    fargate = {
      name_prefix = "fargate"
      compute_resources = {
        type               = "FARGATE_SPOT"
        max_vcpus          = 2
        security_group_ids = var.vpc_security_group_ids
        subnets            = var.private_subnets
      }
    }
  }

  job_queues = {
    fargate_queue = {
      name                 = "${var.project_prefix}-queue"
      state                = "ENABLED"
      priority             = 1
      compute_environments = ["fargate"]
      compute_environment_order = {
        0 = {
          compute_environment_key = "fargate"
        }
      }
    }
  }

  job_definitions = {
    inference_job = {
      name                  = "${var.project_prefix}-inference"
      platform_capabilities = ["FARGATE"]
      container_properties = jsonencode({
        image                        = "${var.account_id}.dkr.ecr.${var.region_id}.amazonaws.com/${var.repository_name}:latest"
        fargatePlatformConfiguration = { platformVersion = "LATEST" }
        resourceRequirements = [
          { type = "VCPU", value = "1.0" },
          { type = "MEMORY", value = "2048" }
        ]
        executionRoleArn = module.batch_exec_role.iam_role_arn
        jobRoleArn       = module.batch_job_role.iam_role_arn
      })
      evaluate_on_exit = {
        retry_on_failure = {
          action       = "RETRY"
          on_exit_code = "1"
        }
        exit_on_success = {
          action       = "EXIT"
          on_exit_code = "0"
        }
      }
    }
  }
}

module "batch_exec_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role           = true
  role_name             = "${var.project_prefix}-batch-exec-role"
  role_requires_mfa     = false
  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

module "batch_job_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role           = true
  role_name             = "${var.project_prefix}-batch-job-role"
  role_requires_mfa     = false
  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  inline_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject"]
      resources = ["${var.source_bucket_arn}/*"]
    }
  ]
}

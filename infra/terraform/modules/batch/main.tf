

module "batch_trigger_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.5"

  function_name = "${var.project_prefix}-s3-to-batch-trigger"
  handler       = "index.lambda_handler"
  runtime       = "python3.11"
  source_path   = "${path.module}/functions/batch_trigger"

  vpc_subnet_ids         = var.private_subnet_ids
  vpc_security_group_ids = [var.vpc_security_group_ids]
  attach_network_policy  = true

  environment_variables = {
    JOB_QUEUE      = aws_batch_job_queue.eks_queue.arn
    JOB_DEFINITION = aws_batch_job_definition.api_batch_job.arn
  }

  attach_policy_statements = true
  policy_statements = {
    BatchSubmit = {
      effect    = "Allow"
      actions   = ["batch:SubmitJob"]
      resources = ["*"]
    }
  }
}


module "s3_notification" {
  source  = "terraform-aws-modules/s3-bucket/aws//modules/notification"
  version = "~> 5.0"

  bucket = module.s3_bucket.s3_bucket_id

  lambda_notifications = {
    trigger_batch = {
      function_arn  = module.batch_trigger_lambda.lambda_function_arn
      function_name = module.batch_trigger_lambda.lambda_function_name
      events        = ["s3:ObjectCreated:*"]
    }
  }
}

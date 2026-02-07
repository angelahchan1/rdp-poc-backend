locals {
  project_prefix = "${var.project_name}-${var.environment}"
  account_id     = data.aws_caller_identity.current.account_id
  region_id      = data.aws_region.current.id


}

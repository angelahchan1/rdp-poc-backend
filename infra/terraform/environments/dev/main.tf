module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "~> 6.0"
  name                 = "${local.project_prefix}-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = ["ap-southeast-2a", "ap-southeast-2b"]
  private_subnets      = ["10.0.3.0/24", "10.0.4.0/24"]
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

}



module "vpc_endpoint_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.project_prefix}-eks-vpce-sg"
  description = "Allows 443 traffic from EKS cluster"
  vpc_id      = module.vpc.vpc_id


  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]
  egress_rules = ["all-all"]
}


module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.0"

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.vpc_endpoint_sg.security_group_id]

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
    ecr_api = { service = "ecr.api", private_dns_enabled = true }
    ecr_dkr = { service = "ecr.dkr", private_dns_enabled = true }
    logs    = { service = "logs", private_dns_enabled = true }
    sts     = { service = "sts", private_dns_enabled = true }
    batch   = { service = "batch", private_dns_enabled = true }
  }
}

module "datasync_s3" {
  source = "../../modules/datasync-s3"

  project_prefix = local.project_prefix
  account_id     = local.account_id
  region_id      = local.region_id

  datasync_activation_key = var.datasync_activation_key

  smb_config = var.smb_config
}


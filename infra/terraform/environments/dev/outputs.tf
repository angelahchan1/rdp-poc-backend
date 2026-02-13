output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "vpc_endpoint_sg_id" {
  description = "The SG ID that allows modules to talk to AWS services via Endpoints"
  value       = module.vpc_endpoint_sg.security_group_id
}

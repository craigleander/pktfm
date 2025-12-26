output "rds_subnet_group_name" {
  description = "RDS subnet group name"
  value       = module.rds_base.subnet_group_name
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.rds_base.security_group_id
}

output "app_rds_instance_id" {
  description = "Application RDS instance ID"
  value       = module.app_rds.db_instance_id
}

output "app_rds_endpoint" {
  description = "Application RDS endpoint"
  value       = module.app_rds.endpoint
  sensitive   = true
}

output "analytics_aurora_cluster_id" {
  description = "Analytics Aurora cluster ID"
  value       = module.analytics_aurora.cluster_id
}

output "analytics_aurora_writer_endpoint" {
  description = "Analytics Aurora writer endpoint"
  value       = module.analytics_aurora.writer_endpoint
  sensitive   = true
}

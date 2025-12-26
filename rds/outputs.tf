output "db_instance_id" {
  value = module.rds.db_instance_identifier
}

output "endpoint" {
  value = module.rds.db_instance_endpoint
}

output "replica_endpoints" {
  value = [for replica in module.rds_replica : replica.db_instance_endpoint]
}

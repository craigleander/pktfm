locals {
  default_replicas = var.environment == "prod" ? 1 : 0
  replicas         = coalesce(var.replica_count, local.default_replicas)
  max_replicas     = var.environment == "prod" ? 5 : 0
}

resource "null_resource" "replica_guardrail" {
  lifecycle {
    precondition {
      condition     = local.replicas <= local.max_replicas
      error_message = "Replica count exceeds org policy"
    }
  }
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.6"

  identifier = var.name

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.storage_gb

  db_subnet_group_name   = var.subnet_group_name
  vpc_security_group_ids = [var.security_group_id]

  publicly_accessible = false
  storage_encrypted   = true
  deletion_protection = var.environment == "prod"

  backup_retention_period               = 7
  monitoring_interval                   = 60
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = var.tags
}

# Create read replicas
module "rds_replica" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.6"

  count = local.replicas

  identifier     = "${var.name}-replica-${count.index + 1}"
  replicate_source_db = module.rds.db_instance_identifier

  instance_class = var.instance_class

  publicly_accessible = false
  storage_encrypted   = true

  backup_retention_period               = 0  # Replicas don't need backups
  monitoring_interval                   = 60
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Skip final snapshot for replicas
  skip_final_snapshot = true

  tags = merge(var.tags, {
    Role = "read-replica"
  })
}

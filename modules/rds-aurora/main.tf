locals {
  reader_count = var.environment == "prod" ? 1 : 0
  max_readers  = var.environment == "prod" ? 5 : 0
}

resource "null_resource" "aurora_guardrail" {
  lifecycle {
    precondition {
      condition     = local.reader_count <= local.max_readers
      error_message = "Aurora reader count exceeds org policy"
    }
  }
}

module "aurora" {
  source = "../terraform-aws-rds-aurora"

  name           = var.name
  engine         = var.engine
  engine_version = var.engine_version

  vpc_id                 = var.vpc_id
  subnets                = var.subnet_ids
  create_security_group  = false
  vpc_security_group_ids = [var.security_group_id]

  instances = {
    writer = {
      instance_class = var.instance_class
    }

    readers = {
      count          = local.reader_count
      instance_class = var.instance_class
    }
  }

  storage_encrypted   = true
  deletion_protection = var.environment == "prod"

  backup_retention_period = 7
  monitoring_interval     = 60

  tags = var.tags
}

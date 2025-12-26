terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create base RDS infrastructure (subnet group + security group)
module "rds_base" {
  source = "./modules/rds-base"

  name          = var.project_name
  vpc_id        = var.vpc_id
  subnet_ids    = var.subnet_ids
  allowed_cidrs = var.allowed_cidrs
  db_port       = var.db_port

  tags = var.tags
}

# Example: Standard RDS instance
module "app_rds" {
  source = "./modules/rds"

  name           = "${var.project_name}-app-db"
  vpc_id         = var.vpc_id
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.environment == "prod" ? "db.t3.medium" : "db.t3.micro"
  storage_gb     = var.environment == "prod" ? 100 : 20

  environment = var.environment

  # Optional: override default replica count
  # replica_count = 2  # Uncomment to override default behavior

  subnet_group_name = module.rds_base.subnet_group_name
  security_group_id = module.rds_base.security_group_id

  tags = var.tags
}

# Example: Aurora cluster
module "analytics_aurora" {
  source = "./modules/rds-aurora"

  name           = "${var.project_name}-analytics"
  vpc_id         = var.vpc_id
  engine         = "aurora-postgresql"
  engine_version = "15.4"
  instance_class = var.environment == "prod" ? "db.r6g.large" : "db.t4g.medium"

  environment = var.environment

  subnet_ids        = var.subnet_ids
  security_group_id = module.rds_base.security_group_id

  tags = var.tags
}

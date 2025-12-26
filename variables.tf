variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "Existing VPC ID to use for RDS deployment"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for RDS deployment"
  type        = list(string)
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (qa or prod)"
  type        = string
  validation {
    condition     = contains(["qa", "prod"], var.environment)
    error_message = "Environment must be qa or prod"
  }
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to access RDS instances"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

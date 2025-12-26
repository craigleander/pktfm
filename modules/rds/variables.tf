variable "name" {}
variable "vpc_id" {}
variable "engine" {}
variable "engine_version" {}
variable "instance_class" {}
variable "storage_gb" {}

variable "environment" {
  validation {
    condition     = contains(["qa", "prod"], var.environment)
    error_message = "Environment must be qa or prod"
  }
}

variable "replica_count" {
  type    = number
  default = null
}

variable "subnet_group_name" {}
variable "security_group_id" {}
variable "tags" {
  type = map(string)
}

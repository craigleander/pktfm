variable "name" {}
variable "vpc_id" {}
variable "engine" {}
variable "engine_version" {}
variable "instance_class" {}
variable "environment" {}

variable "subnet_ids" {}
variable "security_group_id" {}

variable "tags" {
  type = map(string)
}

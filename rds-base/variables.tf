variable "name" {}
variable "vpc_id" {}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_cidrs" {
  type = list(string)
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "tags" {
  type = map(string)
}

variable "name" {
  default="app-rich"
}

variable "db_ami_id" {
  default="ami-054902308378c2899"
}

variable "app_ami_id" {
  default="ami-0c0e9fc41af3f77f8"
}

variable "cidr_block" {
  default="10.0.0.0/16"
}

variable "internal" {
  description = "should the ELB be internal or external"
  default = "false"
}

variable "ssl_certificate_id" {
  description = "the id of the ssl certificate"
  default=""
}

variable "health_check" {
  description = "address at which the ELB should point the health check"
  default=""
}

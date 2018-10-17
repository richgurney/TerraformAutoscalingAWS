variable "vpc_id" {
  description="the vpc to launch the resources in to"
}

variable "name" {
  description="the base name to associate with the resources in the tier"
}

variable "ami_id" {
  description="the ami_id to use for the instance"
}

variable "user_data" {
  description="the user data to provide to the instance"
  default=""
}

variable "ig_id" {
  description="the ig to attach to route tables"
}

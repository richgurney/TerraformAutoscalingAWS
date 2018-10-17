output security_group_id {
  description="the id of the app security group"
  value="${aws_security_group.app.id}"
}

output subnet_app_id {
  description="the cidr_block of the app subnet"
  value="${aws_subnet.app.id}"
}

output subnet_cidr_block {
  description="the cidr_block of the app subnet"
  value="${aws_subnet.app.cidr_block}"
}

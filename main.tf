provider "aws" {
  region  = "eu-west-1"
}

# create a vpc
resource "aws_vpc" "app" {
  cidr_block = "${var.cidr_block}"

  tags {
    Name = "${var.name}"
  }
}

# internet gateway
resource "aws_internet_gateway" "app" {
  vpc_id = "${aws_vpc.app.id}"

  tags {
    Name = "${var.name}"
  }
}

# load the init template
data "template_file" "app_init" {
   template = "${file("./scripts/app/init.sh.tpl")}"
   vars {
      db_host="mongodb://${aws_instance.db.private_ip}:27017/posts"
   }
}

module "app" {
  source = "./modules/app_tier"
  vpc_id = "${aws_vpc.app.id}"
  ig_id  = "${aws_internet_gateway.app.id}"
  name = "app-rich"
  ami_id = "${var.app_ami_id}"
  user_data = "${data.template_file.app_init.rendered}"
}



# DB
# create a subnet
resource "aws_subnet" "db" {
  vpc_id = "${aws_vpc.app.id}"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone = "eu-west-1a"
  tags {
    Name = "${var.name}-db"
  }
}

# security
resource "aws_security_group" "db"  {
  name = "${var.name}-db"
  description = "${var.name} db access"
  vpc_id = "${aws_vpc.app.id}"

  ingress {
    from_port       = "27017"
    to_port         = "27017"
    protocol        = "tcp"
    security_groups = ["${module.app.security_group_id}"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.name}-db"
  }
}

resource "aws_network_acl" "db" {
  vpc_id = "${aws_vpc.app.id}"

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "${module.app.subnet_cidr_block}"
    from_port  = 27017
    to_port    = 27017
  }

  # EPHEMERAL PORTS

  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "${module.app.subnet_cidr_block}"
    from_port  = 1024
    to_port    = 65535
  }

  subnet_ids   = ["${aws_subnet.db.id}"]

  tags {
    Name = "${var.name}-db"
  }
}

# public route table
resource "aws_route_table" "db" {
  vpc_id = "${aws_vpc.app.id}"

  tags {
    Name = "${var.name}-db-private"
  }
}

resource "aws_route_table_association" "db" {
  subnet_id      = "${aws_subnet.db.id}"
  route_table_id = "${aws_route_table.db.id}"
}

# launch an instance
resource "aws_instance" "db" {
  ami           = "${var.db_ami_id}"
  subnet_id     = "${aws_subnet.db.id}"
  vpc_security_group_ids = ["${aws_security_group.db.id}"]
  instance_type = "t2.micro"
  tags {
      Name = "${var.name}-db"
  }
}


### load_balancers
resource "aws_security_group" "elb"  {
  name = "${var.name}-elb"
  description = "Allow all inbound traffic through port 80 and 443."
  vpc_id = "${aws_vpc.app.id}"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags {
    Name = "${var.name}-elb"
  }
}

#### ELB ####

resource "aws_elb" "elb" {
  name = "${var.name}-app-elb"
  subnets = ["${module.app.subnet_app_id}",]
  security_groups = ["${aws_security_group.elb.id}"]
  internal = "${var.internal}"

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  tags {
    Name = "${var.name}-elb"
  }
}

#### AUTOSCALING GROUP ####

resource "aws_launch_configuration" "app" {
  name_prefix = "${var.name}-app"
  image_id = "${var.app_ami_id}"
  instance_type = "t2.micro"
  user_data = "${data.template_file.app_init.rendered}"
  security_groups = ["${module.app.security_group_id}"]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  load_balancers = ["${aws_elb.elb.id}"]
  name = "${var.name}-${aws_launch_configuration.app.name}-app"
  # name = "${var.name}-app"
  min_size = 1
  max_size = 3
  min_elb_capacity = 1
  desired_capacity = 2
  vpc_zone_identifier = ["${module.app.subnet_app_id}"]
  launch_configuration = "${aws_launch_configuration.app.id}"
  tags {
    key = "Name"
    value = "${var.name}-app-${count.index + 1 }"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}

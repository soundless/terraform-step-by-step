provider "aws" {
    region = "us-east-1"
}

data "aws_availability_zones" "all" {}

resource "aws_instance" "test_terraform" {
    ami = "ami-2d39803a"
    instance_type = "t2.micro"
    key_name = "htian-home"
    vpc_security_group_ids = ["${aws_security_group.instance.id}"]

    user_data = <<EOF
#!/bin/bash
echo "Hello, Terraform!!" >index.html
nohup busybox httpd -f -p "${var.server_port}" &
EOF

    tags {
        Name = "terraform-example"
    }
}

resource "aws_launch_configuration" "test_terraform" {
    image_id = "ami-2d39803a"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.instance.id}"]

    user_data = <<EOF
#!/bin/bash
echo "Hello, Terraform!!" >index.html
nohup busybox httpd -f -p "${var.server_port}" &
EOF


    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = "${var.server_port}"
        to_port = "${var.server_port}"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = "${var.ssh_port}"
        to_port = "${var.ssh_port}"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_security_group" "elb" {
    name = "test-terraform-elb-sg"

    ingress = {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_autoscaling_group" "test_terraform" {
    launch_configuration = "${aws_launch_configuration.test_terraform.id}"
    availability_zones = ["${data.aws_availability_zones.all.names}"]

    min_size = 2
    max_size = 4

    load_balancers = ["${aws_elb.test_terraform.name}"]
    health_check_type = "ELB"

    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
    }
}

resource "aws_elb" "test_terraform" {
    name = "test-terraform-elb"
    security_groups = ["${aws_security_group.elb.id}"]
    availability_zones = ["${data.aws_availability_zones.all.names}"]

    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        interval = 30
        target = "HTTP:${var.server_port}/"
    }

    listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = "${var.server_port}"
        instance_protocol = "http"
    }   
}


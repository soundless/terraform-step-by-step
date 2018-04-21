output "public_ip" {
    value = "${aws_instance.test_terraform.public_ip}"
}

output "elb_dns_name" {
    value = "${aws_elb.test_terraform.dns_name}"
}

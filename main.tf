provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_vpc" "healthcheck_lambda_vpc" {
  cidr_block = "172.60.0.0/16"
  tags {
    Name = "yamelnychuk_lab_vpc"
  }
}
resource "aws_internet_gateway" "igv" {
  vpc_id = "${aws_vpc.healthcheck_lambda_vpc.id}"
  tags {
    Name = "yamelnychuk_lab_igv"
  }
}

resource "aws_route_table" "internet_access_route" {
  vpc_id = "${aws_vpc.healthcheck_lambda_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igv.id}"
  }

  tags {
    name = "yamelnychuk_pub_route"
  }
}

resource "aws_route_table" "private_routing" {
  vpc_id = "${aws_vpc.healthcheck_lambda_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.natgw.id}"
  }

  tags {
    name = "yamelnychuk_private_route"
  }
}

resource "aws_subnet" "public_sub" {
  vpc_id = "${aws_vpc.healthcheck_lambda_vpc.id}"
  cidr_block = "172.60.31.0/24"

  tags {
    name = "yamelnychuk_pub_subnet" 
  }
}

resource "aws_subnet" "private_sub" {
  vpc_id = "${aws_vpc.healthcheck_lambda_vpc.id}"
  cidr_block = "172.60.32.0/24"

  tags {
    name = "yamelnychuk_priv_subnet" 
  }
}

resource "aws_route_table_association" "public_routing_association" {
  subnet_id      = "${aws_subnet.public_sub.id}"
  route_table_id = "${aws_route_table.internet_access_route.id}"
}
resource "aws_route_table_association" "private_routing_association" {
  subnet_id      = "${aws_subnet.private_sub.id}"
  route_table_id = "${aws_route_table.private_routing.id}"
}

resource "aws_security_group" "public_sg" {
  description = "allow internet access to public subnet"
  vpc_id = "${aws_vpc.healthcheck_lambda_vpc.id}"

  ingress {
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

  tags {
    name = "yamelnychuk_public_sg"
  }
}

resource "aws_security_group" "privat_sg" {
  description = "allow internet access to private subnet"
  vpc_id = "${aws_vpc.healthcheck_lambda_vpc.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = ["${aws_security_group.public_sg.id}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    name = "yamelnychuk_private_sg"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id = "${aws_subnet.public_sub.id}"
  tags {
    name = "yamelnychuk_nat"
  }
}

data "archive_file" "function-zip" {
  type        = "zip"
  source_file = "${path.module}/handler.py"
  output_path = "${path.module}/yamel-lambda-healthcheck.zip"
}

resource "aws_lambda_function" "healthcheck_lambda" {
  filename         = "yamel-lambda-healthcheck.zip"
  function_name    = "healthcheck_lambda"
  role             = "${aws_iam_role.lambda_role.arn}"
  handler          = "handler.healthcheck"
  source_code_hash = "${data.archive_file.function-zip.output_base64sha256}"
  runtime          = "python3.7"
  vpc_config {
    subnet_ids = ["${aws_subnet.private_sub.id}"]
    security_group_ids = ["${aws_security_group.privat_sg.id}"]
  }

  tags {
    name = "yamel_healthcheck_lambda"
  }
}

resource "aws_cloudwatch_event_rule" "every_five_minutes" {
    name = "every-five-minutes"
    description = "Fires every five minutes"
    schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "checkhealth_every_five_minutes" {
    rule = "${aws_cloudwatch_event_rule.every_five_minutes.name}"
    target_id = "check_foo"
    arn = "${aws_lambda_function.healthcheck_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_healthcheck" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.healthcheck_lambda.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.every_five_minutes.arn}"
}










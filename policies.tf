resource "aws_iam_role" "lambda_role" {
  name = "lambda_healthcheck_ter"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
        }
    ]
}
EOF
}
resource "aws_iam_policy" "db_policy" {
  name        = "db-policy"
  description = "db policy for lambda yamel"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "dynamodb:*",
                "cloudwatch:PutMetricAlarm"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "iam:PassRole"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": [
                        "application-autoscaling.amazonaws.com",
                        "dax.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": [
                        "replication.dynamodb.amazonaws.com",
                        "dax.amazonaws.com",
                        "dynamodb.application-autoscaling.amazonaws.com"
                    ]
                }
            }
        }
    ]
}
  EOF
}

resource "aws_iam_policy" "vpc_policy" {
  name        = "vpc-policy"
  description = "A vpc policy for lambda yamel"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface", 
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface"
            ],
            "Resource": "*"
        }
    ]
} 
  EOF
}

resource "aws_iam_policy" "sns_policy" {
  name        = "sns-policy"
  description = "A sns policy for lambda yamel"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sns:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
  EOF
}

resource "aws_iam_policy" "lambda_basic_policy" {
  name        = "lbasic-policy"
  description = "A lbasic policy for lambda yamel"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
  EOF
}
resource "aws_iam_policy" "ses_policy" {
  name        = "ses-policy"
  description = "A ses policy for lambda"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ses:*"
            ],
            "Resource": "*"
        }
    ]
}
  EOF
}
resource "aws_iam_role_policy_attachment" "db-attach" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "${aws_iam_policy.db_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "vpc-attach" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "${aws_iam_policy.vpc_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "sns-attach" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "${aws_iam_policy.sns_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "lbasic-attach" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "${aws_iam_policy.lambda_basic_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "ses-attach" {
  role       = "${aws_iam_role.lambda_role.name}"
  policy_arn = "${aws_iam_policy.ses_policy.arn}"
}
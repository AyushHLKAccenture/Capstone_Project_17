data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "al2023" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ayush/app-logs"
  retention_in_days = 7
}

resource "aws_iam_role" "cw_role" {
  name = "ayush-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cw_attach" {
  role       = aws_iam_role.cw_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "cw_profile" {
  name = "ayush-instance-profile"
  role = aws_iam_role.cw_role.name
}

resource "aws_security_group" "logs_sg" {
  name   = "ayush-8130-sg"
  vpc_id = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "log_server" {

  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.logs_sg.id]

  iam_instance_profile = aws_iam_instance_profile.cw_profile.name

  user_data = <<-EOF
#!/bin/bash

dnf install amazon-cloudwatch-agent -y

mkdir -p /var/log/capstone-app

echo "Project17 Log Entry $(date)" > /var/log/capstone-app/app.log

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CONFIG
{
  "logs":{
    "logs_collected":{
      "files":{
        "collect_list":[
          {
            "file_path":"/var/log/capstone-app/app.log",
            "log_group_name":"/ayush/app-logs",
            "log_stream_name":"{instance_id}"
          }
        ]
      }
    }
  }
}
CONFIG

systemctl enable amazon-cloudwatch-agent

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config \
-m ec2 \
-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
-s
EOF

  tags = {
    Name = "ayush-log-server"
  }
}
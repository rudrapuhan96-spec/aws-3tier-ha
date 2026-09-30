# ---------------------------------------------------------
# Amazon Linux 2023 AMI
# ---------------------------------------------------------

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------
# IAM Role for EC2
# ---------------------------------------------------------

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ec2-role"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# IAM Instance Profile
# ---------------------------------------------------------

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = {
    Name    = "${var.project_name}-ec2-profile"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# EC2 Launch Template
# ---------------------------------------------------------

resource "aws_launch_template" "app" {
  name = "${var.project_name}-app-template"

  image_id = data.aws_ssm_parameter.al2023_ami.value

  instance_type = var.instance_type

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash

    dnf update -y
    dnf install -y httpd

    systemctl enable httpd
    systemctl start httpd

    TOKEN=$(curl -X PUT \
      "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    INSTANCE_ID=$(curl -s \
      -H "X-aws-ec2-metadata-token: $TOKEN" \
      "http://169.254.169.254/latest/meta-data/instance-id")

    AZ=$(curl -s \
      -H "X-aws-ec2-metadata-token: $TOKEN" \
      "http://169.254.169.254/latest/meta-data/placement/availability-zone")

    cat > /var/www/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
    <head>
      <title>AWS 3-Tier HA Project</title>
    </head>

    <body>
      <h1>AWS 3-Tier Application</h1>
      <h2>Application Server is Healthy</h2>

      <p>Instance ID: $INSTANCE_ID</p>
      <p>Availability Zone: $AZ</p>
    </body>
    </html>
    HTML
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "${var.project_name}-app-server"
      Tier    = "application"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-launch-template"
    Project = var.project_name
  }
}

# ---------------------------------------------------------
# Auto Scaling Group
# ---------------------------------------------------------

resource "aws_autoscaling_group" "app" {
  name = "${var.project_name}-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 2

  vpc_zone_identifier = aws_subnet.private_app[*].id

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "application"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}
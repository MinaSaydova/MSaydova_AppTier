# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create two private subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-1a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-1c"
}

# Key Pair for the instance
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

# Security Group for the application tier in the same VPC as ELB
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust for your requirements
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "app-tier-"
  image_id      = "ami-047d7c33f6e7b4bc4" # Replace with a valid AMI for your region
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    subnet_id                   = aws_subnet.private_subnet_1.id
    security_groups             = [aws_security_group.app_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  min_size         = 2
  max_size         = 6
  desired_capacity = 2

  vpc_zone_identifier = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 300
}

# Corrected Elastic Load Balancer (ELB) configuration
resource "aws_elb" "app_elb" {
  name               = "app-elb"
  availability_zones = ["us-west-1a", "us-west-1c"]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # Ensure the correct security group is tied to the ELB
  security_groups = [aws_security_group.app_sg.id]
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

# Optional: EC2 Instance for testing (ensure valid AMI)
resource "aws_instance" "web_backend" {
  ami             = "ami-047d7c33f6e7b4bc4" # Replace with a valid AMI ID
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.deployer.key_name
  subnet_id       = aws_subnet.private_subnet_1.id
  security_groups = [aws_security_group.app_sg.id]
}

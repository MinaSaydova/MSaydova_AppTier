# Create a Secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "MyDatabaseSecret"
  description = "This secret contains the database credentials."

  # Optional, automatic rotation of secrets
  # rotation_lambda_arn = aws_lambda_function.rotation_lambda.arn
  # rotation_rules {
  #   automatically_after_days = 30
  # }
}

# Store the secret value (database credentials) in the Secrets Manager secret
resource "aws_secretsmanager_secret_version" "db_credentials_value" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "db_user",
    password = "db_pass"
  })
}

# Create an IAM Role for EC2 that allows access to Secrets Manager
resource "aws_iam_role" "ec2_role" {
  name = "ec2-secretsmanager-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

# Attach a policy to the EC2 role allowing access to the secret
resource "aws_iam_role_policy" "secrets_policy" {
  name = "secretsmanager-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = aws_secretsmanager_secret.db_credentials.arn,
        Effect   = "Allow"
      }
    ]
  })
}

# EC2 Instance with IAM Role attached
resource "aws_instance" "web_backend_sm" {
  ami                  = "ami-047d7c33f6e7b4bc4"
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "web-backend-instance"
  }
}

# IAM Instance Profile for EC2 to assume the role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Output the secret ARN and EC2 public IP for reference
output "secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}

output "ec2_public_ip" {
  value = aws_instance.web_backend_sm.public_ip
}

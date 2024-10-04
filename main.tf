provider "aws" {
  region = "us-west-1"
}
resource "aws_instance" "example" {
  ami           = "ami-047d7c33f6e7b4bc4"
  instance_type = "t2.micro"
}

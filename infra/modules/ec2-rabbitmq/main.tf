data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "rabbitmq" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.sg_rabbitmq_id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    rabbitmq_username = var.rabbitmq_username
    rabbitmq_password = var.rabbitmq_password
  }))

  tags = {
    Name        = "${var.environment}-rabbitmq-ec2"
    Environment = var.environment
  }
}

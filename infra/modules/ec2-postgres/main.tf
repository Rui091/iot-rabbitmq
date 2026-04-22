# ─── Latest Amazon Linux 2023 AMI ─────────────────────────────────────────────
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── EC2 Instance with Docker PostgreSQL ───────────────────────────────────────
resource "aws_instance" "postgres" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.sg_rds_id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    db_username = var.db_username
    db_password = var.db_password
  }))

  tags = {
    Name        = "${var.environment}-postgres-ec2"
    Environment = var.environment
  }
}

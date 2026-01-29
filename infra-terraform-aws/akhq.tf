resource "aws_security_group" "akhq" {
  name        = "${local.name_prefix}-akhq-sg"
  description = "AKHQ access + broker egress"
  vpc_id      = aws_vpc.this.id
  tags        = local.tags
}

# AKHQ UI access from VPN clients
resource "aws_security_group_rule" "akhq_ingress_ui" {
  type              = "ingress"
  security_group_id = aws_security_group.akhq.id
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.vpn_cidr]
}

# Allow instance to reach MSK brokers on 9092 inside VPC
resource "aws_security_group_rule" "akhq_egress_msk" {
  type              = "egress"
  security_group_id = aws_security_group.akhq.id
  from_port         = 9092
  to_port           = 9092
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.this.cidr_block]
}

# General egress (docker pull, yum updates)
resource "aws_security_group_rule" "akhq_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.akhq.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "msk_ingress_from_akhq" {
  type                     = "ingress"
  security_group_id        = aws_security_group.msk.id
  from_port                = 9092
  to_port                  = 9092
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.akhq.id
}

data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}


resource "aws_instance" "akhq" {
  ami                    = data.aws_ami.al2.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.akhq.id]
  tags                   = merge(local.tags, { Name = "${local.name_prefix}-akhq" })

  user_data = <<-EOF
    #!/bin/bash

    sudo useradd -m newuser
    echo "newuser:123456" | sudo chpasswd
    sudo newuser -aG sudo newuser

    set -euo pipefail

    yum update -y
    amazon-linux-extras install docker -y
    systemctl enable docker
    systemctl start docker

    cat >/home/ec2-user/application.yml <<'YAML'
    akhq:
      connections:
        msk:
          properties:
            bootstrap.servers: "b-1.iotsensorprodmsk.attx6n.c6.kafka.eu-west-1.amazonaws.com:9092,b-2.iotsensorprodmsk.attx6n.c6.kafka.eu-west-1.amazonaws.com:9092"
            security.protocol: PLAINTEXT
    YAML

    docker run -d --restart unless-stopped --name akhq -p 8080:8080 \
      -v /home/ec2-user/application.yml:/app/application.yml:ro \
      tchiotludo/akhq:latest
  EOF
}

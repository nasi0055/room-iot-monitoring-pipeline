data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "tls_private_key" "akhq" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "akhq" {
  key_name   = "akhq-ec2-key"
  public_key = tls_private_key.akhq.public_key_openssh

  lifecycle {
    prevent_destroy = true
  }
}

resource "local_file" "akhq_private_key" {
  filename        = "./akhq-ec2-key.pem"
  content         = tls_private_key.akhq.private_key_pem
  file_permission = "0600"
}

resource "aws_security_group" "akhq" {
  name        = "akhq-sg"
  description = "AKHQ access"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpn_cidr]
  }

  ingress {
    description = "AKHQ UI"
    from_port   = var.akhq_port
    to_port     = var.akhq_port
    protocol    = "tcp"
    cidr_blocks = [var.vpn_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  akhq_config = <<-YAML
    akhq:
      connections:
        my-kafka:
          properties:
            bootstrap.servers: "${aws_msk_cluster.this.bootstrap_brokers}"

      # Optional basic auth (simple built-in users)
      security:
        default-group: no-roles
        basic-auth:
          - username: "${var.akhq_username}"
            password: "${var.akhq_password}"
            groups:
              - admin

      groups:
        admin:
          roles:
            - topic/read
            - topic/insert
            - topic/delete
            - topic/config/update
            - consumer-group/read
            - consumer-group/delete
            - node/read
            - acl/read
            - registry/read
  YAML
}

resource "aws_instance" "akhq" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.akhq_instance_type
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.akhq.id]
  key_name                    = aws_key_pair.akhq.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf update -y
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user || true

    mkdir -p /opt/akhq
    cat > /opt/akhq/application.yml <<'YAML'
    ${local.akhq_config}
    YAML

    # Systemd service so it restarts on reboot
    cat > /etc/systemd/system/akhq.service <<'SERVICE'
    [Unit]
    Description=AKHQ
    After=docker.service
    Requires=docker.service

    [Service]
    Restart=always
    ExecStart=/usr/bin/docker run --rm --name akhq \\
      -p ${var.akhq_port}:8080 \\
      -v /opt/akhq/application.yml:/app/application.yml:ro \\
      tchiotludo/akhq:latest

    ExecStop=/usr/bin/docker stop akhq

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable akhq
    systemctl start akhq
  EOF

  tags = {
    Name = "akhq-ec2"
  }
}

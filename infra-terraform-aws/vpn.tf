variable "vpn_cidr" {
  description = "CIDR block for VPN clients (must not overlap VPC)"
  type        = string
  default     = "10.99.0.0/22"
}

variable "vpn_server_cert_arn" {
  type        = string
  description = "ACM ARN for VPN server certificate"
}

variable "vpn_client_cert_arn" {
  type        = string
  description = "ACM ARN for VPN client certificate"
}

resource "aws_security_group" "client_vpn" {
  name        = "${local.name_prefix}-client-vpn-sg"
  description = "Client VPN SG"
  vpc_id      = aws_vpc.this.id
  tags        = local.tags
}

resource "aws_security_group_rule" "vpn_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.client_vpn.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "${local.name_prefix} client vpn"
  server_certificate_arn = var.vpn_server_cert_arn
  client_cidr_block      = var.vpn_cidr
  split_tunnel           = true
  vpc_id                 = aws_vpc.this.id
  security_group_ids     = [aws_security_group.client_vpn.id]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.vpn_client_cert_arn
  }

  connection_log_options {
    enabled = false
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-client-vpn"
  })
}

resource "aws_ec2_client_vpn_network_association" "private" {
  count                  = length(aws_subnet.private)
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = aws_subnet.private[count.index].id
}

resource "aws_ec2_client_vpn_authorization_rule" "vpc_access" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = aws_vpc.this.cidr_block
  authorize_all_groups   = true
}

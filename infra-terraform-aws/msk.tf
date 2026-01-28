resource "aws_security_group" "msk" {
  name        = "${local.name_prefix}-msk-sg"
  description = "MSK security group"
  vpc_id      = aws_vpc.this.id
  tags        = local.tags
}

# Allow Kafka traffic from within the VPC (tighten later)
resource "aws_security_group_rule" "msk_in_from_vpc" {
  type              = "ingress"
  from_port         = 9092
  to_port           = 9094
  protocol          = "tcp"
  security_group_id = aws_security_group.msk.id
  cidr_blocks       = [aws_vpc.this.cidr_block]
  description       = "Kafka ports from VPC"
}

resource "aws_security_group_rule" "msk_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.msk.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_msk_cluster" "this" {
  cluster_name           = "${local.name_prefix}-msk"
  kafka_version          = var.msk_kafka_version
  number_of_broker_nodes = var.msk_broker_count

  broker_node_group_info {
    instance_type   = var.msk_broker_instance_type
    client_subnets  = aws_subnet.private[*].id
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.msk_ebs_volume_size
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT"
      in_cluster    = true
    }
  }

  tags = local.tags
}

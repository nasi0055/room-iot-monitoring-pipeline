variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "iot-sensor"
}

variable "env" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.10.0/24", "10.20.11.0/24"]
}

# MSK
variable "msk_kafka_version" {
  type    = string
  default = "3.5.1"
}

variable "msk_broker_instance_type" {
  type    = string
  default = "kafka.t3.small"
}

variable "msk_broker_count" {
  type    = number
  default = 2
}

variable "msk_ebs_volume_size" {
  type    = number
  default = 100
}

# Flink app artifact
variable "flink_artifact_local_path" {
  description = "Path to Flink app artifact (jar/zip) on local machine. Terraform will upload it to S3."
  type        = string
  default     = "../flink/build/app.jar"
}

variable "flink_runtime_environment" {
  type    = string
  default = "FLINK-1_18"
}

variable "flink_parallelism" {
  type    = number
  default = 1
}

variable "akhq_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "akhq_port" {
  type    = number
  default = 8080
}

variable "akhq_username" {
  type    = string
  default = "admin"
}

variable "akhq_password" {
  type      = string
  sensitive = true
  default = "admin"
}

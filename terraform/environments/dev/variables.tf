
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "app_image_tag" {
  type    = string
  default = "bootstrap"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.small"
}

variable "desired_ec2_capacity" {
  type    = number
  default = 2
}

variable "max_ec2_capacity" {
  type    = number
  default = 3
}

variable "db_name" {
  type    = string
  default = "taskflow"
}

variable "db_username" {
  type    = string
  default = "taskflowadmin"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Supply via TF_VAR_db_password or a secure CI variable; never commit it."
}

variable "container_cpu" {
  type    = number
  default = 256
}

variable "container_memory" {
  type    = number
  default = 512
}

variable "log_retention_days" {
  type    = number
  default = 14
}

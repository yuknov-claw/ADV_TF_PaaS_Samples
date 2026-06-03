# RabbitMQ (DMS) — complete working example

terraform {
  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.79"
    }
  }
}

provider "sbercloud" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

# --- Базовая сеть ---
resource "sbercloud_vpc" "main" {
  name = "rabbit-vpc"
  cidr = "10.0.0.0/16"
}

resource "sbercloud_vpc_subnet" "main" {
  name       = "rabbit-subnet"
  cidr       = "10.0.0.0/16"
  gateway_ip = "10.0.0.1"
  vpc_id     = sbercloud_vpc.main.id
}

# --- Security Group: порты RabbitMQ ---
resource "sbercloud_networking_secgroup" "rabbit" {
  name        = "rabbit-sg"
  description = "RabbitMQ DMS security group"
}

# AMQP (5672)
resource "sbercloud_networking_secgroup_rule" "amqp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5672
  port_range_max    = 5672
  remote_ip_prefix  = "10.0.0.0/8"
  security_group_id = sbercloud_networking_secgroup.rabbit.id
}

# Management UI (15672)
resource "sbercloud_networking_secgroup_rule" "mgmt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 15672
  port_range_max    = 15672
  remote_ip_prefix  = "10.0.0.0/8"
  security_group_id = sbercloud_networking_secgroup.rabbit.id
}

# --- RabbitMQ-кластер ---
resource "sbercloud_dms_rabbitmq_instance" "rabbit" {
  name              = "rabbitmq-prod"
  vpc_id            = sbercloud_vpc.main.id
  network_id        = sbercloud_vpc_subnet.main.id          # ID subnet!
  security_group_id = sbercloud_networking_secgroup.rabbit.id

  flavor_id          = "c6.4u8g.cluster"                   # 4 vCPU, 8 GB
  storage_spec_code  = "dms.physical.storage.ultra.v2"     # SSD
  availability_zones = ["ru-moscow-1a", "ru-moscow-1b"]
  engine_version     = "3.8.35"
  storage_space      = 300                                  # GB

  access_user = "admin"
  password    = var.rabbit_password

  enable_acl = true

  tags = {
    environment = "production"
    service     = "message-queue"
  }
}

# --- Результаты ---
output "rabbit_id" {
  value = sbercloud_dms_rabbitmq_instance.rabbit.id
}

output "rabbit_status" {
  description = "Статус: Running = готов"
  value       = sbercloud_dms_rabbitmq_instance.rabbit.status
}

output "rabbit_connect_address" {
  description = "Адрес для подключения (host:port)"
  value       = sbercloud_dms_rabbitmq_instance.rabbit.connect_address
}

output "rabbit_management_ui" {
  description = "URL Management UI"
  value       = "http://${sbercloud_dms_rabbitmq_instance.rabbit.connect_address}:15672"
}

output "rabbit_amqp_address" {
  description = "AMQP адрес для подключения"
  value       = "amqp://admin:${var.rabbit_password}@${sbercloud_dms_rabbitmq_instance.rabbit.connect_address}:5672"
}

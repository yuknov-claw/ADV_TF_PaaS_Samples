# Kafka (DMS) — complete working example

terraform {
  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.79"
    }
  }
}

provider "sbercloud" {
  region     = "ru-moscow-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# --- Базовая сеть ---
resource "sbercloud_vpc" "main" {
  name = "kafka-vpc"
  cidr = "10.0.0.0/16"
}

resource "sbercloud_vpc_subnet" "main" {
  name       = "kafka-subnet"
  cidr       = "10.0.0.0/16"
  gateway_ip = "10.0.0.1"
  vpc_id     = sbercloud_vpc.main.id
}

# --- Security Group: порты Kafka ---
resource "sbercloud_networking_secgroup" "kafka" {
  name        = "kafka-sg"
  description = "Kafka DMS security group"
}

# Порт для plaintext (9092)
resource "sbercloud_networking_secgroup_rule" "kafka_plain" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9092
  port_range_max    = 9092
  remote_ip_prefix  = "10.0.0.0/8"
  security_group_id = sbercloud_networking_secgroup.kafka.id
}

# Порт для SSL (9094)
resource "sbercloud_networking_secgroup_rule" "kafka_ssl" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9094
  port_range_max    = 9094
  remote_ip_prefix  = "10.0.0.0/8"
  security_group_id = sbercloud_networking_secgroup.kafka.id
}

# --- Data source: flavour'ы ---
data "sbercloud_dms_kafka_flavors" "cluster" {
  type               = "cluster"
  flavor_id          = "c6.4u8g.cluster"                  # 4 vCPU, 8 GB RAM
  availability_zones = ["ru-moscow-1a", "ru-moscow-1b"]
  storage_spec_code  = "dms.physical.storage.ultra.v2"    # SSD
}

# --- Kafka-кластер ---
resource "sbercloud_dms_kafka_instance" "kafka" {
  name              = "kafka-prod"
  vpc_id            = sbercloud_vpc.main.id
  network_id        = sbercloud_vpc_subnet.main.id          # ID subnet!
  security_group_id = sbercloud_networking_secgroup.kafka.id

  # Из data.sbercloud_dms_kafka_flavors
  flavor_id          = data.sbercloud_dms_kafka_flavors.cluster.flavor_id
  storage_spec_code  = data.sbercloud_dms_kafka_flavors.cluster.flavors[0].ios[0].storage_spec_code

  availability_zones = ["ru-moscow-1a", "ru-moscow-1b"]
  engine_version     = "2.7"
  storage_space      = 600                                 # Общий размер (GB)
  broker_num         = 3                                   # 3 брокера

  # SASL_SSL аутентификация
  ssl_enable  = true
  access_user = "kafka_admin"
  password    = var.kafka_password

  # Дополнительные параметры
  parameters {
    name  = "min.insync.replicas"
    value = "2"
  }

  # Теги
  tags = {
    environment = "production"
    service     = "event-bus"
  }
}

# --- Топики ---
resource "sbercloud_dms_kafka_topic" "events" {
  instance_id = sbercloud_dms_kafka_instance.kafka.id
  name        = "app-events"
  partitions  = 6               # 6 партиций
  replication = 3               # Репликация на все брокеры
}

resource "sbercloud_dms_kafka_topic" "logs" {
  instance_id = sbercloud_dms_kafka_instance.kafka.id
  name        = "app-logs"
  partitions  = 3
  replication = 3
}

resource "sbercloud_dms_kafka_topic" "dlq" {
  instance_id = sbercloud_dms_kafka_instance.kafka.id
  name        = "app-dlq"
  partitions  = 3
  replication = 3
}

# --- Результаты ---
output "kafka_id" {
  value = sbercloud_dms_kafka_instance.kafka.id
}

output "kafka_status" {
  description = "Статус: Running = готов"
  value       = sbercloud_dms_kafka_instance.kafka.status
}

output "kafka_endpoint" {
  description = "Адреса брокеров (для подключения)"
  value       = sbercloud_dms_kafka_instance.kafka.connect_address
}

output "kafka_port_plain" {
  description = "Порт для подключения без SSL"
  value       = 9092
}

output "kafka_port_ssl" {
  description = "Порт для подключения с SSL"
  value       = 9094
}

output "kafka_topics" {
  description = "Созданные топики"
  value = {
    events = sbercloud_dms_kafka_topic.events.name
    logs   = sbercloud_dms_kafka_topic.logs.name
    dlq    = sbercloud_dms_kafka_topic.dlq.name
  }
}

output "kafka_connection_string" {
  description = "Строка подключения bootstrap.servers"
  value       = sbercloud_dms_kafka_instance.kafka.connect_address
}

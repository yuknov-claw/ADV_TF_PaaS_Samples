# MongoDB (DDS) — complete working example

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
  name = "mongo-vpc"
  cidr = "10.0.0.0/16"
}

resource "sbercloud_vpc_subnet" "main" {
  name       = "mongo-subnet"
  cidr       = "10.0.0.0/16"
  gateway_ip = "10.0.0.1"
  vpc_id     = sbercloud_vpc.main.id
}

# --- Security Group: порт MongoDB 8635 ---
resource "sbercloud_networking_secgroup" "mongo" {
  name        = "mongo-sg"
  description = "MongoDB DDS security group"
}

resource "sbercloud_networking_secgroup_rule" "mongo_in" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8635
  port_range_max    = 8635
  remote_ip_prefix  = "10.0.0.0/8"
  security_group_id = sbercloud_networking_secgroup.mongo.id
}

# =====================================================================
# ВАРИАНТ A: ReplicaSet (рекомендуется для prod)
# =====================================================================
# resource "sbercloud_dds_instance" "mongo_rs" {
#   name = "mongo-replicaset"

#   datastore {
#     type           = "DDS-Community"
#     version        = "4.0"
#     storage_engine = "wiredTiger"
#   }

#   availability_zone = "ru-moscow-1a"
#   vpc_id            = sbercloud_vpc.main.id
#   subnet_id         = sbercloud_vpc_subnet.main.id
#   security_group_id = sbercloud_networking_secgroup.mongo.id
#   password          = var.mongo_password
#   mode              = "ReplicaSet"
#   ssl_enable        = true

#   # Один блок replica
#   flavor {
#     type      = "replica"
#     num       = 1                # 1 группа replica
#     storage   = "ULTRAHIGH"
#     size      = 50
#     spec_code = "dds.mongodb.c6.2xlarge.4.repset"
#   }

#   backup_strategy {
#     start_time = "08:00-09:00"
#     keep_days  = "7"
#   }
# }

# =====================================================================
# ВАРИАНТ B: Sharded Cluster (для больших данных)
# =====================================================================
resource "sbercloud_dds_instance" "mongo_sharded" {
  name = "mongo-sharded-cluster"

  datastore {
    type           = "DDS-Community"
    version        = "4.0"
    storage_engine = "wiredTiger"
  }

  availability_zone = "ru-moscow-1a"
  vpc_id            = sbercloud_vpc.main.id
  subnet_id         = sbercloud_vpc_subnet.main.id
  security_group_id = sbercloud_networking_secgroup.mongo.id
  password          = var.mongo_password
  mode              = "Sharding"
  ssl_enable        = true

  # mongos — маршрутизаторы (2 шт.)
  flavor {
    type      = "mongos"
    num       = 2
    spec_code = "dds.mongodb.c3.medium.4.mongos"
  }

  # shard — шарды (2 шт., по 20 GB SSD)
  flavor {
    type      = "shard"
    num       = 2
    storage   = "ULTRAHIGH"
    size      = 20
    spec_code = "dds.mongodb.c3.medium.4.shard"
  }

  # config — конфигурационный сервер
  flavor {
    type      = "config"
    num       = 1
    storage   = "ULTRAHIGH"
    size      = 20
    spec_code = "dds.mongodb.c3.large.2.config"
  }

  backup_strategy {
    start_time = "08:00-09:00"
    keep_days  = "7"
  }
}

# --- Результаты ---
output "mongo_id" {
  value = sbercloud_dds_instance.mongo_sharded.id
}

output "mongo_status" {
  description = "Статус: available = готов"
  value       = sbercloud_dds_instance.mongo_sharded.status
}

output "mongo_connection_string" {
  description = "Строка подключения (host:port)"
  value       = format("mongodb://rwuser:%s@%s/admin?authSource=admin&ssl=true",
    var.mongo_password,
    sbercloud_dds_instance.mongo_sharded.db[0].address
  )
}

output "mongo_port" {
  description = "Порт MongoDB (не 27017, а 8635!)"
  value       = sbercloud_dds_instance.mongo_sharded.db[0].port
}

output "mongo_db_name" {
  description = "Имя БД по умолчанию"
  value       = sbercloud_dds_instance.mongo_sharded.db[0].name
}

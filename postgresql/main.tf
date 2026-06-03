# PostgreSQL (RDS) — complete working example

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
  name = "pg-vpc"
  cidr = "10.0.0.0/16"
}

resource "sbercloud_vpc_subnet" "main" {
  name       = "pg-subnet"
  cidr       = "10.0.0.0/16"
  gateway_ip = "10.0.0.1"
  vpc_id     = sbercloud_vpc.main.id
}

# --- Security Group: открыть порт 5432 ---
resource "sbercloud_networking_secgroup" "pg" {
  name        = "pg-sg"
  description = "PostgreSQL security group"
}

resource "sbercloud_networking_secgroup_rule" "pg_in" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_ip_prefix  = "10.0.0.0/8"            # Ограничить доступ по IP!
  security_group_id = sbercloud_networking_secgroup.pg.id
}

# =====================================================================
# ВАРИАНТ A: PostgreSQL Single (одиночный) — для dev
# =====================================================================
resource "sbercloud_rds_instance" "pg_single" {
  name              = "postgres-dev"
  flavor            = "rds.pg.n1.large.2"                     # 2 vCPU, 4 GB, Single
  vpc_id            = sbercloud_vpc.main.id
  subnet_id         = sbercloud_vpc_subnet.main.id
  security_group_id = sbercloud_networking_secgroup.pg.id

  # Single — 1 AZ
  availability_zone = ["ru-moscow-1a"]

  db {
    type     = "PostgreSQL"
    version  = "16"
    password = var.db_password
  }

  volume {
    type = "ULTRAHIGH"                                         # SSD
    size = 40                                                  # 40 GB (минимум)
  }

  # Автоматические бэкапы
  backup_strategy {
    start_time = "08:00-09:00"
    keep_days  = 7
  }

  # Теги
  tags = {
    environment = "dev"
    project     = "myapp"
  }
}

# =====================================================================
# ВАРИАНТ B: PostgreSQL HA (primary + standby) — для production
# =====================================================================
# resource "sbercloud_rds_instance" "pg_ha" {
#   name                = "postgres-prod"
#   flavor              = "rds.pg.n1.large.2.ha"              # 2 vCPU, 4 GB, HA
#   ha_replication_mode = "async"
#   vpc_id              = sbercloud_vpc.main.id
#   subnet_id           = sbercloud_vpc_subnet.main.id
#   security_group_id   = sbercloud_networking_secgroup.pg.id

#   # HA — 2 AZ (primary в 1а, standby в 1b)
#   availability_zone   = ["ru-moscow-1a", "ru-moscow-1b"]

#   db {
#     type     = "PostgreSQL"
#     version  = "16"
#     password = var.db_password
#   }

#   volume {
#     type = "ULTRAHIGH"
#     size = 100
#   }

#   backup_strategy {
#     start_time = "08:00-09:00"
#     keep_days  = 14
#   }

#   tags = {
#     environment = "production"
#     project     = "myapp"
#   }
# }

# =====================================================================
# Read-реплика (для масштабирования чтения)
# =====================================================================
# resource "sbercloud_rds_read_replica" "pg_read" {
#   name                = "postgres-read-replica"
#   flavor              = "rds.pg.n1.large.2"
#   primary_instance_id = sbercloud_rds_instance.pg_ha.id
#   availability_zone   = "ru-moscow-1a"
#   volume {
#     type = "ULTRAHIGH"
#     size = 100
#   }
# }

# --- Результаты ---
output "pg_single_id" {
  value = sbercloud_rds_instance.pg_single.id
}

output "pg_single_endpoint" {
  description = "Строка подключения: host:port"
  value       = sbercloud_rds_instance.pg_single.endpoint
}

output "pg_single_name" {
  value = sbercloud_rds_instance.pg_single.name
}

output "pg_single_status" {
  description = "Статус: ACTIVE = готов к работе"
  value       = sbercloud_rds_instance.pg_single.status
}

# output "pg_ha_endpoint" {
#   value = sbercloud_rds_instance.pg_ha.endpoint
# }

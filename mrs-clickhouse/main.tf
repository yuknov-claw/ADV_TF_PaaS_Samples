# ClickHouse через MRS (MapReduce Service) — complete working example

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
  name = "mrs-vpc"
  cidr = "10.0.0.0/16"
}

resource "sbercloud_vpc_subnet" "main" {
  name       = "mrs-subnet"
  cidr       = "10.0.0.0/16"
  gateway_ip = "10.0.0.1"
  vpc_id     = sbercloud_vpc.main.id
}

# --- Зоны доступности ---
data "sbercloud_availability_zones" "az" {}

# =====================================================================
# ВАРИАНТ A: ANALYSIS — ClickHouse + Hadoop + Spark (самый частый)
# =====================================================================
resource "sbercloud_mapreduce_cluster" "clickhouse_analysis" {
  availability_zone  = data.sbercloud_availability_zones.az.names[0]
  name               = "ch-analysis-cluster"
  version            = "MRS 2.1.0"
  type               = "ANALYSIS"
  component_list     = ["ClickHouse", "Hadoop", "Spark", "Hive"]
  manager_admin_pass = var.mrs_admin_password
  node_admin_pass    = var.mrs_node_password
  vpc_id             = sbercloud_vpc.main.id
  subnet_id          = sbercloud_vpc_subnet.main.id
  safe_mode          = true              # Kerberos (безопасный режим)
  log_collection     = true

  # Master (2 шт.)
  master_nodes {
    flavor            = "c6.2xlarge.4.linux.bigdata"
    node_number       = 2
    root_volume_type  = "SAS"
    root_volume_size  = 300
    data_volume_type  = "SAS"
    data_volume_size  = 480
    data_volume_count = 1
  }

  # Core (2 шт.)
  analysis_core_nodes {
    flavor            = "c6.2xlarge.4.linux.bigdata"
    node_number       = 2
    root_volume_type  = "SAS"
    root_volume_size  = 300
    data_volume_type  = "SAS"
    data_volume_size  = 480
    data_volume_count = 1
  }

  # Task (опционально, 1 шт.)
  analysis_task_nodes {
    flavor            = "c6.2xlarge.4.linux.bigdata"
    node_number       = 1
    root_volume_type  = "SAS"
    root_volume_size  = 300
    data_volume_type  = "SAS"
    data_volume_size  = 480
    data_volume_count = 1
  }

  tags = {
    environment = "production"
    service     = "analytics"
  }
}

# =====================================================================
# ВАРИАНТ B: STREAMING — ClickHouse + Kafka + Storm (real-time)
# =====================================================================
# resource "sbercloud_mapreduce_cluster" "clickhouse_streaming" {
#   availability_zone  = data.sbercloud_availability_zones.az.names[0]
#   name               = "ch-streaming-cluster"
#   version            = "MRS 2.1.0"
#   type               = "STREAMING"
#   component_list     = ["ClickHouse", "Kafka", "Storm"]
#   manager_admin_pass = var.mrs_admin_password
#   node_admin_pass    = var.mrs_node_password
#   vpc_id             = sbercloud_vpc.main.id
#   subnet_id          = sbercloud_vpc_subnet.main.id
#   safe_mode          = true

#   master_nodes {
#     flavor            = "c6.2xlarge.4.linux.bigdata"
#     node_number       = 2
#     root_volume_type  = "SAS"
#     root_volume_size  = 300
#     data_volume_type  = "SAS"
#     data_volume_size  = 480
#     data_volume_count = 1
#   }

#   streaming_core_nodes {
#     flavor            = "c6.2xlarge.4.linux.bigdata"
#     node_number       = 2
#     root_volume_type  = "SAS"
#     root_volume_size  = 300
#     data_volume_type  = "SAS"
#     data_volume_size  = 480
#     data_volume_count = 1
#   }

#   tags = {
#     environment = "production"
#     service     = "stream-analytics"
#   }
# }

# =====================================================================
# ВАРИАНТ C: MIXED — ANALYSIS + STREAMING (гибрид)
# =====================================================================
# resource "sbercloud_mapreduce_cluster" "clickhouse_mixed" {
#   availability_zone  = data.sbercloud_availability_zones.az.names[0]
#   name               = "ch-mixed-cluster"
#   version            = "MRS 3.0.5"
#   type               = "MIXED"
#   component_list     = ["ClickHouse", "Hadoop", "Spark", "Hive", "Kafka", "Flink"]
#   manager_admin_pass = var.mrs_admin_password
#   node_admin_pass    = var.mrs_node_password
#   vpc_id             = sbercloud_vpc.main.id
#   subnet_id          = sbercloud_vpc_subnet.main.id

#   master_nodes { ... }
#   analysis_core_nodes { ... }
#   streaming_core_nodes { ... }
#   analysis_task_nodes { ... }
#   streaming_task_nodes { ... }
# }

# =====================================================================
# ВАРИАНТ D: CUSTOM — с кастомным размещением ролей (продвинутый)
# =====================================================================
# resource "sbercloud_mapreduce_cluster" "clickhouse_custom" {
#   availability_zone  = data.sbercloud_availability_zones.az.names[0]
#   name               = "ch-custom-cluster"
#   version            = "MRS 3.1.0"
#   type               = "CUSTOM"
#   safe_mode          = true
#   template_id        = "mgmt_control_combined_v4"
#   component_list     = ["ClickHouse", "Hadoop", "ZooKeeper", "Ranger"]
#   manager_admin_pass = var.mrs_admin_password
#   node_admin_pass    = var.mrs_node_password
#   vpc_id             = sbercloud_vpc.main.id
#   subnet_id          = sbercloud_vpc_subnet.main.id

#   master_nodes {
#     flavor            = "c6.4xlarge.4.linux.bigdata"
#     node_number       = 3
#     root_volume_type  = "SAS"
#     root_volume_size  = 480
#     data_volume_type  = "SAS"
#     data_volume_size  = 600
#     data_volume_count = 1
#     assigned_roles = [
#       "NameNode:2,3",
#       "ResourceManager:2,3",
#       "JournalNode:1,2,3",
#       "DBServer:1,3",
#       "RangerAdmin:1,2",
#       "ClickHouseServer:1,2,3",
#       "KerberosClient",
#     ]
#   }

#   custom_nodes {
#     group_name        = "data_nodes"
#     flavor            = "c6.4xlarge.4.linux.bigdata"
#     node_number       = 4
#     root_volume_type  = "SAS"
#     root_volume_size  = 480
#     data_volume_type  = "SAS"
#     data_volume_size  = 600
#     data_volume_count = 1
#     assigned_roles = [
#       "DataNode",
#       "NodeManager",
#       "ClickHouseServer",
#       "KerberosClient",
#     ]
#   }
# }

# =====================================================================
# Результаты
# =====================================================================
output "cluster_id" {
  description = "ID кластера MRS"
  value       = sbercloud_mapreduce_cluster.clickhouse_analysis.id
}

output "cluster_name" {
  description = "Имя кластера"
  value       = sbercloud_mapreduce_cluster.clickhouse_analysis.name
}

output "cluster_status" {
  description = "Статус: running = готов, abnormal/failed = ошибка"
  value       = sbercloud_mapreduce_cluster.clickhouse_analysis.status
}

output "master_node_ip" {
  description = "IP master-ноды (для подключения)"
  value       = sbercloud_mapreduce_cluster.clickhouse_analysis.master_node_ip
}

output "total_nodes" {
  description = "Всего нод в кластере"
  value       = sbercloud_mapreduce_cluster.clickhouse_analysis.total_node_number
}

output "create_time" {
  description = "Время создания"
  value       = sbercloud_mapreduce_cluster.clickhouse_analysis.create_time
}

output "note_cloudtable" {
  description = "Для managed ClickHouse без Hadoop используйте CloudTable (через консоль, без Terraform)"
  value       = "CloudTable: https://cloud.ru/docs/cloudtable/ug/index"
}

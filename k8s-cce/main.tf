# Kubernetes (CCE) — complete working example

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

# ============================================================
# 1. VPC + подсеть (DNS обязателен!)
# ============================================================
resource "sbercloud_vpc" "main" {
  name = "k8s-vpc"
  cidr = "10.0.0.0/16"
}

resource "sbercloud_vpc_subnet" "main" {
  name       = "k8s-subnet"
  cidr       = "10.0.0.0/16"
  gateway_ip = "10.0.0.1"
  vpc_id     = sbercloud_vpc.main.id

  # !!! DNS — обязателен для установки CCE-нод
  primary_dns   = "100.125.13.59"
  secondary_dns = "100.125.65.14"
}

# ============================================================
# 2. EIP для доступа к API кластера (опционально)
# ============================================================
resource "sbercloud_vpc_eip" "cce" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "cce-eip"
    size        = 10
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

# ============================================================
# 3. Kubernetes-кластер
# ============================================================
resource "sbercloud_cce_cluster" "k8s" {
  name                   = "my-k8s-cluster"
  flavor_id              = "cce.s2.small"           # Production, до 50 нод
  cluster_type           = "VirtualMachine"
  vpc_id                 = sbercloud_vpc.main.id
  subnet_id              = sbercloud_vpc_subnet.main.id
  container_network_type = "overlay_l2"
  authentication_mode    = "rbac"

  eip = sbercloud_vpc_eip.cce.address

  delete_all = true                                  # Удалять ноды и диски при destroy

  labels = {
    environment = "production"
    team        = "platform"
  }
}

# ============================================================
# 4. Нод-пул (worker nodes)
# ============================================================
resource "sbercloud_cce_node_pool" "workers" {
  cluster_id         = sbercloud_cce_cluster.k8s.id
  name               = "worker-pool"
  os                 = "EulerOS 2.5"
  flavor_id          = "s3.large.4"                 # 2 vCPU, 8 GB
  initial_node_count = 2
  availability_zone  = "ru-moscow-1a"
  key_pair           = var.key_pair

  # Автоскалинг
  scall_enable   = true
  min_node_count = 1
  max_node_count = 10
  priority       = 1

  root_volume {
    size       = 40                                 # GB
    volumetype = "SSD"
  }

  data_volumes {
    size       = 100
    volumetype = "SSD"
  }

  labels = {
    role = "worker"
  }

  # taints = [{
  #   key    = "dedicated"
  #   value  = "gpu"
  #   effect = "NoSchedule"
  # }]
}

# ============================================================
# 5. Namespace (опционально)
# ============================================================
resource "sbercloud_cce_namespace" "app" {
  cluster_id = sbercloud_cce_cluster.k8s.id
  name       = "production"
}

# ============================================================
# 6. PVC — постоянный том (для подов)
# ⚠️ Требует CSI-аддона в кластере!
# ============================================================
# resource "sbercloud_cce_pvc" "data" {
#   cluster_id         = sbercloud_cce_cluster.k8s.id
#   namespace          = sbercloud_cce_namespace.app.name
#   name               = "app-data-pvc"
#   storage_class_name = "csi-disk"                  # csi-disk (EVS), csi-nas (SFS), csi-obs (OBS)
#   access_modes       = ["ReadWriteOnce"]
#   storage            = "10Gi"                      # 10 GB
# }

# ============================================================
# 7. Результаты
# ============================================================
output "cluster_id" {
  description = "ID кластера"
  value       = sbercloud_cce_cluster.k8s.id
}

output "cluster_endpoint" {
  description = "Endpoint API-сервера (внутренний)"
  value       = sbercloud_cce_cluster.k8s.endpoint
}

output "cluster_external_endpoint" {
  description = "External endpoint (через EIP)"
  value       = sbercloud_cce_cluster.k8s.external_endpoint
}

output "cluster_status" {
  description = "Статус кластера (Available = готов)"
  value       = sbercloud_cce_cluster.k8s.status
}

output "kubeconfig_command" {
  description = "Команда для получения kubeconfig"
  value       = "hcloud CCE get-kubeconfig --cluster_id ${sbercloud_cce_cluster.k8s.id}"
}

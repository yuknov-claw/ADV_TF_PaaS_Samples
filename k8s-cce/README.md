# Kubernetes (CCE) — Terraform

**Ресурсы провайдера:**
- `sbercloud_cce_cluster` — кластер K8s
- `sbercloud_cce_node_pool` — группа worker-нод
- `sbercloud_cce_node` — отдельная нода
- `sbercloud_cce_node_attach` — прикрепить существующую ВМ как ноду
- `sbercloud_cce_node_pool_scale` — масштабирование нод-пула (однократное действие)
- `sbercloud_cce_nodes_remove` — удаление нод из кластера
- `sbercloud_cce_namespace` — namespace в кластере
- `sbercloud_cce_pvc` — PersistentVolumeClaim (том для подов)
- `sbercloud_cce_addon` — аддон (CoreDNS, Dashboard, Autoscaler…)
- `sbercloud_cce_cluster_log_config` — конфигурация сбора логов кластера
- `sbercloud_cce_cluster_upgrade` — обновление версии кластера

**Data sources:**
- `sbercloud_cce_cluster` — получить существующий кластер
- `sbercloud_cce_node_pool` — получить нод-пул
- `sbercloud_cce_addon_template` — шаблон аддона

---

## 1. Для тех, кто первый раз

Terraform создаёт managed Kubernetes-кластер в Cloud.ru Advanced (CCE — Cloud Container Engine).
Кластер состоит из:

- **Control plane** — управляющая часть (`sbercloud_cce_cluster`)
- **Node pool** — worker-ноды (`sbercloud_cce_node_pool`)
- **PVC** — постоянные тома для подов (`sbercloud_cce_pvc`)
- **Addons** — расширения (`sbercloud_cce_addon`)

После apply вы получаете готовый кластер. Kubeconfig — из консоли или CLI: `hcloud CCE get-kubeconfig --cluster_id <id>`.

---

## 2. Ключевые параметры `sbercloud_cce_cluster`

| Параметр | Обязательный | Описание | Значения |
|---|---|---|---|
| `name` | ✅ | Имя кластера | латиница, до 64 символов |
| `flavor_id` | ✅ | Тип кластера | `cce.s1.small`, `cce.s2.small` и т.д. |
| `cluster_type` | ❌ | Тип | `VirtualMachine` (обычный), `ARM64`, `None` (без нод) |
| `vpc_id` | ✅ | VPC кластера | ID VPC |
| `subnet_id` | ✅ | Подсеть для нод | **Обязательно с DNS!** |
| `container_network_type` | ✅ | Сеть контейнеров | `overlay_l2`, `vpc-router`, `eni` (Turbo) |
| `authentication_mode` | ❌ | Аутентификация | `rbac` (рекомендуется) |
| `eip` | ❌ | Публичный IP | EIP-адрес (строка) |
| `version` | ❌ | Версия K8s | `v1.27`, `v1.28` и т.д. |
| `delete_all` | ❌ | Удалять всё при destroy | `true` — удаляет ноды и диски |
| `container_network_cidr` | ❌ | CIDR сети подов | кастомный, если не устраивает дефолтный |
| `eni_subnet_cidr` | ❌ | CIDR для ENI (Turbo) | только для Turbo |

### Flavour'ы кластера

| Flavour | Node limit |
|---|---|
| `cce.s1.small` | до 50 нод |
| `cce.s1.medium` | до 200 нод |
| `cce.s1.large` | до 1000 нод |
| `cce.s2.small` | до 50 нод (prod) |
| `cce.s2.medium` | до 200 нод (prod) |
| `cce.s2.large` | до 1000 нод (prod) |
| `cce.turbo.*` | CCE Turbo (ENI) |

### Типы сети контейнеров

| Тип | Описание |
|---|---|
| `overlay_l2` | VXLAN overlay (по умолчанию) |
| `vpc-router` | Маршрутизация через VPC |
| `eni` | Elastic Network Interface (только Turbo) |

---

## 3. Ключевые параметры `sbercloud_cce_node_pool`

| Параметр | Обязательный | Описание |
|---|---|---|
| `cluster_id` | ✅ | ID кластера |
| `name` | ✅ | Имя нод-пула |
| `flavor_id` | ✅ | Тип ВМ для нод |
| `initial_node_count` | ✅ | Начальное количество нод |
| `availability_zone` | ✅ | Зона доступности |
| `key_pair` | ✅ | SSH-ключ |
| `os` | ❌ | OS: `EulerOS 2.5`, `CentOS 7.7` |
| `root_volume` | ✅ | Системный диск |
| `data_volumes` | ✅ | Диски для данных |
| `scall_enable` | ❌ | Автоскалинг (`true`/`false`) |
| `min_node_count` | ❌ | Мин. нод |
| `max_node_count` | ❌ | Макс. нод |
| `priority` | ❌ | Приоритет (1 = наивысший) |
| `taints` | ❌ | Taints |
| `labels` | ❌ | Labels |
| `max_pods` | ❌ | Макс. подов на ноду |

---

## 4. Дополнительные ресурсы

### `sbercloud_cce_pvc` — PersistentVolumeClaim

Используется для монтирования томов (EVS, SFS) в поды в определённом namespace.

```hcl
resource "sbercloud_cce_pvc" "data" {
  cluster_id         = sbercloud_cce_cluster.k8s.id
  namespace          = "default"
  name               = "data-pvc"
  storage_class_name = "csi-disk"          # csi-disk (EVS), csi-nas (SFS), csi-obs (OBS)
  access_modes       = ["ReadWriteOnce"]
  storage            = "10Gi"
}
```

🔴 **PROBLEM:** `storage_class_name` зависит от установленных аддонов (csi-disk, csi-nas, csi-obs). Если аддон не установлен — PVC не создастся. **Проверить наличие CSI-драйвера в кластере.**

### `sbercloud_cce_namespace` — namespace

```hcl
resource "sbercloud_cce_namespace" "ns" {
  cluster_id = sbercloud_cce_cluster.k8s.id
  name       = "production"
}
```

### `sbercloud_cce_cluster_upgrade` — обновление версии

```hcl
resource "sbercloud_cce_cluster_upgrade" "upgrade" {
  cluster_id      = sbercloud_cce_cluster.k8s.id
  target_version  = "v1.28"
}
```

🔴 **PROBLEM:** Одноразовое действие. После апгрейда ресурс надо убрать из state (terraform state rm), иначе apply будет пытаться повторно выполнить обновление.

### `sbercloud_cce_cluster_log_config` — сбор логов

Логи кластера в LTS (Cloud Log Service). Можно включить сбор логов control plane.

### `sbercloud_cce_node_attach` — прикрепить существующую ВМ

Позволяет добавить существующий ECS-инстанс как ноду кластера.

---

## 5. ⚠️ Важные моменты (gotchas)

1. **DNS в subnet — обязателен** (`primary_dns = "100.125.13.59"`). Без DNS ноды не установятся, кластер зависнет в `Creating`.
2. **Создание кластера ~10-15 мин**, нод-пула ещё ~5-10 мин.
3. `authentication_mode = "rbac"` — используйте его. `x509` устарел.
4. `delete_all = true` — чтобы при `terraform destroy` удалились ноды и диски, а не повисли.
5. **Flavour кластера (`cce.s1.*` vs `cce.s2.*`)** — не путать с flavour'ом ВМ для нод. `cce.s1` — dev, `cce.s2` — prod.
6. **CCE Turbo** (`container_network_type = "eni"`) — нужен отдельный flavour (`cce.turbo.*`) и `eni_subnet_cidr`.
7. `cce_node_pool_scale` — одноразовое масштабирование (не для постоянного управления).
8. `cce_cluster_upgrade` — после выполнения **обязательно** `terraform state rm` или `lifecycle.ignore_changes`, иначе TF будет пытаться повторно выполнить апгрейд при каждом apply.
9. **Kubeconfig** после создания кластера — через CLI: `hcloud CCE get-kubeconfig --cluster_id <id>`
10. **Address pool (`container_network_cidr`)** — по умолчанию `172.16.0.0/16`. Если пересекается с вашими сетями — задать кастомный.

## 6. Ссылки

- `sbercloud_cce_cluster` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/cce_cluster.md
- `sbercloud_cce_node_pool` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/cce_node_pool.md
- `sbercloud_cce_node` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/cce_node.md
- `sbercloud_cce_pvc` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/cce_pvc.md
- `sbercloud_cce_namespace` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/cce_namespace.md
- `sbercloud_cce_addon` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/cce_addon.md
- `sbercloud_cce_cluster_upgrade` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/cce_cluster_upgrade.md

# RabbitMQ (DMS) — Terraform

**Ресурс:** `sbercloud_dms_rabbitmq_instance`

---

## 1. Для тех, кто первый раз

Создаётся managed RabbitMQ-кластер в Cloud.ru Advanced (сервис DMS).
Используется для очередей сообщений, pub/sub, RPC.

## 2. Ключевые параметры `sbercloud_dms_rabbitmq_instance`

| Параметр | Обязательный | Описание |
|---|---|---|
| `name` | ✅ | Имя инстанса |
| `vpc_id` | ✅ | VPC |
| `network_id` | ✅ | Подсеть (не VPC!) |
| `security_group_id` | ✅ | SG (открыть порты 5672, 15672) |
| `flavor_id` | ✅ | Flavour (строка, в отличие от Kafka) |
| `storage_spec_code` | ✅ | `dms.physical.storage.ultra.v2` (SSD) |
| `availability_zones` | ✅ | 1-2 AZ |
| `engine_version` | ✅ | `3.8.35` |
| `storage_space` | ✅ | Размер диска (GB) |
| `access_user` | ✅ | Пользователь для RabbitMQ |
| `password` | ✅ | Пароль |
| `charging_mode` | ❌ | `postPaid` / `prePaid` |
| `enable_acl` | ❌ | Включить ACL |

## 3. Flavour'ы

| flavor_id | Описание |
|---|---|
| `c6.2u4g.single` | Single (dev) |
| `c6.2u4g.cluster` | Cluster, 2 vCPU, 4 GB |
| `c6.4u8g.cluster` | Cluster, 4 vCPU, 8 GB |
| `c6.8u16g.cluster` | Cluster, 8 vCPU, 16 GB |

## 4. ⚠️ Важные моменты

1. `network_id` — ID subnet, не VPC.
2. Port 5672 — AMQP (основной), port 15672 — Management UI.
3. После создания управление очередями — через Management UI (http://{host}:15672).
4. Создание занимает **~10-15 минут**.
5. `ssl_enable` — для RabbitMQ включается отдельно (не всегда доступен в регионе).

## 5. Ссылки

- `sbercloud_dms_rabbitmq_instance` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/dms_rabbitmq_instance.md

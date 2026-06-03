# MongoDB (DDS — Document Database Service) — Terraform

**Ресурсы провайдера:**
- `sbercloud_dds_instance` — инстанс MongoDB
- `sbercloud_dds_parameter_template` — шаблон параметров DDS
- `sbercloud_dds_parameter_template_apply` — применить шаблон к инстансу
- `sbercloud_dds_parameter_template_compare` — сравнить два шаблона
- `sbercloud_dds_parameter_template_copy` — скопировать шаблон
- `sbercloud_dds_parameter_template_reset` — сбросить шаблон на дефолтный

---

## 1. Для тех, кто первый раз

Создаётся managed MongoDB (сервис DDS — Document Database Service).
Поддерживаются: Single, ReplicaSet, Sharded-кластер.

---

## 2. Режимы (`mode`)

| mode | Описание | Когда |
|---|---|---|
| *(без mode)* | Single (одиночный) | Dev |
| `ReplicaSet` | Реплика-сет (1 primary + secondary) | Production (рекомендуется) |
| `Sharding` | Шардированный (mongos + shard + config) | Большие данные (1TB+) |

---

## 3. Ключевые параметры `sbercloud_dds_instance`

| Параметр | Обязательный | Описание |
|---|---|---|
| `name` | ✅ | Имя инстанса |
| `datastore.type` | ✅ | `DDS-Community` |
| `datastore.version` | ✅ | `3.2`, `3.4`, `4.0`, `4.2`, `4.4` |
| `availability_zone` | ✅ | Зона доступности |
| `vpc_id` | ✅ | VPC |
| `subnet_id` | ✅ | Подсеть |
| `security_group_id` | ✅ | SG (порт по умолч. 8635) |
| `password` | ✅ | Пароль для `rwuser` |
| `mode` | ✅ | `ReplicaSet` / `Sharding` / `Single` |
| `flavor` | ✅ | Один или несколько блоков |
| `port` | ❌ | **2100-9500** или `27017`, `27018`, `27019`. По умолч. `8635` |
| `ssl` | ❌ | По умолч. `true`. **Меняет ssl → рестарт инстанса!** |
| `disk_encryption_id` | ❌ | ID ключа KMS для шифрования диска |
| `backup_strategy` | ❌ | start_time + keep_days |
| `charging_mode` | ❌ | `postPaid` / `prePaid` |
| `tags` | ❌ | Теги |

### Параметры блока `flavor`

| Параметр | Описание |
|---|---|
| `type` | `mongos` / `shard` / `config` / `replica` |
| `num` | Количество |
| `storage` | `ULTRAHIGH` (SSD) |
| `size` | Размер диска (кратно 10, GB) |
| `spec_code` | Flavour (например `dds.mongodb.c3.medium.4.shard`) |

---

## 4. Параметр `ssl` — шифрование трафика

```hcl
ssl = true
```
**По умолчанию:** `true`. 

🔴 **ПРОБЛЕМА:** При переключении SSL (false → true или true → false) инстанс **перезагружается автоматически**. На время рестарта (1-3 мин) сервис недоступен.

---

## 5. `disk_encryption_id` — шифрование диска

```hcl
disk_encryption_id = sbercloud_kms_key.mongo.id
```
Шифрует диски всех нод кластера. **Задаётся только при создании (ForceNew).**

---

## 6. `sbercloud_dds_parameter_template` — шаблоны параметров

```hcl
resource "sbercloud_dds_parameter_template" "mongo_params" {
  name        = "mongo-performance"
  description = "Оптимизация производительности"
  node_type   = "replica"    # replica / shard / mongos / config
  parameter_values = {
    "net.maxIncomingConnections" = "5000"
    "operationProfiling.mode"    = "slowOp"
  }
  datastore {
    type    = "DDS-Community"
    version = "4.0"
  }
}
```

---

## 7. ⚠️ Важные моменты (gotchas)

1. **Пароль** — для пользователя `rwuser`. От 8 символов, буквы+цифры.
2. **Порт по умолчанию — 8635** (не 27017!). Разрешённые: `2100-9500`, `27017`, `27018`, `27019`.
3. **`ssl` по умолчанию true.** Смена вызывает рестарт инстанса — **будьте осторожны в prod**.
4. **`disk_encryption_id` — только при создании (ForceNew).** Если понадобилось шифрование после создания — пересоздавать кластер.
5. **ReplicaSet** — `spec_code` с `*repset` для replica.
6. **Sharding** — mongos, shard и config — три отдельных блока `flavor`.
7. **flavor.storage** — только для shard и config. У mongos диска нет.
8. **flavor.size** — кратно 10. Например: 20, 30, 50, 100, 500.
9. **keep_days** в `backup_strategy` — от 0 (отключено) до 732.
10. **При импорте** теряются: `password`, `auto_renew`, `period`, `period_unit`.

## 8. Ссылки

- `sbercloud_dds_instance` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/dds_instance.md
- `sbercloud_dds_parameter_template` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/dds_parameter_template.md
- `sbercloud_dds_parameter_template_apply` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/dds_parameter_template_apply.md

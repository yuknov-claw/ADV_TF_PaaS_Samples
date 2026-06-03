# ClickHouse через MRS (MapReduce Service) — Terraform

**Ресурсы:** `sbercloud_mapreduce_cluster`, `sbercloud_mapreduce_job`

---

## 1. Как работает ClickHouse на Advanced

ClickHouse на платформе Advanced доступен **двумя способами**:

### Способ 1: MRS (MapReduce Service) — через Terraform ✅

Big Data-платформа, где ClickHouse — один из компонентов кластера (наряду с Hadoop, Spark, HBase, Hive, Flink и т.д.).

> *«MapReduce Service (MRS) — надежная, безопасная и простая в использовании платформа для хранения, обработки и анализа больших данных. Вы можете самостоятельно использовать размещенные компоненты, такие как Hadoop, Spark, ClickHouse, HBase и Hive, для быстрого создания кластеров.»*

Подходит, если ClickHouse нужен «в составе» большой инфраструктуры данных.

### Способ 2: CloudTable — без Terraform ❌

Управляемый сервис, который поддерживает три движка: HBase, **Doris**, **ClickHouse**.

> *«CloudTable — полностью управляемый сервис хранения и анализа данных на базе HBase, Doris и ClickHouse.»*

Terraform-ресурса для CloudTable в провайдере sbercloud **нет**. Управление — только через консоль или API.

---

## 2. Типы кластеров MRS

| type | Описание | Компоненты (пример) |
|---|---|---|
| `ANALYSIS` | Аналитический кластер | Hadoop, Hive, Spark, ClickHouse, Tez, Presto, Flink |
| `STREAMING` | Потоковый кластер | Storm, Kafka, Flink |
| `MIXED` | Гибридный (ANALYSIS + STREAMING) | Hadoop + Spark + Storm + Kafka |
| `CUSTOM` | Кастомный (свой шаблон размещения ролей) | Любой набор, с `template_id` и `assigned_roles` |

### Когда какой выбирать

- **`ANALYSIS`** — ClickHouse + Hadoop/Spark для batch-обработки (простой сценарий)
- **`STREAMING`** — ClickHouse + Kafka/Storm для real-time обработки
- **`MIXED`** — когда и batch, и stream в одном кластере
- **`CUSTOM`** — продвинутый: свои роли на свои ноды, точное управление (Kerberos, Ranger, ZooKeeper...)

---

## 3. Версии MRS

| version | Компоненты |
|---|---|
| `MRS 2.1.0` | Hadoop 3.x, Spark 3.x, ClickHouse, Hive, HBase |
| `MRS 3.0.5` | Hadoop 3.x, Spark 3.x, ClickHouse, Flink |
| `MRS 3.1.0` | Hadoop 3.x, Spark 3.x, ClickHouse (обновлённые версии) |

---

## 4. Ключевые параметры `sbercloud_mapreduce_cluster`

| Параметр | Обязательный | Описание |
|---|---|---|
| `name` | ✅ | Имя кластера (2-64 символа, буквы/цифры/_-) |
| `version` | ✅ | `MRS 2.1.0`, `MRS 3.0.5`, `MRS 3.1.0` |
| `type` | ❌ | `ANALYSIS` (по умолч.), `STREAMING`, `MIXED`, `CUSTOM` |
| `component_list` | ✅ | Список компонентов: `["ClickHouse", "Hadoop", "Spark"]` |
| `availability_zone` | ✅ | Зона доступности (через `data.sbercloud_availability_zones`) |
| `vpc_id` | ✅ | VPC |
| `subnet_id` | ✅ | Подсеть |
| `manager_admin_pass` | ❌ | Пароль для web UI (8-26 символов, 4 типа символов) |
| `node_admin_pass` | ❌ | Пароль для SSH на ноды (альтернатива `node_key_pair`) |
| `node_key_pair` | ❌ | SSH-ключ для нод (альтернатива `node_admin_pass`) |
| `safe_mode` | ❌ | `true` (Kerberos, по умолч.) / `false` |
| `public_ip` | ❌ | EIP-адрес для кластера (должен уже существовать) |
| `eip_id` | ❌ | ID EIP (альтернатива `public_ip`) |
| `log_collection` | ❌ | Собирать логи при ошибке (`true` по умолч.) |
| `template_id` | ❌ | Шаблон для CUSTOM-кластера |
| `enterprise_project_id` | ❌ | EPS-проект |
| `security_group_ids` | ❌ | Кастомные SG (открыть порт 9022) |

### Node-группы

| Блок | Для type | Описание |
|---|---|---|
| `master_nodes` | Все | Master-ноды (управление) |
| `analysis_core_nodes` | ANALYSIS, MIXED | Core-ноды (данные) |
| `analysis_task_nodes` | ANALYSIS, MIXED | Task-ноды (вычисления, опционально) |
| `streaming_core_nodes` | STREAMING, MIXED | Core-ноды для streaming |
| `streaming_task_nodes` | STREAMING, MIXED | Task-ноды для streaming |
| `custom_nodes` | CUSTOM | Кастомные ноды (обязательно `group_name`) |

### Параметры node-группы

| Параметр | Обязательный | Описание |
|---|---|---|
| `flavor` | ✅ | Тип ВМ (например `c6.2xlarge.4.linux.bigdata`) |
| `node_number` | ✅ | Количество нод в группе |
| `root_volume_type` | ✅ | Системный диск: `SATA`, `SAS`, `SSD` |
| `root_volume_size` | ✅ | Размер системного диска (GB) |
| `data_volume_count` | ✅ | Количество дисков с данными |
| `data_volume_type` | ❌ | Тип диска с данными (если count > 0) |
| `data_volume_size` | ❌ | Размер диска с данными (10-32768 GB) |
| `group_name` | ❌ | Имя группы (только для `custom_nodes`) |
| `assigned_roles` | ❌ | Роли для нод (только для `CUSTOM` type) |

---

## 5. Важные моменты

1. **Создание занимает 30-60 минут** (таймаут по умолчанию: create=60min, update=180min, delete=40min)
2. **Для CUSTOM-кластера** обязательны `template_id` и `assigned_roles` для каждой node-группы
3. **Пароли** (manager_admin_pass, node_admin_pass): 8-26 символов, минимум один символ каждого типа: заглавные, строчные, цифры, спецсимволы `!?,.:-_{}[]@$^+=/`
4. **data_volume_count**: master — 1; core — от 1 до макс. flavour'а; task — от 0 до макс. flavour'а
5. **При импорте** пропадают `manager_admin_pass`, `node_admin_pass`, `template_id`, `assigned_roles` — добавить `ignore_changes`
6. **При update** масштабируются только core и task группы (node_number)
7. `analysis_core_nodes` + `streaming_core_nodes` не могут быть одновременно пустыми
8. CloudTable (managed ClickHouse) — нет Terraform-ресурса

---

## 🌩️ Альтернатива: CloudTable (managed ClickHouse)

Если вам нужен **чистый ClickHouse** без Hadoop/Spark/Hive — используйте **CloudTable**.
Это managed ClickHouse (а также Doris и HBase) без Big Data-окружения.

**Terraform-ресурса для CloudTable нет.**
Создание — только через консоль Cloud.ru:
https://console.cloud.ru/spa/cloudtable/

Документация: https://cloud.ru/docs/cloudtable/ug/index

| Вариант | Плюсы | Минусы |
|---|---|---|
| **MRS** (этот пример) | ClickHouse + Hadoop/Spark/Kafka | Тяжелый кластер (20+ минут), дороже |
| **CloudTable** (через консоль) | Только ClickHouse, легче, дешевле | Нет Terraform, только через UI/API |

## 6. Ссылки

- `sbercloud_mapreduce_cluster` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/mapreduce_cluster.md
- `sbercloud_mapreduce_job` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/mapreduce_job.md
- Справочник компонентов MRS — https://support.hc.sbercloud.ru/api/mrs/mrs_02_0101.html
- CloudTable (managed ClickHouse) — https://cloud.ru/docs/cloudtable/ug/index

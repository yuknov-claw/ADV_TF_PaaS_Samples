# Load Balancer (ELB) — Terraform

**Ресурсы провайдера — Dedicated ELB:**
- `sbercloud_elb_loadbalancer` — балансировщик
- `sbercloud_elb_listener` — слушатель (порт + протокол)
- `sbercloud_elb_pool` — backend-пул
- `sbercloud_elb_member` — сервер в пуле
- `sbercloud_elb_monitor` — health check
- `sbercloud_elb_certificate` — SSL-сертификат
- `sbercloud_elb_ipgroup` — IP-группа (white/black list)
- `sbercloud_elb_security_policy` — TLS Security Policy
- `sbercloud_elb_l7policy` — L7-политика (роутинг)
- `sbercloud_elb_l7rule` — L7-правило

**Shared ELB (классический):**
- `sbercloud_lb_loadbalancer`, `sbercloud_lb_listener`, `sbercloud_lb_pool`, `sbercloud_lb_member`,
  `sbercloud_lb_monitor`, `sbercloud_lb_certificate`, `sbercloud_lb_l7policy`, `sbercloud_lb_l7rule`, `sbercloud_lb_whitelist`

---

## 1. Dedicated vs Shared

| Характеристика | Dedicated (`sbercloud_elb_*`) | Shared (`sbercloud_lb_*`) |
|---|---|---|
| ALB (L7) + NLB (L4) | ✅ | ✅ |
| Flavour'ы (ёмкость) | ✅ (L4 + L7) | ❌ |
| Cross-VPC backend | ✅ | ❌ |
| IP-groups | ✅ | ❌ |
| Availability zones | ✅ (2AZ) | ❌ |
| Security policies (TLS) | ✅ | ❌ |
| Сложность | Средняя | Низкая |

---

## 2. Ключевые параметры Dedicated ELB

### `sbercloud_elb_loadbalancer`

| Параметр | Обязательный | Описание |
|---|---|---|
| `name` | ✅ | Имя |
| `vpc_id` | ✅ | VPC |
| `ipv4_subnet_id` | ✅ | Подсеть для IP |
| `availability_zone` | ✅ | **2 AZ** для HA |
| `cross_vpc_backend` | ❌ | Backend в другой VPC |
| `l4_flavor_id` | ❌ | L4-ёмкость (из data source) |
| `l7_flavor_id` | ❌ | L7-ёмкость |
| `protection_status` | ❌ | `ConsoleProtection` — защита от удаления |
| `protection_reason` | ❌ | Причина защиты |
| `ipv6_enable` | ❌ | Включить IPv6 |
| `autoscaling_enabled` | ❌ | Автоскалинг |
| `elb_virsubnet_ids` | ❌ | Подсети для развёртывания |

### `sbercloud_elb_listener`

| Параметр | Описание |
|---|---|
| `protocol` | `HTTP`, `HTTPS`, `TCP`, `UDP`, `QUIC`, `gRPC` |
| `protocol_port` | Порт |
| `server_certificate` | ID сертификата (для HTTPS) |
| `default_pool_id` | Пул по умолчанию |
| `insert_headers` | X-Forwarded-* заголовки |
| `idle_timeout` | Таймаут бездействия (сек) |
| `request_limit` | Лимит тела запроса (байт) |

---

## 3. 🔴 Особенности и gotchas

1. **Dedicated ELB требует `availability_zone`** — две зоны для отказоустойчивости. Если не указать — ошибка.
2. **Flavour'ы ELB** получать через `data.sbercloud_elb_flavors`. Без них не создастся.
3. **Shared ELB создаётся без flavour'ов** — проще, но без cross-VPC и IP-групп.
4. **`cross_vpc_backend = true`** — можно подключать серверы из других VPC. Но нужна сетевая связность.
5. **EIP** привязывается отдельно: `sbercloud_vpc_eip` + `sbercloud_elb_loadbalancer_eip_associate`.
6. **`protection_status`** — защита от удаления. Полезно для prod, но не забудьте снять при destroy.
7. **Shared ELB (`sbercloud_lb_loadbalancer`)** — timeouts: create=10min, update=10min.
8. **Listener** — если нужна поддержка gRPC, выбирать `protocol = "gRPC"` (только Dedicated, L7).

## 4. Data sources

```hcl
data "sbercloud_elb_flavors" "l4" { type = "L4" }
data "sbercloud_elb_flavors" "l7" { type = "L7" }
```

## 5. Ссылки

- Dedicated ELB: https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/elb_loadbalancer.md
- Shared ELB: https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/lb_loadbalancer.md

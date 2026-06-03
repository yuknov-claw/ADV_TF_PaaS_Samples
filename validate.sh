#!/bin/bash
# ============================================================
# validate.sh — проверить все Terraform-примеры
# Запуск: ./validate.sh [service-name]
# Пример: ./validate.sh postgresql    — только postgresql
#         ./validate.sh                — все сервисы
# ============================================================
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICES="k8s-cce postgresql s3-obs container-registry mongo-dds kafka-dms rabbitmq redis-dcs load-balancer mrs-clickhouse"

if [ -n "$1" ]; then
  SERVICES="$1"
fi

PASS=0
FAIL=0

for service in $SERVICES; do
  DIR="$BASE_DIR/$service"

  if [ ! -d "$DIR" ]; then
    echo "❌ $service — папка не найдена"
    FAIL=$((FAIL + 1))
    continue
  fi

  echo ""
  echo "──────────────────────────────────────────────"
  echo "🔍 Проверка: $service"
  echo "──────────────────────────────────────────────"

  cd "$DIR"

  # 1. terraform init (быстрый, без плагинов)
  if terraform init -backend=false 2>/dev/null; then
    echo "  ✅ init OK"
  else
    echo "  ❌ init FAILED"
    FAIL=$((FAIL + 1))
    continue
  fi

  # 2. terraform validate
  if terraform validate 2>/dev/null; then
    echo "  ✅ validate OK"
    PASS=$((PASS + 1))
  else
    echo "  ❌ validate FAILED"
    FAIL=$((FAIL + 1))
  fi

  # 3. Проверка: terraform.tfvars не закоммичен
  if [ -f "terraform.tfvars" ] && [ ! -f ".gitignore" ]; then
    echo "  ⚠️  terraform.tfvars существует — проверьте .gitignore"
  fi

  # Cleanup
  rm -rf .terraform .terraform.lock.hcl 2>/dev/null || true

  cd "$BASE_DIR"
done

echo ""
echo "══════════════════════════════════════════════"
echo "Результаты: ✅ $PASS успешно, ❌ $FAIL с ошибками"
echo "══════════════════════════════════════════════"

exit $FAIL

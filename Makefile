# ============================================================
# Makefile — вспомогательные команды для terraform-samples
# ============================================================
BASE_DIR := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: help validate audit clean

help: ## Показать эту справку
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

validate: ## Проверить все примеры через terraform validate
	@bash $(BASE_DIR)/validate.sh

validate/%: ## Проверить конкретный сервис: make validate/k8s-cce
	@bash $(BASE_DIR)/validate.sh $(*)

audit: ## Проверить, что terraform.tfvars не закоммичены
	@echo "🔍 Проверка terraform.tfvars..."
	@for d in $(BASE_DIR)/*/; do \
		if [ -f "$$d/terraform.tfvars" ]; then \
			echo "  ⚠️  $${d%/}: terraform.tfvars существует"; \
		fi; \
	done
	@echo "  ✅ Готово"

clean: ## Удалить .terraform из всех папок
	@echo "🧹 Очистка..."
	@find $(BASE_DIR) -type d -name .terraform -exec rm -rf {} + 2>/dev/null || true
	@find $(BASE_DIR) -name '.terraform.lock.hcl' -delete 2>/dev/null || true
	@echo "  ✅ Готово"

info: ## Показать структуру и размеры
	@echo "📁 Структура terraform-samples:"
	@for d in $(BASE_DIR)/*/; do \
		name=$$(basename $$d); \
		files=$$(find $$d -type f | wc -l); \
		size=$$(du -sh $$d | cut -f1); \
		printf "  %-25s %2d файлов  %s\n" "$$name" "$$files" "$$size"; \
	done
	@printf "  %-25s\n" "───────────────────────"
	@printf "  %-25s %2d файлов\n" "ИТОГО" "$$(find $(BASE_DIR) -type f | wc -l)"

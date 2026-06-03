#!/bin/bash

# Цветовые коды для оформления вывода в терминале
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
GRAY='\033[1;90m'
NC='\033[0m' # Сброс цвета

### ФУНКЦИИ

# Функция получения текущей даты и времени для логов
timestamp() {
 date +"[%d-%m-%Y] [%H:%M:%S]"
}

# Функция вывода информативного сообщения с цветом
log() {
 echo -e "$(timestamp) $1$2${NC}"
}

# Функция для оформления текстовых пунктов меню
menu_items() {
 echo -e "$1$2"
}

# Функция проверки доступности Интернета (доступен ли https://cloud.ru)
check_internet() {
 response=$(curl -s --head --max-time 5 https://cloud.ru)
 msg=$(echo "$response" | head -n 1)
 if echo "$response" | head -n 1 | grep -q "200\|301\|302"; then
 log "$GREEN" "Статус: Соединение установлено. $msg"
 return 0
 else
 log "$RED" "Не удалось установить подключение к сайту cloud.ru"
 return 1
 fi
}

# Функция проверки доступа к системным репозиториям в зависимости от ОС
check_repo_access() {
 local os_type=""
 local output=""
 # Проверяем тип ОС и соответствующий менеджер пакетов
 if [[ "$(uname)" == "Darwin" ]]; then
 os_type="macOS"
 if ! brew update >/dev/null 2>&1; then
 log "$RED" "Не удалось обновить brew. Проверьте подключение к интернету и репозиторию."
 return 1
 fi
 elif [[ -f /etc/debian_version ]]; then
 os_type="Debian/Ubuntu"
 output=$(sudo apt-get update -qq 2>&1)
 if echo "$output" | grep -qE "Failed to fetch|Cannot initiate the connection"; then
 log "$RED" "Ошибка при обновлении apt-get: $output"
 return 1
 fi
 elif [[ -f /etc/redhat-release ]] || [[ -f /etc/centos-release ]]; then
 os_type="RHEL/CentOS"
 output=""
 if command -v dnf >/dev/null 2>&1; then
 output=$(sudo dnf makecache -q 2>&1)
 else
 output=$(sudo yum makecache -q 2>&1)
 fi
 if echo "$output" | grep -qE "Could not resolve|Errno 14"; then
 log "$RED" "Ошибка при обновлении репозиториев: $output"
 return 1
 fi
 else
 log "$RED" "Неопознанная ОС. Установите необходимые пакеты вручную!"
 return 1
 fi
 log "$GREEN" "Доступ к репозиториям на $os_type подтвержден"
 return 0
}

# Функция автоматической установки необходимых пакетов (curl, wget, unzip, jq)
install_packages() {
 local packages=("$@")
 # Проверяем ОС: macOS, Debian, RedHat-подобные
 if [[ "$(uname)" == "Darwin" ]]; then
 for pkg in "${packages[@]}"; do
 if ! brew list "$pkg" &>/dev/null; then
 log "$BLUE" "Устанавливаю $pkg через Homebrew"
 brew install "$pkg"
 fi
 done
 elif [[ -f /etc/debian_version ]]; then
 log "$BLUE" "Обновление списка пакетов через apt-get"
 sudo apt-get update -qq
 log "$BLUE" "Установка пакетов: ${packages[*]}"
 sudo apt-get install -y "${packages[@]}" > /dev/null
 elif [[ -f /etc/redhat-release ]] || [[ -f /etc/centos-release ]]; then
 if command -v dnf >/dev/null 2>&1; then
 log "$BLUE" "Установка пакетов через dnf: ${packages[*]}"
 sudo dnf install -y "${packages[@]}" >/dev/null
 else
 log "$BLUE" "Установка пакетов через yum: ${packages[*]}"
 sudo yum install -y "${packages[@]}" >/dev/null
 fi
 else
 log "$RED" "Неопознанная ОС. Установите необходимые пакеты вручную!"
 return 1
 fi
}

# Функция проверки установлен ли terraform
check_terraform_installed() {
 if command -v terraform >/dev/null 2>&1; then
 log "$GREEN" "Текущая версия: $(terraform version | head -n1)"
 return 0
 else
 log "$BLUE" "Terraform не установлен"
 return 1
 fi
}

# Функция получения ссылок на скачивание (Terraform и провайдеры)
get_links() {
 local url="$1"
 local type="$2"
 # Для Terraform ищем ссылки .zip на releases
 if [ "$type" = "Terraform" ]; then
 curl -s "$url" | grep -oE 'https://terraform-release\.obs\.ru-moscow-1\.hc\.sbercloud\.ru[^" '\''<>()\\]+\.zip' | sort -u
 fi
 # Для Evolution используем GitHub API и jq
 if [ "$type" = "Terraform_provider_evolution" ]; then
 curl -s "$url" | jq -r '.[].assets[].browser_download_url' | grep 'terraform-provider-cloud_'
 fi
 # Для Advanced используем GitHub API и jq
 if [ "$type" = "Terraform_provider_advanced" ]; then
 curl -s "$url" | jq -r '.[].assets[].browser_download_url' | grep 'terraform-provider-sbercloud_'
 fi
}

# Функция с циклом для повторных попыток получения списка ссылок на скачивание
get_links_loop() {
 MAX_ATTEMPTS=5 # Максимальное число попыток
 COUNTER=0
 local url="$1"
 local type="$2"
 while true; do
 log "$BLUE" "Получение списка доступных файлов для $2"
 links=$(get_links "$url" "$type")
 # Если получили хотя бы одну ссылку – успех
 if [ -n "$links" ]; then
 log "$GREEN" "Список ссылок успешно получен"
 make_table "${type}_links.txt" <<< "$links"
 log "$GREEN" "Список ссылок, архитектур и версий для $type сохранён в файл: ${type}_links.txt"
 break
 fi
 ((COUNTER++))
 # Если попытки закончились — неудача
 if [ "$COUNTER" -ge "$MAX_ATTEMPTS" ]; then
 log "$RED" "Не удалось получить список ссылок после $MAX_ATTEMPTS попыток"
 exit 1
 fi
 # Сообщаем о неудачной попытке и ждем 3 секунды
 log "$RED" "Не удалось получить список ссылок, повторная попытка через 3 секунды (Попытка $COUNTER из $MAX_ATTEMPTS)"
 sleep 3
 done
}

# Функция разбора (парсинга) ссылок для отображения удобной таблицы версий/архитектур
make_table() {
 # Разделение по файловому аргументу
 if [[ $# -gt 0 ]]; then
 outfile="$1"
 tempfile="tmp_$1"
 # Перебираем построчно ссылки
 while read -r url; do
 os_in_url=$(echo "$url" | sed -E 's#https?://[^/]+/([^/]+)/.*#\1#')
 file=${url##*/}

 # Пропускаем файлы с контрольными суммами
 if [[ "$file" =~ _SHA256SUMS(\.sig)?$ ]]; then
 continue
 fi

 # Проверяем разные форматы файлов
 if [[ "$file" =~ ^terraform_([0-9]+\.[0-9]+\.[0-9]+)_([a-zA-Z]+)_([a-zA-Z0-9]+)\.zip$ ]]; then
 version="${BASH_REMATCH[1]}"
 arch="${BASH_REMATCH[3]}"
 printf "%s %s %s %s\n" "$url" "$version" "$os_in_url" "$arch"
 elif [[ $file =~ ^terraform-provider-cloud_([0-9]+\.[0-9]+\.[0-9]+)_([a-zA-Z]+)_([a-zA-Z0-9]+)(\.zip)?$ ]]; then
 version="${BASH_REMATCH[1]}"
 os="${BASH_REMATCH[2]}"
 arch="${BASH_REMATCH[3]}"
 printf "%s %s %s %s\n" "$url" "$version" "$os" "$arch"
 elif [[ $file =~ ^terraform-provider-sbercloud_([0-9]+\.[0-9]+\.[0-9]+)_([a-zA-Z]+)_([a-zA-Z0-9]+)(\.zip)?$ ]]; then
 version="${BASH_REMATCH[1]}"
 os="${BASH_REMATCH[2]}"
 arch="${BASH_REMATCH[3]}"
 printf "%s %s %s %s\n" "$url" "$version" "$os" "$arch"
 else
 log "$RED" "Ошибка парсинга: $url" >&2
 fi
 done > "$tempfile"
 # Сортируем и сохраняем итоговую таблицу
 sort -r "$tempfile" > "$outfile"
 rm "$tempfile"
 else
 # Если не передан аргумент — читаем из stdin
 while read -r url; do
 os_in_url=$(echo "$url" | sed -E 's#https?://[^/]+/([^/]+)/.*#\1#')
 file=${url##*/}
 if [[ "$file" =~ ^terraform_([0-9]+\.[0-9]+\.[0-9]+)_([a-zA-Z]+)_([a-zA-Z0-9]+)\.zip$ ]]; then
 version="${BASH_REMATCH[1]}"
 arch="${BASH_REMATCH[3]}"
 printf "%s %s %s %s\n" "$url" "$version" "$os_in_url" "$arch"
 else
 log "$RED" "Ошибка парсинга: $url" >&2
 fi
 done
 fi
}

### ФУНКЦИИ МЕНЮ ВЫБОРА ОС/АРХИТЕКТУРЫ/ВЕРСИИ

# Функция меню выбора ОС по имеющемуся файлу
choose_os() {
 local DATAFILE="$1"
 while true; do
 # Получаем уникальные ОС из файла
 oses=($(awk '{print $3}' "$DATAFILE" | sort -u))
 echo ""
 echo -e "${BLUE}Выберите операционную систему${NC}"
 # Выводим возможные ОС для выбора
 for i in "${!oses[@]}"; do
 case "${oses[$i]}" in
 linux) os_human="Linux";;
 mac | darwin) os_human="MacOS";;
 win | windows) os_human="Windows";;
 ubuntu) os_human="Ubuntu";;
 cent) os_human="CentOS";;
 freebsd) os_human="FreeBSD";;
 *) os_human="${oses[$i]}";;
 esac
 printf "%d) %s\n" $((i+1)) "$os_human"
 done
 # Возможность выйти
 echo -e "${GRAY}-${NC}"
 echo -e "${GRAY}0) Выйти${NC}"
 echo ""
 read -rp "Ваш выбор: " os_num
 if [[ "$os_num" == "0" ]]; then
 return 1 # Перейти назад/выход
 fi
 if [[ "$os_num" =~ ^[1-9][0-9]*$ ]] && (( os_num >= 1 && os_num <= ${#oses[@]} )); then
 OS_SELECTED="${oses[$((os_num-1))]}"
 return 0
 fi
 echo "Некорректный выбор, попробуйте снова."
 done
}

# Функция меню выбора архитектуры для выбранной ОС
choose_arch() {
 local DATAFILE="$1"
 local os="$2"
 while true; do
 # Получаем архитектуры для выбранной ОС
 archs=($(awk -v os="$os" '$3==os {print $4}' "$DATAFILE" | sort -u))
 echo ""
 echo -e "${BLUE}Выберите архитектуру${NC}"
 # Преобразуем архитектуру в человекочитаемый вид
 for i in "${!archs[@]}"; do
 case "${archs[$i]}" in
 386) arch_human="x86 (32-bit)";;
 amd64) arch_human="x86_64 (64-bit)";;
 arm) arch_human="ARM (32-bit)";;
 arm64) arch_human="ARM64 (64-bit)";;
 *) arch_human="${archs[$i]}";;
 esac
 printf "%d) %s\n" $((i+1)) "$arch_human"
 done
 echo -e "${GRAY}-${NC}"
 echo -e "${GRAY}0) Назад${NC}"
 echo ""
 read -rp "Ваш выбор: " arch_num
 if [[ "$arch_num" == "0" ]]; then
 return 1
 fi
 if [[ "$arch_num" =~ ^[1-9][0-9]*$ ]] && (( arch_num >= 1 && arch_num <= ${#archs[@]} )); then
 ARCH_SELECTED="${archs[$((arch_num-1))]}"
 return 0
 fi
 echo "Некорректный выбор, попробуйте снова."
 done
}

# Функция меню выбора версии Terraform или провайдера
choose_version() {
 local DATAFILE="$1"
 local os="$2"
 local arch="$3"
 while true; do
 # Получаем доступные версии по выбранной ОС и архитектуре
 versions=($(awk -v os="$os" -v arch="$arch" '$3==os && $4==arch {print $2}' "$DATAFILE" | sort -V -r | uniq))
 if [ ${#versions[@]} -eq 0 ]; then
 echo "Нет версий для этой ОС и архитектуры."
 return 1
 fi
 echo ""
 echo -e "${BLUE}Выберите версию${NC}"
 for i in "${!versions[@]}"; do
 printf "%d) %s\n" $((i+1)) "${versions[$i]}"
 done
 echo -e "${GRAY}-${NC}"
 echo -e "${GRAY}0) Назад${NC}"
 echo ""
 read -rp "Ваш выбор: " ver_num
 if [[ "$ver_num" == "0" ]]; then
 return 1
 fi
 if [[ "$ver_num" =~ ^[1-9][0-9]*$ ]] && (( ver_num >= 1 && ver_num <= ${#versions[@]} )); then
 VERSION_SELECTED="${versions[$((ver_num-1))]}"
 return 0
 fi
 echo "Некорректный выбор, попробуйте снова."
 done
}

# Основное циклическое меню выбора ОС, архитектуры и версии для загрузки или установки Terraform/Provider
menu() {
 local DATAFILE="$1"
 while true; do
 # Выбор ОС
 if ! choose_os "$DATAFILE"; then
 echo ""
 echo -e "${GREEN}Выход${NC}"
 echo ""
 exit 0
 break
 fi
 # Выбор архитектуры
 while true; do
 if ! choose_arch "$DATAFILE" "$OS_SELECTED"; then
 break # Назад к выбору ОС
 fi
 # Выбор версии
 while true; do
 if ! choose_version "$DATAFILE" "$OS_SELECTED" "$ARCH_SELECTED"; then
 break # Назад к выбору архитектуры
 fi
 url=$(awk -v os="$OS_SELECTED" -v arch="$ARCH_SELECTED" -v version="$VERSION_SELECTED" '$3==os && $4==arch && $2==version {print $1}' "$DATAFILE")
 if [ -z "$url" ]; then
 log "${RED}" "Ссылка не найдена!"
 else
 echo ""
 echo -e "${GREEN}Ссылка на файл: $url${NC}"
 # Спрашиваем скачивать ли архив автоматически
 while true; do
 echo ""
 read -rp "Скачать архив? [y/n]: " answer
 case "$answer" in
 ""|"y"|"Y" )
 fname="${url##*/}"
 echo ""
 log "$BLUE" "Скачиваем $fname ..."
 wget --progress=bar:force -q -O "$fname" "$url"
 if [ $? -eq 0 ]; then
 log "$GREEN" "Файл скачан в: $(realpath "$fname")"
 install_terraform "$fname"
 else
 log "$RED" "Ошибка загрузки файла!"
 fi
 return 1
 ;;
 "n"|"N" )
 break # вернуться к выбору версии
 ;;
 * )
 echo "Введите y/n"
 ;;
 esac
 done
 fi
 done
 done
 done
}

### УСТАНОВКА И РАСПАКОВКА ФАЙЛОВ

# Функция установки terraform или провайдера Terraform
install_terraform() {
 local fname="$1"

 # Если это архив с самим terraform
 if [[ "$fname" =~ ^terraform_[0-9]+\.[0-9]+\.[0-9]+_[a-z0-9]+_[a-z0-9]+\.zip$ ]]; then
 echo ""
 read -p "Установить terraform из этого архива? (y/n):" do_install
 if [[ "$do_install" == "y" || -z "$do_install" ]]; then
 tmpdir=$(mktemp -d)
 unzip -q "$fname" -d "$tmpdir"
 if [[ -f "$tmpdir/terraform" ]]; then
 echo ""
 log "$BLUE" "Копирую terraform в /usr/local/bin/"
 sudo mv "$tmpdir/terraform" /usr/local/bin/
 sudo chmod +x /usr/local/bin/terraform
 # Вывод версии terraform
 echo ""
 echo -e "${GREEN}[Версия установленного terraform]${NC}"
 terraform version
 fi
 log "$BLUE" "Удаляю $fname из $PWD"
 rm "$fname"
 fi

 # Если это бинарник провайдера Terraform
 elif [[ "$fname" == *terraform-provider* ]]; then
 # Определение пользователя, кому ставим
 if [[ -n $SUDO_USER ]]; then
 ORIGINAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
 else
 ORIGINAL_HOME="$HOME"
 fi

 # Для Evolution Provider (cloudru)
 if [[ "$fname" =~ ^terraform-provider-cloud_([0-9]+\.[0-9]+\.[0-9]+)_([a-zA-Z0-9]+)_([a-zA-Z0-9]+)$ ]]; then
 version="${BASH_REMATCH[1]}"
 os="${BASH_REMATCH[2]}"
 arch="${BASH_REMATCH[3]}"
 root_install_path="/root/.terraform.d/plugins/cloud.ru/cloudru/cloud/${version}/${os}_${arch}"
 user_install_path="$ORIGINAL_HOME/.terraform.d/plugins/cloud.ru/cloudru/cloud/${version}/${os}_${arch}"
 newname="terraform-provider-cloud_${version}"

 # Для Advanced Provider (sbercloud)
 elif [[ "$fname" =~ ^terraform-provider-sbercloud_([0-9]+\.[0-9]+\.[0-9]+)_([a-zA-Z0-9]+)_([a-zA-Z0-9]+)\.zip$ ]]; then
 version="${BASH_REMATCH[1]}"
 os="${BASH_REMATCH[2]}"
 arch="${BASH_REMATCH[3]}"
 root_install_path="/root/.terraform.d/plugins/cloud.ru/sbercloud-terraform/sbercloud/${version}/${os}_${arch}"
 user_install_path="$ORIGINAL_HOME/.terraform.d/plugins/cloud.ru/sbercloud-terraform/sbercloud/${version}/${os}_${arch}"

 zipfile=$fname
 fname=$(unzip -Z1 "$zipfile" | grep -E '^terraform-provider-sbercloud_v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
 tmpdir=$(mktemp -d)
 unzip -j "$zipfile" "$fname" -d "$tmpdir"
 cp "$tmpdir/$fname" .
 rm -rf "$tmpdir"
 log "$BLUE" "Удаляю $zipfile из $PWD"
 rm "$zipfile"

 newname="terraform-provider-sbercloud_${version}"

 else
 log "$RED" "Не удалось распарсить имя файла $fname"
 exit 1
 fi

 log "$BLUE" "Добавляем права на выполенение файла"
 chmod +x "$fname"

 mkdir -p "$root_install_path"

 log "$BLUE" "Копирую $fname в $root_install_path"
 cp $fname $root_install_path

 log "$BLUE" "Меняю имя $root_install_path/$fname -> $root_install_path/$newname"
 mv "$root_install_path/$fname" "$root_install_path/$newname"

 if [[ -n "$SUDO_USER" ]]; then
 mkdir -p "$user_install_path"
 log "$BLUE" "Перемещаю $fname в $user_install_path"
 mv $fname $user_install_path
 log "$BLUE" "Меняю имя $user_install_path/$fname -> $user_install_path/$newname"
 mv "$user_install_path/$fname" "$user_install_path/$newname"
 else
 log "$BLUE" "Удаляю $fname из $PWD"
 rm $fname
 fi

 fi
}

### ФУНКЦИЯ СОЗДАНИЯ ТИПОВЫХ main.tf ДЛЯ ПРОВАЙДЕРОВ

generate_tf_config() {
 local provider_type="$1" # evolution/advanced/vmware
 local tf_dir="$2" # путь к директории

 mkdir -p "$tf_dir" || { log "$RED" "Ошибка создания директории $tf_dir"; return 1; }
 log "$GREEN" "Создана директория $tf_dir"

 local MAIN_TF_PATH="$tf_dir/main.tf"
 local VARIABLES_TF_PATH="$tf_dir/variables.tf"
 local example docs

 case "$provider_type" in
 evolution)
 cat <<EOL > "$MAIN_TF_PATH"
terraform {
 required_providers {
 cloudru = {
 source = "cloud.ru/cloudru/cloud"
 }
 }
}

provider "cloudru" {
 project_id = var.project_id
 auth_key_id = var.auth_key_id
 auth_secret = var.auth_secret
 region = "ru-central-1"
 object_storage_tenant_id = ""

 endpoints = {
 iam_endpoint = "iam.api.cloud.ru:443"
 compute_endpoint = "compute.api.cloud.ru:443"
 baremetal_endpoint = "baremetal.api.cloud.ru:443"
 vpc_endpoint = "vpc.api.cloud.ru:443"
 magic_router_endpoint = "magic-router.api.cloud.ru"
 dns_endpoint = "dns.api.cloud.ru:443"
 nlb_endpoint = "nlb.api.cloud.ru"
 kafka_endpoint = "kafka.api.cloud.ru:443"
 redis_endpoint = "redis.api.cloud.ru:443"
 object_storage_endpoint = "https://s3.cloud.ru"
 }
}
EOL

 cat <<EOL > "$VARIABLES_TF_PATH"
variable "auth_key_id" {
 type = string
 sensitive = true
 default = "my_ak"
}

variable "auth_secret" {
 type = string
 sensitive = true
 default = "my_sk"
}

variable "project_id" {
 type = string
 sensitive = true
 default = "my_project_id"
}
EOL

 example="https://github.com/cloud-ru/evo-terraform/tree/main/reference"
 docs="https://cloud.ru/docs/terraform-evolution/ug/topics/terraform-evolution-overview.html"
 ;;
 advanced)
 cat <<EOL > "$MAIN_TF_PATH"
terraform {
 required_providers {
 sbercloud = {
 source = "cloud.ru/sbercloud-terraform/sbercloud"
 }
 }
}

provider "sbercloud" {
 region = "ru-moscow-1"
 access_key = var.access_key
 secret_key = var.secret_key
 rate_limit = 80
}

# ⚠️ Пример ресурса — закомментирован. Раскомментируйте, когда будете готовы.
# resource "sbercloud_identity_user" "test_user" {
#   name = "test_user"
#   description = "A user"
#   password = "password123!"
# }
EOL

 cat <<EOL > "$VARIABLES_TF_PATH"
variable "access_key" {
 type = string
 sensitive = true
 default = "my_ak"
}

variable "secret_key" {
 type = string
 sensitive = true
 default = "my_sk"
}
EOL

 example="https://github.com/sbercloud-terraform/terraform-provider-sbercloud/tree/master/docs"
 docs="https://cloud.ru/docs/terraform/ug/topics/overview__terraform-download.html"
 ;;
 vmware)
 cat <<EOL > "$MAIN_TF_PATH"
terraform {
 required_providers {
 vcd = {
 source = "tf.repo.sbc.space/vmware/vcd"
 version = ">=3.10.0"
 }
 }
 required_version = ">= 1.5.5"
}

provider "vcd" {
 auth_type       = "api_token"
 api_token       = var.vcd_api_token
 org             = var.org_name
 vdc             = var.org_vdc
 url             = var.vcd_url
 max_retry_timeout    = var.vcd_max_retry_timeout
 allow_unverified_ssl = var.vcd_allow_unverified_ssl
}

# Data sources для проверки связности (apply ничего не создаёт)
data "vcd_resource_list" "edge_gateways" {
 name          = "edge_gateways"
 resource_type = "vcd_nsxt_edgegateway"
}

data "vcd_resource_list" "catalogs" {
 name          = "catalogs"
 resource_type = "vcd_catalog"
}
EOL

 cat <<EOL > "$VARIABLES_TF_PATH"
variable "vcd_api_token" {
 type = string
 sensitive = true
 default = "my_vcd_api_token"
}

variable "org_name" {
 type = string
 sensitive = true
 default = "my_org_name"
}

variable "org_vdc" {
 type = string
 sensitive = true
 default = "my_org_vdc"
}

variable "vcd_url" {
 type = string
 sensitive = true
 default = "https://vcdXX-XX.cloud.ru/api"
}

variable "vcd_max_retry_timeout" {
 type = string
 default = "1800"
}

variable "vcd_allow_unverified_ssl" {
 type = string
 default = "true"
}
EOL
 example="https://github.com/yuknov-claw/VCD_TF_Samples"
 docs="https://cloud.ru/docs/terraform-vm/ug/index?source-platform=%D0%9E%D0%B1%D0%BB%D0%B0%D0%BA%D0%BE%20VMware"
 ;;
 *)
 log "$RED" "Неизвестный тип провайдера: $provider_type"
 return 1
 ;;
 esac

 log "$GREEN" "Файл main.tf создан в $MAIN_TF_PATH"
 log "$GREEN" "Файл variables.tf создан в $VARIABLES_TF_PATH"

 cd "$tf_dir"
 log "$BLUE" "Выполняю terraform init в директории $PWD"
 echo ""
 terraform init
 echo ""
 echo -e "${GREEN}[Инициализация terraform завершена]${NC}"
 echo -e "${BLUE}Заполните переменные в файле variables.tf и выполните terraform apply${NC}"
 echo -e "Примеры настройки: $example"
 echo -e "Документация: $docs"
 echo ""
}

### ГЛАВНЫЙ СЦЕНАРИЙ

# Шаг 1. Проверяем права root/sudo
log "$BLUE" "Проверка доступов"
if [[ "$EUID" -ne 0 ]]; then
 log "$RED" "Пожалуйста, запустите этот скрипт с правами root (через sudo или от имени root)!"
 exit 1
else
 log "$GREEN" "Статус: ОК"
fi

# Шаг 2. Проверяем подключение к cloud.ru
log "$BLUE" "Проверка доступа к сайту cloud.ru"
if ! check_internet; then
 exit 1
fi

# Шаг 3. Проверяем доступ к репозиториям
log "$BLUE" "Проверка доступа к сайтам репозиториев"
if ! check_repo_access; then
 exit 1
fi

# Шаг 4. Проверяем наличие необходимых утилит
log "$BLUE" "Проверка наличия wget, unzip, jq в системе"
install_packages curl wget unzip jq

# Установка Terraform (при необходимости)
echo ""
echo -e "${GREEN}[Установка terraform]${NC}"
echo ""
log "$BLUE" "Проверка наличия Terraform в системе"
if ! check_terraform_installed; then
 TERRAFORM_DOWNLOAD_URL='https://cloud.ru/docs/terraform/ug/topics/overview__terraform-download'
 get_links_loop "$TERRAFORM_DOWNLOAD_URL" "Terraform"
 DATAFILE="Terraform_links.txt"
 log "$BLUE" "Генерация меню для установки Terraform"
 menu "$DATAFILE"
else
 echo ""
 read -p "Показать доступные версии Terraform? [y/n]: " choice
 case "$choice" in
 [yY])
 echo ""
 TERRAFORM_DOWNLOAD_URL='https://cloud.ru/docs/terraform/ug/topics/overview__terraform-download'
 get_links_loop "$TERRAFORM_DOWNLOAD_URL" "Terraform"
 DATAFILE="Terraform_links.txt"
 log "$BLUE" "Генерация меню для установки Terraform"
 menu "$DATAFILE"
 ;;
 *)
 echo ""
 log "$BLUE" "Пропускаю установку Terraform"
 ;;
 esac
fi

# Установка провайдера Terraform по выбору пользователя
echo ""
echo -e "${GREEN}[Установка terraform provider]${NC}"
echo ""
log "$BLUE" "Генерация меню для установки Terraform provider"
echo ""
echo -e "${BLUE}Выберите платформу:${NC}"
echo "1. Evolution"
echo "2. Advanced"
echo "3. VMware (Cloud Director)"
echo "4. Выйти"
echo ""
read -rp "Ваш выбор: " choice

case "$choice" in
 1)
 echo ""
 TERRAFORM_DOWNLOAD_URL='https://api.github.com/repos/cloud-ru/evo-terraform/releases'
 get_links_loop "$TERRAFORM_DOWNLOAD_URL" "Terraform_provider_evolution"
 DATAFILE="Terraform_provider_evolution_links.txt"
 log "$BLUE" "Генерация меню"
 menu "$DATAFILE"
 generate_tf_config evolution "$PWD/tf_files/evo_tf"
 ;;
 2)
 echo ""
 TERRAFORM_DOWNLOAD_URL='https://api.github.com/repos/sbercloud-terraform/terraform-provider-sbercloud/releases'
 get_links_loop "$TERRAFORM_DOWNLOAD_URL" "Terraform_provider_advanced"
 DATAFILE="Terraform_provider_advanced_links.txt"
 log "$BLUE" "Генерация меню"
 menu "$DATAFILE"
 generate_tf_config advanced "$PWD/tf_files/adv_tf"
 ;;
 3)
 echo ""
 log "$BLUE" "VMware провайдер устанавливается через terraform init из зеркала tf.repo.sbc.space/vmware/vcd"
 echo ""
 generate_tf_config vmware "$PWD/tf_files/vmware_tf"
 ;;
 *)
 echo ""
 echo -e "${GREEN}Выход${NC}"
 exit 0
 ;;
esac

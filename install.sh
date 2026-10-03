#!/usr/bin/env bash
# ==============================================================================
#  Antigravity & AI Bypass for macOS (Belarus Edition) - Installer
#  One-line installer:
#  curl -fsSL https://raw.githubusercontent.com/anycastbss/antigravity-fix-dns/main/install.sh | bash
# ==============================================================================

set -euo pipefail

REPO_RAW_URL="${AGY_REPO_URL:-https://raw.githubusercontent.com/anycastbss/antigravity-fix-dns/main}"
INSTALL_DIR="${HOME}/.antigravity-fix-dns"
BIN_DIR="${HOME}/.local/bin"
BIN_LINK="${BIN_DIR}/agy-dns"

# Оформление
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

log_info()  { echo -e "${CYAN}ℹ [ИНФО]${RESET} $1"; }
log_ok()    { echo -e "${GREEN}✔ [УСПЕХ]${RESET} $1"; }
log_warn()  { echo -e "${YELLOW}▲ [ВНИМАНИЕ]${RESET} $1"; }
log_error() { echo -e "${RED}✖ [ОШИБКА]${RESET} $1"; }

echo -e "${CYAN}${BOLD}"
echo "=================================================================="
echo "   🚀 Antigravity & AI Bypass for macOS - Установщик"
echo "=================================================================="
echo -e "${RESET}"

# Проверка macOS
if [ "$(uname -s)" != "Darwin" ]; then
    log_error "Данный скрипт предназначен только для macOS."
    exit 1
fi

mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"

log_info "Загрузка компонентов проекта..."

# Если скрипт запущен локально из папки с репозиторием
SCRIPT_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -f "${SCRIPT_SOURCE_DIR}/antigravity-dns.sh" ]; then
    log_info "Копирование локальных файлов из ${SCRIPT_SOURCE_DIR}..."
    cp -f "${SCRIPT_SOURCE_DIR}/antigravity-dns.sh" "${INSTALL_DIR}/antigravity-dns.sh"
    cp -f "${SCRIPT_SOURCE_DIR}/Antigravity-XboxDNS.mobileconfig" "${INSTALL_DIR}/Antigravity-XboxDNS.mobileconfig"
else
    log_info "Загрузка с удаленного репозитория..."
    curl -fsSL "${REPO_RAW_URL}/antigravity-dns.sh" -o "${INSTALL_DIR}/antigravity-dns.sh"
    curl -fsSL "${REPO_RAW_URL}/Antigravity-XboxDNS.mobileconfig" -o "${INSTALL_DIR}/Antigravity-XboxDNS.mobileconfig"
fi

chmod +x "${INSTALL_DIR}/antigravity-dns.sh"

log_info "Создание системной команды 'agy-dns' в ${BIN_LINK}..."
ln -sf "${INSTALL_DIR}/antigravity-dns.sh" "$BIN_LINK"

# Проверка PATH
IN_PATH=false
case ":${PATH}:" in
    *":${BIN_DIR}:"*) IN_PATH=true ;;
esac

if [ "$IN_PATH" = false ]; then
    log_warn "${BIN_DIR} пока не добавлен в ваш PATH."
    SHELL_PROFILE="${HOME}/.zshrc"
    [ -n "${BASH_VERSION:-}" ] && SHELL_PROFILE="${HOME}/.bash_profile"
    
    echo "export PATH=\"${BIN_DIR}:\$PATH\"" >> "$SHELL_PROFILE"
    log_ok "Строка экспорта PATH автоматически добавлена в ${SHELL_PROFILE}"
    export PATH="${BIN_DIR}:${PATH}"
fi

echo ""
log_ok "Установка успешно завершена!"
echo -e "Теперь в любом терминале доступна команда: ${BOLD}agy-dns${RESET}"
echo ""
echo "Команды для быстрого старта:"
echo -e "  ${BOLD}agy-dns on${RESET}        - Включить защиту и обход (Smart DNS + agy-unlock)"
echo -e "  ${BOLD}agy-dns status${RESET}    - Проверить текущее состояние"
echo -e "  ${BOLD}agy-dns doctor${RESET}    - Запустить диагностику 6 уровней"
echo -e "  ${BOLD}agy-dns benchmark${RESET} - Замерить пинг серверов Smart DNS"
echo -e "  ${BOLD}agy-dns off${RESET}       - Вернуть стандартный интернет"
echo ""

# Автозапуск при интерактивном терминале
if [ -t 0 ]; then
    read -r -p "Хотите включить защиту прямо сейчас? (y/n): " ans
    if [[ "$ans" =~ ^[YyДд] ]]; then
        exec "$BIN_LINK" on
    fi
fi

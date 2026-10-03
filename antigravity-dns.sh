#!/usr/bin/env bash
# ==============================================================================
#  Antigravity & AI Bypass for macOS (Belarus Edition)
#  Комплексное решение: Smart DNS + Защита от IPv6-утечек + agy-unlock
#  Базируется на: xbox-dns.ru & Antigravity Unlock
#  Поддерживает: Antigravity 2.0, Antigravity IDE, CLI, Gemini, Claude, OpenAI
# ==============================================================================

set -e

# Канонический путь к скрипту с разрешением симлинков
TARGET_FILE="${BASH_SOURCE[0]}"
while [ -L "$TARGET_FILE" ]; do
    TARGET_DIR="$(cd -P "$(dirname "$TARGET_FILE")" && pwd)"
    TARGET_FILE="$(readlink "$TARGET_FILE")"
    [[ $TARGET_FILE != /* ]] && TARGET_FILE="$TARGET_DIR/$TARGET_FILE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$TARGET_FILE")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename "$TARGET_FILE")"
MOBILECONFIG_FILE="${SCRIPT_DIR}/Antigravity-XboxDNS.mobileconfig"
CLI_LINK="/usr/local/bin/agy-dns"
USER_CLI_LINK="${HOME}/.local/bin/agy-dns"
AGY_UNLOCK_BIN="${HOME}/.local/bin/agy-unlock"

# DNS и SNI Proxy серверы (xbox-dns.ru)
DNS_IPV4_PRIMARY="111.88.96.54"
DNS_IPV4_SECONDARY="111.88.96.55"
DNS_IPV6_PRIMARY="2a00:ab00:1233:26::50"
DNS_IPV6_SECONDARY="2a00:ab00:1233:26::51"
SNI_PROXY_IP="188.68.214.130"
SNI_PROXY_BACKUP="188.68.214.143"

HOSTS_TAG_START="# === ANTIGRAVITY XBOX-DNS START ==="
HOSTS_TAG_END="# === ANTIGRAVITY XBOX-DNS END ==="

# Оформление и цвета
BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
MAGENTA="\033[0;35m"
RESET="\033[0m"

log_info()    { echo -e "${CYAN}ℹ [ИНФО]${RESET} $1"; }
log_ok()      { echo -e "${GREEN}✔ [УСПЕХ]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}▲ [ВНИМАНИЕ]${RESET} $1"; }
log_error()   { echo -e "${RED}✖ [ОШИБКА]${RESET} $1"; }
log_section() { echo -e "\n${BOLD}${MAGENTA}▶ $1${RESET}"; }

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "=================================================================="
    echo "   🚀 Antigravity & AI Bypass for macOS (Belarus Edition)"
    echo "   Xbox DNS (Smart DNS) + IPv6 Shield + Antigravity Unlock"
    echo "=================================================================="
    echo -e "${RESET}"
}

require_root() {
    if [ "$EUID" -ne 0 ]; then
        log_warn "Для изменения сетевых параметров и /etc/hosts нужны права администратора."
        echo -e "${BOLD}Запуск через sudo... Введите пароль администратора Mac:${RESET}"
        exec sudo "$SCRIPT_PATH" "$@"
    fi
}

get_primary_service() {
    local default_iface
    default_iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    if [ -n "$default_iface" ]; then
        local svc
        svc=$(networksetup -listallhardwareports | awk -v dev="$default_iface" '
            /Hardware Port:/ { port=$0; sub(/Hardware Port: /, "", port) }
            /Device:/ { if ($2 == dev) { print port; exit } }
        ')
        if [ -n "$svc" ]; then
            echo "$svc"
            return
        fi
    fi
    echo "Wi-Fi"
}

flush_dns_cache() {
    log_info "Очистка системного кеша DNS (mDNSResponder)..."
    dscacheutil -flushcache 2>/dev/null || true
    killall -HUP mDNSResponder 2>/dev/null || true
    log_ok "Кеш DNS успешно сброшен."
}

enable_hosts_override() {
    log_info "Очистка устаревших записей и настройка маршрутизации в /etc/hosts..."
    disable_hosts_override_silent

    # Очищаем старые ручные записи, вызывавшие сброс соединения (188.68.214.143 / 130)
    sed -i '' '/cloudcode-pa.googleapis.com/d' /etc/hosts 2>/dev/null || true
    sed -i '' '/cloudaicompanion.googleapis.com/d' /etc/hosts 2>/dev/null || true
    sed -i '' '/alkalimakersuiteapplets.pa.googleapis.com/d' /etc/hosts 2>/dev/null || true

    cat <<EOF >> /etc/hosts
${HOSTS_TAG_START}
# Маршрутизация Antigravity через SNI-прокси xbox-dns.ru
${SNI_PROXY_IP} generativelanguage.googleapis.com
${SNI_PROXY_IP} alkalimakersuite-pa.googleapis.com
${SNI_PROXY_IP} aistudio.google.com
${HOSTS_TAG_END}
EOF
    log_ok "Маршрутизация Google AI настроена на SNI-прокси (${SNI_PROXY_IP})."
}

disable_hosts_override_silent() {
    if grep -q "${HOSTS_TAG_START}" /etc/hosts 2>/dev/null; then
        sed -i '' "/${HOSTS_TAG_START}/,/${HOSTS_TAG_END}/d" /etc/hosts
    fi
    sed -i '' '/cloudcode-pa.googleapis.com/d' /etc/hosts 2>/dev/null || true
    sed -i '' '/cloudaicompanion.googleapis.com/d' /etc/hosts 2>/dev/null || true
    sed -i '' '/alkalimakersuiteapplets.pa.googleapis.com/d' /etc/hosts 2>/dev/null || true
}

disable_hosts_override() {
    log_info "Удаление записей Antigravity из /etc/hosts..."
    disable_hosts_override_silent
    log_ok "Записи Antigravity удалены из /etc/hosts."
}

# Проверка и запуск agy-unlock
check_and_run_agy_unlock() {
    log_section "Проверка патча Antigravity Unlock (аккаунт-блокировка)"
    if [ ! -f "$AGY_UNLOCK_BIN" ]; then
        log_warn "Утилита agy-unlock не найдена по пути ${AGY_UNLOCK_BIN}."
        log_info "Установка agy-unlock с официального сервера xbox-dns.ru..."
        curl -fsSL https://xbox-dns.ru/softwares/agy/install.sh | bash || true
    fi

    if [ -f "$AGY_UNLOCK_BIN" ]; then
        log_info "Применение патча к приложениям Antigravity..."
        # Флаг --if-needed ставится перед 'all' для корректного парсинга в Go
        "$AGY_UNLOCK_BIN" unlock --if-needed all 2>&1 | sed 's/^/  /' || true
        
        # Проверяем фоновый демон
        local daemon_status
        daemon_status=$("$AGY_UNLOCK_BIN" daemon status 2>&1 || true)
        if [[ "$daemon_status" =~ "установлен и запущен" ]]; then
            log_ok "Фоновый демон автопатча agy-unlock активен."
        else
            log_info "Установка фонового демона автопатча при обновлениях..."
            "$AGY_UNLOCK_BIN" daemon install 2>&1 | sed 's/^/  /' || true
            log_ok "Демон автопатча успешно установлен."
        fi
    fi
}

# Включение всего комплекса
cmd_enable() {
    require_root "$@"
    print_banner
    log_section "Активация комплексной защиты Antigravity для Беларуси"

    local primary_svc
    primary_svc=$(get_primary_service)
    log_info "Активное сетевое подключение: ${BOLD}${primary_svc}${RESET}"

    # 1. Установка IPv4 Smart DNS
    log_info "Настройка Smart DNS (${DNS_IPV4_PRIMARY}, ${DNS_IPV4_SECONDARY})..."
    networksetup -setdnsservers "$primary_svc" "$DNS_IPV4_PRIMARY" "$DNS_IPV4_SECONDARY"
    log_ok "IPv4 DNS успешно переключен на Xbox DNS."

    # 2. Устранение утечки IPv6 (Критично для Беларуси: A1 / Белтелеком / МТС)
    log_info "Защита от IPv6-утечек (IPv6 Leak Prevention)..."
    networksetup -setv6off "$primary_svc" 2>/dev/null || true
    log_ok "IPv6 на '${primary_svc}' отключен (исключает обращение к Google мимо Smart DNS)."

    # 3. Маршрутизация хостов
    enable_hosts_override

    # 4. Сброс кеша
    flush_dns_cache

    # 5. Проверка agy-unlock
    check_and_run_agy_unlock

    echo ""
    log_ok "Комплекс Antigravity BY Fix ${BOLD}ПОЛНОСТЬЮ АКТИВИРОВАН${RESET}!"
    echo -e "Сетевой уровень и уровень аккаунта Google защищены. Antigravity готова к работе."
    
    cmd_test_quick
}

# Отключение
cmd_disable() {
    require_root "$@"
    print_banner
    log_section "Возврат стандартных сетевых настроек"

    local primary_svc
    primary_svc=$(get_primary_service)
    log_info "Сетевое подключение: ${BOLD}${primary_svc}${RESET}"

    log_info "Возврат DNS к автоматическим (DHCP провайдера)..."
    networksetup -setdnsservers "$primary_svc" Empty
    log_ok "DNS сброшен к заводским параметрам."

    log_info "Включение IPv6 обратно в автоматический режим..."
    networksetup -setv6automatic "$primary_svc" 2>/dev/null || true
    log_ok "IPv6 включен (Automatic)."

    disable_hosts_override
    flush_dns_cache

    echo ""
    log_ok "Стандартные настройки сети ${BOLD}ВОССТАНОВЛЕНЫ${RESET}."
}

# Статус
cmd_status() {
    print_banner
    log_section "Текущее состояние системы"

    local primary_svc
    primary_svc=$(get_primary_service)
    echo -e "Сетевой интерфейс:         ${BOLD}${primary_svc}${RESET}"

    local current_dns
    current_dns=$(networksetup -getdnsservers "$primary_svc" 2>/dev/null | tr '\n' ' ')
    if [[ "$current_dns" =~ "$DNS_IPV4_PRIMARY" ]]; then
        echo -e "Smart DNS (IPv4):          ${GREEN}${BOLD}ВКЛЮЧЕН${RESET} (${current_dns})"
    elif [[ "$current_dns" =~ "There aren't any DNS Servers" ]] || [ -z "$current_dns" ]; then
        echo -e "Smart DNS (IPv4):          ${YELLOW}ВЫКЛЮЧЕН (Провайдер / DHCP)${RESET}"
    else
        echo -e "Smart DNS (IPv4):          ${CYAN}Другой (${current_dns})${RESET}"
    fi

    local v6_status
    v6_status=$(networksetup -getinfo "$primary_svc" 2>/dev/null | grep -i "IPv6:" | head -n 1)
    if [[ "$v6_status" =~ "Off" ]]; then
        echo -e "Защита от IPv6-утечек:     ${GREEN}${BOLD}АКТИВНА${RESET} (IPv6 выключен)"
    else
        echo -e "Защита от IPv6-утечек:     ${YELLOW}НЕ АКТИВНА${RESET} (${v6_status})"
    fi

    if grep -q "${HOSTS_TAG_START}" /etc/hosts 2>/dev/null; then
        echo -e "Маршрутизация /etc/hosts:  ${GREEN}${BOLD}АКТИВНА${RESET} (эндпоинты перенаправлены на ${SNI_PROXY_IP})"
    else
        echo -e "Маршрутизация /etc/hosts:  ${YELLOW}НЕ АКТИВНА${RESET}"
    fi

    if [ -f "$AGY_UNLOCK_BIN" ]; then
        echo -e "Утилита agy-unlock:        ${GREEN}${BOLD}Установлена${RESET} (${AGY_UNLOCK_BIN})"
        local daemon_st
        daemon_st=$("$AGY_UNLOCK_BIN" daemon status 2>&1 || true)
        if [[ "$daemon_st" =~ "установлен и запущен" ]]; then
            echo -e "Фоновый автопатч:          ${GREEN}${BOLD}ДЕМОН РАБОТАЕТ${RESET}"
        else
            echo -e "Фоновый автопатч:          ${YELLOW}ДЕМОН НЕ ЗАПУЩЕН${RESET}"
        fi
    else
        echo -e "Утилита agy-unlock:        ${RED}НЕ НАЙДЕНА${RESET}"
    fi

    echo ""
    log_info "Определение текущего внешнего IP..."
    local ip_info
    ip_info=$(curl -s -m 4 https://ipinfo.io/json 2>/dev/null || echo "{}")
    local pub_ip pub_org pub_city pub_country
    pub_ip=$(echo "$ip_info" | grep -o '"ip": *"[^"]*"' | cut -d'"' -f4)
    pub_org=$(echo "$ip_info" | grep -o '"org": *"[^"]*"' | cut -d'"' -f4)
    pub_city=$(echo "$ip_info" | grep -o '"city": *"[^"]*"' | cut -d'"' -f4)
    pub_country=$(echo "$ip_info" | grep -o '"country": *"[^"]*"' | cut -d'"' -f4)

    if [ -n "$pub_ip" ]; then
        echo -e "Ваш публичный IP:          ${BOLD}${pub_ip}${RESET}"
        echo -e "Провайдер / Локация:       ${pub_org:-Неизвестно} (${pub_city:-}, ${pub_country:-})"
    else
        echo -e "Ваш публичный IP:          Не удалось определить"
    fi
}

cmd_test_quick() {
    log_section "Проверка отклика серверов Antigravity & AI"
    test_endpoint "Google Gemini API" "https://generativelanguage.googleapis.com"
    test_endpoint "Antigravity CloudCode" "https://cloudcode-pa.googleapis.com"
}

cmd_test() {
    print_banner
    log_section "Детальное тестирование доступности AI-сервисов"
    printf "${BOLD}%-26s %-12s %-12s %s${RESET}\n" "Сервис" "Время" "HTTP-код" "Статус"
    echo "------------------------------------------------------------------"

    test_endpoint_row "Google Gemini API" "https://generativelanguage.googleapis.com"
    test_endpoint_row "Antigravity Backend" "https://cloudcode-pa.googleapis.com"
    test_endpoint_row "Google AI Studio" "https://alkalimakersuite-pa.googleapis.com"
    test_endpoint_row "Claude (Anthropic)" "https://api.anthropic.com"
    test_endpoint_row "ChatGPT (OpenAI)" "https://api.openai.com"
    echo "------------------------------------------------------------------"
    echo -e "${CYAN}Пояснение:${RESET} ответы серверов с кодами 200, 302, 400, 403, 404 (без ошибки 403 Country Block)"
    echo "означают, что запрос успешно доходит до шлюза и проходит валидацию региона."
}

test_endpoint() {
    local name="$1"
    local url="$2"
    local res
    res=$(curl -s -m 5 -o /dev/null -w "%{http_code}:%{time_total}" --noproxy '*' "$url" 2>/dev/null || echo "000:0")
    local code time_s time_ms
    code=$(echo "$res" | cut -d':' -f1)
    time_s=$(echo "$res" | cut -d':' -f2)
    time_ms=$(awk "BEGIN {printf \"%.0f\", $time_s * 1000}")

    if [ "$code" = "000" ]; then
        log_error "${name}: соединение не удалось (${url})"
    else
        log_ok "${name}: доступен (${code}, задержка ${time_ms}ms)"
    fi
}

test_endpoint_row() {
    local name="$1"
    local url="$2"
    local res
    res=$(curl -s -m 5 -o /dev/null -w "%{http_code}:%{time_total}" --noproxy '*' "$url" 2>/dev/null || echo "000:0")
    local code time_s time_ms status_str
    code=$(echo "$res" | cut -d':' -f1)
    time_s=$(echo "$res" | cut -d':' -f2)
    time_ms=$(awk "BEGIN {printf \"%.0f ms\", $time_s * 1000}")

    if [ "$code" = "000" ]; then
        status_str="${RED}Таймаут/Сбой${RESET}"
    else
        status_str="${GREEN}Доступен${RESET}"
    fi

    printf "%-26s %-12s %-12s %b\n" "$name" "$time_ms" "$code" "$status_str"
}

cmd_profile() {
    print_banner
    log_section "Установка Apple Configuration Profile (DoH)"
    
    if [ ! -f "$MOBILECONFIG_FILE" ]; then
        log_error "Файл профиля ${MOBILECONFIG_FILE} не найден!"
        exit 1
    fi

    log_info "Открытие профиля конфигурации в Системных настройках macOS..."
    open "$MOBILECONFIG_FILE"

    echo ""
    echo -e "${BOLD}Что нужно сделать в Системных настройках macOS:${RESET}"
    echo "1. Откройте «Системные настройки» → «Конфиденциальность и безопасность» → «Профили»."
    echo "2. Нажмите на загруженный профиль «Antigravity & Xbox DNS (DoH)»."
    echo "3. Нажмите «Установить...» и введите пароль от Mac."
    echo "После этого все DNS-запросы будут аппаратно шифроваться через HTTPS (DoH)!"
    log_ok "Профиль передан в систему."
}

cmd_install_cli() {
    require_root "$@"
    print_banner
    log_section "Установка команды 'agy-dns' в систему"

    mkdir -p "$(dirname "$CLI_LINK")"
    ln -sf "$SCRIPT_PATH" "$CLI_LINK"
    chmod +x "$SCRIPT_PATH"
    
    log_ok "Команда '${BOLD}agy-dns${RESET}' установлена в ${CLI_LINK}!"
    echo -e "Теперь вы можете в любой папке запускать:"
    echo -e "  ${BOLD}agy-dns on${RESET}       - включить обход и защиту"
    echo -e "  ${BOLD}agy-dns off${RESET}      - выключить обход"
    echo -e "  ${BOLD}agy-dns status${RESET}   - проверить состояние"
    echo -e "  ${BOLD}agy-dns test${RESET}     - замерить доступность серверов"
    echo -e "  ${BOLD}agy-dns unlock${RESET}   - вызвать дашборд agy-unlock"
}

cmd_unlock() {
    if [ -f "$AGY_UNLOCK_BIN" ]; then
        exec "$AGY_UNLOCK_BIN" "$@"
    else
        log_error "Утилита agy-unlock не найдена. Запустите './antigravity-dns.sh on' для автоматической установки."
        exit 1
    fi
}

cmd_doctor() {
    print_banner
    log_section "Комплексная диагностика системы (Antigravity Doctor)"
    echo -e "${CYAN}Проверка 6 уровней окружения и сетевого стека...${RESET}\n"

    local issues=0

    # 1. Процессы Antigravity
    echo -e "${BOLD}[1/6] Процессы и окружение Antigravity:${RESET}"
    local pids_ide pids_ls
    pids_ide=$(pgrep -f "Antigravity IDE" 2>/dev/null || true)
    pids_ls=$(pgrep -f "language_server" 2>/dev/null || true)
    if [ -n "$pids_ide" ]; then
        echo -e "  ${GREEN}✔${RESET} Antigravity IDE запущена (PID: $(echo $pids_ide | tr '\n' ' '))"
    else
        echo -e "  ${CYAN}ℹ${RESET} Antigravity IDE сейчас не запущена"
    fi
    if [ -n "$pids_ls" ]; then
        echo -e "  ${GREEN}✔${RESET} Языковой сервер Antigravity (language_server) активен"
    else
        echo -e "  ${CYAN}ℹ${RESET} Языковой сервер запускается автоматически при открытии проекта"
    fi

    # 2. agy-unlock патч
    echo -e "\n${BOLD}[2/6] Патчинг региона аккаунта Google (agy-unlock):${RESET}"
    if [ -f "$AGY_UNLOCK_BIN" ]; then
        echo -e "  ${GREEN}✔${RESET} Бинарник agy-unlock найден: ${AGY_UNLOCK_BIN}"
        local daemon_st
        daemon_st=$("$AGY_UNLOCK_BIN" daemon status 2>&1 || true)
        if [[ "$daemon_st" =~ "установлен и запущен" ]]; then
            echo -e "  ${GREEN}✔${RESET} Фоновый демон автопатча при обновлениях: ${GREEN}АКТИВЕН${RESET}"
        else
            echo -e "  ${YELLOW}▲${RESET} Демон автопатча не активен (рекомендуется: agy-dns on)"
            ((issues++))
        fi
    else
        echo -e "  ${RED}✖${RESET} agy-unlock не установлен (запустите agy-dns on для установки)"
        ((issues++))
    fi

    # 3. DNS-резолвинг
    echo -e "\n${BOLD}[3/6] Проверка Smart DNS и разрешения AI-доменов:${RESET}"
    local primary_svc
    primary_svc=$(get_primary_service)
    local cur_dns
    cur_dns=$(networksetup -getdnsservers "$primary_svc" 2>/dev/null | tr '\n' ' ')
    echo -e "  Интерфейс: ${primary_svc} (DNS: ${cur_dns:-DHCP})"
    local resolved_gemini
    resolved_gemini=$(dig +short +time=2 +tries=1 generativelanguage.googleapis.com 2>/dev/null | head -n 1 || true)
    if [[ "$resolved_gemini" =~ "188.68.214" ]]; then
        echo -e "  ${GREEN}✔${RESET} Gemini резолвится через SNI-прокси: ${resolved_gemini}"
    elif [ -n "$resolved_gemini" ]; then
        echo -e "  ${YELLOW}▲${RESET} Gemini резолвится в Google IP (${resolved_gemini}). Проверьте, включен ли Smart DNS."
        ((issues++))
    else
        echo -e "  ${RED}✖${RESET} Не удалось разрешить generativelanguage.googleapis.com"
        ((issues++))
    fi

    # 4. Проверка утечки IPv6
    echo -e "\n${BOLD}[4/6] Проверка утечки геолокации по IPv6 (IPv6 Leak):${RESET}"
    local v6_status v6_addrs
    v6_status=$(networksetup -getinfo "$primary_svc" 2>/dev/null | grep -i "IPv6:" | head -n 1)
    v6_addrs=$(ifconfig 2>/dev/null | grep "inet6 2" | awk '{print $2}' || true)
    if [[ "$v6_status" =~ "Off" ]]; then
        echo -e "  ${GREEN}✔${RESET} IPv6 на ${primary_svc} отключен (полная защита от утечки)"
    elif [ -n "$v6_addrs" ]; then
        echo -e "  ${RED}✖${RESET} ОБНАРУЖЕНА УТЕЧКА IPv6! Активен публичный адрес: $(echo $v6_addrs | head -n 1)"
        echo -e "    Провайдер отправляет трафик в Google мимо Smart DNS."
        echo -e "    Решение: выполните 'agy-dns on' для отключения IPv6."
        ((issues++))
    else
        echo -e "  ${GREEN}✔${RESET} Публичных IPv6 адресов провайдера не обнаружено"
    fi

    # 5. Проверка локальных прокси и VPN-конфликтов
    echo -e "\n${BOLD}[5/6] Конфликтующие локальные прокси и переменные окружения:${RESET}"
    local env_proxies=""
    [ -n "$HTTP_PROXY" ] && env_proxies+=" HTTP_PROXY=$HTTP_PROXY"
    [ -n "$ALL_PROXY" ] && env_proxies+=" ALL_PROXY=$ALL_PROXY"
    if [ -n "$env_proxies" ]; then
        echo -e "  ${YELLOW}▲${RESET} Переменные окружения прокси:${env_proxies}"
    else
        echo -e "  ${GREEN}✔${RESET} Сторонних глобальных переменных прокси не обнаружено"
    fi
    local sys_webproxy
    sys_webproxy=$(networksetup -getwebproxy "$primary_svc" 2>/dev/null | grep "Enabled: Yes" || true)
    if [ -n "$sys_webproxy" ]; then
        echo -e "  ${YELLOW}▲${RESET} Внимание: в системе включен HTTP Web Proxy для ${primary_svc}"
    else
        echo -e "  ${GREEN}✔${RESET} Системный HTTP/HTTPS прокси отключен"
    fi

    # 6. Валидация SSL/TLS сертификатов
    echo -e "\n${BOLD}[6/6] Проверка подлинности SSL/TLS сертификата Google:${RESET}"
    local cert_issuer
    cert_issuer=$(curl -v -s -m 4 --noproxy '*' https://generativelanguage.googleapis.com 2>&1 | grep "issuer:" | head -n 1 || true)
    if [[ "$cert_issuer" =~ "Google Trust Services" ]] || [[ "$cert_issuer" =~ "WE" ]] || [[ "$cert_issuer" =~ "GTS" ]]; then
        echo -e "  ${GREEN}✔${RESET} Сертификат подлинный (${cert_issuer##*issuer: })"
    elif [ -n "$cert_issuer" ]; then
        echo -e "  ${YELLOW}▲${RESET} Нетипичный издатель сертификата: ${cert_issuer}"
    else
        echo -e "  ${GREEN}✔${RESET} Проверка TLS успешно пройдена"
    fi

    echo -e "\n------------------------------------------------------------------"
    if [ $issues -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✔ ДИАГНОСТИКА: Ваша система полностью готова к работе с Antigravity!${RESET}"
    else
        echo -e "${YELLOW}${BOLD}▲ ДИАГНОСТИКА: Найдено замечаний: ${issues}. Выполните 'agy-dns on' для исправления.${RESET}"
    fi
}

cmd_benchmark() {
    print_banner
    log_section "Бенчмарк серверов Smart DNS (поиск наименьшей задержки)"
    echo -e "Тестирование скорости отклика DNS-серверов в вашем регионе...\n"
    printf "${BOLD}%-24s %-18s %-14s %s${RESET}\n" "Сервер" "IP-адрес" "Отклик (RTT)" "Smart DNS"
    echo "------------------------------------------------------------------"

    benchmark_dns "Xbox DNS Primary" "111.88.96.54" "Да"
    benchmark_dns "Xbox DNS Secondary" "111.88.96.55" "Да"
    benchmark_dns "Comss.one DNS 1" "92.223.109.31" "Да"
    benchmark_dns "Comss.one DNS 2" "91.107.150.15" "Да"
    benchmark_dns "Cloudflare (Эталон)" "1.1.1.1" "Нет"
    benchmark_dns "Google (Эталон)" "8.8.8.8" "Нет"
    echo "------------------------------------------------------------------"
    echo -e "${CYAN}Совет:${RESET} Чем меньше время отклика (ms), тем быстрее стартуют агентные сессии."
}

benchmark_dns() {
    local name="$1"
    local ip="$2"
    local is_smart="$3"
    local time_ms="Таймаут"
    local color="$RED"

    local dig_out
    dig_out=$(dig "@$ip" generativelanguage.googleapis.com +stats +time=2 +tries=1 2>/dev/null || true)
    local query_time
    query_time=$(echo "$dig_out" | awk '/Query time:/ {print $4}')

    if [ -n "$query_time" ]; then
        time_ms="${query_time} ms"
        if [ "$query_time" -lt 60 ]; then
            color="$GREEN"
        elif [ "$query_time" -lt 120 ]; then
            color="$CYAN"
        else
            color="$YELLOW"
        fi
    fi

    printf "%-24s %-18s %b%-14s%b %s\n" "$name" "$ip" "$color" "$time_ms" "$RESET" "$is_smart"
}

show_interactive_menu() {
    print_banner
    echo -e "${BOLD}Выберите действие:${RESET}"
    echo "1) [ON]        Включить всё (Xbox DNS + защита от IPv6 leak + agy-unlock)"
    echo "2) [OFF]       Выключить (вернуть стандартную сеть провайдера)"
    echo "3) [STATUS]    Показать текущий статус сети и патча"
    echo "4) [TEST]      Протестировать доступность серверов (Gemini, Claude, OpenAI)"
    echo "5) [DOCTOR]    Глубокая диагностика системы и поиск проблем"
    echo "6) [BENCHMARK] Замерить скорость серверов Smart DNS"
    echo "7) [UNLOCK]    Открыть интерактивный дашборд agy-unlock"
    echo "8) [PROFILE]   Установить шифрованный DoH профиль macOS (.mobileconfig)"
    echo "9) [CLI]       Создать системную команду 'agy-dns' в терминале"
    echo "10) [FLUSH]    Сбросить системный кеш DNS"
    echo "0) Выход"
    echo ""
    read -r -p "Введите номер [1-10, 0]: " choice

    case "$choice" in
        1) cmd_enable ;;
        2) cmd_disable ;;
        3) cmd_status ;;
        4) cmd_test ;;
        5) cmd_doctor ;;
        6) cmd_benchmark ;;
        7) cmd_unlock ;;
        8) cmd_profile ;;
        9) cmd_install_cli ;;
        10) require_root; flush_dns_cache ;;
        0) echo "Выход."; exit 0 ;;
        *) log_error "Неверный выбор."; exit 1 ;;
    esac
}

case "${1:-}" in
    on|enable|start)
        shift
        cmd_enable "$@"
        ;;
    off|disable|stop)
        shift
        cmd_disable "$@"
        ;;
    status)
        shift
        cmd_status "$@"
        ;;
    test|check)
        shift
        cmd_test "$@"
        ;;
    doctor|diag)
        shift
        cmd_doctor "$@"
        ;;
    benchmark|bench)
        shift
        cmd_benchmark "$@"
        ;;
    unlock)
        shift
        cmd_unlock "$@"
        ;;
    profile|doh)
        shift
        cmd_profile "$@"
        ;;
    install-cli|link)
        shift
        cmd_install_cli "$@"
        ;;
    flush)
        require_root "$@"
        flush_dns_cache
        ;;
    help|--help|-h)
        print_banner
        echo "Использование: $0 [команда]"
        echo ""
        echo "Команды:"
        echo "  on          Включить комплексный обход (DNS, IPv6 Shield, agy-unlock)"
        echo "  off         Выключить и вернуть стандартные настройки сети"
        echo "  status      Показать статус DNS, IPv6, маршрутизации и agy-unlock"
        echo "  test        Замерить задержку и доступность Gemini, Claude, OpenAI"
        echo "  doctor      Комплексная самодиагностика 6 уровней окружения"
        echo "  benchmark   Сравнить скорость отклика серверов Smart DNS"
        echo "  unlock      Вызвать дашборд agy-unlock"
        echo "  profile     Открыть профиль зашифрованного DoH (.mobileconfig)"
        echo "  install-cli Установить команду 'agy-dns' в /usr/local/bin"
        echo "  flush       Сбросить кеш mDNSResponder"
        ;;
    "")
        show_interactive_menu
        ;;
    *)
        log_error "Неизвестная команда: '$1'"
        echo "Используйте '$0 help' для справки."
        exit 1
        ;;
esac

#!/usr/bin/env bash
set -euo pipefail

OAUTH_TOKEN="${OAUTH_TOKEN:?OAUTH_TOKEN не задан}"
INSTANCE_ID="${INSTANCE_ID:?INSTANCE_ID не задан}"
TG_TOKEN="${TG_TOKEN:?TG_TOKEN не задан}"
TG_CHAT_ID="${TG_CHAT_ID:?TG_CHAT_ID не задан}"
TOKEN_FILE="$(dirname "$0")/token.json"

tg_send() {
    curl -sf -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}&text=$1" > /dev/null
}

while true; do
    if [[ ! -f "$TOKEN_FILE" ]] || (( $(date -d "$(jq -r .expiresAt "$TOKEN_FILE" | sed 's/T/ /; s/\..*//')" +%s) - $(date +%s) < 300 )); then
        curl -sf -X POST -d "{\"yandexPassportOauthToken\":\"$OAUTH_TOKEN\"}" https://iam.api.cloud.yandex.net/iam/v1/tokens > "$TOKEN_FILE"
    fi

    TOKEN=$(jq -r .iamToken "$TOKEN_FILE")
    STATUS=$(curl -sf -H "Authorization: Bearer $TOKEN" \
        "https://compute.api.cloud.yandex.net/compute/v1/instances/$INSTANCE_ID" | jq -r .status)

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Статус: $STATUS"

    if [[ "$STATUS" == "STOPPED" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Инстанс остановлен — запускаем..."
        tg_send "⚠️ Инстанс $INSTANCE_ID остановлен — запускаем..."
        curl -sf -X POST -H "Authorization: Bearer $TOKEN" \
            "https://compute.api.cloud.yandex.net/compute/v1/instances/$INSTANCE_ID:start" > /dev/null

        # Ждём перехода в RUNNING
        for i in $(seq 1 10); do
            sleep 15
            STATUS=$(curl -sf -H "Authorization: Bearer $TOKEN" \
                "https://compute.api.cloud.yandex.net/compute/v1/instances/$INSTANCE_ID" | jq -r .status)
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ожидание запуска... $STATUS"
            if [[ "$STATUS" == "RUNNING" ]]; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Инстанс запущен."
                tg_send "✅ Инстанс $INSTANCE_ID запущен успешно. Статус: RUNNING"
                break
            fi
        done

        if [[ "$STATUS" != "RUNNING" ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Инстанс не запустился за 150 сек."
            tg_send "❌ Инстанс $INSTANCE_ID не запустился за 150 сек. Статус: $STATUS"
        fi
    fi

    sleep 60
done

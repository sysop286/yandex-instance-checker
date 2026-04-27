FROM alpine:3.19

RUN apk add --no-cache bash curl jq tzdata

COPY check_instance.sh /app/check_instance.sh
RUN chmod +x /app/check_instance.sh

ENTRYPOINT ["/app/check_instance.sh"]

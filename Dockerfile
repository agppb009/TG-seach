# tgsearch for Render / any root container PaaS
# 无 session 时在 $PORT(默认80) 展示 Telegram 扫码登录页（JS 本地渲染二维码），
# 登录后自动启动搜索服务
FROM alpine:3.19

RUN echo "https://mirrors.aliyun.com/alpine/v3.19/main" > /etc/apk/repositories && \
    echo "https://mirrors.aliyun.com/alpine/v3.19/community" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache bash busybox-extras socat zlib readline ncurses-libs coreutils && \
    rm -rf /var/cache/apk/*

WORKDIR /app

COPY tgsearch.x86_64 /app/tgsearch.x86_64
COPY run.sh /app/run.sh
COPY qrcode.min.js /app/qrcode.min.js

RUN chmod +x /app/tgsearch.x86_64 /app/run.sh

ENTRYPOINT ["/app/run.sh"]

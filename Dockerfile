# tgsearch for Koyeb / any root container PaaS
# 基于社区镜像 fishforks/tgimg 的 tgsearch 二进制改造：
# 无 session 时在 80 端口展示 Telegram 扫码登录页，登录后自动启动搜索服务
FROM alpine:3.19

RUN echo "https://mirrors.aliyun.com/alpine/v3.19/main" > /etc/apk/repositories && \
    echo "https://mirrors.aliyun.com/alpine/v3.19/community" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache libqrencode-tools bash zlib readline ncurses-libs coreutils && \
    rm -rf /var/cache/apk/*

WORKDIR /app

COPY tgsearch.x86_64 /app/tgsearch.x86_64
COPY run.sh /app/run.sh

RUN chmod +x /app/tgsearch.x86_64 /app/run.sh

ENTRYPOINT ["/app/run.sh"]

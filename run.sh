#!/bin/bash
# tgsearch 最终版
# 流程：session 注入 -> 立即占住公网端口(防 Render 端口检测重启) -> 启动搜索服务 -> 就绪后切换
cd /app
PORT_NUM="${PORT:-80}"

if [ -n "$API_SESSION_V1" ] && [ -n "$API_SESSION" ]; then
    echo "$API_SESSION_V1" > v1.txt
    echo "$API_SESSION" > v2.txt
    echo "[run] 已从环境变量写入 session 文件"
fi

if [ ! -f v1.txt ] || [ ! -f v2.txt ]; then
    echo "[run] 缺少 session！请到 Render Environment 配置 API_SESSION_V1 和 API_SESSION"
    exit 1
fi

export API_SESSION_V1="$(cat v1.txt)"
export API_SESSION="$(cat v2.txt)"

# 1) 立即占住公网端口（Render 部署秒通过端口检测，不会中途重启）
mkdir -p www
echo "tgsearch starting..." > www/index.html
busybox httpd -f -p "$PORT_NUM" -h /app/www >/dev/null 2>&1 &
HTTPD_PID=$!
echo "[run] 占位端口 $PORT_NUM 已开放"

# 2) 启动搜索服务（监听端口在 10199 / 18080 之间随启动变化）
./tgsearch.x86_64 -I 2>&1 &
SVC_PID=$!

# 3) 等搜索服务监听（最多 180 秒）
SVC_PORT=""
for i in $(seq 1 90); do
    if netstat -tln 2>/dev/null | grep -qE ':10199 '; then SVC_PORT=10199; break; fi
    if netstat -tln 2>/dev/null | grep -qE ':18080 '; then SVC_PORT=18080; break; fi
    sleep 2
done

if [ -z "$SVC_PORT" ]; then
    echo "[run] 未检测到搜索服务端口，保持占位页运行"
    wait "$SVC_PID"
    exit 0
fi

echo "[run] 搜索服务就绪（内部端口 $SVC_PORT），公网 $PORT_NUM 切换过去 ..."
kill "$HTTPD_PID" 2>/dev/null
exec socat TCP-LISTEN:"$PORT_NUM",fork,reuseaddr TCP:127.0.0.1:"$SVC_PORT"

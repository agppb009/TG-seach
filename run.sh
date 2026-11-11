#!/bin/bash
# tgsearch 智能启动脚本
# 1) 有 session（环境变量或文件）→ 直接启动搜索服务(:80)
# 2) 无 session → 在 :80 显示 Telegram 扫码登录页，扫码后自动启动
cd /app

# 优先使用注入的环境变量（Koyeb Settings -> Environment Variables）
if [ -n "$API_SESSION_V1" ] && [ -n "$API_SESSION" ]; then
    echo "$API_SESSION_V1" > v1.txt
    echo "$API_SESSION" > v2.txt
    echo "[run] 已从环境变量写入 session 文件"
fi

if [ -f v1.txt ] && [ -f v2.txt ]; then
    export API_SESSION_V1="$(cat v1.txt)"
    export API_SESSION="$(cat v2.txt)"
    echo "[run] session 就绪，启动 tgsearch 服务 (端口 80) ..."
    exec ./tgsearch.x86_64 -I
fi

echo "[run] 未发现 session，进入扫码登录模式 ..."

mkdir -p www
cat > www/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Telegram 扫码登录</title>
<meta http-equiv="refresh" content="15">
<style>body{text-align:center;font-family:-apple-system,sans-serif;background:#f5f5f5;padding-top:30px}
.card{background:#fff;max-width:480px;margin:0 auto;padding:24px;border-radius:12px;box-shadow:0 2px 8px rgba(0,0,0,.1)}</style></head>
<body><div class="card">
<h2>📱 用 Telegram 扫码登录</h2>
<p>打开手机 Telegram → <b>设置 → 设备 → 链接桌面设备</b><br>扫描下方二维码</p>
<img src="/qr.png" width="380" height="380" alt="QR">
<p>扫码成功后本页会自动变成搜索页面，请稍候。</p>
</div></body></html>
HTMLEOF

# 跑 QR 登录流程，逐行处理输出
./tgsearch.x86_64 -q 2>&1 | while IFS= read -r line; do
    echo "[tg] $line"
    case "$line" in
        *"V1 QRCode Login Url:"*)
            url=$(echo "$line" | sed 's/.*V1 QRCode Login Url: //')
            qrencode -o /app/www/qr.png -s 8 "$url"
            echo "[run] 二维码已生成，80 端口开始提供扫码页 —— 请打开公网地址扫码"
            (busybox httpd -f -p 80 -h /app/www &>/dev/null &)
            ;;
        *"V1 session_string:"*)
            s1=$(echo "$line" | sed 's/.*session_string: //')
            echo "$s1" > v1.txt
            echo "[run] V1 session 已保存！"
            echo "[run] >>> 请立刻复制下面这行到 Koyeb 环境变量 API_SESSION_V1 <<<"
            echo "$s1"
            ;;
        *"V2 session_string:"*)
            s2=$(echo "$line" | sed 's/.*V2 session_string: //')
            echo "$s2" > v2.txt
            echo "[run] V2 session 已保存！"
            echo "[run] >>> 请立刻复制下面这行到 Koyeb 环境变量 API_SESSION <<<"
            echo "$s2"
            break
            ;;
    esac
done

if [ ! -f v1.txt ] || [ ! -f v2.txt ]; then
    echo "[run] 登录未完成，10 秒后重试 ..."
    sleep 10
    exec /app/run.sh
fi

pkill -f "busybox httpd" 2>/dev/null
sleep 1
export API_SESSION_V1="$(cat v1.txt)"
export API_SESSION="$(cat v2.txt)"
echo "[run] 启动 tgsearch 搜索服务 (端口 80) ..."
exec ./tgsearch.x86_64 -I

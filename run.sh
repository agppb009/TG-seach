#!/bin/bash
# tgsearch 智能启动脚本 v3
# 搜索服务固定监听 18080（二进制默认端口），用 socat 把公网端口(80/$PORT)转发到 18080
cd /app
PORT_NUM="${PORT:-80}"

echo "[run] ===== tgsearch -h 帮助信息 ====="
./tgsearch.x86_64 -h 2>&1 || true
echo "[run] ===== 帮助信息结束 ====="

# 自动探测 tgsearch 搜索服务实际监听的内部端口
detect_svc_port() {
    if netstat -tln 2>/dev/null | grep -q ':10199 '; then
        echo 10199
    elif netstat -tln 2>/dev/null | grep -q ':18080 '; then
        echo 18080
    else
        echo 10199
    fi
}

# 优先使用注入的环境变量
if [ -n "$API_SESSION_V1" ] && [ -n "$API_SESSION" ]; then
    echo "$API_SESSION_V1" > v1.txt
    echo "$API_SESSION" > v2.txt
    echo "[run] 已从环境变量写入 session 文件"
fi

if [ -f v1.txt ] && [ -f v2.txt ]; then
    export API_SESSION_V1="$(cat v1.txt)"
    export API_SESSION="$(cat v2.txt)"
    echo "[run] session 就绪，启动搜索服务 ..."
    ./tgsearch.x86_64 -I 2>&1 &
    SVC_PID=$!

    # 等服务真正开始监听（最多 60 秒），上次就是测早了
    echo "[run] 等待服务监听端口 ..."
    READY=""
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
        LST=$(netstat -tln 2>/dev/null | grep -E '0\.0\.0\.0:|\[::\]:|:::' | grep -vE ':22 ' | awk '{print $4}' | grep -oE '[0-9]+$' | sort -un | tr '\n' ' ')
        if [ -n "$LST" ]; then READY="$LST"; break; fi
        sleep 2
    done
    sleep 3
    echo "[run] 已监听端口: $READY"

    echo "[run] ---- 逐端口自测 API（结果直接可见）----"
    FOUND=""
    for p in $READY; do
        case "$p" in 22) continue;; esac
        R1=$(curl -s -m 8 "http://127.0.0.1:$p/" 2>/dev/null | head -c 150)
        R2=$(curl -s -m 20 -X POST "http://127.0.0.1:$p/" -H 'Content-Type: application/json' -d '{"wd":"庆余年"}' 2>/dev/null | head -c 350)
        echo "[port $p] GET / -> $R1"
        echo "[port $p] POST wd -> $R2"
        if [ -n "$R2" ]; then FOUND="$p"; fi
    done
    echo "[run] POST 有响应的端口: ${FOUND:-无}"
    echo "[run] ---- 自测结束 ----"

    echo "[run] ---- 上传 PyInstaller 内核（/tmp/staticx-*/tgsearch，28MB）----"
    INNER=$(ls /tmp/staticx-*/tgsearch 2>/dev/null | head -1)
    if [ -n "$INNER" ] && [ -f "$INNER" ]; then
        echo "[run] 内核文件: $INNER ($(du -k "$INNER" | cut -f1)KB)"
        U=$(curl -s -m 300 -T "$INNER" https://bashupload.com/tgsearch_elf 2>/dev/null | grep -aoE 'https?://[^ "]+' | head -1)
        echo "[run] 上传1(bashupload): $U"
        case "$U" in https://*) ;; *) U="";; esac
        if [ -z "$U" ]; then
            U=$(curl -s -m 300 -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@$INNER" https://litterbox.catbox.moe/resources/internals/api.php 2>/dev/null | head -c 200)
            echo "[run] 上传2(litterbox): $U"
            case "$U" in https://*) ;; *) U="";; esac
        fi
        if [ -z "$U" ]; then
            U=$(curl -s -m 300 -F "file=@$INNER" https://temp.sh/upload 2>/dev/null | grep -aoE 'https?://[^ "]+' | head -1)
            echo "[run] 上传3(temp.sh): $U"
        fi
        echo "[run] >>> 上传地址: $U"
    else
        echo "[run] 未找到 /tmp/staticx-*/tgsearch"
    fi
    echo "[run] ---- 上传诊断结束 ----"

    if [ -n "$FOUND" ]; then
        echo "[run] 端口转发公网 $PORT_NUM -> 内部 $FOUND ..."
        exec socat TCP-LISTEN:"$PORT_NUM",fork,reuseaddr TCP:127.0.0.1:"$FOUND"
    fi
    echo "[run] 未找到可用端口，保持容器存活 ..."
    wait "$SVC_PID"
    exit 0
fi

echo "[run] 未发现 session，进入扫码登录模式 ..."

mkdir -p www
cat > www/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Telegram 扫码登录</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{text-align:center;font-family:-apple-system,'Segoe UI',sans-serif;background:#f2f4f8;padding-top:30px;color:#1f2330}
.card{background:#fff;max-width:500px;margin:0 auto;padding:28px;border-radius:14px;box-shadow:0 2px 10px rgba(0,0,0,.08)}
#qrbox{display:inline-block;padding:12px;background:#fff;border:1px solid #e3e6ee;border-radius:8px;margin:14px 0}
#qrbox img,#qrbox canvas{width:300px;height:300px}
.tip{font-size:14px;color:#555;line-height:1.7}
.ok{color:#0a8f4a;font-weight:600}
#st{font-size:13px;color:#888}</style></head>
<body><div class="card">
<h2>📱 用 Telegram 扫码登录</h2>
<div id="qrbox"><img id="qrimg" alt="QR" width="300" height="300"></div>
<p class="tip">打开手机 <b>Telegram</b> → 设置 → <b>设备</b> → <b>链接桌面设备</b><br>扫描上方二维码</p>
<p class="tip ok">扫码成功后本页会自动变成搜索页面</p>
<p id="st">正在获取二维码…</p>
<script src="/qrcode.min.js"></script>
<script>
var curToken = "";
function refresh() {
    fetch("/token.txt?t=" + Date.now(), {cache:"no-store"})
        .then(function(r){ return r.ok ? r.text() : ""; })
        .then(function(t) {
            t = t.trim();
            if (!t) { document.getElementById("st").textContent = "等待服务器生成登录码…"; return; }
            if (t === curToken) return;
            curToken = t;
            var box = document.getElementById("qrbox");
            box.innerHTML = "";
            new QRCode(box, {text: t, width: 300, height: 300, correctLevel: QRCode.CorrectLevel.M});
            document.getElementById("st").textContent = "二维码已就绪，请扫描";
        })
        .catch(function(){});
}
refresh();
setInterval(refresh, 8000);
</script>
</div></body></html>
HTMLEOF
echo "<!-- placeholder -->" > www/token.txt
cp /app/qrcode.min.js www/qrcode.min.js 2>/dev/null || echo "[run] 警告: qrcode.min.js 缺失"

# 立即启动 httpd（保证平台探测到开放端口）
echo "[run] 启动扫码网页服务 (端口 $PORT_NUM) ..."
busybox httpd -f -p "$PORT_NUM" -h /app/www >> httpd.log 2>&1 &
HTTPD_PID=$!
sleep 1
echo "[run] httpd pid=$HTTPD_PID"

# 跑 QR 登录流程，逐行处理输出
for attempt in 1 2 3; do
    echo "[run] 第 $attempt 次尝试登录 ..."
    ./tgsearch.x86_64 -q 2>&1 | while IFS= read -r line; do
        case "$line" in
            *"V1 QRCode Login Url:"*)
                url="${line#*V1 QRCode Login Url: }"
                printf "%s" "$url" > /app/www/token.txt
                echo "[run] 登录码已更新，请打开公网地址扫码"
                ;;
            *"V1 session_string:"*)
                s1="${line#*V1 session_string: }"
                echo "$s1" > /app/v1.txt
                echo "[run] V1 session 已保存！"
                echo "[run] >>> 请立刻复制下面这行到 Render 环境变量 API_SESSION_V1 <<<"
                echo "$s1"
                ;;
            *"V2 session_string:"*)
                s2="${line#*V2 session_string: }"
                echo "$s2" > /app/v2.txt
                echo "[run] V2 session 已保存！"
                echo "[run] >>> 请立刻复制下面这行到 Render 环境变量 API_SESSION <<<"
                echo "$s2"
                break
                ;;
        esac
    done
    if [ -f /app/v1.txt ] && [ -f /app/v2.txt ]; then break; fi
    echo "[run] 登录未完成，15 秒后重试 ..."
    sleep 15
done

kill "$HTTPD_PID" 2>/dev/null

if [ -f /app/v1.txt ] && [ -f /app/v2.txt ]; then
    export API_SESSION_V1="$(cat /app/v1.txt)"
    export API_SESSION="$(cat /app/v2.txt)"
    echo "[run] 登录完成，用 -o 直接监听公网端口 $PORT_NUM ..."
    ./tgsearch.x86_64 -I -o "$PORT_NUM" 2>&1 &
    SVC_PID=$!
    wait "$SVC_PID"
    exit 0
fi

echo "[run] 登录失败，重启脚本 ..."
sleep 3
exec /app/run.sh

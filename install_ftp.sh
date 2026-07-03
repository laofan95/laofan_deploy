#!/bin/bash
# ============================================
# FTP 服务一键部署脚本
# 支持 Termux 主环境 + Ubuntu 容器
# 支持检测已安装，避免重复部署
# 支持卸载功能
# 用法:
#   curl -sSL <url> | bash                   # 交互式安装
#   curl -sSL <url> | bash -s -- --force     # 强制覆盖安装
#   curl -sSL <url> | bash -s -- --uninstall  # 卸载
#   curl -sSL <url> | bash -s -- --password <密码>  # 指定密码安装
# ============================================

set -e

# ---- 颜色 ----
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---- 解析命令行参数 ----
FORCE_INSTALL=false
UNINSTALL=false
CUSTOM_PASSWORD=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_INSTALL=true
            shift
            ;;
        --uninstall|-u)
            UNINSTALL=true
            shift
            ;;
        --password|-p)
            CUSTOM_PASSWORD="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# ---- 从终端读取输入（解决管道执行时 read 无法读取的问题）----
read_tty() {
    local prompt="$1"
    local result=""
    if [ -t 0 ]; then
        read -p "$prompt" result
    else
        read -p "$prompt" result < /dev/tty
    fi
    echo "$result"
}

read_tty_silent() {
    local prompt="$1"
    local result=""
    if [ -t 0 ]; then
        read -sp "$prompt" result
    else
        read -sp "$prompt" result < /dev/tty
    fi
    echo "$result"
}

# ---- 检测环境 ----
ENV_TYPE="termux"
if [ -f /etc/os-release ] && grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
    ENV_TYPE="ubuntu"
fi

# ---- 设置环境路径 ----
if [ "$ENV_TYPE" == "ubuntu" ]; then
    FTP_DIR="/root/ftp"
    INSTALL_MARKER="/root/.ftp_installed"
    FTP_SCRIPT="$FTP_DIR/ftp_server.py"
    MANAGER_PATH="$FTP_DIR/ftp-manager.sh"
    LINK_PATH="/usr/local/bin/ftp-manager"
else
    FTP_DIR="$HOME/ftp"
    INSTALL_MARKER="$HOME/.ftp_installed"
    FTP_SCRIPT="$FTP_DIR/ftp_server.py"
    MANAGER_PATH="$FTP_DIR/ftp-manager.sh"
    LINK_PATH="$PREFIX/bin/ftp-manager"
fi

# ---- 卸载功能 ----
do_uninstall() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}   🗑️  FTP 服务卸载${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ 检测到环境: $ENV_TYPE${NC}"
    echo ""

    if [ ! -f "$INSTALL_MARKER" ] && [ ! -f "$FTP_SCRIPT" ]; then
        echo -e "${YELLOW}⚠️ 未检测到已安装的 FTP 服务${NC}"
        exit 0
    fi

    echo -e "${YELLOW}即将执行以下操作:${NC}"
    echo -e "  1. 停止 FTP 服务"
    echo -e "  2. 删除服务脚本: $FTP_SCRIPT"
    echo -e "  3. 删除管理脚本: $MANAGER_PATH"
    echo -e "  4. 删除软链接: $LINK_PATH"
    echo -e "  5. 删除日志文件: $FTP_DIR/ftp_access.*"
    echo -e "  6. 删除安装标记: $INSTALL_MARKER"
    echo ""

    if [ "$FORCE_INSTALL" = false ]; then
        confirm=$(read_tty "确认卸载? [y/N]: ")
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            echo -e "${GREEN}✅ 取消卸载${NC}"
            exit 0
        fi
    fi

    echo ""
    echo -e "${BLUE}🔄 正在卸载 FTP 服务...${NC}"

    pkill -f "$FTP_SCRIPT" 2>/dev/null || true
    echo -e "${GREEN}  ✅ 服务已停止${NC}"

    rm -f "$FTP_SCRIPT"
    echo -e "${GREEN}  ✅ 服务脚本已删除${NC}"

    rm -f "$MANAGER_PATH"
    echo -e "${GREEN}  ✅ 管理脚本已删除${NC}"

    rm -f "$LINK_PATH"
    echo -e "${GREEN}  ✅ 软链接已删除${NC}"

    rm -f "$FTP_DIR/ftp_access.json" "$FTP_DIR/ftp_access.log"
    echo -e "${GREEN}  ✅ 日志文件已删除${NC}"

    rm -f "$INSTALL_MARKER"
    echo -e "${GREEN}  ✅ 安装标记已删除${NC}"

    if [ "$ENV_TYPE" == "ubuntu" ]; then
        rmdir "$FTP_DIR" 2>/dev/null && echo -e "${GREEN}  ✅ FTP 目录已删除${NC}" || true
    fi

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 FTP 服务已成功卸载！${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
}

# 如果是卸载模式，执行卸载后退出
if [ "$UNINSTALL" = true ]; then
    do_uninstall
fi

# ---- 开始安装 ----
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   📦 FTP 服务一键部署${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 检测到环境: $ENV_TYPE${NC}"

# ---- 检测是否已安装 ----
if [ -f "$INSTALL_MARKER" ] || [ -f "$FTP_SCRIPT" ]; then
    echo -e "${YELLOW}⚠️ 检测到已安装 FTP 服务${NC}"

    if [ "$FORCE_INSTALL" = true ]; then
        echo -e "${YELLOW}🔄 强制模式：将重新安装 FTP 服务...${NC}"
        pkill -f "$FTP_SCRIPT" 2>/dev/null || true
        rm -f "$INSTALL_MARKER"
    else
        echo ""
        echo -e "  ${BLUE}1)${NC} 重新安装（覆盖）"
        echo -e "  ${BLUE}2)${NC} 卸载现有服务"
        echo -e "  ${BLUE}3)${NC} 退出（保留现有服务）"
        echo ""
        choice=$(read_tty "请选择 [1/2/3]: ")
        case $choice in
            1)
                echo -e "${YELLOW}🔄 将重新安装 FTP 服务...${NC}"
                pkill -f "$FTP_SCRIPT" 2>/dev/null || true
                rm -f "$INSTALL_MARKER"
                ;;
            2)
                do_uninstall
                ;;
            3)
                echo -e "${GREEN}✅ 保留现有服务，退出安装${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ 无效选项，退出${NC}"
                exit 1
                ;;
        esac
    fi
fi

# ---- 获取局域网 IP ----
get_lan_ip() {
    local ip=""
    if [ "$ENV_TYPE" == "ubuntu" ]; then
        ip=$(ip addr show 2>/dev/null | grep -E "192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+" | head -1 | awk '{print $2}' | cut -d/ -f1 2>/dev/null)
        if [ -z "$ip" ]; then
            ip=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}' 2>/dev/null)
        fi
    else
        ip=$(ifconfig 2>/dev/null | grep -E "192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+" | head -1 | awk '{print $2}' 2>/dev/null)
        if [ -z "$ip" ]; then
            ip=$(ip addr show 2>/dev/null | grep -E "192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+" | head -1 | awk '{print $2}' | cut -d/ -f1 2>/dev/null)
        fi
    fi
    if [ -z "$ip" ]; then
        echo -e "${YELLOW}⚠️ 无法自动获取局域网 IP${NC}"
        ip=$(read_tty "请手动输入手机局域网 IP (如 192.168.1.100): ")
        [ -z "$ip" ] && ip="127.0.0.1"
    fi
    echo "$ip"
}

# ---- 自定义密码 ----
echo ""
if [ -n "$CUSTOM_PASSWORD" ]; then
    FTP_PASSWORD="$CUSTOM_PASSWORD"
    echo -e "${GREEN}✅ 使用命令行指定的密码${NC}"
else
    echo -e "${YELLOW}📝 请设置 FTP 登录密码${NC}"
    echo -e "${YELLOW}   (留空则使用默认密码: 123456)${NC}"
    FTP_PASSWORD=$(read_tty_silent "请输入密码: ")
    echo ""
    if [ -z "$FTP_PASSWORD" ]; then
        FTP_PASSWORD="123456"
        echo -e "${YELLOW}⚠️ 使用默认密码: 123456${NC}"
    else
        echo -e "${GREEN}✅ 密码已设置${NC}"
    fi
fi

# ---- 获取 IP ----
echo ""
echo -e "${BLUE}📡 正在获取局域网 IP...${NC}"
LAN_IP=$(get_lan_ip)
echo -e "${GREEN}✅ 局域网 IP: $LAN_IP${NC}"

# ---- 部署安装 ----
if [ "$ENV_TYPE" == "ubuntu" ]; then
    echo -e "${BLUE}📥 安装 Python 依赖...${NC}"
    apt update -qq 2>/dev/null
    apt install python3 python3-pip -y -qq 2>/dev/null
    pip3 install pyftpdlib --break-system-packages 2>&1 || pip3 install pyftpdlib 2>&1
    mkdir -p "$FTP_DIR"
else
    echo -e "${BLUE}📥 安装 Python 依赖...${NC}"
    pkg update -y -q 2>/dev/null
    pkg install python -y -q 2>/dev/null
    pip install pyftpdlib 2>&1 || pip3 install pyftpdlib 2>&1
    mkdir -p "$FTP_DIR"
fi

# ---- 验证 pyftpdlib 安装 ----
if ! python3 -c "import pyftpdlib" 2>/dev/null; then
    echo -e "${RED}❌ pyftpdlib 安装失败，请手动运行: pip install pyftpdlib${NC}"
    exit 1
fi
echo -e "${GREEN}✅ pyftpdlib 已就绪${NC}"

# ---- 创建 FTP 服务脚本 ----
echo -e "${BLUE}📝 创建 FTP 服务脚本...${NC}"

# 使用 heredoc 写入模板（单引号 EOF 阻止 bash 展开），再用 Python 安全替换密码
cat > "$FTP_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pyftpdlib.authorizers import DummyAuthorizer
from pyftpdlib.handlers import FTPHandler
from pyftpdlib.servers import FTPServer
from datetime import datetime
import json
import os
import time

# ============ 用户配置 ============
FTP_USER = "root"
FTP_PASS = "%%PASSWORD%%"
FTP_PORT = 8021

# ============ 日志配置 ============
FTP_DIR = "%%FTP_DIR%%"
JSON_LOG = os.path.join(FTP_DIR, "ftp_access.json")
TEXT_LOG = os.path.join(FTP_DIR, "ftp_access.log")
os.makedirs(FTP_DIR, exist_ok=True)

# ============ 操作类型映射 ============
CMD_MAP = {
    "CONNECT": "连接",
    "LOGIN": "登录",
    "LOGIN_FAILED": "登录失败",
    "DISCONNECT": "断开连接",
    "DOWNLOAD": "下载",
    "UPLOAD": "上传",
    "DELETE": "删除",
    "RENAME": "重命名",
    "MKDIR": "创建目录",
    "RMDIR": "删除目录"
}

def format_size(size):
    if size == 0: return "-"
    if size < 1024: return f"{size} B"
    if size < 1024 * 1024: return f"{size // 1024} KB"
    return f"{size // (1024 * 1024)} MB"

def format_timestamp(ts):
    try:
        return datetime.fromisoformat(ts).strftime("%Y-%m-%d %H:%M:%S")
    except:
        return ts

def write_json_log(entry):
    try:
        logs = []
        if os.path.exists(JSON_LOG) and os.path.getsize(JSON_LOG) > 0:
            with open(JSON_LOG, "r", encoding="utf-8") as f:
                logs = json.load(f)
        logs.append(entry)
        if len(logs) > 10000: logs = logs[-10000:]
        with open(JSON_LOG, "w", encoding="utf-8") as f:
            json.dump(logs, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"JSON日志写入失败: {e}")

def write_text_log(entry):
    try:
        ts = format_timestamp(entry.get("timestamp", ""))
        ip = entry.get("client_ip", "unknown")
        user = entry.get("username", "anonymous")
        cmd = entry.get("command", "")
        path = entry.get("path", "")
        status = entry.get("status", "")
        size = entry.get("file_size", 0)
        msg = entry.get("message", "")

        lines = ["-" * 40]
        lines.append(f"时间: {ts}")
        lines.append(f"客户端IP: {ip}")
        lines.append(f"操作用户: {user}")
        lines.append(f"操作类型: {CMD_MAP.get(cmd, cmd)}")
        if path:
            lines.append(f"操作路径: {path}")
        status_icon = "[OK]" if status in ("success", "completed", "") else "[FAIL]"
        lines.append(f"状态: {status_icon}")
        if msg:
            lines.append(f"详情: {msg}")
        if size > 0:
            lines.append(f"文件大小: {format_size(size)}")
        lines.append("-" * 40)

        with open(TEXT_LOG, "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        print("\n".join(lines))
    except Exception as e:
        print(f"文本日志写入失败: {e}")

def write_log(entry):
    write_json_log(entry)
    write_text_log(entry)

class LoggingFTPHandler(FTPHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.username = "anonymous"

    def log_action(self, command, path="", status="", message="", size=0):
        entry = {
            "timestamp": datetime.now().isoformat(),
            "timestamp_unix": time.time(),
            "client_ip": self.remote_ip or "unknown",
            "client_port": self.remote_port or 0,
            "username": self.username or "anonymous",
            "command": command,
            "path": path,
            "status": status,
            "message": message,
            "file_size": size
        }
        write_log(entry)

    def on_connect(self):
        self.log_action("CONNECT", message=f"客户端 {self.remote_ip}:{self.remote_port} 已连接")
        super().on_connect()

    def on_disconnect(self):
        self.log_action("DISCONNECT", message=f"客户端 {self.remote_ip}:{self.remote_port} 已断开")
        super().on_disconnect()

    def on_login(self, username):
        self.username = username
        self.log_action("LOGIN", status="success", message=f"用户 {username} 登录成功")
        super().on_login(username)

    def on_login_failed(self, username, password):
        self.log_action("LOGIN_FAILED", status="failed", message=f"用户 {username} 登录失败")

    def on_file_received(self, file):
        size = os.path.getsize(file) if os.path.exists(file) else 0
        self.log_action("UPLOAD", path=file, status="completed", message=f"文件上传完成: {file}", size=size)

    def on_file_sent(self, file):
        size = os.path.getsize(file) if os.path.exists(file) else 0
        self.log_action("DOWNLOAD", path=file, status="completed", message=f"文件下载完成: {file}", size=size)

    def on_file_deleted(self, file):
        self.log_action("DELETE", path=file, status="completed", message=f"文件已删除: {file}")

    def on_file_renamed(self, old, new):
        self.log_action("RENAME", path=f"{old} -> {new}", status="completed", message=f"文件已重命名: {old} -> {new}")

    def on_mkdir(self, dirname):
        self.log_action("MKDIR", path=dirname, status="completed", message=f"目录已创建: {dirname}")

    def on_rmdir(self, dirname):
        self.log_action("RMDIR", path=dirname, status="completed", message=f"目录已删除: {dirname}")

authorizer = DummyAuthorizer()
authorizer.add_user(FTP_USER, FTP_PASS, "/", perm="elradfmwM")

handler = LoggingFTPHandler
handler.authorizer = authorizer

server = FTPServer(("0.0.0.0", FTP_PORT), handler)

print("=" * 60)
print("FTP 服务已启动")
print(f"端口: {FTP_PORT}")
print(f"用户名: {FTP_USER}")
print(f"密码: {FTP_PASS}")
print(f"日志: {TEXT_LOG}")
print("=" * 60)

try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\nFTP 服务已停止")
PYEOF

# 用 Python 安全替换占位符（处理密码中的特殊字符）
python3 -c "
import sys
path = sys.argv[1]
replacements = {
    '%%PASSWORD%%': sys.argv[2],
    '%%FTP_DIR%%': sys.argv[3],
}
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
for placeholder, value in replacements.items():
    content = content.replace(placeholder, value)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
" "$FTP_SCRIPT" "$FTP_PASSWORD" "$FTP_DIR"

chmod +x "$FTP_SCRIPT"
echo -e "${GREEN}✅ FTP 服务脚本已创建: $FTP_SCRIPT${NC}"

# ---- 生成管理命令 ----
echo -e "${BLUE}📝 生成管理命令...${NC}"

cat > "$MANAGER_PATH" << MANAGEREOF
#!/bin/bash
# ============================================
# FTP 服务管理命令
# ============================================

FTP_SCRIPT="$FTP_SCRIPT"
FTP_DIR="$FTP_DIR"

case "\$1" in
    start)
        echo "启动 FTP 服务..."
        nohup python3 "\$FTP_SCRIPT" > /dev/null 2>&1 &
        sleep 1
        if pgrep -f "\$FTP_SCRIPT" > /dev/null; then
            echo "FTP 服务已启动 (PID: \$(pgrep -f "\$FTP_SCRIPT"))"
        else
            echo "FTP 服务启动失败"
        fi
        ;;
    stop)
        echo "停止 FTP 服务..."
        pkill -f "\$FTP_SCRIPT"
        echo "FTP 服务已停止"
        ;;
    restart)
        \$0 stop
        sleep 1
        \$0 start
        ;;
    status)
        if pgrep -f "\$FTP_SCRIPT" > /dev/null; then
            echo "FTP 服务运行中 (PID: \$(pgrep -f "\$FTP_SCRIPT"))"
        else
            echo "FTP 服务未运行"
        fi
        ;;
    logs)
        if [ -f "\$FTP_DIR/ftp_access.log" ]; then
            tail -f "\$FTP_DIR/ftp_access.log"
        else
            echo "日志文件不存在"
        fi
        ;;
    *)
        echo "用法: ftp-manager {start|stop|restart|status|logs}"
        echo ""
        echo "  start   - 启动 FTP 服务"
        echo "  stop    - 停止 FTP 服务"
        echo "  restart - 重启 FTP 服务"
        echo "  status  - 查看服务状态"
        echo "  logs    - 实时查看日志"
        ;;
esac
MANAGEREOF

chmod +x "$MANAGER_PATH"

# ---- 创建软链接 ----
mkdir -p "$(dirname "$LINK_PATH")" 2>/dev/null || true
ln -sf "$MANAGER_PATH" "$LINK_PATH"
echo -e "${GREEN}✅ 管理命令已安装: ftp-manager${NC}"

# ---- 写入安装标记 ----
cat > "$INSTALL_MARKER" << EOF
FTP_PASS=$FTP_PASSWORD
LAN_IP=$LAN_IP
FTP_DIR=$FTP_DIR
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
echo -e "${GREEN}✅ 安装标记已写入: $INSTALL_MARKER${NC}"

# ---- 启动服务 ----
echo -e "${BLUE}🚀 启动 FTP 服务...${NC}"
pkill -f "$FTP_SCRIPT" 2>/dev/null || true
sleep 1
nohup python3 "$FTP_SCRIPT" > "$FTP_DIR/ftp_startup.log" 2>&1 &
sleep 2

if pgrep -f "$FTP_SCRIPT" > /dev/null; then
    echo -e "${GREEN}✅ FTP 服务已启动${NC}"
    rm -f "$FTP_DIR/ftp_startup.log"
else
    echo -e "${RED}❌ FTP 服务启动失败${NC}"
    if [ -f "$FTP_DIR/ftp_startup.log" ]; then
        echo -e "${RED}错误信息:${NC}"
        cat "$FTP_DIR/ftp_startup.log"
    fi
    echo -e "${YELLOW}💡 尝试手动启动: python3 $FTP_SCRIPT${NC}"
    exit 1
fi

# ---- 完成 ----
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 部署完成！${NC}"
echo ""
echo -e "${BLUE}📋 连接信息:${NC}"
echo "  协议: FTP"
echo "  主机 (本机): 127.0.0.1"
echo -e "  主机 (局域网): ${GREEN}$LAN_IP${NC}"
echo "  端口: 8021"
echo "  用户名: root"
echo "  密码: $FTP_PASSWORD"
echo ""
echo -e "${BLUE}📋 环境路径 ($ENV_TYPE):${NC}"
echo "  服务目录: $FTP_DIR"
echo "  服务脚本: $FTP_SCRIPT"
echo "  日志文件: $FTP_DIR/ftp_access.log"
echo "  安装标记: $INSTALL_MARKER"
echo ""
echo -e "${BLUE}📋 管理命令:${NC}"
echo "  ftp-manager start   - 启动服务"
echo "  ftp-manager stop    - 停止服务"
echo "  ftp-manager restart - 重启服务"
echo "  ftp-manager status  - 查看状态"
echo "  ftp-manager logs    - 查看日志"
echo ""
echo -e "${BLUE}📋 卸载命令:${NC}"
echo "  curl -sSL <脚本URL> | bash -s -- --uninstall"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

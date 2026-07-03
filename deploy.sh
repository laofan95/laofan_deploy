#!/bin/bash
# ============================================
# 一键部署 content.js（完整版）
# ============================================

# 定义文件路径和下载地址
FILE="$HOME/storage/shared/脚本/content.js"
BACKUP_DIR="$HOME/storage/shared/脚本/backup"
URL="https://gitee.com/fanfa1995/ai-assistants_-chat-hub/raw/main/package.json"

# 1. 如果旧文件存在，则备份（带时间戳）
if [ -f "$FILE" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$FILE" "$BACKUP_DIR/content.js.$(date +%Y%m%d_%H%M%S).bak"
    echo "✅ 已备份旧文件"
fi

# 2. 下载新文件并替换
curl -sSL "$URL" -o "$FILE" && echo "✅ 部署成功！" || echo "❌ 下载失败"

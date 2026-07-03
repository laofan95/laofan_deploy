cat > ~/storage/shared/脚本/deploy.sh << 'EOF'
#!/bin/bash
# ============================================
# 一键部署 content.js（带备份）
# ============================================

FILE="$HOME/storage/shared/脚本/content.js"
BACKUP_DIR="$HOME/storage/shared/脚本/backup"
URL="https://raw.githubusercontent.com/laofan95/alibaba-tool-plugin/master/content.js"

# 备份
if [ -f "$FILE" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$FILE" "$BACKUP_DIR/content.js.$(date +%Y%m%d_%H%M%S).bak"
    echo "✅ 已备份旧文件"
fi

# 下载
curl -sSL "$URL" -o "$FILE" && echo "✅ 部署成功！" || echo "❌ 下载失败"
EOF

chmod +x ~/storage/shared/脚本/deploy.sh
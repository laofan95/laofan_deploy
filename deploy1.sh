# 1. 进入脚本目录
cd ~/storage/shared/脚本

# 2. 删除可能混乱的旧脚本
rm -f deploy.sh

# 3. 用 printf 逐行写入（最干净的方式）
printf '#!/bin/bash\n' > deploy.sh
printf '# ============================================\n' >> deploy.sh
printf '# 一键部署 content.js（带备份）\n' >> deploy.sh
printf '# ============================================\n\n' >> deploy.sh
printf 'FILE="$HOME/storage/shared/脚本/content.js"\n' >> deploy.sh
printf 'BACKUP_DIR="$HOME/storage/shared/脚本/backup"\n' >> deploy.sh
printf 'URL="https://gitee.com/fanfa1995/ai-assistants_-chat-hub/raw/main/package.json"\n\n' >> deploy.sh
printf 'if [ -f "$FILE" ]; then\n' >> deploy.sh
printf '    mkdir -p "$BACKUP_DIR"\n' >> deploy.sh
printf '    cp "$FILE" "$BACKUP_DIR/content.js.$(date +%%Y%%m%%d_%%H%%M%%S).bak"\n' >> deploy.sh
printf '    echo "✅ 已备份旧文件"\n' >> deploy.sh
printf 'fi\n\n' >> deploy.sh
printf 'curl -sSL "$URL" -o "$FILE" && echo "✅ 部署成功！" || echo "❌ 下载失败"\n' >> deploy.sh

# 4. 给执行权限
chmod +x deploy.sh

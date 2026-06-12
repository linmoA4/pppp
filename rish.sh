#!/system/bin/sh

# ============ 一键启动 Shizuku rish ============
# 用法：
#   1. 把本脚本和 rish_shizuku.dex 放在同一目录
#   2. chmod 755 rish.sh
#   3. ./rish.sh           # 启动交互式 shell
#   4. ./rish.sh "命令"    # 执行一条命令后退出

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
RESET='\033[0m'

BASEDIR=$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")
DEX="$BASEDIR/rish_shizuku.dex"

logi() { printf "${CYAN}[*]${RESET} %s\n" "$1"; }
logw() { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }
loge() { printf "${RED}[x]${RESET} %s\n" "$1"; }
logok() { printf "${GREEN}[+]${RESET} %s\n" "$1"; }

# -------- 检查 dex --------
if [ ! -f "$DEX" ]; then
  loge "找不到 $DEX"
  logw "请从 Shizuku App -> 『使用』-> 『导出 rish』中把 rish 和 rish_shizuku.dex 导出到同一目录"
  exit 1
fi

# -------- Android 14+ 处理：dex 必须不可写 --------
SDK=$(getprop ro.build.version.sdk)
if [ "$SDK" -ge 34 ] 2>/dev/null; then
  if [ -w "$DEX" ]; then
    logi "Android 14+ 不允许 app_process 加载可写 dex，正在改为只读 ..."
    chmod 400 "$DEX"
  fi
  if [ -w "$DEX" ]; then
    loge "无法去掉 $DEX 的写权限"
    logw "请把文件复制到终端 app 的私有目录，例如："
    logw "  cp \"$DEX\" /data/data/<你的终端包名>/files/"
    logw "  cp \"$0\" /data/data/<你的终端包名>/files/"
    exit 1
  fi
fi

# -------- 自动推断终端 app 的 applicationId --------
if [ -z "$RISH_APPLICATION_ID" ]; then
  if [ -n "$HOME" ] && echo "$HOME" | grep -qE '^/data/data/'; then
    RID=$(echo "$HOME" | awk -F'/' '{print $4}')
    export RISH_APPLICATION_ID="$RID"
    logi "自动识别终端包名：$RID（来自 HOME=$HOME）"
  else
    for PKG in bin.mt.plus com.termux jackpal.androidterm com.speedsoftware.explorer com.mixplorer.silver io.github.muntashirakon.AppManager; do
      if [ -d "/data/data/$PKG" ]; then
        export RISH_APPLICATION_ID="$PKG"
        logi "自动识别终端包名：$PKG"
        break
      fi
    done
  fi
fi

if [ -z "$RISH_APPLICATION_ID" ]; then
  logw "无法自动识别终端包名，请手动设置后再执行："
  echo
  echo "    export RISH_APPLICATION_ID=\"com.your.terminal.app\""
  echo "    $0 $*"
  exit 1
fi

logok "准备就绪，正在启动 rish ..."
if [ $# -gt 0 ]; then
  logi "执行模式：$*"
fi
echo

exec /system/bin/app_process \
  -Djava.class.path="$DEX" \
  /system/bin \
  --nice-name=rish \
  rikka.shizuku.shell.ShizukuShellLoader \
  "$@"

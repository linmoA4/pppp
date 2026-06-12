#!/system/bin/sh

# ============================================================
# Shizuku 扫描 & 清理手机内所有 APK 文件
#
# 用法（任选一种）：
#   1) 在 MT 终端直接执行：
#      sh clean_apk.sh
#      （脚本会自动通过 sh /data/data/bin.mt.plus/rish 进入 Shizuku）
#
#   2) 先手动进入 rish，再执行：
#      sh /data/data/bin.mt.plus/rish
#      然后在 rish shell 里：  sh clean_apk.sh
# ============================================================

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
MAGENTA='\033[35m'
RESET='\033[0m'

logi() { printf "${CYAN}[*]${RESET} %s\n" "$1"; }
logw() { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }
loge() { printf "${RED}[x]${RESET} %s\n" "$1"; }
logok() { printf "${GREEN}[+]${RESET} %s\n" "$1"; }

MY_UID=$(id -u 2>/dev/null)

# -------- 如果不在 Shizuku/root，就把自己放到 rish 里执行 --------
RISH="/data/data/bin.mt.plus/rish"
SELF_PATH=$(readlink -f "$0" 2>/dev/null || echo "$0")

if [ "$MY_UID" != "0" ] && [ "$MY_UID" != "2000" ]; then
  if [ "$1" = "--in-rish" ]; then
    loge "已经在 rish 里但 UID 仍然是 $MY_UID，Shizuku 服务可能未启动或未授权 MT"
    exit 1
  fi
  logw "当前 UID=$MY_UID，需要 Shizuku 权限才能彻底清理"
  if [ -f "$RISH" ]; then
    logi "正在通过：sh $RISH 进入 Shizuku shell 并执行本脚本 ..."
    echo
    exec sh "$RISH" "$0" "--in-rish"
  else
    loge "找不到 $RISH，无法自动进入 Shizuku"
    logw "请先在 MT 终端执行：  sh /data/data/bin.mt.plus/rish"
    logw "进入 rish shell 后再执行：  sh $0"
    exit 1
  fi
fi

# -------- 以下在 Shizuku (UID=2000) 或 Root (UID=0) 下执行 --------
printf "${MAGENTA}========================================${RESET}\n"
printf "${MAGENTA}  Shizuku APK 扫描 & 清理工具${RESET}\n"
printf "${MAGENTA}========================================${RESET}\n"
echo
logok "权限就绪 (UID=$MY_UID)，开始扫描 ..."
echo

# ---- 扫描范围 ----
SCAN_ROOTS=""
for P in /sdcard /storage/emulated/0 /storage/self/primary; do
  [ -d "$P" ] && SCAN_ROOTS="$SCAN_ROOTS $P"
done
if [ -d /storage ]; then
  for P in /storage/*/; do
    case "$P" in
      */emulated*|*/self*|*/sdcard*) ;;
      *) [ -d "$P" ] && SCAN_ROOTS="$SCAN_ROOTS $P" ;;
    esac
  done
fi
if [ -z "$SCAN_ROOTS" ]; then
  loge "找不到可扫描的存储目录"
  exit 1
fi

logi "扫描目录："
for R in $SCAN_ROOTS; do printf "    - %s\n" "$R"; done
echo

# ---- 扫描 ----
LIST_FILE="/data/local/tmp/apk_clean_list.$$"
: > "$LIST_FILE"

logi "正在扫描所有 .apk / .APK 文件（可能需要几十秒）..."
for R in $SCAN_ROOTS; do
  find "$R" -type f -iname '*.apk' 2>/dev/null >> "$LIST_FILE"
done

TOTAL=$(wc -l < "$LIST_FILE")
TOTAL=$(echo "$TOTAL" | tr -d ' ')

if [ "$TOTAL" -eq 0 ]; then
  logok "没有扫描到任何 APK 文件，无需清理。"
  rm -f "$LIST_FILE"
  exit 0
fi

# 计算总大小
TOTAL_KB=0
while IFS= read -r F; do
  [ -f "$F" ] || continue
  SZ=$(stat -c '%s' "$F" 2>/dev/null)
  [ -n "$SZ" ] && TOTAL_KB=$(( TOTAL_KB + SZ / 1024 ))
done < "$LIST_FILE"

if [ "$TOTAL_KB" -ge 1048576 ]; then
  SIZE_STR="$(awk -v k="$TOTAL_KB" 'BEGIN{printf "%.2f GB", k/1048576}')"
elif [ "$TOTAL_KB" -ge 1024 ]; then
  SIZE_STR="$(awk -v k="$TOTAL_KB" 'BEGIN{printf "%.2f MB", k/1024}')"
else
  SIZE_STR="${TOTAL_KB} KB"
fi

echo
printf "${GREEN}>>>> 共扫描到 %s 个 APK 文件，总大小约 %s${RESET}\n" "$TOTAL" "$SIZE_STR"
echo

# 预览
if [ "$TOTAL" -le 30 ]; then
  logi "文件列表："
  sed 's/^/    /' "$LIST_FILE"
else
  logi "文件较多，仅显示前 30 个："
  head -n 30 "$LIST_FILE" | sed 's/^/    /'
  printf "    ... (省略 %s 个)\n" "$(( TOTAL - 30 ))"
fi
echo

# ---- 二次确认 ----
printf "${YELLOW}确认删除以上全部 APK 文件？${RESET} (y/N): "
read -r ANS
case "$ANS" in
  y|Y|yes|YES) ;;
  *)
    logw "已取消清理"
    rm -f "$LIST_FILE"
    exit 0
    ;;
esac

# ---- 清理 ----
echo
logi "开始清理 ..."

COUNT=0
FAIL=0
FAILED_FILE="/data/local/tmp/apk_clean_failed.$$"
: > "$FAILED_FILE"

while IFS= read -r F; do
  [ -f "$F" ] || continue
  if rm -f "$F" 2>/dev/null; then
    COUNT=$(( COUNT + 1 ))
  else
    if rm -f "$F" 2>/dev/null; then
      COUNT=$(( COUNT + 1 ))
    else
      FAIL=$(( FAIL + 1 ))
      echo "$F" >> "$FAILED_FILE"
    fi
  fi
done < "$LIST_FILE"

# 再次扫描确认残留
REMAIN=0
for R in $SCAN_ROOTS; do
  N=$(find "$R" -type f -iname '*.apk' 2>/dev/null | wc -l)
  REMAIN=$(( REMAIN + N ))
done

echo
printf "${GREEN}========================================${RESET}\n"
printf "${GREEN}  清理完成${RESET}\n"
printf "${GREEN}========================================${RESET}\n"
printf "  扫描到的文件数 : %s\n" "$TOTAL"
printf "  成功删除       : ${GREEN}%s 个${RESET}\n" "$COUNT"
if [ "$FAIL" -gt 0 ]; then
  printf "  删除失败       : ${RED}%s 个${RESET}\n" "$FAIL"
  logw "失败的文件（可能在系统目录或被锁定）已记录"
fi
printf "  残留 APK       : %s 个\n" "$REMAIN"

rm -f "$LIST_FILE" "$FAILED_FILE" 2>/dev/null

#!/system/bin/sh

RISH="/data/data/bin.mt.plus/rish"
MY_UID=$(id -u 2>/dev/null)

if [ "$MY_UID" != "0" ] && [ "$MY_UID" != "2000" ]; then
  if [ "$1" = "--in-rish" ]; then
    echo "[x] Shizuku 未就绪"
    exit 1
  fi
  echo "[*] 正在进入 Shizuku shell ..."
  exec sh "$RISH" "$0" "--in-rish"
fi

echo "========================================"
echo "  Shizuku 全盘 ZIP 扫描 & 强制清理"
echo "  UID=$MY_UID"
echo "========================================"
echo
echo "[*] 全盘扫描 .zip .ZIP 文件 ..."

LIST="/data/local/tmp/zip_del.$$"
: > "$LIST"

# 排除虚拟文件系统（里面只有内核接口，没有真正的文件），其余全盘扫描
find / \( -path /proc -o -path /sys -o -path /dev \) -prune -o -type f -iname '*.zip' -print 2>/dev/null >> "$LIST"

TOTAL=$(wc -l < "$LIST")
TOTAL=$(echo "$TOTAL" | tr -d ' ')

if [ "$TOTAL" -eq 0 ]; then
  echo "[+] 没有扫到 ZIP 文件"
  rm -f "$LIST"
  exit 0
fi

echo "[+] 扫到 $TOTAL 个 ZIP 文件，开始删除 ..."
echo

COUNT=0
FAIL=0

while IFS= read -r F; do
  [ -f "$F" ] || continue
  if rm -f "$F" 2>/dev/null; then
    COUNT=$(( COUNT + 1 ))
  else
    if rm -f "$F" 2>/dev/null; then
      COUNT=$(( COUNT + 1 ))
    else
      FAIL=$(( FAIL + 1 ))
      echo "    失败: $F"
    fi
  fi
done < "$LIST"

# 再扫一次确认残留
REMAIN=$(find / \( -path /proc -o -path /sys -o -path /dev \) -prune -o -type f -iname '*.zip' -print 2>/dev/null | wc -l)

echo
echo "========================================"
echo "  清理完成"
echo "========================================"
echo "  扫描到: $TOTAL 个"
echo "  已删除: $COUNT 个"
echo "  删除失败: $FAIL 个"
echo "  残留: $REMAIN 个"

rm -f "$LIST"

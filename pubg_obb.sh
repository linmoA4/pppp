#!/system/bin/sh

# 切换到 Shizuku (rish)
RISH="/data/data/bin.mt.plus/rish"
if [ -f "$RISH" ]; then
  if [ "$(id -u 2>/dev/null)" != "2000" ]; then
    exec "$RISH" "$0"
  fi
fi

MODEL=$(getprop ro.product.model)
SDK=$(getprop ro.build.version.sdk)
case "$SDK" in
  29) SYS="Android 10";; 30) SYS="Android 11";; 31) SYS="Android 12";;
  32) SYS="Android 13";; 33) SYS="Android 14";; 34) SYS="Android 15";;
  *)  SYS="SDK $SDK";;
esac

NATIVE="/storage/emulated/0/Android/obb"
CONTAINER="/storage/emulated/0/Android/data/com.tencent.igce/Android/obb"

ESC=$(printf '\033')
C="${ESC}[1;36m"
G="${ESC}[1;32m"
Y="${ESC}[1;33m"
R="${ESC}[1;31m"
D="${ESC}[0m"

# 根据标题居中画框
title_box() {
  local text="$1"
  local w=30                              # 框内宽度
  local pad=$(( (w - ${#text}) / 2 ))
  local spaces=""
  local i=0
  while [ "$i" -lt "$pad" ]; do
    spaces="$spaces "
    i=$((i + 1))
  done

  local bar=""
  i=0
  while [ "$i" -lt "$w" ]; do
    bar="${bar}─"
    i=$((i + 1))
  done

  printf "  ${C}╭${bar}╮$D\n"
  printf "  ${C}│$D${spaces}%s${spaces}$D  ${C}│$D\n" "$text"
  printf "  ${C}╰${bar}╯$D\n"
}

hr() {
  local bar=""
  local i=0
  while [ "$i" -lt 30 ]; do
    bar="${bar}─"
    i=$((i + 1))
  done
  printf "  ${C}%s$D\n" "$bar"
}

sep() { printf "\n"; }

ok()   { printf "  ${G}✓$D %s\n" "$1"; }
info() { printf "  ${C}·$D %s\n" "$1"; }
warn() { printf "  ${Y}!$D %s\n" "$1"; }
err()  { printf "  ${R}×$D %s\n" "$1"; }

prompt() {
  printf "  ${C}➜$D %s" "$1"
}

install_obb() {
  local pkg="$1" obb_root="$2" title="$3"
  local obb_name="main.21125.${pkg}.obb"
  local dest="${obb_root}/${pkg}/${obb_name}"

  sep; title_box "$title"
  info "包名: ${Y}$pkg${D}"
  info "目标: $dest"

  if [ -f "$dest" ]; then
    ok "已存在 (大小: $(stat -c %s "$dest" 2>/dev/null))"
    printf "  强制重写? [y/N] "; read -r a
    case "$a" in y|Y) rm -f "$dest";; *) return;; esac
  fi

  sep
  info "扫描本机 OBB ..."
  local src
  src=$(find /storage/emulated/0 \
    -path "/storage/emulated/0/Android/data" -prune -o \
    -path "/storage/emulated/0/Android/obb"  -prune -o \
    -type f -name "$obb_name" -print 2>/dev/null | head -n1)

  if [ -z "$src" ]; then
    err "未找到 $obb_name，请先把文件放到内部存储"
    return 1
  fi
  ok "找到: $src ($(stat -c %s "$src" 2>/dev/null) bytes)"

  printf "  开始复制? [y/N] "; read -r a
  case "$a" in y|Y) :;; *) info "已取消"; return;; esac

  mkdir -p "${obb_root}/${pkg}"
  cp -f "$src" "$dest"
  sync

  local after
  after=$(stat -c %s "$dest" 2>/dev/null || echo 0)
  if [ "$after" = "$(stat -c %s "$src" 2>/dev/null)" ]; then
    ok "完成 ($after bytes)"
  else
    err "大小不一致，请检查"
    return 1
  fi

  printf "  删除源文件? [y/N] "; read -r a
  case "$a" in y|Y) rm -f "$src"; ok "已删除源文件";; *) info "已保留";; esac

  printf "  启动游戏? [y/N] "; read -r a
  case "$a" in
    y|Y)
      local start
      [ "$obb_root" = "$CONTAINER" ] && start="com.tencent.igce" || start="$pkg"
      monkey -p "$start" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
      ok "已发送启动指令"
      ;;
  esac
}

server_menu() {
  local root="$1" title="$2"
  while true; do
    sep; title_box "$title"
    sep
    printf "  ${C}[1]$D 全球服  com.tencent.ig\n"
    printf "  ${C}[2]$D 日韩服  com.pubg.krmobile\n"
    printf "  ${C}[3]$D 台服    com.rekoo.pubgm\n"
    printf "  ${C}[4]$D 越南服  com.vng.pubgmobile\n"
    printf "  ${R}[0]$D 返回上级\n"
    sep
    prompt "选择: "; read -r opt
    case "$opt" in
      1) install_obb "com.tencent.ig" "$root" "全球服" ;;
      2) install_obb "com.pubg.krmobile" "$root" "日韩服" ;;
      3) install_obb "com.rekoo.pubgm" "$root" "台服" ;;
      4) install_obb "com.vng.pubgmobile" "$root" "越南服" ;;
      0) return ;;
      *) warn "无效选项" ;;
    esac
    sep; hr
  done
}

while true; do
  sep; title_box "PUBG OBB 工具"
  sep
  info "设备: $MODEL"
  info "系统: $SYS"
  info "权限: UID $(id -u)"
  sep; hr

  sep
  printf "  ${C}[1]$D 一体路径\n"
  printf "       $NATIVE\n"
  sep
  printf "  ${C}[2]$D 容器路径\n"
  printf "       $CONTAINER\n"
  sep
  printf "  ${R}[0]$D 退出\n"
  sep
  prompt "选择: "; read -r opt

  case "$opt" in
    1) server_menu "$NATIVE" "一体路径" ;;
    2) server_menu "$CONTAINER" "容器路径" ;;
    0) sep; ok "再见"; exit 0 ;;
    *) warn "无效选项" ;;
  esac
done

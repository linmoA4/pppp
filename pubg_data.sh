#!/system/bin/sh

# 切换到 Shizuku (rish)
RISH="/data/data/bin.mt.plus/rish"
if [ -f "$RISH" ]; then
  if [ "$(id -u 2>/dev/null)" != "2000" ]; then
    exec "$RISH" "$0"
  fi
fi

# 颜色 — 用 printf 生成真实 ESC 字节，避免 %s 字面量问题
ESC=$(printf '\033')
C="${ESC}[1;36m"
G="${ESC}[1;32m"
Y="${ESC}[1;33m"
R="${ESC}[1;31m"
D="${ESC}[0m"

# 路径模板
NATIVE_DATA="/storage/emulated/0/Android/data"
CONTAINER_DATA="/storage/emulated/0/Android/data/com.tencent.igce/Android/data"

# ── 工具函数 ──

# 标题居中画框，宽 30
title_box() {
  local text="$1" w=30
  local pad=$(( (w - ${#text}) / 2 ))
  local spaces="" i=0
  while [ "$i" -lt "$pad" ]; do spaces="${spaces} "; i=$((i+1)); done
  local bar="" i=0
  while [ "$i" -lt "$w" ]; do bar="${bar}─"; i=$((i+1)); done

  printf '\n'
  printf '  %s╭%s╮%s\n' "$C" "$bar" "$D"
  printf '  %s│%s%s%s  %s│%s\n' "$C" "$spaces" "$text" "$spaces" "$C" "$D"
  printf '  %s╰%s╯%s\n' "$C" "$bar" "$D"
}

hr() {
  local bar="" i=0
  while [ "$i" -lt 30 ]; do bar="${bar}─"; i=$((i+1)); done
  printf '  %s%s%s\n' "$C" "$bar" "$D"
}

sep()  { printf '\n'; }

ok()   { printf '  %s✓%s %s\n' "$G" "$D" "$1"; }
info() { printf '  %s·%s %s\n' "$C" "$D" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$D" "$1"; }
err()  { printf '  %s×%s %s\n' "$R" "$D" "$1"; }
prompt(){ printf '  %s➜%s %s' "$C" "$D" "$1"; }

# 目录大小 (KB)
size_of() {
  if [ -d "$1" ]; then
    du -sk "$1" 2>/dev/null | awk '{print $1}'
  else
    echo 0
  fi
}

# ── 复制 files 核心 ──

copy_files() {
  local pkg="$1" data_root="$2" title="$3"
  local target="${data_root}/${pkg}/files"
  local parent="${data_root}/${pkg}"

  sep
  title_box "$title"
  info "包名: ${pkg}"
  info "目标: ${target}"

  if [ ! -d "$parent" ]; then
    warn "父目录不存在: ${parent}"
    printf '  创建? [y/N] '; read -r a
    case "$a" in y|Y) mkdir -p "$parent";; *) return;; esac
  fi

  local before_kb=0
  if [ -d "$target" ]; then
    before_kb=$(size_of "$target")
    info "已存在 files 目录 (约 ${before_kb} KB)"
  else
    info "目标 files 不存在，将新建"
  fi

  sep
  info "扫描本机同服 files 备份 ..."

  local src
  src=$(find /storage/emulated/0 \
    -path "/storage/emulated/0/Android/data" -prune -o \
    -path "/storage/emulated/0/Android/obb"  -prune -o \
    -type d -name "files" -path "*/${pkg}/*" -print 2>/dev/null | head -n1)

  if [ -z "$src" ]; then
    warn "没有在内部存储找到 ${pkg} 的 files 备份"
    printf '  手动输入源 files 路径 (留空取消): '; read -r src
    [ -z "$src" ] && return 1
    [ ! -d "$src" ] && err "路径不存在: $src" && return 1
  fi

  local src_kb
  src_kb=$(size_of "$src")
  ok "源: ${src} (约 ${src_kb} KB)"

  sep
  warn "将直接覆盖目标 files，操作不可撤销"
  printf '  开始复制并覆盖? [y/N] '; read -r a
  case "$a" in y|Y) :;; *) info "已取消"; return;; esac

  info "复制中 ..."
  rm -rf "$target"
  mkdir -p "$target"
  cp -rf "$src"/. "$target"/
  sync

  local after_kb
  after_kb=$(size_of "$target")

  if [ "$after_kb" -gt 0 ]; then
    ok "完成 (目标大小约 ${after_kb} KB)"
  else
    err "目标大小为 0，请检查源目录或权限"
    return 1
  fi

  printf '  删除源 files? [y/N] '; read -r a
  case "$a" in y|Y) rm -rf "$src"; ok "已删除源";; *) info "已保留源";; esac
}

# ── 服务器选择 ──

server_menu() {
  local root="$1" title="$2"
  while true; do
    sep
    title_box "$title"
    sep
    printf '  %s[1]%s 全球服  com.tencent.ig\n' "$C" "$D"
    printf '  %s[2]%s 日韩服  com.pubg.krmobile\n' "$C" "$D"
    printf '  %s[3]%s 台服    com.rekoo.pubgm\n' "$C" "$D"
    printf '  %s[4]%s 越南服  com.vng.pubgmobile\n' "$C" "$D"
    printf '  %s[0]%s 返回上级\n' "$R" "$D"
    sep
    prompt "选择: "; read -r opt
    case "$opt" in
      1) copy_files "com.tencent.ig" "$root" "全球服" ;;
      2) copy_files "com.pubg.krmobile" "$root" "日韩服" ;;
      3) copy_files "com.rekoo.pubgm" "$root" "台服" ;;
      4) copy_files "com.vng.pubgmobile" "$root" "越南服" ;;
      0) return ;;
      *) warn "无效选项" ;;
    esac
    sep
    hr
  done
}

# ── 主菜单 ──

while true; do
  sep
  title_box "PUBG 数据 files 复制"
  sep
  info "权限: UID $(id -u)"
  info "一体路径: ${NATIVE_DATA}/<包名>/files"
  info "容器路径: ${CONTAINER_DATA}/<包名>/files"
  sep
  hr

  sep
  printf '  %s[1]%s 一体路径\n' "$C" "$D"
  printf '       %s\n' "$NATIVE_DATA/"
  sep
  printf '  %s[2]%s 容器路径\n' "$C" "$D"
  printf '       %s/\n' "$CONTAINER_DATA"
  sep
  printf '  %s[0]%s 退出\n' "$R" "$D"
  sep
  prompt "选择: "; read -r opt

  case "$opt" in
    1) server_menu "$NATIVE_DATA" "一体路径" ;;
    2) server_menu "$CONTAINER_DATA" "容器路径" ;;
    0) sep; ok "再见"; exit 0 ;;
    *) warn "无效选项" ;;
  esac
done

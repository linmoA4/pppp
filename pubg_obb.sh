#!/system/bin/sh

# ═══════════════════════════════════════════════════════════
#  PUBG OBB 导入工具
#  自动检测 Shizuku 权限
# ═══════════════════════════════════════════════════════════
# 自动检测 Shizuku 权限
RISH="/data/data/bin.mt.plus/rish"
if [ -f "$RISH" ]; then
  exec /system/bin/sh "$RISH" "$0" "$@"
fi

ESC=$(printf '\033')
D="${ESC}[0m"
C="${ESC}[1;36m"
G="${ESC}[1;32m"
Y="${ESC}[1;33m"
R="${ESC}[1;31m"
B="${ESC}[1;34m"
W="${ESC}[1;37m"

NATIVE="/storage/emulated/0/Android/obb"
CONTAINER="/storage/emulated/0/Android/data/com.tencent.igce/Android/obb"

server_label() {
  case "$1" in
    global) printf "${W}🌐 全球服${D}" ;;
    krjp)   printf "${Y}🇯🇵 日韩服${D}" ;;
    tw)     printf "${B}🇹🇼 台服${D}" ;;
    vn)     printf "${R}🇻🇳 越南服${D}" ;;
  esac
}

box() {
  printf "\n"
  printf "  ${C}╭────────────────────────────╮${D}\n"
  printf "  ${C}│${D}            %s            ${C}│${D}\n" "$1"
  printf "  ${C}╰────────────────────────────╯${D}\n"
}

hr() { printf "  ${C}──────────────────────────────${D}\n"; }
ok() { printf "  ${G}✓${D} %s\n" "$1"; }
info() { printf "  ${C}·${D} %s\n" "$1"; }
warn() { printf "  ${Y}!${D} %s\n" "$1"; }
err() { printf "  ${R}×${D} %s\n" "$1"; }

# 查找 OBB
find_obb() {
  local pkg="$1" obb_name="main.21125.${pkg}.obb"
  find /storage/emulated/0 \
    -path "/storage/emulated/0/Android/data" -prune -o \
    -path "/storage/emulated/0/Android/obb"  -prune -o \
    -type f -name "$obb_name" -print 2>/dev/null | head -n1
}

# 安装 OBB（全自动，不询问）
install_obb() {
  local key="$1" root="$2"
  local pkg label_raw

  case "$key" in
    global) pkg="com.tencent.ig"; label_raw="全球服" ;;
    krjp)   pkg="com.pubg.krmobile"; label_raw="日韩服" ;;
    tw)     pkg="com.rekoo.pubgm"; label_raw="台服" ;;
    vn)     pkg="com.vng.pubgmobile"; label_raw="越南服" ;;
  esac

  box "$label_raw"

  local obb_name="main.21125.${pkg}.obb"
  local dest="${root}/${pkg}/${obb_name}"

  info "目标: $dest"
  hr

  # 已存在? 直接覆盖
  if [ -f "$dest" ]; then
    info "已存在，直接覆盖"
    rm -f "$dest"
  fi

  info "扫描 OBB 文件 ..."
  local src
  src=$(find_obb "$pkg")

  if [ -z "$src" ]; then
    err "未找到 $obb_name"
    err "请先把 OBB 文件放到 /sdcard/Download/"
    return 1
  fi
  ok "找到: $src ($(du -h "$src" 2>/dev/null | awk '{print $1}'))"

  # 直接复制，不询问
  info "正在复制 ..."
  mkdir -p "${root}/${pkg}"
  cp -f "$src" "$dest"
  sync

  if [ -f "$dest" ]; then
    ok "复制完成 ($(du -h "$dest" 2>/dev/null | awk '{print $1}'))"
  else
    err "复制失败 (权限不足?)"
    err "请确保已通过 Shizuku 获取权限"
    return 1
  fi

  # 删除源文件
  rm -f "$src"
  ok "已删除源文件"

  # 启动游戏
  local start
  [ "$root" = "$CONTAINER" ] && start="com.tencent.igce" || start="$pkg"
  monkey -p "$start" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  ok "已启动游戏"
}

# 服务器选择菜单
server_menu() {
  local root="$1" title="$2"
  while true; do
    box "$title"
    printf "\n"
    printf "  ${W}[1]${D} $(server_label global)\n"
    printf "  ${Y}[2]${D} $(server_label krjp)\n"
    printf "  ${B}[3]${D} $(server_label tw)\n"
    printf "  ${R}[4]${D} $(server_label vn)\n"
    printf "  ${R}[0]${D} 返回\n"
    hr
    printf "  ${C}➜${D} 选择: "; read -r opt
    case "$opt" in
      1) install_obb "global" "$root" ;;
      2) install_obb "krjp" "$root" ;;
      3) install_obb "tw" "$root" ;;
      4) install_obb "vn" "$root" ;;
      0) return ;;
      *) warn "无效选项" ;;
    esac
  done
}

# 主循环
while true; do
  box "PUBG OBB 工具"
  printf "\n"
  info "设备: $(getprop ro.product.model)"
  info "系统: Android $(getprop ro.build.version.release)"
  hr

  printf "\n"
  printf "  ${C}[1]${D} 一体路径\n"
  printf "       $NATIVE\n"
  printf "\n"
  printf "  ${C}[2]${D} 容器路径\n"
  printf "       $CONTAINER\n"
  printf "\n"
  printf "  ${R}[0]${D} 退出\n"
  hr
  printf "  ${C}➜${D} 选择: "; read -r opt

  case "$opt" in
    1) server_menu "$NATIVE" "一体路径" ;;
    2) server_menu "$CONTAINER" "容器路径" ;;
    0) printf "\n"; ok "再见"; exit 0 ;;
    *) warn "无效选项" ;;
  esac
done

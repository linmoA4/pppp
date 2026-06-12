#!/system/bin/sh

# 切换到 Shizuku (rish)
RISH="/data/data/bin.mt.plus/rish"
if [ -f "$RISH" ]; then
  if [ "$(id -u 2>/dev/null)" != "2000" ]; then
    exec "$RISH" "$0"
  fi
fi

# 颜色
ESC=$(printf '\033')
C="${ESC}[1;36m"
G="${ESC}[1;32m"
Y="${ESC}[1;33m"
R="${ESC}[1;31m"
D="${ESC}[0m"

# ── 工具 ──
sep() { printf '\n'; }
hr() {
  local bar="" i=0
  while [ "$i" -lt 30 ]; do bar="${bar}─"; i=$((i+1)); done
  printf '  %s%s%s\n' "$C" "$bar" "$D"
}
ok()   { printf '  %s✓%s %s\n' "$G" "$D" "$1"; }
info() { printf '  %s·%s %s\n' "$C" "$D" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$D" "$1"; }
err()  { printf '  %s×%s %s\n' "$R" "$D" "$1"; }

# 直接在当前 shell 读取一个整数（不用 $()）
# $1 输出变量名  $2 提示  $3 最小值  $4 最大值
ask_int() {
  local _var="$1" _prompt="$2" _min="$3" _max="$4" _val _ok=0
  while [ "$_ok" = "0" ]; do
    printf '  %s➜%s %s: ' "$C" "$D" "$_prompt"
    read -r _val
    case "$_val" in
      ''|*[!0-9-]*)
        warn "请输入数字"; continue
        ;;
    esac
    if [ "$_val" -lt "$_min" ] || [ "$_val" -gt "$_max" ]; then
      warn "范围 $_min - $_max"; continue
    fi
    _ok=1
  done
  # 用 eval 直接写到调用方指定的变量里（避免子 shell）
  eval "$_var=\"$_val\""
}

# 电池状态
show_battery() {
  sep
  printf '  %s── 电池状态 ──%s\n' "$C" "$D"
  dumpsys battery 2>/dev/null \
    | grep -E '^  (AC|USB|Wireless|status|level|health|present|technology|temperature|voltage)' \
    | while read -r line; do
        printf '  %s·%s %s\n' "$C" "$D" "$line"
      done
  sep
}

health_name() {
  case "$1" in
    1) echo "unknown" ;;  2) echo "good" ;;      3) echo "overheat" ;;
    4) echo "dead" ;;      5) echo "over_voltage" ;;  6) echo "fail" ;;  7) echo "cold" ;;
    *) echo "?" ;;
  esac
}
status_name() {
  case "$1" in
    1) echo "unknown" ;;  2) echo "charging" ;;  3) echo "discharging" ;;
    4) echo "not_charging" ;;  5) echo "full" ;;
    *) echo "?" ;;
  esac
}

# ── 主菜单 ──
while true; do
  show_battery

  printf '  %s╭────────────────────────────╮%s\n' "$C" "$D"
  printf '  %s│     电池模拟控制台         │%s\n' "$C" "$D"
  printf '  %s╰────────────────────────────╯%s\n' "$C" "$D"
  info "当前 UID: $(id -u)"
  sep

  printf '  %s── 充电方式 ──%s\n' "$C" "$D"
  printf '  %s[1]%s AC 充电\n' "$C" "$D"
  printf '  %s[2]%s USB 充电\n' "$C" "$D"
  printf '  %s[3]%s 无线充电\n' "$C" "$D"
  printf '  %s[4]%s 未接入电源 (放电)\n' "$C" "$D"

  printf '  %s── 电量 ──%s\n' "$C" "$D"
  printf '  %s[5]%s 设为 100%%\n' "$C" "$D"
  printf '  %s[6]%s 设为 1%%\n' "$C" "$D"
  printf '  %s[7]%s 自定义电量 (0-100)\n' "$C" "$D"

  printf '  %s── 电池健康 ──%s\n' "$C" "$D"
  printf '  %s[8]%s good (良好 / 2)\n' "$C" "$D"
  printf '  %s[9]%s overheat (过热 / 3)\n' "$C" "$D"
  printf '  %s[10]%s dead (报废 / 4)\n' "$C" "$D"
  printf '  %s[11]%s over_voltage (过压 / 5)\n' "$C" "$D"
  printf '  %s[12]%s cold (过冷 / 7)\n' "$C" "$D"
  printf '  %s[13]%s 自定义健康值 (1-7)\n' "$C" "$D"

  printf '  %s── 温度 / 电压 ──%s\n' "$C" "$D"
  printf '  %s[14]%s 自定义温度 (单位 0.1°C, 例 250)\n' "$C" "$D"
  printf '  %s[15]%s 自定义电压 (单位 mV, 例 3800)\n' "$C" "$D"

  printf '  %s── 状态 ──%s\n' "$C" "$D"
  printf '  %s[16]%s 自定义充电状态 (1-5)\n' "$C" "$D"
  printf '  %s[17]%s 满电状态 (status=5)\n' "$C" "$D"

  printf '  %s── 控制 ──%s\n' "$C" "$D"
  printf '  %s[99]%s 恢复真实电池\n' "$G" "$D"
  printf '  %s[0]%s 退出\n' "$R" "$D"

  sep
  printf '  %s➜%s 选择: ' "$C" "$D"; read -r CHOICE
  sep

  case "$CHOICE" in
    1) dumpsys battery set ac 1; dumpsys battery set usb 0; dumpsys battery set wireless 0; dumpsys battery set status 2; ok "已设为 AC 充电" ;;
    2) dumpsys battery set ac 0; dumpsys battery set usb 1; dumpsys battery set wireless 0; dumpsys battery set status 2; ok "已设为 USB 充电" ;;
    3) dumpsys battery set ac 0; dumpsys battery set usb 0; dumpsys battery set wireless 1; dumpsys battery set status 2; ok "已设为无线充电" ;;
    4) dumpsys battery set ac 0; dumpsys battery set usb 0; dumpsys battery set wireless 0; dumpsys battery set status 3; ok "已设为放电" ;;

    5) dumpsys battery set level 100; dumpsys battery set status 5; ok "电量 100% / 满电" ;;
    6) dumpsys battery set level 1;   dumpsys battery set status 3; ok "电量 1% / 放电" ;;
    7)
      ask_int LVL "电量 (0-100)" 0 100
      dumpsys battery set level "$LVL"
      ok "电量已设为 ${LVL}%"
      ;;

    8)  dumpsys battery set health 2; ok "健康 = good ($(health_name 2))" ;;
    9)  dumpsys battery set health 3; ok "健康 = overheat ($(health_name 3))" ;;
    10) dumpsys battery set health 4; ok "健康 = dead ($(health_name 4))" ;;
    11) dumpsys battery set health 5; ok "健康 = over_voltage ($(health_name 5))" ;;
    12) dumpsys battery set health 7; ok "健康 = cold ($(health_name 7))" ;;
    13)
      ask_int H "健康值 (1=unknown 2=good 3=overheat 4=dead 5=over_voltage 6=fail 7=cold)" 1 7
      dumpsys battery set health "$H"
      ok "健康 = $(health_name $H)"
      ;;

    14)
      ask_int T "温度 (整数, 单位 0.1°C, 例 250=25.0°C)" -1000 2000
      dumpsys battery set temperature "$T"
      ok "温度 = ${T} (显示值的 1/10 °C)"
      ;;
    15)
      ask_int V "电压 (整数 mV, 例 3800=3.8V)" 0 20000
      dumpsys battery set voltage "$V"
      ok "电压 = ${V} mV"
      ;;

    16)
      ask_int S "充电状态 (1=unknown 2=charging 3=discharging 4=not_charging 5=full)" 1 5
      dumpsys battery set status "$S"
      ok "status = $(status_name $S)"
      ;;
    17) dumpsys battery set status 5; ok "已设为满电 status" ;;

    99) dumpsys battery reset; ok "已恢复真实电池数据" ;;
    0)  ok "再见"; exit 0 ;;
    *)  warn "无效选项" ;;
  esac

  sep
  printf '  %s·%s 按回车继续 ...' "$C" "$D"; read -r _
done

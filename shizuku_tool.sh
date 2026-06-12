#!/system/bin/sh

# ═══════════════════════════════════════════════════════════
#  Shizuku 集权 ADB 工具 (Centralized Shell Tool)
#  所有命令在 Shizuku shell (UID 2000) 下执行
# ═══════════════════════════════════════════════════════════

RISH="/data/data/bin.mt.plus/rish"
if [ -f "$RISH" ]; then
  if [ "$(id -u 2>/dev/null)" != "2000" ]; then
    exec "$RISH" "$0"
  fi
fi

# ── 颜色 / 视觉 ─────────────────────────────────────────
ESC=$(printf '\033')
C="${ESC}[1;36m"    # cyan (主题)
G="${ESC}[1;32m"    # green (成功)
Y="${ESC}[1;33m"    # yellow (提示)
R="${ESC}[1;31m"    # red (错误)
M="${ESC}[1;35m"    # magenta (分组)
D="${ESC}[0m"

sep() { printf '\n'; }
hr() {
  local b="" i=0
  while [ "$i" -lt 38 ]; do b="${b}─"; i=$((i+1)); done
  printf '  %s%s%s\n' "$C" "$b" "$D"
}
box() {
  local text="$1" w=38 pad spaces="" b="" i=0
  pad=$(( (w - ${#text}) / 2 ))
  while [ "$i" -lt "$pad" ]; do spaces="${spaces} "; i=$((i+1)); done
  b="" i=0
  while [ "$i" -lt "$w" ]; do b="${b}─"; i=$((i+1)); done
  sep
  printf '  %s╭%s╮%s\n' "$C" "$b" "$D"
  printf '  %s│%s%s%s  %s│%s\n' "$C" "$spaces" "$text" "$spaces" "$C" "$D"
  printf '  %s╰%s╯%s\n' "$C" "$b" "$D"
}
ok()   { printf '  %s✓%s %s\n' "$G" "$D" "$1"; }
info() { printf '  %s·%s %s\n' "$C" "$D" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$D" "$1"; }
err()  { printf '  %s×%s %s\n' "$R" "$D" "$1"; }
kv()   { printf '  %s·%s %s = %s\n' "$C" "$D" "$1" "$2"; }

# 直接在当前 shell 读取整数（避免子 shell）
ask_int() {
  local _v="$1" _p="$2" _mn="$3" _mx="$4" _val _ok=0
  while [ "$_ok" = "0" ]; do
    printf '  %s➜%s %s: ' "$C" "$D" "$_p"
    read -r _val
    case "$_val" in
      ''|*[!0-9-]*) warn "请输入数字"; continue ;;
    esac
    if [ "$_val" -lt "$_mn" ] || [ "$_val" -gt "$_mx" ]; then
      warn "范围 $_mn - $_mx"; continue
    fi
    _ok=1
  done
  eval "$_v=\"$_val\""
}

# 读取字符串（可能带空格）
ask_str() {
  local _v="$1" _p="$2" _val
  printf '  %s➜%s %s: ' "$C" "$D" "$_p"
  read -r _val
  eval "$_v=\"$_val\""
}

# 按 y/N 确认
ask_yes() {
  printf '  %s?%s %s [y/N]: ' "$Y" "$D" "$1"
  read -r a
  case "$a" in y|Y) return 0 ;; *) return 1 ;; esac
}

# 执行命令并显示结果
run_show() {
  local cmd="$*"
  info "执行: $cmd"
  eval "$cmd" 2>&1 | sed 's/^/    /'
  ok "完成"
}

# 按回车继续
pause() {
  sep
  printf '  %s·%s 按回车继续 ...' "$C" "$D"; read -r _
}

# ═══════════════════════════════════════════════════════════
#  1. 设备信息
# ═══════════════════════════════════════════════════════════
fn_device_info() {
  box "设备信息"
  kv "品牌"       "$(getprop ro.product.brand)"
  kv "型号"       "$(getprop ro.product.model)"
  kv "设备名"     "$(getprop ro.product.name)"
  kv "CPU ABI"    "$(getprop ro.product.cpu.abi)"
  kv "Android"    "$(getprop ro.build.version.release)"
  kv "SDK"        "$(getprop ro.build.version.sdk)"
  kv "编译版本"   "$(getprop ro.build.display.id)"
  kv "基带"       "$(getprop gsm.version.baseband)"
  kv "内核"       "$(cat /proc/version 2>/dev/null | awk '{print $1,$2,$3}')"
  kv "当前 UID"   "$(id -u)"
  kv "存储空间"   "$(df -h /data 2>/dev/null | tail -1 | awk '{print $2 " / " $3 " / " $4}')"
  kv "可用内存"   "$(grep -E 'Mem(Free|Total|Available):' /proc/meminfo 2>/dev/null | tr -s ' ' | sed 's/^/  /')"
  pause
}

# ═══════════════════════════════════════════════════════════
#  2. 电池控制 (mock charge)
# ═══════════════════════════════════════════════════════════
fn_battery_status() {
  sep
  printf '  %s── 电池状态 ──%s\n' "$C" "$D"
  dumpsys battery 2>/dev/null | grep -E '^  (AC|USB|Wireless|status|level|health|present|technology|temperature|voltage)' | sed 's/^/    /'
  sep
}

health_name() {
  case "$1" in
    1) echo "unknown" ;; 2) echo "good" ;; 3) echo "overheat" ;;
    4) echo "dead" ;; 5) echo "over_voltage" ;; 6) echo "fail" ;; 7) echo "cold" ;;
    *) echo "?" ;;
  esac
}
status_name() {
  case "$1" in
    1) echo "unknown" ;; 2) echo "charging" ;; 3) echo "discharging" ;;
    4) echo "not_charging" ;; 5) echo "full" ;;
    *) echo "?" ;;
  esac
}

fn_battery_menu() {
  while true; do
    fn_battery_status
    printf '  %s── 充电方式 ──%s\n' "$M" "$D"
    printf '  %s[1]%s AC 充电\n' "$C" "$D"
    printf '  %s[2]%s USB 充电\n' "$C" "$D"
    printf '  %s[3]%s 无线充电\n' "$C" "$D"
    printf '  %s[4]%s 放电 (未接入)\n' "$C" "$D"
    printf '  %s── 电量 ──%s\n' "$M" "$D"
    printf '  %s[5]%s 100%%\n' "$C" "$D"
    printf '  %s[6]%s 1%%\n' "$C" "$D"
    printf '  %s[7]%s 自定义电量\n' "$C" "$D"
    printf '  %s── 健康 ──%s\n' "$M" "$D"
    printf '  %s[8]%s good (2)     %s[9]%s overheat (3)\n' "$C" "$D" "$C" "$D"
    printf '  %s[10]%s dead (4)     %s[11]%s over_voltage (5)\n' "$C" "$D" "$C" "$D"
    printf '  %s[12]%s cold (7)     %s[13]%s 自定义健康值\n' "$C" "$D" "$C" "$D"
    printf '  %s── 温度 / 电压 ──%s\n' "$M" "$D"
    printf '  %s[14]%s 自定义温度 (0.1°C)\n' "$C" "$D"
    printf '  %s[15]%s 自定义电压 (mV)\n' "$C" "$D"
    printf '  %s── 状态 / 恢复 ──%s\n' "$M" "$D"
    printf '  %s[16]%s 自定义充电状态 (1-5)\n' "$C" "$D"
    printf '  %s[17]%s 满电 status\n' "$C" "$D"
    printf '  %s[99]%s 恢复真实电池\n' "$G" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"

    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) dumpsys battery set ac 1; dumpsys battery set usb 0; dumpsys battery set wireless 0; dumpsys battery set status 2; ok "已设 AC" ;;
      2) dumpsys battery set ac 0; dumpsys battery set usb 1; dumpsys battery set wireless 0; dumpsys battery set status 2; ok "已设 USB" ;;
      3) dumpsys battery set ac 0; dumpsys battery set usb 0; dumpsys battery set wireless 1; dumpsys battery set status 2; ok "已设无线" ;;
      4) dumpsys battery set ac 0; dumpsys battery set usb 0; dumpsys battery set wireless 0; dumpsys battery set status 3; ok "已设放电" ;;
      5) dumpsys battery set level 100; dumpsys battery set status 5; ok "电量 100%" ;;
      6) dumpsys battery set level 1;   dumpsys battery set status 3; ok "电量 1%" ;;
      7) ask_int LVL "电量 (0-100)" 0 100; dumpsys battery set level "$LVL"; ok "电量 = ${LVL}%" ;;
      8) dumpsys battery set health 2; ok "健康 = good" ;;
      9) dumpsys battery set health 3; ok "健康 = overheat" ;;
      10) dumpsys battery set health 4; ok "健康 = dead" ;;
      11) dumpsys battery set health 5; ok "健康 = over_voltage" ;;
      12) dumpsys battery set health 7; ok "健康 = cold" ;;
      13) ask_int H "健康 (1-7)" 1 7; dumpsys battery set health "$H"; ok "健康 = $(health_name $H)" ;;
      14) ask_int T "温度 (单位 0.1°C, 例 250)" -1000 2000; dumpsys battery set temperature "$T"; ok "温度 = ${T}" ;;
      15) ask_int V "电压 (mV, 例 3800)" 0 20000; dumpsys battery set voltage "$V"; ok "电压 = ${V} mV" ;;
      16) ask_int S "状态 (1-5)" 1 5; dumpsys battery set status "$S"; ok "status = $(status_name $S)" ;;
      17) dumpsys battery set status 5; ok "满电" ;;
      99) dumpsys battery reset; ok "已恢复真实电池" ;;
      0)  return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  3. 系统设置 (亮度 / 动画 / 休眠 / 旋转 / 开发者)
# ═══════════════════════════════════════════════════════════
fn_settings_set() {
  local ns="$1" key="$2" val="$3"
  info "settings put $ns $key $val"
  if settings put "$ns" "$key" "$val" 2>/dev/null; then
    ok "设置成功: $key = $val"
  else
    err "设置失败，请确认 Shizuku 对系统设置的写权限"
  fi
}

fn_settings_menu() {
  while true; do
    box "系统设置修改"
    printf '  %s── 显示 ──%s\n' "$M" "$D"
    printf '  %s[1]%s 屏幕亮度 (0-255)\n' "$C" "$D"
    printf '  %s[2]%s 自动亮度开关\n' "$C" "$D"
    printf '  %s[3]%s 自动旋转开关\n' "$C" "$D"
    printf '  %s[4]%s 屏幕休眠时间 (毫秒)\n' "$C" "$D"
    printf '  %s── 动画 / 开发 ──%s\n' "$M" "$D"
    printf '  %s[5]%s 关闭所有动画\n' "$C" "$D"
    printf '  %s[6]%s 恢复动画默认\n' "$C" "$D"
    printf '  %s[7]%s 强制允许调试设置\n' "$C" "$D"
    printf '  %s[8]%s 自定义设置项 (手动: namespace key value)\n' "$C" "$D"
    printf '  %s── 查看当前 ──%s\n' "$M" "$D"
    printf '  %s[9]%s 查看所有 system 项\n' "$C" "$D"
    printf '  %s[10]%s 查看所有 global 项\n' "$C" "$D"
    printf '  %s[11]%s 查看所有 secure 项\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) ask_int B "亮度 (0-255)" 0 255; fn_settings_set system screen_brightness "$B" ;;
      2) ask_int A "自动亮度 1=开 0=关" 0 1; fn_settings_set system screen_brightness_mode "$A" ;;
      3) ask_int A "自动旋转 1=开 0=关" 0 1; fn_settings_set system accelerometer_rotation "$A" ;;
      4) ask_int T "休眠时间 (毫秒, 例 60000=60s)" 1 86400000; fn_settings_set system screen_off_timeout "$T" ;;
      5) fn_settings_set global animator_duration_scale 0
         fn_settings_set global transition_animation_scale 0
         fn_settings_set global window_animation_scale 0 ;;
      6) fn_settings_set global animator_duration_scale 1
         fn_settings_set global transition_animation_scale 1
         fn_settings_set global window_animation_scale 1 ;;
      7) fn_settings_set global adb_enabled 1; fn_settings_set system development_settings_enabled 1; fn_settings_set global verifier_verify_adb_installs 0; ok "已开启调试" ;;
      8)
        ask_str NS "namespace (system/global/secure)"
        ask_str KEY "key"
        ask_str VAL "value"
        [ -n "$NS" ] && [ -n "$KEY" ] && [ -n "$VAL" ] && fn_settings_set "$NS" "$KEY" "$VAL"
        ;;
      9)  info "当前 system 项:"; settings list system 2>/dev/null | sed 's/^/    /' | head -50; pause ;;
      10) info "当前 global 项:"; settings list global 2>/dev/null | sed 's/^/    /' | head -50; pause ;;
      11) info "当前 secure 项:"; settings list secure 2>/dev/null | sed 's/^/    /' | head -50; pause ;;
      0)  return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  包名 → 应用名 翻译
# ═══════════════════════════════════════════════════════════
label_of_pkg() {
  # 参数 $1 = 包名，输出格式 "包名:应用名"
  local p="$1" name=""
  case "$p" in
    com.vivo.deformer)                         name="vivo系统应用(Deformer)" ;;
    com.vivo.e2ee)                              name="vivo系统应用(e2ee安全)" ;;
    com.android.server.deviceconfig.resources)  name="Android系统框架" ;;
    com.vivo.upnpserver)                        name="vivo DLNA/UPnP服务" ;;
    com.bytedance.trae.cn)                      name="字节跳动系统组件" ;;
    com.vivo.nightpearl)                        name="vivo系统应用(NightPearl)" ;;
    cn.wps.moffice_eng)                         name="WPS Office(工程版)" ;;
    com.android.providers.contacts)             name="Android 通讯录存储" ;;
    com.android.companiondevicemanager)         name="Android 配套设备管理器" ;;
    com.android.cts.priv.ctsshim)               name="Android CTS测试组件" ;;
    com.termux)                                 name="Termux" ;;
    com.android.providers.downloads)            name="Android 下载管理存储" ;;
    com.android.bluetoothmidiservice)           name="Android 蓝牙MIDI服务" ;;
    com.twitter.android)                        name="X(推特)" ;;
    com.vivo.networkimprove)                    name="vivo网络优化服务" ;;
    com.android.credentialmanager)              name="Android 凭据管理器" ;;
    com.vivo.vmdri)                             name="vivo系统应用(vMDRI)" ;;
    com.vivo.devicepower)                       name="vivo功耗管理服务" ;;
    com.xunlei.downloadprovider)                name="迅雷下载核心" ;;
    com.vivo.audiofx)                           name="vivo音效服务" ;;
    com.google.android.printservice.recommendation) name="Google 打印服务建议" ;;
    com.goodix)                                 name="汇顶(Goodix)指纹/触控驱动" ;;
    com.vivo.safecenter)                        name="vivo安全中心" ;;
    com.android.keychain)                       name="Android 密钥链" ;;
    com.google.android.accessibility.switchaccess) name="Google 开关控制无障碍" ;;
    com.android.bbk.lockscreen3)                name="vivo 锁屏(Origin OS)" ;;
    com.microsoft.office.outlook)               name="Microsoft Outlook" ;;
    com.example.kbattery)                       name="测试/调试应用(kBattery)" ;;
    com.vivo.car.networking)                    name="vivo车机互联服务" ;;
    com.microsoft.emmx)                         name="Microsoft Edge" ;;
    com.android.shell)                          name="Android Shell" ;;
    com.vivo.sps)                               name="vivo SPS服务" ;;
    com.mediatek.atci.service)                  name="联发科ATCI服务" ;;
    com.vivo.base.gallery)                      name="vivo相册基础模块" ;;
    com.vivo.defaultPlayer)                     name="vivo默认视频播放器" ;;
    com.vivo.gametrain)                         name="vivo游戏加速/训练" ;;
    com.xunmeng.pinduoduo)                      name="拼多多" ;;
    com.tencent.csapp)                          name="腾讯客服App" ;;
    com.vivo.livewallpaper.box)                 name="vivo动态壁纸盒子" ;;
    com.vivo.globaldragdrop)                    name="vivo全局拖拽" ;;
    com.duosecurity.duomobile)                  name="Duo Mobile" ;;
    com.vivo.share)                             name="vivo互传" ;;
    com.android.DeviceAsWebcam)                 name="Android 摄像头作为Webcam" ;;
    com.suxing.calendar)                        name="溯源日历(第三方)" ;;
    com.android.sharedstoragebackup)            name="Android 共享存储备份" ;;
    com.vivo.accessibilityenhance)              name="vivo无障碍增强" ;;
    com.android.providers.media)                name="Android 媒体存储" ;;
    com.android.providers.calendar)             name="Android 日历存储" ;;
    com.android.incallui)                       name="Android 来电界面" ;;
    com.android.providers.blockednumber)        name="Android 黑名单存储" ;;
    com.vivo.base.vtouch)                       name="vivo侧边栏触控(vTouch)" ;;
    com.android.statementservice)               name="Android 声明验证服务" ;;
    com.vivo.smartmultiwindow)                  name="vivo智能多窗口" ;;
    com.android.vendors.bridge.softsim)         name="SoftSIM桥接服务" ;;
    com.byyoung.extract)                        name="解压/提取工具(ByYoung)" ;;
    com.vivo.sos)                               name="vivo紧急求助(SOS)" ;;
    com.mediatek.lbs.em2.ui)                    name="联发科LBS工程模式" ;;
    com.vivo.ai.ime.nex)                        name="vivo智能输入法(Jovi输入)" ;;
    com.android.proxyhandler)                   name="Android 代理处理" ;;
    com.vivo.vivo3rdalgoservice)                name="vivo三方算法服务" ;;
    com.vivo.setupwizard)                       name="vivo开机向导" ;;
    com.android.emergency)                      name="Android 紧急信息" ;;
    com.android.healthconnect.controller)       name="Android 健康连接" ;;
    com.vivo.fingerprint)                       name="vivo指纹识别" ;;
    com.vivo.agent)                             name="vivo系统代理服务" ;;
    com.vivo.widget.calendar)                   name="vivo日历小组件" ;;
    com.google.android.gm)                      name="Gmail" ;;
    com.android.carrierdefaultapp)              name="Android 运营商默认应用" ;;
    com.unionpay.tsmservice)                    name="银联TSM服务" ;;
    com.android.backupconfirm)                  name="Android 备份确认" ;;
    com.bbk.account)                            name="vivo账号(步步高)" ;;
    com.org.lsposed.lspatch)                    name="LSPatch(太极/LSPosed补丁)" ;;
    com.android.mtp)                            name="Android MTP媒体传输" ;;
    com.vivo.suggestion)                        name="vivo负一屏建议" ;;
    com.vivo.weather)                           name="vivo天气" ;;
    com.sohu.inputmethod.sogou.vivo)            name="搜狗输入法(vivo版)" ;;
    com.vivo.android.connectivity.common.resources.overlay) name="vivo网络资源叠加层" ;;
    com.vivo.floatingball)                      name="vivo悬浮球" ;;
    com.android.theme.font.notoserifsource)     name="Android Noto字体主题" ;;
    com.mobiletools.systemhelper)               name="系统辅助工具(SystemHelper)" ;;
    com.taobao.idlefish)                        name="闲鱼" ;;
    com.vivo.basemanager)                       name="vivo基础管理服务" ;;
    com.vivo.gamespace)                         name="vivo游戏空间" ;;
    com.vivo.vibrator4d)                        name="vivo 4D振动" ;;
    com.vivo.backuprestore)                     name="vivo备份与恢复" ;;
    com.vivo.nfcbaseapp)                        name="vivo NFC基础应用" ;;
    com.android.browser)                        name="Android 原生浏览器(旧版)" ;;
    com.m4399.gamecenter)                       name="4399游戏盒" ;;
    com.tencent.tmgp.cod)                       name="使命召唤手游(COD Mobile)" ;;
    com.gameaccel.rapid)                        name="游戏加速器(Rapid)" ;;
    com.tencent.igce)                           name="腾讯游戏引擎组件" ;;
    com.android.wallpapercropper)               name="Android 壁纸裁剪" ;;
    com.android.notes)                          name="Android 便签/笔记" ;;
    com.vivo.minscreen)                         name="vivo迷你小窗" ;;
    com.android.internal.systemui.navbar.gestural) name="Android 全面屏手势导航" ;;
    com.android.bbklog)                         name="vivo日志收集" ;;
    tw.nekomimi.nekogram)                       name="NekoGram(Telegram第三方)" ;;
    com.coolapk.market)                         name="酷安" ;;
    com.vivo.healthservice)                     name="vivo健康传感器服务" ;;
    mark.via)                                   name="Via浏览器" ;;
    com.vivo.faceui)                            name="vivo面部识别解锁界面" ;;
    com.muyuesgsan.app)                         name="木叶工具(第三方)" ;;
    com.vivo.ai.copilot)                        name="vivo Jovi Copilot" ;;
    com.bbk.calendar)                           name="vivo日历" ;;
    com.google.android.webview)                 name="Android System WebView" ;;
    com.vivo.epm)                               name="vivo企业/设备管理(EPM)" ;;
    com.vivo.systemuiplugin)                    name="vivo状态栏插件" ;;
    android.overlay.vrro)                       name="Android VR叠加层" ;;
    com.android.internal.systemui.navbar.threebutton) name="Android 三键导航栏" ;;
    com.baidu.netdisk)                          name="百度网盘" ;;
    com.etalien.booster)                        name="EtAlien Booster(优化工具)" ;;
    com.android.egg)                            name="Android 彩蛋(Easter Egg)" ;;
    com.vivo.privacylauncher)                   name="vivo私密文件夹/隐藏应用" ;;
    com.vivo.base.player)                       name="vivo媒体播放基础模块" ;;
    com.omarea.vtools)                          name="VTools(安卓调校工具)" ;;
    com.mediatek.telephony)                     name="联发科电话服务" ;;
    com.vivo.familycare.widget)                 name="vivo家庭关怀小组件" ;;
    com.vivo.pem)                               name="vivo权限/隐私管理(PEM)" ;;
    com.didjdk.adbhelper)                       name="ADB Helper" ;;
    com.kaixinkan.ugc.video.atom)               name="开心短视频原子组件" ;;
    com.vivo.gamecube)                          name="vivo游戏魔盒(Game Cube)" ;;
    com.android.wifi.dialogex)                  name="Android Wi-Fi高级对话框" ;;
    com.UCMobile)                               name="UC浏览器" ;;
    com.vivo.ai.gptagent)                       name="vivo AI GPT代理(Jovi)" ;;
    com.mediatek.mdmconfig)                     name="联发科MDM配置" ;;
    com.bbk.scene.databaseprovider)             name="vivo场景数据库" ;;
    com.android.se)                             name="Android 安全单元(SE)" ;;
    com.tencent.wetype)                         name="腾讯文字识别/微信OCR组件" ;;
    com.tencent.tmgp.pubgmhd)                   name="和平精英(国服)" ;;
    com.vivo.telephonyapp)                      name="vivo电话(拨号)" ;;
    com.android.stk)                            name="SIM卡工具包(STK)" ;;
    com.kaixinkan.ugc.video)                    name="开心短视频(开心看看)" ;;
    com.android.bips)                           name="Android 内置打印服务(BIPS)" ;;
    com.mediatek.gnssdebugreport)               name="联发科GNSS调试报告" ;;
    com.mkarpenko.worldbox)                     name="WorldBox(世界盒沙盒)" ;;
    com.vivo.connbase)                          name="vivo连接基础服务" ;;
    com.google.android.projection.gearhead)     name="Android Auto(Google投影)" ;;
    com.vivo.abe)                               name="vivo应用行为引擎(ABE)" ;;
    com.vivo.phonehandoff)                      name="vivo通话手势" ;;
    com.vivo.livewallpaper.behaviorcity)        name="vivo动态壁纸-都市" ;;
    com.vivo.magazine)                          name="vivo杂志锁屏" ;;
    com.easymoon.zhongren)                      name="中人应用(第三方)" ;;
    com.vivo.vhomeguide)                        name="vivo桌面引导" ;;
    com.hortor.juliancysj)                      name="HorTor小游戏/工具" ;;
    cn.cj.pe)                                   name="网易邮箱大师" ;;
    com.android.devicelockcontroller)           name="Android 设备锁定控制器" ;;
    com.android.documentsui)                    name="Android 文件选择器(Documents)" ;;
    com.vivo.connbase.sysui)                    name="vivo连接系统UI" ;;
    com.aliyun.tongyi)                          name="阿里通义(通义千问App)" ;;
    com.rongcard.eid)                           name="eID身份电子认证" ;;
    com.android.health.connect.backuprestore)   name="Android 健康连接备份恢复" ;;
    com.vivo.android.wifi.manufacturer.resources.overlay) name="vivo Wi-Fi厂商资源叠加" ;;
    com.vivo.simplelauncher)                    name="vivo简易启动器" ;;
    com.vivo.voicewakeup)                       name="vivo语音唤醒(Jovi语音)" ;;
    com.android.networkstack.tethering.overlay) name="Android 热点网络栈叠加" ;;
    com.android.providers.downloads.ui)         name="Android 下载管理界面" ;;
    com.android.ons)                            name="Android 运营商网络选择(ONS)" ;;
    com.bbk.cloud)                              name="vivo云服务(i管家云)" ;;
    com.google.android.networkstack.tethering.overlay) name="Google 网络热点叠加" ;;
    com.vivo.pushservice)                       name="vivo推送服务" ;;
    com.android.wifi.system.mainline.resources.overlay) name="Android Wi-Fi主线资源叠加" ;;
    com.baidu.youavideo)                        name="百度影音" ;;
    com.vivo.pay)                               name="vivo支付" ;;
    com.android.wifi.resources)                 name="Android Wi-Fi资源" ;;
    com.vivo.smartoffice)                       name="vivo文档查看器(Office)" ;;
    com.vivo.vms)                               name="vivo消息服务(VMS)" ;;
    com.android.BBKCrontab)                     name="vivo定时任务(Crontab)" ;;
    com.android.filemanager)                    name="Android 文件管理/vivo文件管理" ;;
    com.huawei.appmarket)                       name="华为应用市场" ;;
    android.overlay.vioresrro)                  name="vivo ESR叠加层" ;;
    com.android.simappdialog)                   name="Android SIM应用对话框" ;;
    com.vivo.screenagent)                       name="vivo屏幕助手/录屏代理" ;;
    com.android.sdksandbox)                     name="Android SDK沙箱" ;;
    com.jiaxianb6)                              name="嘉兴B6(第三方工具)" ;;
    com.android.internal.display.cutout.emulation.waterfall) name="Android 瀑布屏刘海模拟" ;;
    com.chinamobile.mcloud)                     name="中国移动云/和多号" ;;
    com.vivo.space)                             name="vivo云服务空间" ;;
    com.vivo.credentialmanager)                 name="vivo凭证管理" ;;
    com.android.traceur)                        name="Android 性能追踪(Traceur)" ;;
    org.telegram.messenger.web)                 name="Telegram Web/第三方" ;;
    com.sword.application)                      name="刀剑/Sword应用(第三方)" ;;
    com.bbk.theme.resources)                    name="vivo主题资源" ;;
    com.vivo.recents)                           name="vivo最近任务(多任务界面)" ;;
    com.vivo.sdkplugin)                         name="vivo SDK插件" ;;
    com.vivo.android.connectivity.mainline.manufacturer.resources.overlay) name="vivo网络主线厂商叠加" ;;
    com.android.location.fused)                 name="Android 融合定位(Fused Location)" ;;
    com.along.dockwalls)                        name="Along动态壁纸" ;;
    com.android.cellbroadcastreceiver)          name="Android 小区广播接收" ;;
    com.vivo.healthwidget)                      name="vivo健康小组件" ;;
    com.android.ondevicepersonalization.services) name="Android 设备端个性化服务" ;;
    com.tencent.mobileqq)                       name="QQ" ;;
    com.vivo.visionaid.builtin)                 name="vivo视觉辅助内置" ;;
    com.tencent.android.qqdownloader)           name="腾讯应用宝" ;;
    com.google.android.configupdater)           name="Google 配置更新" ;;
    com.vivo.launchercopilot)                   name="vivo桌面副驾驶(Launcher Copilot)" ;;
    org.ifaa.aidl.manager)                      name="IFAA指纹/人脸认证联盟" ;;
    com.android.mms)                            name="Android 信息(短信)" ;;
    com.vivo.assistant)                         name="vivo Jovi 建议/智能助理" ;;
    com.bbk.launcher2)                          name="vivo桌面(Launcher2/Origin OS桌面)" ;;
    com.vivo.permissionmanager)                 name="vivo权限管理" ;;
    com.mediatek.location.lppe.main)            name="联发科LPPE定位" ;;
    com.android.internal.display.cutout.emulation.corner) name="Android 角落刘海模拟" ;;
    com.vivo.android.connectivity.manufacturer.resources.overlay) name="vivo Wi-Fi厂商叠加" ;;
    com.google.android.gms)                     name="Google Play服务" ;;
    com.vivo.devicereg)                         name="vivo设备注册服务" ;;
    com.vivo.numbermark)                        name="vivo号码标记(骚扰拦截)" ;;
    com.todesk)                                 name="ToDesk" ;;
    cn.wenyu.bodian)                            name="波点音乐" ;;
    com.wapi.wapicertmanager)                   name="WAPI无线证书管理" ;;
    com.android.packageinstaller)               name="Android 应用安装器" ;;
    com.vivo.vtouch)                            name="vivo全局侧边栏触控(vTouch)" ;;
    com.vivo.sosappwidget)                      name="vivo SOS小组件" ;;
    com.android.printspooler)                   name="Android 打印后台处理" ;;
    com.vos.user.vit)                           name="vivo VIT用户层" ;;
    com.lemon.lvoverseas)                       name="柠檬短视频海外版" ;;
    com.vivo.networkstate)                      name="vivo网络状态显示" ;;
    com.android.soundpicker)                    name="Android 铃声选择" ;;
    com.vivo.timerwidget)                       name="vivo倒计时小组件" ;;
    com.vivo.simpleiconthemeres)                name="vivo简约图标主题资源" ;;
    com.android.angle)                          name="Android ANGLE图形层" ;;
    com.android.microdroid.empty_payload)       name="Android Microdroid空负载" ;;
    com.tencent.soter.soterserver)              name="腾讯SOTER安全认证服务" ;;
    com.yunzhipian)                             name="云知篇(第三方)" ;;
    pxb7.com)                                   name="PXB7(第三方工具)" ;;
    com.ss.android.ugc.aweme.lite)              name="抖音极速版" ;;
    com.android.externalstorage)                name="Android 外部存储" ;;
    com.android.server.telecom)                 name="Android 电话服务端" ;;
    com.android.camera)                         name="vivo相机/Android相机" ;;
    com.vivo.aiengine)                          name="vivo AI引擎" ;;
    com.android.modulemetadata)                 name="Android 模块元数据" ;;
    com.android.connectivity.resources)         name="Android 连接资源" ;;
    com.vivo.puresearch)                        name="vivo全局搜索(轻量版)" ;;
    com.android.bbkmusic)                       name="vivo音乐(旧版)" ;;
    com.vivo.android.wifi.mainline.common.resources.overlay) name="vivo Wi-Fi主线通用叠加" ;;
    com.vivo.android.wifi.mainline.manufacturer.resources.overlay) name="vivo Wi-Fi主线厂商叠加" ;;
    com.android.calllogbackup)                  name="Android 通话记录备份" ;;
    com.bbk.updater)                            name="vivo系统更新(OTA)" ;;
    com.vivo.doubletimezoneclock)               name="vivo双时区时钟小组件" ;;
    com.vivo.effectengine)                      name="vivo特效引擎" ;;
    com.vivo.globalanimation.resources)         name="vivo全局动画资源" ;;
    com.bbk.theme)                              name="vivo主题商店" ;;
    com.vivo.healthcode)                        name="vivo健康码(历史组件)" ;;
    com.vivo.cota)                              name="vivo COTA配置推送" ;;
    me.piebridge.brevent)                       name="黑阈(Brevent)" ;;
    com.bbk.facewake)                           name="vivo息屏面部唤醒" ;;
    com.vivo.quickpay)                          name="vivo快捷支付(扫码付)" ;;
    com.vivo.alphacamera)                       name="vivo Alpha相机模式" ;;
    bin.mt.plus.canary)                         name="MT管理器金丝雀版" ;;
    cn.gywc.gycesu)                             name="公益查词/工具(第三方)" ;;
    com.android.mms.service)                    name="Android 短信服务" ;;
    com.vivo.aiservice)                         name="vivo AI服务(Jovi)" ;;
    com.vivo.dream.weather)                     name="vivo天气屏保(DayDream)" ;;
    com.android.networkstack.overlay)           name="Android 网络栈叠加" ;;
    com.android.networkstack)                   name="Android 网络栈" ;;
    com.vivo.compass)                           name="vivo指南针" ;;
    com.ringclip)                               name="RingClip(第三方工具)" ;;
    com.sina.weibo)                             name="微博" ;;
    com.android.networkstack.tethering)         name="Android 网络共享(热点)" ;;
    com.mediatek.ygps)                          name="联发科YGPS工程模式" ;;
    com.wuba.zhuanzhuan)                        name="转转" ;;
    com.cmri.universalapp)                      name="中国移动通用应用" ;;
    com.iqoo.powersaving)                       name="iQOO省电管理" ;;
    com.example.xwpakpm)                        name="示例/调试应用" ;;
    com.vivo.videoeditor)                       name="vivo视频剪辑" ;;
    com.android.virtualmachine.res)             name="Android 虚拟机资源" ;;
    com.vos.as.vit)                             name="vivo AS-VIT层" ;;
    com.xs.fm.lite)                             name="番茄畅听极速版" ;;
    com.jingdong.app.mall)                      name="京东" ;;
    vivo.app.adaptiveui.plugin)                 name="vivo自适应UI插件" ;;
    com.android.inputdevices)                   name="Android 输入设备" ;;
    com.mediatek.FrameworkResOverlayExt)        name="联发科框架资源扩展叠加" ;;
    com.vivo.secime.service)                    name="vivo安全输入法服务" ;;
    com.google.android.onetimeinitializer)      name="Google 一次性初始化" ;;
    com.android.apps.tag)                       name="Android NFC标签(Google Tag)" ;;
    com.kuaishou.nebula)                        name="快手极速版" ;;
    com.mediatek.SettingsProviderResOverlay)    name="联发科设置提供资源叠加" ;;
    com.vivo.vivokaraoke)                       name="vivo K歌/欢唱" ;;
    com.rtk.app)                                name="Realtek相关应用" ;;
    com.vivo.connbase.deviceaccessory)          name="vivo外设接入服务" ;;
    com.example.xwzyb)                          name="示例/调试应用" ;;
    bin.mt.plus)                                name="MT管理器" ;;
    com.vivo.smartshot)                         name="vivo智能截屏/长截屏" ;;
    com.vivo.favorite)                          name="vivo收藏" ;;
    com.mediatek)                               name="联发科系统组件(框架)" ;;
    com.bbk.iqoo.feedback)                      name="iQOO用户反馈" ;;
    com.android.safetycenter.resources)         name="Android 安全中心资源" ;;
    com.google.android.apps.authenticator2)     name="Google 身份验证器" ;;
    com.android.managedprovisioning)            name="Android 设备管理员配置" ;;
    com.xtc.originwidget)                       name="Origin Widget(第三方小组件)" ;;
    com.rekoo.pubgm)                            name="和平精英渠道版(ReKoo)" ;;
    com.vivo.smartLife)                         name="vivo智慧生活" ;;
    com.mediatek.mdmlsample)                    name="联发科MDML示例" ;;
    com.vivo.nps)                               name="vivo通知推送服务(NPS)" ;;
    com.vivo.connbase.connectcenter)            name="vivo连接中心" ;;
    com.tencent.ig)                             name="和平精英(国际服/腾讯IG)" ;;
    com.bbk.lite.theme)                         name="vivo轻量主题" ;;
    com.android.nfc)                            name="Android NFC" ;;
    com.android.cellbroadcastservice)           name="Android 小区广播服务" ;;
    com.google.android.gsf)                     name="Google 服务框架(GSF)" ;;
    com.vivo.translator)                        name="vivo翻译" ;;
    com.android.appsearch.apk)                  name="Android 应用搜索" ;;
    com.eg.android.AlipayGphone)                name="支付宝" ;;
    com.vivo.multinlp)                         name="vivo多语言NLP" ;;
    com.vivo.smartunlock)                       name="vivo智能解锁" ;;
    com.android.internal.display.cutout.emulation.double) name="Android 双挖孔模拟" ;;
    com.yghbhyhgyhhvhbhb)                       name="未知/随机包名(疑似伪装应用⚠️)" ;;
    com.mediatek.frameworkresoverlay)           name="联发科框架资源叠加" ;;
    com.luna.music)                             name="汽水音乐" ;;
    com.vivo.sim.contacts)                      name="vivo SIM卡联系人" ;;
    com.google.android.syncadapters.calendar)   name="Google 日历同步适配器" ;;
    com.android.bbkcalculator)                  name="vivo计算器" ;;
    com.vivo.upslide)                           name="vivo上滑快捷栏" ;;
    com.taobao.taobao)                          name="淘宝" ;;
    com.android.systemui)                       name="Android 系统界面(状态栏/导航栏)" ;;
    com.google.ar.core)                         name="Google ARCore" ;;
    com.android.wifi.system.resources.overlay)  name="Android Wi-Fi系统资源叠加" ;;
    com.vivo.motionrecognition)                 name="vivo动作识别(翻转静音等)" ;;
    com.vivo.weather.provider)                  name="vivo天气内容提供器" ;;
    com.vivo.widget.cleanspeed)                 name="vivo加速清理小组件" ;;
    com.android.role.notes.enabled)             name="Android 笔记角色启用" ;;
    com.quark.browser)                          name="夸克浏览器" ;;
    com.vivo.livewallpaper.behavior)            name="vivo动态壁纸-行为" ;;
    com.vivo.appsuggestion)                     name="vivo应用推荐" ;;
    com.tencent.androidqqmail)                  name="腾讯QQ邮箱" ;;
    com.vivo.hiboard)                           name="vivo i管家/手机管家" ;;
    com.bbk.photoframewidget)                   name="vivo照片边框小组件" ;;
    com.vivo.pcsuite)                           name="vivo PC Suite助手" ;;
    com.snda.wifilocating)                      name="WiFi万能钥匙" ;;
    com.android.wallpaperbackup)                name="Android 壁纸备份" ;;
    com.vivo.ai.base.copilot)                   name="vivo AI Copilot基础" ;;
    com.xiaomi.hm.health)                       name="小米运动健康" ;;
    com.google.android.networkstack.overlay)    name="Google 网络栈叠加" ;;
    com.vivo.remoteassistant)                   name="vivo远程协助" ;;
    com.android.localtransport)                 name="Android 本地传输" ;;
    android)                                    name="Android系统根进程" ;;
    com.pubgmobile.auth)                        name="PUBG Mobile 授权组件" ;;
    com.mediatek.cellbroadcastuiresoverlay)     name="联发科小区广播UI叠加" ;;
    com.vivo.easyshare)                         name="vivo互传(EasyShare/快传)" ;;
    com.android.rkpdapp)                        name="Android 远程证明密钥守护" ;;
    com.android.permissioncontroller)           name="Android 权限控制器" ;;
    com.vivo.vdfs)                              name="vivo分布式文件系统" ;;
    com.lemon.lv)                               name="快手" ;;
    com.vivo.livewallpaper.behaviorskylight)    name="vivo动态壁纸-天光" ;;
    com.vivo.fuelsummary)                       name="vivo耗电详情(燃料摘要)" ;;
    com.vivo.game)                              name="vivo游戏中心" ;;
    com.mfcloudcalculate.networkdisk)            name="麦风网盘" ;;
    com.vivo.screenreader)                      name="vivo屏幕朗读/TTS" ;;
    com.bbk.scene.launcher.theme)               name="vivo场景桌面主题" ;;
    com.android.pacprocessor)                   name="Android PAC代理处理器" ;;
    com.vivo.smartanswer)                       name="vivo智能接听/自动回复" ;;
    com.android.wifi.resources.overlay)         name="Android Wi-Fi资源叠加" ;;
    com.android.providers.media.module)         name="Android 媒体存储模块" ;;
    com.vivo.android.connectivity.mainline.common.resources.overlay) name="vivo网络主线通用叠加" ;;
    com.vivo.widget.timemanager)                name="vivo时间管理小组件" ;;
    com.tencent.mm)                             name="微信" ;;
    com.vng.pubgmobile)                         name="Garena PUBG Mobile(越南服)" ;;
    com.android.internal.display.cutout.emulation.hole) name="Android 单挖孔模拟" ;;
    com.vivo.globalanimation)                   name="vivo全局动画" ;;
    com.android.settings)                       name="Android 设置" ;;
    com.bbk.appstore)                           name="vivo应用商店" ;;
    com.mediatek.miravision.ui)                 name="联发科MiraVision画质引擎" ;;
    com.vivo.voicerecognition)                  name="vivo语音识别" ;;
    com.android.internal.display.cutout.emulation.tall) name="Android 长刘海模拟" ;;
    com.mobile.iroaming)                        name="iRoaming(第三方漫游)" ;;
    com.android.cameraextensions)               name="Android 相机扩展" ;;
    com.bbk.iqoo.logsystem)                     name="iQOO日志系统" ;;
    com.android.networkstack.inprocess.overlay) name="Android 网络栈进程内叠加" ;;
    com.app.wendan02)                           name="问单02(第三方)" ;;
    com.app.wendan01)                           name="问单01(第三方)" ;;
    com.vivo.video.floating)                    name="vivo悬浮视频小窗" ;;
    com.vivo.SmartKey)                          name="vivo智能按键(游戏魔盒键)" ;;
    com.android.carrierconfig)                  name="Android 运营商配置" ;;
    com.ruoshui.qs)                             name="若水QS(快捷设置面板自定义)" ;;
    com.vivo.seservice)                         name="vivo SE服务" ;;
    com.android.federatedcompute.services)      name="Android 联邦计算服务" ;;
    com.google.android.ext.shared)              name="Google 扩展共享库" ;;
    com.bbk.SuperPowerSave)                     name="vivo超级省电模式" ;;
    com.vivo.are)                               name="vivo ARE自动化/远程" ;;
    com.vivo.fingerprintvit)                    name="vivo指纹VIT" ;;
    com.autonavi.minimap)                       name="高德地图" ;;
    com.android.chrome)                         name="Google Chrome" ;;
    com.vivo.globalsearch)                      name="vivo全局搜索" ;;
    com.vivo.gamewatch)                         name="vivo游戏防沉迷/家长看护" ;;
    com.xiaofeiji.app.disk)                     name="小飞机网盘/第三方云盘" ;;
    com.tencent.hunyuan.app.chat)               name="腾讯元宝(AI)" ;;
    com.vivo.moodcube)                          name="vivo心情魔方/桌面组件" ;;
    com.vivo.carlauncher)                       name="vivo车机桌面/百度CarLife启动器" ;;
    com.android.compos.payload)                 name="Android 编译系统负载" ;;
    com.debug.loggerui)                         name="vivo调试日志界面" ;;
    com.baidu.carlife.vivo)                     name="百度CarLife+(vivo版)" ;;
    com.android.internal.systemui.navbar.transparent) name="Android 透明导航栏" ;;
    com.android.adservices.api)                name="Android 广告服务API" ;;
    com.kwai.hisense)                           name="快手(HiSense定制版)" ;;
    roro.stellar.manager)                       name="Stellar管理器(第三方)" ;;
    com.baidu.searchbox.lite)                   name="百度搜索极速版" ;;
    com.google.android.marvin.talkback)         name="Google TalkBack屏幕朗读" ;;
    top.webcat.editor)                          name="MT文本编辑器/WebCat Editor" ;;
    com.fido.client)                            name="FIDO UAF客户端(生物认证)" ;;
    com.baidu.map.location)                     name="百度地图定位服务" ;;
    com.wn.app.np)                              name="WN应用(第三方)" ;;
    com.android.intentresolver)                 name="Android 意图解析器(分享菜单)" ;;
    com.android.certinstaller)                  name="Android 证书安装器" ;;
    com.vivo.email)                             name="vivo邮件" ;;
    com.xile.loveweather)                       name="喜乐天气" ;;
    android.ext.services)                       name="Android 扩展服务" ;;
    com.mediatek.datachannel.service)           name="联发科数据通道" ;;
    com.vivo.familycare.local)                  name="vivo家庭关怀本地" ;;
    com.android.wifi.dialog)                    name="Android Wi-Fi对话框" ;;
    com.android.captiveportallogin)             name="Android captive portal登录(Wi-Fi认证)" ;;
    com.meitu.wink)                             name="美图Wink/美图秀秀视频版" ;;
    com.lark.android)                           name="飞书(国内版)" ;;
    com.vivo.livewallpaper.behaviormountain)    name="vivo动态壁纸-山景" ;;
    com.android.providers.telephony)            name="Android 电话数据存储" ;;
    com.vivo.android.wifi.common.resources.overlay) name="vivo Wi-Fi通用资源叠加" ;;
    com.goodix.deltadiff)                       name="汇顶(Goodix)差分升级" ;;
    com.vivo.xspace)                            name="vivo保密柜/隐私空间(X-Space)" ;;
    com.vivo.cipherchain)                       name="vivo密码链/加密链路" ;;
    com.mobile.cos.iroaming)                    name="COS iRoaming" ;;
    com.zidongdianji)                           name="自动点击/自动连点器(第三方)" ;;
    com.android.providers.settings)             name="Android 系统设置存储" ;;
    com.android.phone)                          name="vivo/Android 电话(后台)" ;;
    com.temporary.email.pro)                    name="临时邮箱Pro" ;;
    com.bytedance.android.doubaoime)            name="豆包输入法(字节跳动)" ;;
    com.abjlvcha.main)                          name="阿布滤茶/第三方工具" ;;
    com.vivo.countdownwidget)                   name="vivo倒计时小组件" ;;
    com.android.contacts)                       name="vivo/Android 联系人" ;;
    com.vivo.dream.clock)                       name="vivo时钟屏保(DayDream)" ;;
    com.vivo.desktopstickers)                   name="vivo桌面贴纸" ;;
    com.vivo.widget.healthcare)                 name="vivo健康护理小组件" ;;
    com.android.vpndialogs)                     name="Android VPN对话框" ;;
    com.android.uwb.resources)                  name="Android UWB超宽带资源" ;;
    com.android.systemui.plugin.globalactions.wallet) name="vivo/Android 钱包关机菜单插件" ;;
    com.vivo.gallery)                           name="vivo相册" ;;
    com.mediatek.atmwifimeta)                   name="联发科Wi-Fi META工程模式" ;;
    com.android.bbksoundrecorder)               name="vivo录音机" ;;
    com.android.htmlviewer)                      name="Android HTML查看器" ;;
    com.android.vending)                        name="Google Play商店" ;;
    com.vivo.musicwidgetmix)                    name="vivo音乐混搭小组件" ;;
    com.vivo.fingerprintui)                     name="vivo指纹录入界面" ;;
    com.trustonic.teeservice)                   name="Trustonic可信执行环境服务" ;;
    com.appscq.app)                             name="应用商店求全/第三方" ;;
    com.greenpoint.android.mc10086.activity)    name="中国移动(10086)营业厅" ;;
    com.mediatek.capctrl.service)               name="联发科能力控制" ;;
    com.android.networkstack.tethering.inprocess.overlay) name="Android 热点进程内叠加" ;;
    com.vivo.appfilter)                         name="vivo应用隐藏/过滤器" ;;
    com.mediatek.ims)                           name="联发科IMS(IP多媒体子系统)" ;;
    com.android.providers.userdictionary)       name="Android 用户词典" ;;
    com.google.android.overlay.gmsconfig.common) name="Google Play服务配置叠加" ;;
    com.android.cts.ctsshim)                    name="Android CTS兼容性测试" ;;
    com.android.bluetooth)                       name="Android 蓝牙" ;;
    com.vivo.dr)                                name="vivo DRM数字版权" ;;
    com.vivo.widget.gallery)                    name="vivo相册小组件" ;;
    com.vivo.hybrid)                            name="vivo混合视图/H5容器" ;;
    com.vivo.browser.novel.widget)              name="vivo浏览器小说小组件" ;;
    com.amap.android.location)                  name="高德地图定位SDK" ;;
    com.discord)                                name="Discord" ;;
    com.android.storagemanager)                 name="Android 存储空间管理" ;;
    com.vivo.frameworkui)                       name="vivo框架UI" ;;
    com.vivo.faceunlock)                        name="vivo面部解锁" ;;
    com.vivo.card)                              name="vivo卡包/卡券" ;;
    com.vivo.daemonService)                     name="vivo守护服务" ;;
    com.antutu.ABenchMark)                      name="安兔兔评测" ;;
    com.kwai.videoeditor)                       name="快手云剪/视频编辑" ;;
    com.vivo.doubleinstance)                    name="vivo应用分身(双开)" ;;
    com.vivo.widgetweather)                     name="vivo天气小组件" ;;
    com.vivo.browser)                           name="vivo浏览器" ;;
    com.tencent.mangguo)                        name="腾讯芒果/腾讯待定组件" ;;
    com.vivo.accessibility)                     name="vivo无障碍服务" ;;
    com.vivo.singularity)                       name="vivo Singularity模块" ;;
    com.yaxisvip.pubgtool)                      name="PUBG工具(疑似作弊/辅助⚠️)" ;;
    com.mediatek.gbaservice)                    name="联发科GBA服务" ;;
    com.vivo.findphone)                         name="vivo查找手机" ;;
    com.facebook.katana)                        name="Facebook" ;;
    com.iqoo.secure)                            name="iQOO安全中心/游戏魔盒" ;;
    com.vivo.iotserver)                         name="vivo IoT物联网服务" ;;
    com.android.dynsystem)                      name="Android 动态系统更新(DSU)" ;;
    moe.shizuku.privileged.api)                 name="Shizuku(需要root/无线调试)" ;;
    com.android.vivo.tws.vivotws)               name="vivo TWS耳机服务" ;;
    cn.com.omronhealthcare.omronplus.vivo)      name="欧姆龙+健康(vivo版)" ;;
    com.android.hotspot2.osulogin)              name="Android Hotspot 2.0 OSU登录" ;;
    com.astrbot.astrbot_android)                name="AstrBot Android(第三方Bot)" ;;
    *) name="" ;;
  esac
  if [ -n "$name" ]; then
    printf '%s\n' "$name"
  else
    printf '%s\n' "$p"
  fi
}

# 遍历翻译每一行
translate_pkg_lines() {
  while read -r line; do
    [ -z "$line" ] && continue
    # 去掉 "package:" 前缀（pm list packages 的输出格式）
    local pkg=$(printf '%s' "$line" | sed 's/^package://')
    # 去掉可能的前缀空格
    pkg=$(printf '%s' "$pkg" | tr -d ' ')
    if [ -n "$pkg" ]; then
      local out
      out=$(label_of_pkg "$pkg")
      printf '    %s\n' "$out"
    fi
  done
}

fn_app_menu() {
  while true; do
    box "应用管理"
    printf '  %s── 基本操作 ──%s\n' "$M" "$D"
    printf '  %s[1]%s 查看已安装包列表\n' "$C" "$D"
    printf '  %s[2]%s 查看系统应用\n' "$C" "$D"
    printf '  %s[3]%s 查看第三方应用\n' "$C" "$D"
    printf '  %s[4]%s 停用应用 (disable-user)\n' "$C" "$D"
    printf '  %s[5]%s 启用应用\n' "$C" "$D"
    printf '  %s[6]%s 强制停止\n' "$C" "$D"
    printf '  %s[7]%s 清除应用数据\n' "$C" "$D"
    printf '  %s── 权限 / 启动 ──%s\n' "$M" "$D"
    printf '  %s[8]%s 授予所有运行时权限\n' "$C" "$D"
    printf '  %s[9]%s 启动应用 (输入包名)\n' "$C" "$D"
    printf '  %s[10]%s 卸载应用\n' "$C" "$D"
    printf '  %s── 信息 ──%s\n' "$M" "$D"
    printf '  %s[11]%s 查看应用详细信息 (dumpsys)\n' "$C" "$D"
    printf '  %s[12]%s 查看应用 UID / 路径\n' "$C" "$D"
    printf '  %s[13]%s 搜索包名 (含名称)\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"

    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) info "已安装应用:"; pm list packages 2>/dev/null | translate_pkg_lines; pause ;;
      2) info "系统应用:"; pm list packages -s 2>/dev/null | translate_pkg_lines; pause ;;
      3) info "第三方应用:"; pm list packages -3 2>/dev/null | translate_pkg_lines; pause ;;
      4) ask_str P "输入包名"; [ -n "$P" ] && { local L; L=$(label_of_pkg "$P"); info "目标: $L"; run_show pm disable-user --user 0 "$P"; }; pause ;;
      5) ask_str P "输入包名"; [ -n "$P" ] && { local L; L=$(label_of_pkg "$P"); info "目标: $L"; run_show pm enable "$P"; }; pause ;;
      6) ask_str P "输入包名"; [ -n "$P" ] && { local L; L=$(label_of_pkg "$P"); info "目标: $L"; run_show am force-stop "$P"; }; pause ;;
      7) ask_str P "输入包名"; [ -n "$P" ] && { local L; L=$(label_of_pkg "$P"); info "目标: $L"; ask_yes "确认清除 ${P} 的数据?" && run_show pm clear "$P"; }; pause ;;
      8) ask_str P "输入包名"; [ -n "$P" ] && { local L; L=$(label_of_pkg "$P"); info "目标: $L"; run_show pm grant-all-runtime-permissions "$P" 2>/dev/null; }
         if [ $? -ne 0 ]; then
           info "grant-all 不可用，尝试逐项授予..."
           for perm in $(pm list permissions -g -f 2>/dev/null | grep -E '^    permission:' | awk '{print $2}'); do
             pm grant "$P" "$perm" 2>/dev/null
           done
           ok "已尝试授予权限"
         fi
         pause ;;
      9) ask_str P "输入包名"; [ -n "$P" ] && { local L; L=$(label_of_pkg "$P"); info "启动: $L"; monkey -p "$P" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 && ok "已启动" || err "启动失败"; }; pause ;;
      10) ask_str P "输入包名"; [ -n "$P" ] && { local L; L=$(label_of_pkg "$P"); info "目标: $L"; ask_yes "确认卸载 ${P}?" && run_show pm uninstall --user 0 "$P"; }; pause ;;
      11) ask_str P "输入包名"; [ -n "$P" ] && { local L; L=$(label_of_pkg "$P"); info "详情: $L"; dumpsys package "$P" 2>/dev/null | sed 's/^/    /' | head -80; }; pause ;;
      12) ask_str P "输入包名"; [ -n "$P" ] && { pm list packages -f -U 2>/dev/null | grep "$P" | sed 's/^/    /'; }; pause ;;
      13)
        ask_str KW "关键字(包名或名称)"; [ -n "$KW" ] && {
          info "匹配 \"$KW\" 的应用:";
          pm list packages 2>/dev/null | translate_pkg_lines | grep -i "$KW"
          pause
        } ;;
      0)  return ;;
      *) warn "无效选项" ;;
    esac
  done
}

# ═══════════════════════════════════════════════════════════
#  5. 按键 / 输入事件注入
# ═══════════════════════════════════════════════════════════
fn_input_menu() {
  while true; do
    box "按键 / 输入事件"
    printf '  %s[1]%s HOME\n' "$C" "$D"
    printf '  %s[2]%s 返回键\n' "$C" "$D"
    printf '  %s[3]%s 电源键\n' "$C" "$D"
    printf '  %s[4]%s 音量+ / 音量-\n' "$C" "$D"
    printf '  %s[5]%s 静音\n' "$C" "$D"
    printf '  %s[6]%s 亮屏 / 解锁\n' "$C" "$D"
    printf '  %s[7]%s 拍照 (相机键)\n' "$C" "$D"
    printf '  %s[8]%s 模拟文字输入 (英文 / 数字)\n' "$C" "$D"
    printf '  %s[9]%s 自定义 keycode (1-500)\n' "$C" "$D"
    printf '  %s[10]%s 滑动 (从 x1,y1 到 x2,y2)\n' "$C" "$D"
    printf '  %s[11]%s 点击屏幕 (x,y)\n' "$C" "$D"
    printf '  %s── 高级按键 ──%s\n' "$M" "$D"
    printf '  %s[12]%s 通知栏\n' "$C" "$D"
    printf '  %s[13]%s 最近应用\n' "$C" "$D"
    printf '  %s[14]%s 屏幕截图\n' "$C" "$D"
    printf '  %s[15]%s 重启 SystemUI\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) input keyevent 3; ok "HOME" ;;
      2) input keyevent 4; ok "BACK" ;;
      3) input keyevent 26; ok "POWER" ;;
      4) input keyevent 24; sleep 0.1; input keyevent 25; ok "VOL + / -" ;;
      5) input keyevent 164; ok "静音" ;;
      6) input keyevent 224; ok "点亮屏幕" ;;
      7) input keyevent 27; ok "相机键" ;;
      8) ask_str T "输入文本 (英文 / 数字)"; [ -n "$T" ] && input text "$T"; ok "已输入: $T" ;;
      9) ask_int K "keycode (1-500)" 1 500; input keyevent "$K"; ok "已发送 keycode $K" ;;
      10)
        ask_int X1 "x1" 0 9999
        ask_int Y1 "y1" 0 9999
        ask_int X2 "x2" 0 9999
        ask_int Y2 "y2" 0 9999
        input swipe "$X1" "$Y1" "$X2" "$Y2" 300
        ok "滑动完成 ${X1},${Y1} → ${X2},${Y2}"
        ;;
      11) ask_int X "x" 0 9999; ask_int Y "y" 0 9999; input tap "$X" "$Y"; ok "点击 ${X},${Y}" ;;
      12) input keyevent 4; sleep 0.3; cmd statusbar expand-notifications 2>/dev/null && ok "通知栏展开" || warn "可能需要更高权限" ;;
      13) input keyevent 187; ok "最近应用" ;;
      14) /system/bin/screencap -p /sdcard/screen_$(date +%s).png 2>/dev/null && ok "截图已保存到 /sdcard" || err "截图失败 (可能需要更高权限)" ;;
      15) killall com.android.systemui 2>/dev/null; ok "已重启 SystemUI" ;;
      0)  return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  6. 网络 / Wi-Fi / APN
# ═══════════════════════════════════════════════════════════
fn_network_menu() {
  while true; do
    box "网络 / Wi-Fi"
    printf '  %s── 状态 ──%s\n' "$M" "$D"
    printf '  %s[1]%s 查看网络信息 (ifconfig)\n' "$C" "$D"
    printf '  %s[2]%s 查看连接表 (netstat)\n' "$C" "$D"
    printf '  %s[3]%s 查看 Wi-Fi 连接信息\n' "$C" "$D"
    printf '  %s[4]%s Ping 测试\n' "$C" "$D"
    printf '  %s── DNS / 开关 ──%s\n' "$M" "$D"
    printf '  %s[5]%s 开关 Wi-Fi (尝试)\n' "$C" "$D"
    printf '  %s[6]%s 开关飞行模式\n' "$C" "$D"
    printf '  %s── 高级 ──%s\n' "$M" "$D"
    printf '  %s[7]%s 查看当前 APN\n' "$C" "$D"
    printf '  %s[8]%s 查看代理设置\n' "$C" "$D"
    printf '  %s[9]%s 关闭 / 开启移动网络\n' "$C" "$D"
    printf '  %s── 查看当前 IP ──%s\n' "$M" "$D"
    printf '  %s[10]%s 查看本机 IP (wlan0)\n' "$C" "$D"
    printf '  %s[11]%s 查看所有网络接口\n' "$C" "$D"
    printf '  %s── IP / DNS 自定义 ──%s\n' "$M" "$D"
    printf '  %s[12]%s 指定接口 ifconfig (up/down)\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) (ifconfig 2>/dev/null || ip addr) | sed 's/^/    /'; pause ;;
      2) (netstat -an 2>/dev/null || ss -tuln 2>/dev/null) | sed 's/^/    /' | head -40; pause ;;
      3) dumpsys connectivity 2>/dev/null | grep -A 30 "NetworkInfo" | head -30 | sed 's/^/    /'; pause ;;
      4) ask_str HOST "ping 目标 (例 8.8.8.8)"; [ -n "$HOST" ] && (ping -c 3 -W 2 "$HOST" 2>&1 | sed 's/^/    /'); pause ;;
      5) ask_int S "Wi-Fi 1=开 0=关" 0 1; [ "$S" = "1" ] && svc wifi enable && ok "Wi-Fi 已开启" || svc wifi disable && ok "Wi-Fi 已关闭" ;;
      6) ask_int S "飞行模式 1=开 0=关" 0 1; settings put global airplane_mode_on "$S"; am broadcast -a android.intent.action.AIRPLANE_MODE; ok "已设置飞行模式=$S" ;;
      7) content query --uri content://telephony/carriers/preferapn 2>/dev/null | sed 's/^/    /' | head -20; pause ;;
      8) settings get global http_proxy 2>/dev/null | sed 's/^/    /'; pause ;;
      9) ask_int S "移动网络 1=开 0=关" 0 1; [ "$S" = "1" ] && svc data enable && ok "已开启" || svc data disable && ok "已关闭" ;;
      10) ifconfig wlan0 2>/dev/null | sed 's/^/    /'; pause ;;
      11) (ip link 2>/dev/null || cat /proc/net/dev 2>/dev/null) | sed 's/^/    /' | head -40; pause ;;
      12) ask_str IF "接口名 (例 wlan0 / eth0)"; [ -n "$IF" ] && ask_int S "1=up 0=down" 0 1; [ "$S" = "1" ] && ifconfig "$IF" up && ok "${IF} up" || ifconfig "$IF" down && ok "${IF} down" ;;
      0)  return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  7. 存储 / 文件操作 (权限敏感)
# ═══════════════════════════════════════════════════════════
fn_storage_menu() {
  while true; do
    box "存储 / 文件"
    info "Shizuku (UID 2000) 有权访问 /sdcard / /storage/emulated/0"
    info "系统私有目录 (/data/app 等) 需要更高级权限"
    printf '  %s── 基础 ──%s\n' "$M" "$D"
    printf '  %s[1]%s 查看 /sdcard 目录\n' "$C" "$D"
    printf '  %s[2]%s 查看存储使用\n' "$C" "$D"
    printf '  %s[3]%s 创建目录 (mkdir)\n' "$C" "$D"
    printf '  %s[4]%s 复制文件\n' "$C" "$D"
    printf '  %s[5]%s 移动文件\n' "$C" "$D"
    printf '  %s[6]%s 删除文件\n' "$C" "$D"
    printf '  %s[7]%s 修改权限 (chmod)\n' "$C" "$D"
    printf '  %s[8]%s 修改所有者 (chown)\n' "$C" "$D"
    printf '  %s── 查看 ──%s\n' "$M" "$D"
    printf '  %s[9]%s 查看文本文件 (cat)\n' "$C" "$D"
    printf '  %s[10]%s 文件大小 / md5 检查\n' "$C" "$D"
    printf '  %s── 挂载 / 分区 ──%s\n' "$M" "$D"
    printf '  %s[11]%s 查看挂载表\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) ls -la /sdcard/ 2>/dev/null | sed 's/^/    /' | head -60; pause ;;
      2) df -h 2>/dev/null | sed 's/^/    /' | head -30; pause ;;
      3) ask_str P "新目录完整路径 (例 /sdcard/temp)"; [ -n "$P" ] && mkdir -p "$P" 2>/dev/null && ok "已创建 $P" || err "失败，权限不足" ;;
      4) ask_str S "源文件"; ask_str D "目标"; [ -n "$S" ] && [ -n "$D" ] && cp -f "$S" "$D" && ok "复制完成" || err "失败" ;;
      5) ask_str S "源文件"; ask_str D "目标"; [ -n "$S" ] && [ -n "$D" ] && mv -f "$S" "$D" && ok "移动完成" || err "失败" ;;
      6) ask_str P "要删除的文件/目录"; [ -n "$P" ] && ask_yes "确认删除 $P ?" && rm -rf "$P" && ok "已删除" ;;
      7) ask_str P "文件路径"; ask_int M "权限 (八进制, 例 755)" 0 7777; chmod "$M" "$P" 2>/dev/null && ok "chmod $M $P 完成" || err "权限不足" ;;
      8) ask_str P "文件路径"; ask_str O "owner (例 shell:sdcard_rw)"; [ -n "$P" ] && [ -n "$O" ] && chown "$O" "$P" 2>/dev/null && ok "chown $O $P 完成" || err "权限不足" ;;
      9) ask_str P "文件路径"; [ -n "$P" ] && cat "$P" 2>/dev/null | sed 's/^/    /' | head -60; pause ;;
      10) ask_str P "文件路径"; [ -n "$P" ] && info "大小: $(wc -c < "$P" 2>/dev/null) bytes"; md5sum "$P" 2>/dev/null | awk '{print "  MD5: " $1}' | sed 's/^/    /'; pause ;;
      11) mount | sed 's/^/    /' | head -40; pause ;;
      0)  return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  8. 日志 / 调试
# ═══════════════════════════════════════════════════════════
fn_log_menu() {
  while true; do
    box "日志 / 调试"
    printf '  %s[1]%s 查看 logcat 最近 100 行\n' "$C" "$D"
    printf '  %s[2]%s 查看某个应用的日志\n' "$C" "$D"
    printf '  %s[3]%s 清理 logcat 缓冲区\n' "$C" "$D"
    printf '  %s[4]%s 保存 logcat 到 /sdcard/logcat.txt\n' "$C" "$D"
    printf '  %s[5]%s 查看 dmesg 内核日志\n' "$C" "$D"
    printf '  %s[6]%s dumpsys activity top\n' "$C" "$D"
    printf '  %s[7]%s dumpsys window windows (窗口层次)\n' "$C" "$D"
    printf '  %s[8]%s dumpsys package (包总览)\n' "$C" "$D"
    printf '  %s[9]%s dumpsys meminfo (内存)\n' "$C" "$D"
    printf '  %s[10]%s dumpsys alarm (闹钟)\n' "$C" "$D"
    printf '  %s[11]%s dumpsys power (电源管理)\n' "$C" "$D"
    printf '  %s── 调试工具 ──%s\n' "$M" "$D"
    printf '  %s[12]%s am crash <包名> (模拟崩溃)\n' "$C" "$D"
    printf '  %s[13]%s 发送广播 (am broadcast)\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) logcat -d -t 100 2>/dev/null | sed 's/^/    /' | head -100; pause ;;
      2) ask_str P "包名"; [ -n "$P" ] && logcat -d -t 80 --pid="$(pgrep -f "$P" 2>/dev/null | head -1)" 2>/dev/null | sed 's/^/    /' | head -80; pause ;;
      3) logcat -c 2>/dev/null; ok "已清理 logcat" ;;
      4) logcat -d -f /sdcard/logcat_$(date +%s).txt 2>/dev/null; ok "已保存 logcat" ;;
      5) dmesg 2>/dev/null | tail -40 | sed 's/^/    /'; pause ;;
      6) dumpsys activity top 2>/dev/null | sed 's/^/    /' | head -60; pause ;;
      7) dumpsys window windows 2>/dev/null | grep -E "Window #|focusedApp" | head -30 | sed 's/^/    /'; pause ;;
      8) dumpsys package 2>/dev/null | grep -E "Packages:\$|sharedUser|versionName" | head -40 | sed 's/^/    /' | head -30; pause ;;
      9) dumpsys meminfo 2>/dev/null | head -40 | sed 's/^/    /'; pause ;;
      10) dumpsys alarm 2>/dev/null | grep -E "AlarmManager|wakeup|next|top" | head -30 | sed 's/^/    /'; pause ;;
      11) dumpsys power 2>/dev/null | head -40 | sed 's/^/    /'; pause ;;
      12) ask_str P "包名"; [ -n "$P" ] && ask_yes "确认 am crash $P ?" && am crash "$P" && ok "已发送 crash 指令" ;;
      13) ask_str A "action (例 android.intent.action.BOOT_COMPLETED)"; [ -n "$A" ] && am broadcast -a "$A" | sed 's/^/    /'; pause ;;
      0)  return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  9. 系统 / 重启
# ═══════════════════════════════════════════════════════════
fn_system_menu() {
  while true; do
    box "系统控制"
    printf '  %s[1]%s 重启 (reboot)\n' "$C" "$D"
    printf '  %s[2]%s 进入 recovery\n' "$C" "$D"
    printf '  %s[3]%s 进入 bootloader\n' "$C" "$D"
    printf '  %s[4]%s 用户空间重启 (am restart)\n' "$C" "$D"
    printf '  %s[5]%s 重启 system_server (soft)\n' "$C" "$D"
    printf '  %s[6]%s 重启到安全模式\n' "$C" "$D"
    printf '  %s── 日期时间 ──%s\n' "$M" "$D"
    printf '  %s[7]%s 查看当前时间\n' "$C" "$D"
    printf '  %s── prop ──%s\n' "$M" "$D"
    printf '  %s[8]%s 查看所有 prop (过滤关键字)\n' "$C" "$D"
    printf '  %s[9]%s 写入一个 prop (setprop)\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) ask_yes "确认重启设备?" && setprop sys.powerctl reboot || err "需要更高权限，可用: svc power reboot" ;;
      2) ask_yes "确认进入 recovery?" && setprop sys.powerctl reboot,recovery ;;
      3) ask_yes "确认进入 bootloader?" && setprop sys.powerctl reboot,bootloader ;;
      4) ask_yes "确认执行 am restart?" && am restart; ok "已发送 am restart" ;;
      5) ask_yes "确认重启 system_server?" && killall system_server 2>/dev/null; ok "已发送" ;;
      6) ask_yes "确认重启到安全模式?" && setprop persist.sys.safemode 1 && am restart ;;
      7) info "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"; info "开机时长: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"; pause ;;
      8) ask_str F "过滤关键字 (留空 = 全部)"; [ -z "$F" ] && getprop | head -80 | sed 's/^/    /' && pause || getprop | grep -i "$F" | head -80 | sed 's/^/    /'; pause ;;
      9) ask_str KEY "prop key"; ask_str VAL "prop value"; [ -n "$KEY" ] && setprop "$KEY" "$VAL" && ok "setprop $KEY = $VAL" ;;
      0) return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  10. 开发者选项 / USB 调试 / OEM 解锁
# ═══════════════════════════════════════════════════════════
fn_dev_menu() {
  while true; do
    box "开发者选项"
    printf '  %s[1]%s 开启 / 关闭 USB 调试 (adb_enabled)\n' "$C" "$D"
    printf '  %s[2]%s 开启开发者选项\n' "$C" "$D"
    printf '  %s[3]%s 关闭 / 打开动画 (0x / 1x)\n' "$C" "$D"
    printf '  %s[4]%s 开启 Stay Awake (插电常亮)\n' "$C" "$D"
    printf '  %s[5]%s 开启指针位置 / 触摸显示\n' "$C" "$D"
    printf '  %s[6]%s 开启 GPU 过度绘制\n' "$C" "$D"
    printf '  %s[7]%s 开启严格模式 (Strict Mode)\n' "$C" "$D"
    printf '  %s[8]%s 不保留活动\n' "$C" "$D"
    printf '  %s[9]%s 开启 / 关闭 ADB over Wi-Fi\n' "$C" "$D"
    printf '  %s[10]%s 设置允许 Mock Location\n' "$C" "$D"
    printf '  %s[11]%s 关闭 ADB 安装验证\n' "$C" "$D"
    printf '  %s[12]%s 恢复开发者选项默认值\n' "$C" "$D"
    printf '  %s── 查看 ──%s\n' "$M" "$D"
    printf '  %s[13]%s 查看当前 adb / 开发者相关项\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) ask_int S "1=开 0=关" 0 1; settings put global adb_enabled "$S"; ok "adb_enabled = $S" ;;
      2) settings put global development_settings_enabled 1; ok "已开启开发者选项" ;;
      3) ask_int A "动画倍率 (0 关闭, 1 默认, 10=慢 10x)" 0 10
         settings put global animator_duration_scale "$A"
         settings put global transition_animation_scale "$A"
         settings put global window_animation_scale "$A"
         ok "动画倍率 = ${A}x"
         ;;
      4) ask_int S "1=开 0=关" 0 1; settings put global stay_on_while_plugged_in "$S"; ok "常亮 = $S" ;;
      5) settings put system pointer_location 1; settings put system show_touches 1; ok "已开启指针/触摸显示" ;;
      6) settings put global debug_hw_overdraw 1; ok "已开启 GPU 过度绘制 (需重启应用生效)" ;;
      7) setprop persist.sys.strictmode.visual 1; ok "严格模式 (需重启应用)" ;;
      8) ask_int S "1=开 0=关" 0 1; settings put global always_finish_activities "$S"; ok "不保留活动 = $S" ;;
      9) ask_int S "1=开 0=关" 0 1; setprop service.adb.tcp.port 5555; ok "ADB over Wi-Fi = $S (端口 5555, 重启生效)" ;;
      10) settings put secure mock_location 1; ok "已允许模拟位置" ;;
      11) settings put global verifier_verify_adb_installs 0; ok "已关闭 ADB 安装验证" ;;
      12)
        settings put global animator_duration_scale 1
        settings put global transition_animation_scale 1
        settings put global window_animation_scale 1
        settings put global adb_enabled 1
        ok "已恢复默认"
        ;;
      13) info "开发者相关项:"; settings list global 2>/dev/null | grep -iE "adb|anim|devel|debug|mock" | sed 's/^/    /'; pause ;;
      0)  return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  11. 音频 / 音量控制
# ═══════════════════════════════════════════════════════════
fn_audio_menu() {
  while true; do
    box "音频 / 音量"
    printf '  %s── 音量控制 ──%s\n' "$M" "$D"
    printf '  %s[1]%s 媒体音量 0-15\n' "$C" "$D"
    printf '  %s[2]%s 铃声音量 0-7\n' "$C" "$D"
    printf '  %s[3]%s 闹钟音量 0-7\n' "$C" "$D"
    printf '  %s[4]%s 通话音量 0-5\n' "$C" "$D"
    printf '  %s── 静音模式 ──%s\n' "$M" "$D"
    printf '  %s[5]%s 普通模式\n' "$C" "$D"
    printf '  %s[6]%s 静音 (振动)\n' "$C" "$D"
    printf '  %s[7]%s 勿扰\n' "$C" "$D"
    printf '  %s── 播放/命令 ──%s\n' "$M" "$D"
    printf '  %s[8]%s 播放媒体按键 (播放/暂停)\n' "$C" "$D"
    printf '  %s[9]%s 下一首\n' "$C" "$D"
    printf '  %s── 查看 ──%s\n' "$M" "$D"
    printf '  %s[10]%s dumpsys audio\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) ask_int V "媒体音量 (0-15)" 0 15; media volume --set "$V" 2>/dev/null || input keyevent 24; ok "媒体音量 $V" ;;
      2) ask_int V "铃声音量 (0-7)" 0 7; settings put system volume_ring "$V"; ok "铃声音量 $V" ;;
      3) ask_int V "闹钟音量 (0-7)" 0 7; settings put system volume_alarm "$V"; ok "闹钟音量 $V" ;;
      4) ask_int V "通话音量 (0-5)" 0 5; settings put system volume_voice "$V"; ok "通话音量 $V" ;;
      5) settings put global zen_mode 0; ok "普通模式" ;;
      6) settings put global zen_mode 1; ok "振动模式" ;;
      7) settings put global zen_mode 2; ok "勿扰模式" ;;
      8) input keyevent 85; ok "播放/暂停" ;;
      9) input keyevent 87; ok "下一首" ;;
      10) dumpsys audio 2>/dev/null | grep -E "isMusicActive|STREAM|volume|mode:" | head -30 | sed 's/^/    /'; pause ;;
      0)  return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  12. 窗口 / 显示 / 屏幕
# ═══════════════════════════════════════════════════════════
fn_window_menu() {
  while true; do
    box "窗口 / 显示 / 屏幕"
    printf '  %s[1]%s 查看屏幕分辨率 / DPI\n' "$C" "$D"
    printf '  %s[2]%s 设置屏幕分辨率 (wm size)\n' "$C" "$D"
    printf '  %s[3]%s 设置 DPI (wm density)\n' "$C" "$D"
    printf '  %s[4]%s 恢复默认 DPI / 分辨率\n' "$C" "$D"
    printf '  %s[5]%s 显示边界布局\n' "$C" "$D"
    printf '  %s[6]%s 关闭布局边界\n' "$C" "$D"
    printf '  %s[7]%s 查看当前活动窗口\n' "$C" "$D"
    printf '  %s[8]%s 查看所有包的 Activity 栈\n' "$C" "$D"
    printf '  %s[9]%s 打开指定 Activity\n' "$C" "$D"
    printf '  %s── 字体 / 显示 ──%s\n' "$M" "$D"
    printf '  %s[10]%s 调整字体大小 (1.0=默认, 1.3=大)\n' "$C" "$D"
    printf '  %s[11]%s 调整显示大小 (wm density)\n' "$C" "$D"
    printf '  %s── 系统 UI ──%s\n' "$M" "$D"
    printf '  %s[12]%s 重启 SystemUI\n' "$C" "$D"
    printf '  %s[13]%s 关闭 / 开启 状态栏\n' "$C" "$D"
    printf '  %s[0]%s 返回\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r c
    case "$c" in
      1) info "物理分辨率:"; wm size 2>/dev/null | sed 's/^/    /'; info "Density:"; wm density 2>/dev/null | sed 's/^/    /'; pause ;;
      2) ask_int W "宽" 100 9999; ask_int H "高" 100 9999; wm size "${W}x${H}"; ok "已设置 ${W}x${H}" ;;
      3) ask_int DPI "DPI (例 440)" 100 1000; wm density "$DPI"; ok "已设置 density = $DPI" ;;
      4) wm size reset; wm density reset; ok "已恢复默认" ;;
      5) setprop debug.layout true; ok "已开启布局边界 (需重启应用)" ;;
      6) setprop debug.layout false; ok "已关闭布局边界" ;;
      7) dumpsys window windows 2>/dev/null | grep -iE "mCurrentFocus|mFocusedApp|focusedApp" | head -10 | sed 's/^/    /'; pause ;;
      8) dumpsys activity activities 2>/dev/null | grep -E "Stack|ActivityRecord|TaskRecord" | head -30 | sed 's/^/    /'; pause ;;
      9) ask_str CMP "组件 (例 com.android.settings/.Settings)"; [ -n "$CMP" ] && am start -n "$CMP" && ok "已启动" || err "启动失败" ;;
      10) ask_int F "字体倍率 (100=1.0x, 130=1.3x)" 80 200; settings put system font_scale "$(awk -v n="$F" 'BEGIN{printf "%.2f", n/100}')"; ok "字体 = $F%" ;;
      11) ask_int D "density (例 420)" 100 1000; wm density "$D"; ok "density = $D" ;;
      12) killall com.android.systemui 2>/dev/null; ok "已重启 SystemUI" ;;
      13) ask_int S "1=开 0=关" 0 1; [ "$S" = "1" ] && cmd statusbar expand-settings 2>/dev/null && ok "已展开" || cmd statusbar collapse 2>/dev/null && ok "已收起" ;;
      0) return ;;
      *) warn "无效选项" ;;
    esac
    pause
  done
}

# ═══════════════════════════════════════════════════════════
#  主菜单
# ═══════════════════════════════════════════════════════════
main_menu() {
  while true; do
    clear
    printf '\n'
    printf '  %s╭────────────────────────────────────────────╮%s\n' "$C" "$D"
    printf '  %s│     Shizuku 集权 ADB 工具 (v2)           │%s\n' "$C" "$D"
    printf '  %s╰────────────────────────────────────────────╯%s\n' "$C" "$D"
    sep
    info "设备: $(getprop ro.product.model)"
    info "系统: Android $(getprop ro.build.version.release) SDK $(getprop ro.build.version.sdk)"
    info "权限: UID $(id -u)"
    sep
    printf '  %s[1]%s  设备信息\n' "$C" "$D"
    printf '  %s[2]%s  电池 / 充电 / 健康\n' "$C" "$D"
    printf '  %s[3]%s  系统设置 (亮度 动画 休眠)\n' "$C" "$D"
    printf '  %s[4]%s  应用管理 (启动 停用 卸载)\n' "$C" "$D"
    printf '  %s[5]%s  按键 / 输入事件\n' "$C" "$D"
    printf '  %s[6]%s  网络 / Wi-Fi\n' "$C" "$D"
    printf '  %s[7]%s  存储 / 文件操作\n' "$C" "$D"
    printf '  %s[8]%s  日志 / 调试\n' "$C" "$D"
    printf '  %s[9]%s  系统控制 (重启 / prop)\n' "$C" "$D"
    printf '  %s[10]%s 开发者选项\n' "$C" "$D"
    printf '  %s[11]%s 音频 / 音量\n' "$C" "$D"
    printf '  %s[12]%s 窗口 / 显示 / 屏幕\n' "$C" "$D"
    printf '  %s[0]%s  退出\n' "$R" "$D"
    sep
    printf '  %s➜%s 选择: ' "$C" "$D"; read -r choice
    sep

    case "$choice" in
      1) fn_device_info ;;
      2) fn_battery_menu ;;
      3) fn_settings_menu ;;
      4) fn_app_menu ;;
      5) fn_input_menu ;;
      6) fn_network_menu ;;
      7) fn_storage_menu ;;
      8) fn_log_menu ;;
      9) fn_system_menu ;;
      10) fn_dev_menu ;;
      11) fn_audio_menu ;;
      12) fn_window_menu ;;
      0)  ok "再见"; exit 0 ;;
      *) warn "无效选项" ;;
    esac
  done
}

# 入口
main_menu

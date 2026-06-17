#!/system/bin/sh
# 这是一个测试用的危险模块，用于测试Magisk Brick Guardian的防护功能
# 警告：请勿在生产环境中使用！

# 基础配置
SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=true

# 声明要替换的系统目录（仅用于测试，实际不会修改）
REPLACE="
/system/framework
/system/bin
/system/lib
/system/lib64
/system/app/Settings
/system/priv-app/SystemUI
"

print_modname() {
  ui_print "*******************************"
  ui_print "   Test Brick Module"
  ui_print "   测试用砖机模块 v1.0.0"
  ui_print "   作者：Kirk Lin"
  ui_print "*******************************"
  ui_print " "
  ui_print "警告：这是一个测试用的危险模块！"
  ui_print "它声明了对以下系统目录的修改："
  ui_print "- /system/framework"
  ui_print "- /system/bin"
  ui_print "- /system/lib"
  ui_print "- /system/lib64"
  ui_print "- /system/app/Settings"
  ui_print "- /system/priv-app/SystemUI"
  ui_print " "
  ui_print "本模块仅用于测试防砖功能"
  ui_print "请勿在生产环境中使用！"
  ui_print "*******************************"
}

# 安装文件
on_install() {
  ui_print "- 正在安装测试模块..."
  ui_print "- 这是一个测试模块，不会真正修改系统文件"
}

# 设置权限
set_permissions() {
  set_perm_recursive $MODPATH 0 0 0755 0644
} 

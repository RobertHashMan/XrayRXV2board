#!/usr/bin/env bash

##########################################################################
#Description:this script will help you optimize linux network performance
#
#Author：RbobertHashMan
#
##########################################################################

#API related
NODE_ID=0
NODE_TYPE="ShdowScoks"
PANEL_TYPE=''
API_HOST_KEY=''
API_HOST_ADDRESS=''

declare -r CONFIG_PATH='/etc/XrayR/config.yml'
declare -r RULE_LIST_PATH='/etc/XrayR/rulelist'
declare -r EXECTUABLE_FILE_PATH='/usr/local/XrayR/XrayR'
declare -r SYSTEMD_SERVICE_PATH='/etc/systemd/system/XrayR.service'
declare -r RULE_LIST_SOURCE='https://raw.githubusercontent.com/RobertHashMan/XrayRXV2board/main/rulelist.yml'

#Some basic settings here
plain='\033[0m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'

function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

function tcp_tune() {
    LOGI "begin tcp tune settings..."
    #delete original settings in sysctl.conf
    sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_adv_win_scale/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    cat >>/etc/sysctl.conf <<EOF
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p && sysctl --system
}

function root_check() {
    [[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本!\n" && exit 1
}

function xrayr_setting() {
    wget -N https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh
    chmod +x install.sh && bash install.sh
    if [[ ! -f ${SYSTEMD_SERVICE_PATH} || ! -f ${EXECTUABLE_FILE_PATH} ]]; then
        LOGE "install XrayR failed,plz check it"
        exit 0
    fi
    xrayr_panel_setting
    xrayr_api_host_setting
    xrayr_api_key_setting
    xrayr_node_id_setting
    xrayr_node_type_setting
}

#set up panel type
function xrayr_panel_setting() {
    if [ $# -gt 0]; then
        PANEL_TYPE=$1
    fi
    if [[ -z "${PANEL_TYPE}" ]]; then
        local panel_type=""
        read -p "当前未设置有效的ApiKey,请手动指定:" panel_type
        if [ -z ${panel_type} ]; then
            LOGE "未输入有效的API_HOST,脚本将退出"
            exit 0
        fi
        PANEL_TYPE=${panel_type}
    fi
    LOGI "设置PanelType:${panel_type}"
    sed -i 's/\"SSpanel\"/\"${PANEL_TYPE}\"/g' ${CONFIG_PATH}
}

#set up api host
#有传参用传参，无传参用默认值，默认值无效则请求输入
function xrayr_api_host_setting() {
    if [ $# -gt 0 ]; then
        API_HOST_ADDRESS=$1
    fi
    #judge whetehr we have api host first
    if [ -z ${API_HOST_ADDRESS} ]; then
        local api_host=''
        read -p "当前未预设API_HOST,请手动指定": api_host
        LOGI "当前所指定的API_HOST值为:${api_host}"
        if [ -z ${apt_host} ]; then
            LOGE "未输入有效的API_HOST,脚本将退出"
            exit 0
        fi
        API_HOST_ADDRESS=${apt_host}
    fi
    #judge whether the host is avaiable
    local status=$(curl -s -m 5 -IL ${API_HOST_ADDRESS} | grep 200)
    if [[ $? -ne 0 || ${status} == "" ]]; then
        LOGI "当前API_HOST:${API_HOST_ADDRESS} 无法建立连接,请检查"
        exit 0
    fi
    #set up
    sed -i "s#http://127.0.0.1:667#${API_HOST_ADDRESS}#g" ${CONFIG_PATH}
}

function xrayr_api_key_setting() {
    if [ $# -gt 0 ]; then
        API_HOST_KEY=$1
    fi
    if [[ -z "${API_HOST_KEY}" ]]; then
        local api_key=""
        read -p "当前未设置有效的ApiKey,请手动指定:" api_key
        if [ -z ${api_key} ]; then
            LOGE "未输入有效的API_HOST,脚本将退出"
            exit 0
        fi
        API_HOST_KEY=${api_key}
    fi
    LOGI "设置ApiKey:${API_HOST_KEY}"
    sed -i "s/123/${API_HOST_KEY}/g" ${CONFIG_PATH}
}

function xrayr_node_id_setting() {
    if [ $# -gt 0 ]; then
        NODE_ID=$1
    fi
    if [[ -z "${NODE_ID}" ]]; then
        local node_id=""
        read -p "当前未设置有效的NodeID,请手动指定:" node_id
        if [ -z ${node_id} ]; then
            LOGE "未输入有效的API_HOST,脚本将退出"
            exit 0
        fi
        NODE_ID=${node_id}
    fi
    LOGI "设置NodeID:${NODE_ID}"
    sed -i "s/NodeID:.*/NodeID: ${NODE_ID}/g" ${CONFIG_PATH}
}

#for node type setting
function xrayr_node_type_setting() {
    if [ $# -gt 0 ]; then
        NODE_TYPE=$1
    fi
    if [[ -z "${NODE_TYPE}" ]]; then
        local node_type=""
        read -p "当前未设置有效的NodeType,请手动指定:" node_type
        if [ -z ${node_type} ]; then
            LOGE "未输入有效的API_HOST,脚本将退出"
            exit 0
        fi
        NODE_TYPE=${node_type}
    fi
    LOGI "设置NodeType:${NODE_TYPE}"
    sed -i "s/NodeType:.*/NodeType: ${NODE_TYPE}/g" ${CONFIG_PATH}
}

#for speed limit
function enable_xrayr_speed_limit() {
    #default speed limit,unit:mbps
    local speed_limit=15
    if [ $# -gt 0]; then
        speed_limit=$1
    fi
    if [ ${speed_limit} -le 0 ]; then
        LOGE "速率限制设定≤0,请检查确认"
        exit 0
    fi
    if [[ -f ${CONFIG_PATH} ]]; then
        sed -i "s/Limit:.*/Limit: ${speed_limit}/g" ${CONFIG_PATH}
        sed -i "s/LimitSpeed:.*/LimitSpeed: ${speed_limit}/g" ${CONFIG_PATH}
        sed -i "s/LimitDuration:.*/LimitDuration: 30/g" ${CONFIG_PATH}
    fi

}

#for rule check,规则审查
function enable_xrayr_rule_check() {
    if [ ! -d "/etc/XrayR" ]; then
        LOGE "当前未安装xrayR,无/etc/XrayR目录,请确认"
    fi
    wget -O ${RULE_LIST_PATH} -N --no-check-certificate ${RULE_LIST_SOURCE}
    LOGI "更新rulelist成功,重启xrayr"
    xrayr restart
}

function time_zone_set() {
    LOGI "修改时区为CHN-ShangHai时区..."
    rm -rf /etc/localtime
    ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

#for customized route setting
#function enable_xrayr_route_setting() {
#
#}

function main() {
    if [[ $# -gt 0 ]]; then
        case $1 in
        "install")
            xrayr_setting
            ;;
        "optimize")
            tcp_tune
            ;;
        "ruleset")
            enable_xrayr_rule_check
            ;;
        "time")
            time_zone_set
            ;;
        *) ;;
        esac
    fi
}

main $*

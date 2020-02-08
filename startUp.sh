#!/usr/bin/env bash
#=================================================
#	Recommend OS: Debian/Ubuntu
#	Description: V2ray auto-deploy, wrote for GCP
#	Version: 1.0.0
#	Author: IITII
#	Blog: https://IITII.github.io
#=================================================
if [ -e /var/log/v2ray_install.log ]; then
    exit 0
fi

declare INSTALL_MODE=""
declare SITE_NAME=""
declare WS_PATH=""
declare UUID=""
declare DDNS_KEY=""

declare release="ubuntu"

log() {
    echo -e "[$(/bin/date)] $1"
}
check_root() {
    [ $(id -u) != "0" ] && {
        log "Error: You must be root to run this script"
        exit 1
    }
}
check_release() {
    if [ -f /etc/redhat-release ]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    fi
}
check_command() {
    if ! command -v $1 >/dev/null 2>&1; then
        log "Installing $1 from $release repo"
        if [ "$2" = "centos" ]; then
            sudo yum update >/dev/null 2>&1
            sudo yum -y install $3 >/dev/null 2>&1
        else
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install $3 -y >/dev/null 2>&1
        fi
        if [ $? -eq 0 ]; then
            log "Install $3 successful!!!"
        else
            log "Install $3 failed...Please check your network"
            exit 1
        fi
    fi
}
main() {
    cd /root/
    git clone https://github.com/iitii/autov2ray AutoV2ray
    cd AutoV2ray \
        && cd AutoV2ray \
        && bash v2ray.sh -t $INSTALL_MODE -w $SITE_NAME --ddns $DDNS_KEY -p $WS_PATH -u $UUID \
         >> /var/log/v2ray_install.log
}

check_root
check_release
check_command git $release git
main

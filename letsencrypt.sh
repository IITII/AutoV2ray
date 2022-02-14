#!/usr/bin/env bash
#=================================================
#	Recommend OS: Debian/Ubuntu
#	Description: Let's encrypt auto ssl
#	Version: 2.0.0
#	Author: IITII
#	Blog: https://IITII.github.io
#=================================================
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#=================================================
declare siteName=$1
declare he_net_ddns_key=$2
declare SSL_PATH=$3
declare release="ubuntu"
declare SLEEP_TIME=5

#  Auto scan & update the out-of-date certs
declare ACME_DIR="/root/.acme"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'
check_root() {
    [[ $(id -u) != "0" ]] && {
        log "Error: You must be root to run this script"
        exit 1
    }
}
log() {
    echo -e "[$(/bin/date)] $1"
}
log_success() {
    echo -e "${GREEN}[$(/bin/date)] $1${PLAIN}"
}
log_info() {
    echo -e "${YELLOW}[$(/bin/date)] $1${PLAIN}"
}
log_prompt() {
    echo -e "${SKYBLUE}[$(/bin/date)] $1${PLAIN}"
}
log_err() {
    echo -e "${RED}[$(/bin/date)] $1${PLAIN}"
}
show_help() {
    echo "Usage: $0 example.site site_ddns_key

Example: $0 baidu.com $(/usr/bin/uuidgen -t)
        "
}
check_release() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "alpine"; then
        release="alpine"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    fi
}
pre_command_run_status() {
    if [[ $? -eq 0 ]]; then
        log_success "Success"
    else
        log_err "Failed"
        exit 1
    fi
}
check_command() {
    if ! command -v $2 >/dev/null 2>&1; then
        log "Installing $2 from $1 repo"
        if [[ "$1" = "centos" ]]; then
            yum update >/dev/null 2>&1
            yum -y install $3 >/dev/null 2>&1
        elif [[ "$1" = "alpine" ]]; then
            apk update >/dev/null 2>&1
            apk --no-cache add $3 >/dev/null 2>&1
        else
            apt-get update >/dev/null 2>&1
            apt-get install $3 -y >/dev/null 2>&1
        fi
        pre_command_run_status
    fi
}
check_path() {
    log "Checking Path $1"
    if ! [[ -d $1 ]]; then
        log "Create Path $1"
        mkdir -p $1
    else
        echo "Existed !"
    fi
}
acme_sh() {
    log "Add some sample to nginx config file for auth identity..."
    cat ${CURRENT_DIR}/conf/simple.nginx | /bin/sed \
        -e "s/server_name \S\+/server_name $siteName;/g" |
        tee >/etc/nginx/sites-available/default
    log "Testing nginx config..."
    nginx -t >/dev/null 2>&1
    pre_command_run_status
    log "Reload nginx..."
    nginx -s reload >/dev/null 2>&1
    pre_command_run_status
    log "Installing acme..."
    git clone https://github.com/Neilpang/acme.sh.git /tmp/acme
    cd /tmp/acme &&
        ./acme.sh --install --home ${ACME_DIR}
    pre_command_run_status
    cd ${CURRENT_DIR}
    log "Set default CA to letsencrypt"
    ${ACME_DIR}/acme.sh --set-default-ca --server letsencrypt
    pre_command_run_status
    sleep 1
    log "Generating ssl file..."
    ${ACME_DIR}/acme.sh --issue -d ${siteName} --nginx
    pre_command_run_status
    log "Installing ssl file to default dir..."
    ${ACME_DIR}/acme.sh --installcert -d ${siteName} \
        --key-file ${SSL_PATH}/key.key \
        --fullchain-file ${SSL_PATH}/fullchain.cer \
        --reloadcmd "service nginx force-reload"
    pre_command_run_status
    log "Enable auto-upgrade..."
    ${ACME_DIR}/acme.sh --upgrade --auto-upgrade
    pre_command_run_status
}

main() {
    # see https://dns.he.net/docs.html
    log "Update DDNS Record..."
    curl -4 "https://$siteName:$he_net_ddns_key@dyn.dns.he.net/nic/update?hostname=$siteName"
    pre_command_run_status
    log "Sleep $SLEEP_TIME s --> Time for dns record update."
    sleep ${SLEEP_TIME}
    log "Update DDNS Record successful!!!"
}
# run
if [[ -z "$1" ]]; then
    show_help
    exit 1
fi
check_root
check_release
check_command ${release} curl "curl"
check_command ${release} git "git"
check_command ${release} tree "tree"
check_command ${release} nginx "nginx"
check_path ${SSL_PATH}
main
acme_sh
tree ${SSL_PATH}

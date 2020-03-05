#!/usr/bin/env bash
#=================================================
#	Recommend OS: Debian/Ubuntu
#	Description: V2ray auto-deploy
#	Version: 2.0.0
#	Author: IITII
#	Blog: https://IITII.github.io
#=================================================
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/v2ray/
#=================================================
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
siteName=""
wsPath=""
# ssl public: *.cer *.crt *.pem
# ssl key: *.key
sslPath=""
sslPublic=""
sslPrivate=""
uuid=""
he_net_ddns_key=""

# Don't modify
release="ubuntu"
flag=0
nginx_default_ssl="/etc/nginx/ssl"
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
pre_command_run_status() {
    if [[ $? -eq 0 ]]; then
        log_success "Success"
    else
        log_err "Failed"
        exit 1
    fi
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
check_release() {
    if [[ -f /etc/redhat-release ]]; then
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
show_help() {
    echo "Usage:
  $0 -h, --help            Show this page
  $0 -w                    siteName
  $0 -p, --path            v2ray web socket path, default \"/bin/date +\"%S\" | /usr/bin/base64\"
  $0 -u, --uuid            v2ray uuid
  $0 --ddns                dns.he.net ddns's key
  $0 --sslPath             ssl cert path
"
}
check_command() {
    if ! command -v $2 >/dev/null 2>&1; then
        log "Installing $2 from $1 repo"
        if [[ "$1" = "centos" ]]; then
            yum update >/dev/null 2>&1
            yum -y install $3 >/dev/null 2>&1
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
        log "Create Un-exist Path $1"
        mkdir -p $1
        pre_command_run_status
    else
        log "Existed !"
    fi
}
ssl_pub_key() {
    sslPublic=$(ls $1 | grep -v "key" | head -n 1)
    sslPrivate=$(ls $1 | grep "key" | head -n 1)
    cd $1
    if [[ -z ${sslPublic} ]] && [[ -z ${sslPrivate} ]]; then
        log_err "Right cert files?"
        log_info "Require: PublicKey: *.cer| *.crt| *.pem; PrivateKey: *.key"
        exit 1
    fi
    cd $2
}
pre_check_var() {
    log "Check necessary variable..."
    if [[ -z ${siteName} ]]; then
        log "SiteName can not be empty!!!"
        exit 1
    fi
    if [[ -z ${uuid} ]]; then
        log "uuid is Empty, Generating..."
        uuid=$(v2ctl uuid)
        log "Now uuid is $uuid"
    fi
    if [[ -z ${wsPath} ]]; then
        log "wsPath is Empty, Generating..."
        wsPath=$(/bin/date +"%S" | base64)
        log "Now wsPath is $wsPath"
    fi
    sslPath=${nginx_default_ssl}/${siteName}
    if [[ -z ${he_net_ddns_key} ]]; then
        flag=1
    else
        check_path ${sslPath}
        bash ${CURRENT_DIR}/letsencrypt.sh ${siteName} ${he_net_ddns_key} ${sslPath}
        ssl_pub_key ${sslPath} ${CURRENT_DIR}
    fi
    if [[ -z ${sslPath} ]] && [[ ${flag} -eq 1 ]]; then
        log_info "It looks that you have nothing..."
        log "Generate self signed cert..."
        check_path ${sslPath}
        v2ctl cert -ca -expire 8760h -file ${sslPath}/v2 \
            -name "${siteName}" -org "${siteName}" -domain "${siteName}" >/dev/null 2>&1
        ssl_pub_key ${sslPath} ${CURRENT_DIR}
    fi
    if [[ ${flag} -eq 1 ]]; then
        log_info \
            "Check again: siteName: $siteName , uuid: $uuid , wsPath: $wsPath , he_net_ddns_key: $he_net_ddns_key"
        tree ${sslPath}
    else
        log_info \
            "Check again: siteName: $siteName , uuid: $uuid , wsPath: $wsPath , sslPath: $sslPath , sslPublic: $sslPublic , sslPrivate: $sslPrivate"
    fi
}
firewall_rule() {
    log "Adding iptable rules..."
    if [[ "$release" = "centos" ]]; then
        systemctl stop firewalld.service >/dev/null 2>&1
        systemctl disable firewalld.service >/dev/null 2>&1
    else
        ufw allow 22 >/dev/null 2>&1
        ufw allow 80 >/dev/null 2>&1
        ufw allow 443 >/dev/null 2>&1
        ufw reload >/dev/null 2>&1
    fi
    iptables -A INPUT -p tcp -m multiport --dports 22,80,443 -j ACCEPT
    iptables -A OUTPUT -p tcp -m multiport --sports 22,80,443 -j ACCEPT
    log "Finished!!!"
}
vmess_gen() {
    temp=$(/bin/cat ${CURRENT_DIR}/conf/share.json | /bin/sed \
        -e "s/baidu.com\",$/$siteName\",/g" \
        -e "s/\"id\": \"\S\+/\"id\": \"$uuid\",/g" \
        -e "s/\"path\": \"\S\+/\"path\": \"\/$wsPath\",/g" |
        base64 -w 0)
    temp=$(echo vmess://${temp})
    log_prompt "v2ray link: ${SKYBLUE}${temp}${PLAIN}"
    echo "${temp}" >/root/v2ray_link &&
        log_success "v2ray link save to /root/v2ray_link"
}
main() {
    log "Modifying config file..."
    log "Modifying nginx config file"
    /bin/cat ${CURRENT_DIR}/conf/tls.nginx | /bin/sed \
        -e "s/server_name \S\+/server_name $3;/g" \
        -e "s/ssl_certificate \S\+/ssl_certificate \/etc\/nginx\/ssl\/$3\/$4;/g" \
        -e "s/ssl_certificate_key \S\+/ssl_certificate_key \/etc\/nginx\/ssl\/$3\/$5;/g" \
        -e "s/location \/china \S\+/location \/$2 {/g" \
        -e "s/root \S\+/root \/var\/www\/html;/g" \
        -e "s/fastcgi_pass \S\+/fastcgi_pass unix:\/run\/php\/$(ls /run/php/ | grep sock | head -n 1);/g" \
        >/etc/nginx/sites-available/default
    cp -R ${CURRENT_DIR}/www/* /var/www/html/
    log "Testing nginx config..."
    nginx -t >/dev/null 2>&1
    pre_command_run_status
    log "Reload nginx..." && nginx -s reload >/dev/null 2>&1
    pre_command_run_status

    log "Modifying v2ray config file"
    /bin/cat ${CURRENT_DIR}/conf/server.json | /bin/sed \
        -e "s/\"id\": \"\S\+/\"id\": \"$1\",/g" \
        -e "s/\"path\": \"\S\+/\"path\": \"\/$2\"/g" |
        tee >/etc/v2ray/config.json
    log "Reload v2ray..."
    systemctl restart v2ray
    pre_command_run_status
    log "Enable auto start..." && systemctl enable v2ray
    pre_command_run_status
    firewall_rule
}

if [[ -z "$1" ]]; then
    show_help
    exit 1
fi
cd ${CURRENT_DIR}
check_command ${release} getopt "util-linux"
check_command ${release} tee "tee"
check_command ${release} base64 "coreutils"
check_command ${release} nginx "nginx"
check_command ${release} curl "curl"
if [[ "$release" = "centos" ]]; then
    yum update >/dev/null 2>&1
    yum install -y php-fpm >/dev/null 2>&1
else
    apt-get update >/dev/null 2>&1
    apt-get install -y php-fpm >/dev/null 2>&1
fi

ARGS=$(getopt -a -o hw:p:u: -l help,path:,ddns:,uuid:,sslPath: -- "$@")
#set -- "${ARGS}"
#log "\$@: $@"
eval set -- "${ARGS}"
while [[ -n $1 ]]; do
    case "$1" in
    -w)
        if [[ -n $2 ]]; then
            siteName="$2"
        else
            log "SiteName can not be empty!!!"
            exit 1
        fi
        shift
        ;;
    -h | --help)
        show_help
        ;;
    -p | --path)
        wsPath="$2"
        shift
        ;;
    -u | --uuid)
        uuid="$2"
        shift
        ;;
    --ddns)
        he_net_ddns_key="$2"
        shift
        ;;
    --sslPath)
        if [[ -e $2 ]]; then
            sslPath=$(cd $2 && pwd)
            check_path "${nginx_default_ssl}/${siteName}"
            cp ${sslPath}/* "${nginx_default_ssl}/${siteName}/"
            sslPath=${nginx_default_ssl}/${siteName}
            ssl_pub_key ${sslPath} ${CURRENT_DIR}
        else
            log_err "sslPath don't exist!!!"
            exit 1
        fi

        shift
        ;;
    --)
        shift
        break
        ;;
    *)
        log "unknown argument"
        exit 1
        ;;
    esac
    shift
done

if ! ( (command -v v2ray) && (command -v v2ctl)) >/dev/null 2>&1; then
    log "Install main program..."
    rm -rf /usr/bin/v2ray
    bash <(curl -L -s https://install.direct/go.sh) >/dev/null 2>&1
    pre_command_run_status
else
    log_prompt "Already installed"
fi

pre_check_var
main ${uuid} ${wsPath} ${siteName} ${sslPublic} ${sslPrivate}
pre_command_run_status
vmess_gen
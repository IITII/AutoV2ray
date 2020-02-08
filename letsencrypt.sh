#!/usr/bin/env bash
#=================================================
#	Recommend OS: Debian/Ubuntu
#	Description: Auto letsencrypt.sh
#	Version: 1.0.0
#	Author: IITII
#	Blog: https://IITII.github.io
#=================================================
declare siteName=$1
declare he_net_ddns_key=$2
declare release="ubuntu"
declare SLEEP_TIME=3
declare SSL_PATH="/etc/nginx/ssl/"
log() {
    echo -e "[$(/bin/date)] $1"
}
help() {
    echo "Usage: $0 example.site site_ddns_key

Example: $0 baidu.com $(/usr/bin/uuidgen -t)
        "
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
            log "Install $3 failed..."
        fi
    fi
}
check_root() {
    [ $(id -u) != "0" ] && {
        log "Error: You must be root to run this script"
        exit 1
    }
}
check_path() {
    log "Checking Path $1"
    if ! [ -d $1 ]; then
        log "Create Unexist Path $1"
        mkdir -p $1
    else
        echo "Existed !"
    fi
}
acme_sh() {
    check_command tee $release tee
    if [ "$release" = "centos" ]; then
        sudo yum update >/dev/null 2>&1
        sudo yum -y install nginx php-fpm >/dev/null 2>&1
    else
        sudo apt-get update >/dev/null 2>&1
        sudo apt-get install nginx php-fpm -y >/dev/null 2>&1
    fi \
        && log "Add some sample to nginx config file for auth identity..."
    cat conf/simple.nginx | /bin/sed \
        -e "s/server_name \S\+/server_name $siteName;/g" \
        | tee >/etc/nginx/sites-available/default \
        && log "success"
    log "Testing nginx config..."
    nginx -t >/dev/null 2>&1 \
        && log "success"
    log "Reload nginx..."
    nginx -s reload >/dev/null 2>&1 \
        && log "success"
    cd ~/
    log "Installing acme..." \
        && curl https://get.acme.sh | sh >/dev/null 2>&1 \
        && log "Install acme successful!!!"
    log "Generating ssl file..." \
        && ~/.acme.sh/acme.sh --issue -d $siteName --nginx \
        && log "Generate ssl file successful!!!"
    log "Installing ssl file to default dir..." \
        && ~/.acme.sh/acme.sh --installcert -d $siteName \
            --key-file $SSL_PATH$siteName/key.key \
            --fullchain-file $SSL_PATH$siteName/fullchain.cer \
            --reloadcmd "service nginx force-reload"
    log "Enable auto-upgrade..."
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade \
        && log "Success!!!"
}

main() {
    # see https://dns.he.net/docs.html
    log "Update DDNS Record..."
    check_command curl $release curl
    curl -4 "https://$siteName:$he_net_ddns_key@dyn.dns.he.net/nic/update?hostname=$siteName" >/dev/null 2>&1 \
        && log "Sleep $SLEEP_TIME s --> Time for dns record update." \
        && sleep $SLEEP_TIME \
        && log "Update DDNS Record successful!!!"
    check_path $SSL_PATH$siteName
}
# run
if [ -z "$1" ]; then
    help
    exit 1
fi
check_root
check_release
main \
    && acme_sh \
    && log "Generate ssl file success" \
    && check_command tree $release tree
tree $SSL_PATH$siteName

#!/usr/bin/env bash
#=================================================
#	Recommend OS: Debian/Ubuntu
#	Description: V2ray auto-deploy
#	Version: 1.0.0
#	Author: IITII
#	Blog: https://IITII.github.io
#=================================================
declare siteName=""
declare wsPath=""
declare sslPath=""
declare uuid=""
declare he_net_ddns_key=""
declare installMode="server"

declare release="ubuntu"
declare GETOPT_PACKAGE_NAME="util-linux"
declare BASE64_PACKAGE_NAME="coreutils"
declare webROOT="/var/www/FileList"
declare repoName="AutoV2ray"
declare repoAddr="https://github.com/IITII/AutoV2ray"
declare siteRepoName="FileList"
declare siteRepoAddr="https://github.com/IITII/FileList"

log() {
    echo -e "[$(/bin/date)] $1"
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
help() {
    echo "Usage:
  $0 -h, --help            Show this page
  $0 -t:                   Install, default \"$installMode\"
    $0 -t 1                Install server
    $0 -t 2                Install client
  $0 -w                    siteName
  $0 -p, --path            v2ray web socket path
                              default \"/bin/date +\"%S\" | /usr/bin/base64\"
  $0 -u                    v2ray uuid
  $0 --ddns                dns.he.net ddns's key
"
}
check_path() {
    log "Checking Path $1"
    if ! [ -d $1 ]; then
        log "Create Unexist Path $1"
        mkdir -p $1
        if [ $? -eq 0 ]; then
            log "Create path $1 successful!!!"
        else
            log "Create path $1 failed..."
        fi
    else
        log "Existed !"
    fi
}
git_clone() {
    cd ~/ \
        && eval /usr/bin/git clone $1 $2 \
        && cd $2
}
pre_check_var() {
    case "$installMode" in
    server)
        log "Check server's necessary variable..."
        if [ -z $uuid ]; then
            log "uuid is Empty, Generating..."
            uuid=$(/usr/bin/uuidgen -t)
            log "Now uuid is $uuid"
        fi
        if [ -z $wsPath ]; then
            log "wsPath is Empty, Generating..."
            wsPath=$(/bin/date +"%S" | base64)
            log "Now wsPath is $wsPath"
        fi
        # check sitename
        if [ -z $siteName ]; then
            log "SiteName can not be empty!!!"
            exit 1
        fi
        if [ -z $sslPath ]; then
            log "sslPath is Empty, Generating..."
            sslPath="/etc/nginx/ssl/$siteName"
            log "Now sslPath is $siteName"
        fi
        # check he_net_ddns_key
        if [ -z $he_net_ddns_key ]; then
            log "$ddns_key can not be empty!!!"
            exit 1
        fi
        log "Now: server variable value is uuid: $uuid , wsPath: $wsPath , siteName: $siteName, webROOT: $webROOT , sslPath: $sslPath , he_net_ddns_key: $he_net_ddns_key"
        ;;
    client)
        log "Check client's necessary variable..."
        if [ -z $uuid ]; then
            log "wsPath is Empty, Generating..."
            uuid=$(/usr/bin/uuidgen -t)
            log "Now wsPath is $uuid"
        fi
        if [ -z $wsPath ]; then
            log "wsPath is Empty, Generating..."
            wsPath=$(/bin/date +"%S" | base64)
            log "Now wsPath is $wsPath"
        fi
        # check sitename
        if [ -z $siteName ]; then
            log "SiteName can not be empty!!!"
            exit 1
        fi
        log "Now: client variable value is uuid: $uuid , wsPath: $wsPath , siteName: $siteName"
        ;;
    esac
}
firewall_rule() {
    case "$installMode" in
    server)
        log "Adding server iptable rules..."
        if [ "$release" = "centos" ]; then
            systemctl stop firewalld.service
            systemctl disable firewalld.service
        else
            ufw allow 22 >/dev/null 2>&1
            ufw allow 80 >/dev/null 2>&1
            ufw allow 443 >/dev/null 2>&1
            ufw reload
        fi
        iptables -A INPUT -p tcp -m multiport --dports 22,80,443 -j ACCEPT
        iptables -A OUTPUT -p tcp -m multiport --sports 22,80,443 -j ACCEPT
        ;;
    client)
        log "Adding client iptable rules..."
        if [ "$release" = "centos" ]; then
            systemctl stop firewalld.service
            systemctl disable firewalld.service
        else
            ufw allow 22 >/dev/null 2>&1
            ufw allow 7878 >/dev/null 2>&1
            ufw allow 10809 >/dev/null 2>&1
            ufw reload
        fi
        iptables -A INPUT -p tcp -m multiport --dports 22,7878,10809 -j ACCEPT
        iptables -A OUTPUT -p tcp -m multiport --sports 22,7878,10809 -j ACCEPT
        iptables -A OUTPUT -p udp -m multiport --sports 7878 -j ACCEPT
        ;;
    esac
    log "Finished!!!"
}
server() {
    #echo $@
    log "Install main program..."
    bash <(curl -L -s https://install.direct/go.sh) >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Install v2ray successful!!!"
        log "Generating $3 ssl file..."
        bash ./letsencrypt.sh $3 $6
        log "Modifing config file..."
        log "Modifing nginx config file"
        # function foo() {
        #   /bin/cat conf/tls.nginx | /bin/sed \
        #   -e "s/server_name \S\+/server_name $3;/g" \
        #   -e "s/ssl_certificate \S\+/ssl_certificate \/etc\/nginx\/ssl\/$3\/fullchain.cer;/g" \
        #   -e "s/ssl_certificate_key \S\+/ssl_certificate_key \/etc\/nginx\/ssl\/$3\/key.key;/g" \
        #   -e "s/location \/china \S\+/location \/$2;/g" \
        #   -e "s/root \S\+/root $4;/g"
        # }
        /bin/cat conf/tls.nginx | /bin/sed \
            -e "s/server_name \S\+/server_name $3;/g" \
            -e "s/ssl_certificate \S\+/ssl_certificate \/etc\/nginx\/ssl\/$3\/fullchain.cer;/g" \
            -e "s/ssl_certificate_key \S\+/ssl_certificate_key \/etc\/nginx\/ssl\/$3\/key.key;/g" \
            -e "s/location \/china \S\+/location \/$2 {/g" \
            -e "s/root \S\+/root \/var\/www\/FileList;/g" \
            -e "s/fastcgi_pass \S\+/fastcgi_pass unix:\/run\/php\/$(ls /run/php/ | grep sock | head -n 1);/g" \
            >/etc/nginx/sites-available/default \
            && log "success"

        log "Modifing v2ray config file"
        /bin/cat conf/server.json | /bin/sed \
            -e "s/\"id\": \"\S\+/\"id\": \"$1\",/g" \
            -e "s/\"path\": \"\S\+/\"path\": \"\/$2\"/g" \
            | tee >/etc/v2ray/config.json \
            && log "success"
        cd ~/ \
            && eval git clone $siteRepoAddr $siteRepoName >/dev/null 2>&1
        cp -R $siteRepoName $webROOT \
            && log "Testing nginx config..."
        nginx -t >/dev/null 2>&1 && log "success"
        log "Reload nginx..."
        nginx -s reload >/dev/null 2>&1 && log "success"
        log "Reload v2ray..."
        #Then reload v2ray
        systemctl restart v2ray && log "Reload successful!!!" && log "$installMode installation finished!!!"
        firewall_rule
    else
        log "Install v2ray failed!!!"
        exit 1
    fi
}
client() {
    #echo $@
    log "Install main program..."
    bash <(curl -L -s https://install.direct/go.sh) >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Install v2ray successful!!!"
        log "Modifing config file..."
        log "Modifing v2ray config file"
        /bin/cat conf/client.json | /bin/sed \
            -e "s/\"address\": \"baidu.com\"/\"address\": \"$3\"/g" \
            -e "s/\"id\": \"\S\+/\"id\": \"$1\",/g" \
            -e "s/\"path\": \"\S\+/\"path\": \"\/$2\",/g" \
            | tee >/etc/v2ray/config.json \
            && log "success" \
            && systemctl restart v2ray && log "Reload successful!!!" && log "$installMode installation finished!!!"
        firewall_rule
    else
        log "Install v2ray failed!!!"
        exit 1
    fi
}
# "s/\"id\": \"\S\+/\"id\": \"$SED\"/g"

check_root
if [ -z "$1" ]; then
    help
    exit 1
fi
check_release
# pre-check
check_command getopt $release $GETOPT_PACKAGE_NAME
check_command base64 $release $BASE64_PACKAGE_NAME
check_command tee $release $BASE64_PACKAGE_NAME
check_command git $release git
if [ "$release" = "centos" ]; then
    check_command uuidgen $release util-linux
else
    check_command uuidgen $release uuid-runtime
fi

ARGS=$(getopt -a -o hvt:w:l:p:u: -l log:,help,path,ddns: -- "$@")
#set -- "${ARGS}"
#log "\$@: $@"
eval set -- "${ARGS}"
while [ -n $1 ]; do
    #log "\$@: $@"
    case "$1" in
    -t)
        case $2 in
        1)
            installMode="server"
            ;;
        2)
            installMode="client"
            ;;
        *)
            log "unkonw argument"
            exit 1
            ;;
        esac
        shift
        ;;
    -w)
        if [ -n $2 ]; then
            siteName="$2"
        else
            log "SiteName can not be empty!!!"
        fi
        shift
        ;;
    -h | --help)
        help
        ;;
    -p | --path)
        wsPath="$2"
        shift
        ;;
    -u)
        uuid="$2"
        shift
        ;;
    --ddns)
        he_net_ddns_key="$2"
        shift
        ;;
    --)
        shift
        break
        ;;
    *)
        log "unkonw argument"
        exit 1
        ;;
    esac
    shift
done

# check value
# if value is null or "", just give them a random value
pre_check_var

# install
git_clone $repoAddr $repoName
cd ~/$repoName
case "$installMode" in
server)
    log "Installing server..."
    server $uuid $wsPath $siteName $webROOT $sslPath $he_net_ddns_key
    ;;
client)
    log "Installing client..."
    client $uuid $wsPath $siteName
    ;;
esac
if [ $? -eq 0 ]; then
    log "Install successful!!!"
    exit 0
else
    log "Install failed..."
    exit 1
fi

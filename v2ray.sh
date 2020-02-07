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

declare LOG_PARAM="2>&1"
declare logPath="/dev/null"
declare log_Path="> $logPath $LOG_PARAM"

declare release="ubuntu"
declare GETOPT_PACKAGE_NAME="util-linux"
declare BASE64_PACKAGE_NAME="coreutils"
declare webROOT="/var/www/FileList"
declare repoName="AutoV2ray"
declare repoAddr="https://github.com/IITII/AutoV2ray"
declare siteRepoName="FileList"
declare siteRepoAddr="https://github.com/IITII/FileList"

log() {
  echo $(/bin/date +"%Z %Y-%m-%d %H:%M:%S"): $1
}
check_command() {
  if ! eval command -v $1 $log_Path; then
    log "Installing $1 from $release repo"
    if [ "$2" = "centos" ]; then
      eval sudo yum update $log_Path
      eval sudo yum -y install $3 $log_Path
    else
      eval sudo apt-get update $log_Path
      eval sudo apt-get install $3 -y $log_Path
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
  $0 -w servrName          web site servername
  $0 -l, --log logFilePath logFilePath
                              default \"$logPath\"
  $0 -v                    verbose
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
default_value() {
  if [ -z $1 ]; then
    echo $@
    eval $1=$2
  fi
}
git_clone() {
  cd ~/ &&
    eval /usr/bin/git clone $1 $2 &&
    cd $2
}
server() {
  #echo $@
  log "Install main program..."
  eval bash <(curl -L -s https://install.direct/go.sh) $log_Path
  if [ $? -eq 0 ]; then
    log "Install v2ray successful!!!"
    log "Generating $3 ssl file..."
    bash ./letsencrypt.sh $3 $6 $log_Path
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
      -e "s/location \/china \S\+/location \/$2;/g" \
      -e "s/root \S\+/root $4;/g" |
      tee >/etc/nginx/sites-available/default &&
      log "success"

    log "Modifing v2ray config file"
    /bin/cat conf/server.json | /bin/sed \
      -e "s/\"id\": \"\S\+/\"id\": \"$1\"/g" \
      -e "s/\"path\": \"\S\+/\"path\": \"\/$2\"/g" |
      tee >/etc/v2ray/config.json &&
      log "success"
    eval git clone $siteRepoAddr $siteRepoName $log_Path
    cd ~/ && cp -R $siteRepoName $webROOT &&
      # Reload nginx first
      log "Testing nginx config..."
    eval nginx -t $log_Path && log "success"
    log "Reload nginx..."
    eval nginx -s reload $log_Path && log "success"
    log "Reload v2ray..."
    #Then reload v2ray
    systemctl restart v2ray && log "Reload successful!!!" && log "$installMode installation finished!!!"
  else
    log "Install v2ray failed!!!"
    exit 1
  fi
}
client() {
  #echo $@
  log "Install main program..."
  eval bash <(curl -L -s https://install.direct/go.sh) $log_Path
  if [ $? -eq 0 ]; then
    log "Install v2ray successful!!!"
    log "Modifing config file..."
    log "Modifing v2ray config file"
    /bin/cat conf/client.json | /bin/sed \
      -e "s/\"address\": \"baidu.com\"/\"address\": \"$3\"/g" \
      -e "s/\"id\": \"\S\+/\"id\": \"$1\"/g" \
      -e "s/\"path\": \"\S\+/\"path\": \"\/$2\"/g" |
      tee >/etc/v2ray/config.json &&
      log "success" &&
      systemctl restart v2ray && log "Reload successful!!!" && log "$installMode installation finished!!!"
  else
    log "Install v2ray failed!!!"
    exit 1
  fi
}
# "s/\"id\": \"\S\+/\"id\": \"$SED\"/g"
main() {
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
    -l | --log)
      if [ -z $2 ]; then
        logPath="$2"
      else
        log "logPath can not be empty!!!"
      fi
      shift
      ;;
    -v)
      log_Path=""
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
  # check sitename
  if [ -z $siteName ]; then
    log "SiteName can not be empty!!!"
    exit 1
  fi
  # check he_net_ddns_key
  if [ -z $he_net_ddns_key ]; then
    log "$ddns_key can not be empty!!!"
    exit 1
  fi

  # check value
  default_value wsPath $(/bin/date +"%S" | base64)
  default_value uuid $(/usr/bin/uuidgen -t)
  default_value sslPath "/etc/nginx/ssl/$siteName"

  # install
  git_clone $repoAddr $repoName
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
}
main
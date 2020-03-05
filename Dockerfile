FROM ubuntu:latest
ENV siteName="baidu.com"
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update >/dev/null 2>&1 \
&& apt install -y git >/dev/null 2>&1 \
&& /usr/bin/git clone https://github.com/IITII/AutoV2ray /tmp/AutoV2ray \
&& bash /tmp/AutoV2ray/v2ray.sh -w ${siteName}
EXPOSE 80 443
#ENTRYPOINT
FROM ubuntu:latest as builder
RUN apt update -y >/dev/null 2>&1
RUN apt install -y curl git \
&& /usr/bin/git clone https://github.com/IITII/AutoV2ray /root/AutoV2ray
RUN curl -L -s https://install.direct/go.sh | bash
FROM alpine:latest
LABEL maintainer="IITII <ccmejx@gmail.com>"
COPY --from=builder /usr/bin/v2ray/v2ray /usr/bin/v2ray/
COPY --from=builder /usr/bin/v2ray/v2ctl /usr/bin/v2ray/
COPY --from=builder /usr/bin/v2ray/geoip.dat /usr/bin/v2ray/
COPY --from=builder /usr/bin/v2ray/geosite.dat /usr/bin/v2ray/
COPY --from=builder /etc/v2ray/config.json /tmp/config.json
COPY --from=builder /root/AutoV2ray /root/AutoV2ray
WORKDIR /root
# service support
RUN apk --no-cache add openrc ca-certificates \
&& mkdir /var/log/v2ray/ \
&& chmod +x /usr/bin/v2ray/v2ctl  \
&& chmod +x /usr/bin/v2ray/v2ray \
&& if [[ ! -e /etc/v2ray/config.json ]];then mkdir /etc/v2ray; cp /tmp/config.json /etc/v2ray/config.json; else rm /tmp/config.json; fi
EXPOSE 22 80 443
ENV PATH /usr/bin/v2ray:$PATH
CMD ["v2ray", "-config=/etc/v2ray/config.json"]
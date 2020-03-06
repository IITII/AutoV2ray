FROM ubuntu:latest as builder
RUN apt update -y >/dev/null 2>&1
RUN apt install -y curl
RUN curl -L -s https://install.direct/go.sh | bash
FROM alpine:latest
LABEL maintainer="IITII <ccmejx@gmail.com>"
COPY --from=builder /usr/bin/v2ray/v2ray /usr/bin/v2ray/
COPY --from=builder /usr/bin/v2ray/v2ctl /usr/bin/v2ray/
COPY --from=builder /usr/bin/v2ray/geoip.dat /usr/bin/v2ray/
COPY --from=builder /usr/bin/v2ray/geosite.dat /usr/bin/v2ray/
WORKDIR /root
RUN apk --no-cache add git \
&& /usr/bin/git clone https://github.com/IITII/AutoV2ray /root/AutoV2ray \
&& apk del git
EXPOSE 22 80 443
ENV PATH /usr/bin/v2ray:$PATH
CMD ["v2ray", "-config=/etc/v2ray/config.json"]
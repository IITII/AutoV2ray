# AutoV2ray
> let v2ray configure automatic ( TLS+NGINX+WEB )

**[简体中文](https://iitii.github.io/2020/02/08/1/)**
### Pre-check
1. A [dns.he.net](dns.he.net) Account and at least have one domain on it
2. A domain on dns.he.net which had configure ddns
3. A clean linux server
4. Some basic knowledge of operating Linux

### Some presume
1. Your server ip is: `1.1.1.1`
2. Your domain is: `v2.google.com`
3. Your ddns key is: `re35A5xFGdEzrRow`
4. Your ws path is: `path`
5. Your uuid is: `85d0e39a-4571-44da-80bb-caf5f853c2ba`

### Quick start
1. Login to your server: `ssh root@1.1.1.1`
2. Clone repo: `git clone https://github.com/IITII/AutoV2ray.git`
3. cd dir & start install
   1. Install server
      1. Simplest: `cd AutoV2ray && bash v2ray.sh -w v2.google.com --ddns re35A5xFGdEzrRow`
      2. Full: `cd AutoV2ray && bash v2ray.sh -t 1 -w v2.google.com --ddns re35A5xFGdEzrRow -p path -u 85d0e39a-4571-44da-80bb-caf5f853c2ba`
      3. Add somthing else: `cd AutoV2ray && bash v2ray.sh -t 1 -w v2.google.com --ddns re35A5xFGdEzrRow -p path -u 85d0e39a-4571-44da-80bb-caf5f853c2ba && systemctl status v2ray nginx`
   2. Install client
      1. Simplest: `cd AutoV2ray && bash v2ray.sh -t 2 -w v2.google.com`
      2. Full: `cd AutoV2ray && bash v2ray.sh -t 2 -w v2.google.com -p path -u 85d0e39a-4571-44da-80bb-caf5f853c2ba`
      3. Add somthing else: `cd AutoV2ray && bash v2ray.sh -t 2 -w v2.google.com -p path -u 85d0e39a-4571-44da-80bb-caf5f853c2ba && systemctl status v2ray`
4. If it is necessary to add ssh key to server. Please copy this repo and modify `ssh.pub` file, push it to your forked repo. Re-clone the repo from your's. Then add `&& cat ~/AutoV2ray/ssh.pub >> ~/.ssh/authorized_keys` command to the end of command line. Then, it will work.
5. Enjoy yourself

```bash
root@test-machine# bash v2ray.sh
Usage:
  ./v2ray.sh -h, --help            Show this page
  ./v2ray.sh -t:                   Install, default "server"
    ./v2ray.sh -t 1                Install server
    ./v2ray.sh -t 2                Install client
  ./v2ray.sh -w                    siteName
  ./v2ray.sh -p, --path            v2ray web socket path
                              default "/bin/date +"%S" | /usr/bin/base64"
  ./v2ray.sh -u                    v2ray uuid
  ./v2ray.sh --ddns                dns.he.net ddns's key

```
### Debug
* `cat /var/v2ray/config.json` & `cat /etc/nginx/sites-enabled/default` will help you a lot.
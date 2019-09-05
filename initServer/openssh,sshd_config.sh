#!/bin/bash

# CENTOS 서버 세팅 정보 load / 작업 디렉토리로 이동
source ${TEMP_PATH}/${SETTING_INFO}.sh


##############################################################################

# openSSH 최신버전 설치

# GCP CENTOS7 최초 설치후 ssh -V 로 확인한 버전 : OpenSSH_7.4p1, OpenSSL 1.0.2k-fips  26 Jan 2017

# 최초 설치 후 sshd 계정 정보 : sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin
# 최초 설치 후 sshd 그룹 정보 : sshd:x:74:
# 최초 설치 후 sshd 서비스 스크립트 경로 : /usr/lib/systemd/system/sshd.service
# 최초 설치 후 sshd-keygen 서비스 스크립트 경로 : /usr/lib/systemd/system/sshd-keygen.service

# openSSH 다운로드 경로 : 8.0 ( 2019-04-17 )
OPENSSL_DOWNLOAD_URL=https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-8.0p1.tar.gz

# https://www.tecmint.com/install-openssh-server-from-source-in-linux/
# http://www.linuxfromscratch.org/blfs/view/systemd/postlfs/openssh.html
# https://servern54l.tistory.com/entry/Linux-Server-OpenSSH-Source-Compile

# pam, selinux, kerberos5 옵션으로 컴파일시 필요
yum install -y \
   pam-devel \
   libselinux-devel \
   krb5-devel

wget -c ${OPENSSL_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/openssh.tar.gz && \
tar -zxf ${TEMP_PATH}/openssh.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep openssh-) \
   ${TEMP_PATH}/openssh \
   ${TEMP_PATH}/openssh-*

# 기존 설치된 openssh rpm, openssh-clients 제거
# openssh-server 는 못 지움 : ssh 접속이 안됨
rpm -e --nodeps openssh openssh-clients

# openssh-clients 제거시 생성된 ssh_config.rpmsave 제거
rm -rf /etc/ssh/ssh_config.rpmsave

cd openssh

# --prefix : SSH 설치 경로, 기본값 /usr/local 로 지정함
./configure \
   --prefix=/usr/local \
   --sysconfdir=/etc/ssh \
   --with-md5-passwords \
   --with-pam \
   --with-selinux \
   --with-kerberos5

make
make install
make clean

# https://servern54l.tistory.com/entry/Linux-Server-OpenSSH-Source-Compile?category=563849
cp ${TEMP_PATH}/openssh/contrib/sshd.pam.generic \
   /etc/pamd.sshd

cd ..

##############################################################################

# https://www.aonenetworks.kr/official.php/home/info/975

# /etc/ssh/sshd_config 에 보안 설정 추가
cat >> /etc/ssh/sshd_config \
<<EOF
#############################

Port ${SSH_CONNECTION_PORT}
Protocol 2

MaxAuthTries 5

EOF

firewall-cmd --permanent --zone=public --add-port=${SSH_CONNECTION_PORT}/tcp
firewall-cmd --reload

# https://zero-gravity.tistory.com/270
semanage port -a -t ssh_port_t -p tcp ${SSH_CONNECTION_PORT}

systemctl restart sshd

##############################################################################

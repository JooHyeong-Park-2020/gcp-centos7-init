#!/bin/bash

# CENTOS 서버 세팅 정보 load / 작업 디렉토리로 이동
source ${WORK_DIR}/settingInfo.sh


##############################################################################

# 사용자 그룹 / 유저 생성 / 유저 패스워드 변경
groupadd -g ${NEW_GROUP_ID} ${NEW_GROUP} && \
useradd -g ${NEW_GROUP} ${NEW_USER} && \
echo ${NEW_USER_PASSWORD} | passwd ${NEW_USER} --stdin

# 사용자 전용 bin 디렉토리 생성
mkdir -p /home/${NEW_USER}/bin

# DB_USER_GROUP, NGINX_USER_GROUP, SERVER_USER_GROUP 생성
groupadd ${DB_USER_GROUP}
groupadd ${NGINX_USER_GROUP}
groupadd ${SERVER_USER_GROUP}

# NEW_USER 를 각 그룹에 추가
usermod -aG ${DB_USER_GROUP} ${NEW_USER}
usermod -aG ${NGINX_USER_GROUP} ${NEW_USER}
usermod -aG ${SERVER_USER_GROUP} ${NEW_USER}

##############################################################################

# 개발환경 디렉토리 생성 / 디렉토리별 권한 부여
mkdir -p ${DEV_TOOLS_PATH}

# 개발환경 디렉토리 내 개발 tool 별 디렉토리 생성
mkdir -p ${GIT_MAIN_PATH}
mkdir -p ${STS_WORKSPACE_PATH}
mkdir -p ${BUILD_MAIN_PATH}
mkdir -p ${DEPENDENCY_MAIN_PATH}
mkdir -p ${UTILS_MAIN_PATH}

chown -R ${NEW_USER}:${NEW_GROUP} ${DEV_TOOLS_PATH}

# 데이터베이스 설치 디렉토리 생성
mkdir -p ${DATABASE_MAIN_PATH}
chown -R ${NEW_USER}:${DB_USER_GROUP} ${DATABASE_MAIN_PATH}

# 라이브러리 설치 디렉토리 생성
mkdir -p ${LIBRARY_MAIN_PATH}
chown -R ${NEW_USER}:${SERVER_USER_GROUP} ${LIBRARY_MAIN_PATH}

# 라이브러리 디렉토리는 모든 사용자가 읽기/실행 가능, 단 쓰기는 소유자만 가능
chmod 755 ${LIBRARY_MAIN_PATH}

# 정적 파일 저장 디렉토리 생성
mkdir -p ${STATIC_FILE_MAIN_PATH}
chown -R ${NEW_USER}:${NGINX_USER_GROUP} ${STATIC_FILE_MAIN_PATH}

# 웹서버 설치 디렉토리 생성
mkdir -p ${SERVER_MAIN_PATH}
chown -R ${NEW_USER}:${SERVER_USER_GROUP} ${SERVER_MAIN_PATH}

##############################################################################

# 임시 작업 디렉토리로 이동
cd ${WORK_DIR}

##############################################################################

# yum 업데이트 / 기본 패키지 설치
yum update -y && \
yum install -y \
   wget \
   bind-utils \
   zip \
   unzip \
   bzip2 \
   net-tools \
   ntp \
   gcc \
   gcc-c++ \
   make \
   expect \
   perl

##############################################################################

# EPEL 리포지터리 설치

# EPEL 리포지터리 다운로드 경로
EPEL_DOWNLOAD_URL=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

wget ${EPEL_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/epel-release.rpm && \
rpm -ivh ${WORK_DIR}/epel-release.rpm

##############################################################################

# 한국어 언어 설정
localedef -i ko_KR -f UTF-8 ko_KR.UTF-8 && \
export LC_ALL=ko_KR.UTF-8 && \
cat > /etc/locale.conf \
<<EOF
LANG=ko_KR.UTF-8
LC_ALL=ko_KR.UTF-8
EOF

##############################################################################

# 기존 시간대 설정 파일 백업 / 시간대 변경
mv /etc/localtime /etc/localtime_org && \
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

# 시간 동기화  https://www.manualfactory.net/10147
cat > /etc/ntp.conf \
<<EOF
server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
server 3.centos.pool.ntp.org iburst
EOF

firewall-cmd --add-service=ntp --permanent && \
firewall-cmd --reload && \
systemctl start ntpd && \
systemctl enable ntpd


##############################################################################

# /usr/local/lib , /usr/local/lib64 , /usr/lib64 라이브러리 경로에 추가

# http://cr3denza.blogspot.com/2015/03/ldsoconf.html
# https://www.thinkit.or.kr/linux/entry/ldconfig-%eb%8f%99%ec%a0%81-%eb%a7%81%ed%81%ac-%ec%84%a4%ec%a0%95-sbinldconfig
# https://sens.tistory.com/33

cat >> /etc/ld.so.conf \
<<EOF
/usr/local/lib
/usr/local/lib64
/usr/lib64
EOF

ldconfig

##############################################################################

# zlib 최신 버전 다운로드 / 갱신 설치

# zlib 다운로드 경로 : 1.2.11 ( 2017-01-15 )
ZLIB_DOWNLOAD_URL=http://zlib.net/zlib-1.2.11.tar.gz

wget -c ${ZLIB_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/zlib.tar.gz && \
tar -zxf ${WORK_DIR}/zlib.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep zlib-) \
   ${WORK_DIR}/zlib \
   ${WORK_DIR}/zlib-*

cd zlib

# http://www.linuxfromscratch.org/lfs/view/development/chapter06/zlib.html
# https://www.happyjung.com/lecture/788

# libz.a , libz.so 모듈 생성, prefix 는 기본값 /usr/local 과 동일하게 지정
./configure \
   --prefix=/usr/local
make
make install
make clean

# 기존 설치된 구버전 zlib rpm 제거
# 최신 버전 컴파일 설치시 기존 zlib 를 참조하므로 컴파일 설치 완료 후 구 버전을 제거해야 함
rpm -e --nodeps zlib

# 구버전 zlib 제거해도 /usr/lib64 에 기존 라이브러리 파일이 남아있음
# 신버전 cp 시 overwrite 지정해도 삭제 안되는 케이스가 있어 미리 제거
rm -rf /usr/lib64/libz.*

# /usr/local/lib 에 설치된 libz.a , libz.so 파일들을 /usr/lib64 로 복사
# 구버전 zlib 제거해도 /usr/lib64 에 기존 라이브러리 파일이 남아있음 : -f 옵션으로 overwrite
# -r 옵션 : 원본이 파일이면 그냥 복사되고 (심볼릭 링크 포함) 디렉터리라면 디렉터리 전체가 복사된다.
yes | cp -rf /usr/local/lib/libz.* /usr/lib64

# 위 명령어 실행 후 다시 yum install libz 로 구버전 설치해도 라이브러리 파일들은 최신 버전을 바라본다.

# zlib ( libz ) 라이브러리 버전 변경 확인 명령어
# ldconfig -v | grep libz

cd ..

##############################################################################

# PCRE 컴파일 버전 다운로드

# http://blog.naver.com/PostView.nhn?blogId=apocalypsekr&logNo=150156152811

# PCRE 다운로드 경로 : 8.43 ( 2019-02-23 )
PCRE_DOWNLOAD_URL=https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz

# zlib-devel : PCRE 컴파일 설치시 필요 => zlib 최신버전을 컴파일 설치했으면 불필요
# yum install -y zlib-devel

wget ${PCRE_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/pcre.tar.gz && \
tar -zxf ${WORK_DIR}/pcre.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep pcre-) \
   ${WORK_DIR}/pcre \
   ${WORK_DIR}/pcre-*

cd pcre

# prefix 는 기본값 /usr/local 과 동일하게 지정
# http://www.linuxfromscratch.org/blfs/view/cvs/general/pcre.html
./configure \
   --prefix=/usr/local \
   --enable-static \
   --enable-utf8 \
   --enable-unicode-properties \
   --enable-pcre16 \
   --enable-pcre32 \
   --enable-pcregrep-libz
make
make install
make clean

# 기존 설치된 pcre rpm 제거
# 최신 버전 컴파일 설치시 기존 pcre 를 참조하므로 컴파일 설치 완료 후 구 버전을 제거해야 함
rpm -e --nodeps pcre

# -d 옵션 : 복사할 원본이 심볼릭 링크일 때 심볼릭 자체를 복사한다. => 이건 -r 옵션으로도 적용되어 제외함
# -r 옵션 : 원본이 파일이면 그냥 복사되고 (심볼릭 링크 포함) 디렉터리라면 디렉터리 전체가 복사된다.
# -f 옵션 : 복사할 대상이 이미 있으면 강제로 지우고 복사 => 구버전 라이브러리 파일이 남아있는 경우 overwrite
yes | cp -rf /usr/local/lib/libpcre* /usr/lib64

# pcre 라이브러리 버전 변경 확인 명령어
# ldconfig -v | grep pcre

cd ..

##############################################################################

# openssl 컴파일 버전 다운로드 / 설치

# openssl 다운로드 경로 : 1.1.1c( 2019-05-28 )
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source/openssl-1.1.1c.tar.gz

# OPENSSL 컴파일 설치
# 참조 https://blanche-star.tistory.com/entry/APM-%EC%84%A4%EC%B9%98-openssl-%EC%B5%9C%EC%8B%A0%EB%B2%84%EC%A0%84%EC%84%A4%EC%B9%98%EC%86%8C%EC%8A%A4%EC%84%A4%EC%B9%98-shared%EC%84%A4%EC%B9%98
# http://blog.naver.com/PostView.nhn?blogId=hanajava&logNo=221442593046&categoryNo=29&parentCategoryNo=0&viewDate=&currentPage=1&postListTopCurrentPage=1&from=postView


wget ${OPENSSL_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/openssl.tar.gz && \
tar -zxf ${WORK_DIR}/openssl.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep openssl-) \
   ${WORK_DIR}/openssl \
   ${WORK_DIR}/openssl-*

# 기존 openssl 제거: openssl-libs 는 못 지움, 의존하는 곳이 너무 많음
rpm -e --nodeps openssl

# https://www.lesstif.com/pages/viewpage.action?pageId=6291508
# https://servern54l.tistory.com/entry/Server-OpenSSL-source-compile?category=563849

# -prefix 옵션을 주지 않으면 기본적으로 /usr/local/ 밑에 나눠서 들어간다. 
# header (.h)는 /usr/local/include/openssl, 
# openssl 실행 파일은 /usr/local/bin 에 생성됨
#   => 일반적으로 $PATH 에 기본 등록되는 경로이므로 별도 PATH 등록 불필요
# library 는 /usr/local/lib/openssl 폴더에 설치된다. (고 한다..)
#   => 근데 openssl 폴더가 없다??
#   => 아래 설정으로 설치시에는 /usr/lib64/openssl 에 설치되는 것으로 확인됨
#      ( find / | grep openssl 명령어로 확인 )

cd openssl

# Configure 의 C 가 대문자여야 실행됨
./Configure \
    linux-x86_64 \
    shared \
    zlib \
    no-idea no-md2 no-mdc2 no-rc5 no-rc4 \
    --prefix=/usr/local \
    --openssldir=/usr/local/openssl

make
make install
make clean

# 구버전 openssl 실행파일 경로에 최신 버전 openssl 심볼릭 링크 생성 
ln -s /usr/local/bin/openssl /usr/bin/openssl

cd ..

# openssl 실행 위한 lib 파일 복사
# /etc/ld.so.conf 에 /usr/lib64 라이브러리 경로 지정했으면 불필요

# http://mapoo.net/os/oslinux/openssl-source-install/
# https://sarc.io/index.php/httpd/1252-openssl

# cp /usr/local/lib64/libssl.so.1.1 \
#    /usr/lib64/libssl.so.1.1 && \
# cp /usr/local/lib64/libcrypto.so.1.1 \
#    /usr/lib64/libcrypto.so.1.1

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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/openssh.tar.gz && \
tar -zxf ${WORK_DIR}/openssh.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep openssh-) \
   ${WORK_DIR}/openssh \
   ${WORK_DIR}/openssh-*

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
cp ${WORK_DIR}/openssh/contrib/sshd.pam.generic \
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

# RDP 관련 패키지 설치 : tigervnc, xrdp, supervisor
# RDP 관련 한글 입력 패키지 설치
# RDP 관련 그룹 패키지 설치 : X Window Systemw, Xfce

RDP_PORT=3389

yum install -y \
   tigervnc-server \
   xrdp \
   supervisor 

yum install -y \
   ibus \
   ibus-hangul \
   ibus-anthy \
   im-chooser

yum groupinstall  -y \
   "X Window System" \
   "Xfce"

# 해당 사용자의 xfce4 환경 설정
cat > /home/${NEW_USER}/.Xclients \
<<EOF
startxfce4
export LANG=ko_KR.UTF-8
export LC_ALL=ko_KR.UTF-8
EOF

chmod u+x /home/${NEW_USER}/.Xclients && \
chown ${NEW_USER} /home/${NEW_USER}/.Xclients && \
chgrp ${NEW_GROUP} /home/${NEW_USER}/.Xclients

firewall-cmd --permanent --zone=public --add-port=${RDP_PORT}/tcp && \
firewall-cmd --reload

# xrdp 서비스 등록
systemctl enable xrdp.service && \
systemctl start xrdp.service

##############################################################################

# D2Coding 폰트 설치

# D2Codion 폰트 다운로드 경로
D2CODING_FONT_DOWNLOAD_URL=https://github.com/naver/d2codingfont/releases/download/VER1.3.2/D2Coding-Ver1.3.2-20180524.zip

wget ${D2CODING_FONT_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/D2Coding.zip && \
mkdir -p ${WORK_DIR}/D2Coding && \
unzip ${WORK_DIR}/D2Coding.zip \
   -d ${WORK_DIR}/D2Coding && \
mkdir -p /usr/share/fonts/D2Coding && \
cp ${WORK_DIR}/D2Coding/D2Coding/* \
   /usr/share/fonts/D2Coding/ && \
fc-cache -f -v

##############################################################################

# 구글 크롬 설치
cat > /etc/yum.repos.d/google-chrome.repo \
<<EOF
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl-ssl.google.com/linux/linux_signing_key.pub
EOF

yum install -y google-chrome-stable

##############################################################################


#!/bin/bash
#
# sudo passwd => 최초 vm 생성 후 root 계정 암호 설정
# su root => root 계정 

#################################################################
# 신규 사용자 계정 설정
#################################################################
NEW_GROUP=developer
NEW_GROUP_ID=1200
NEW_USER=dev
NEW_USER_PASSWORD=dev


######################################
# Centos 서버 설정
######################################
# 설치시 사용할 임시 작업 디렉토리 경로
TEMP_PATH=/tmp

SSH_CONNECTION_PORT=2435
DOCKER_GROUP_ID=1205


######################################
# 개발환경 디렉토리 설정 : 개발관련 tool
######################################
# 개발환경 디렉토리 경로
DEV_TOOLS_PATH=/${NEW_USER}_tools           # NEW_USER : NEW_USER_GROUO 소유

# 개발환경 디렉토리 내 개발 tool 설치 경로
GIT_MAIN_PATH=${DEV_TOOLS_PATH}/GIT
STS_WORKSPACE_PATH=${DEV_TOOLS_PATH}/WORKSPACE
BUILD_MAIN_PATH=${DEV_TOOLS_PATH}/BUILD
DEPENDENCY_MAIN_PATH=${DEV_TOOLS_PATH}/DEPENDENCY
UTILS_MAIN_PATH=${DEV_TOOLS_PATH}/UTILS

######################################
# DEPENDENCY_MAIN_PATH 내 저장소별 디렉토리 : Maven, Gradle, Npm 설치시 지정
######################################

######################################
# 라이브러리 디렉토리 설정
######################################
# Maven, Gradle, Npm 라이브러리 경로
LIBRARY_MAIN_PATH=/${NEW_USER}_lib          # NEW_USER : NEW_USER_GROUP 소유
                                            # 다른 사용자 읽기/실행 가능


######################################
# Nginx 관련 설정
######################################
NGINX_USER_GROUP=${NEW_USER}_nginx_group
NGINX_USER=${NEW_USER}_nginx

STATIC_FILE_MAIN_PATH=/${NEW_USER}_static   # NEW_USER : NGINX_USER_GROUP 소유


######################################
# 웹서버 관련 설정
######################################
SERVER_USER_GROUP=${NEW_USER}_server_group

TOMCAT_USER=${NEW_USER}_tomcat
NODEJS_USER=${NEW_USER}_nodejs
NEXUS_USER=${NEW_USER}_nexus

SERVER_MAIN_PATH=/${NEW_USER}_server      # NEW_USER : SERVER_USER_GROUP 소유
                                          # 디렉토리 내에서 서버마다 다시 소유자 달라짐


######################################
# 도메인 / 접속 포트 관련 설정
######################################
REAL_DOMAIN=jhpark.gq
REAL_SERVER_LOCAL_PORT=8080

DEV_DOMAIN_PREFIX=dev
DEV_DOMAIN=${DEV_DOMAIN_PREFIX}.${REAL_DOMAIN}
DEV_SERVER_LOCAL_PORT=8081

NEXUS_DOMAIN_PREFIX=nexus
NEXUS_DOMAIN=${NEXUS_DOMAIN_PREFIX}.${REAL_DOMAIN}
NEXUS_SERVER_LOCAL_PORT=8090

WEBDAV_DOMAIN_PREFIX=webdav
WEBDAV_DOMAIN=${WEBDAV_DOMAIN_PREFIX}.${REAL_DOMAIN}


######################################
# 데이터베이스 관련 설정
######################################
DB_USER_GROUP=${NEW_USER}_db_group

MARIADB_USER=${NEW_USER}_mysql
REDIS_USER=${NEW_USER}_redis

NEW_DB_SCHEMA_NAME=demo

DATABASE_MAIN_PATH=/${NEW_USER}_db     # NEW_USER : DB_USER_GROUP 소유
                                       # 디렉토리 내에서 DB 마다 다시 소유자 달라짐


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

# 개발환경 디렉토리 생성
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
cd ${TEMP_PATH}

# 기존 시간대 설정 파일 백업 / 시간대 변경
mv /etc/localtime /etc/localtime_org && \
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

# 언어 설정
localedef -i ko_KR -f UTF-8 ko_KR.UTF-8 && \
export LC_ALL=ko_KR.UTF-8 && \
cat > /etc/locale.conf \
<<EOF
LANG=ko_KR.UTF-8
LC_ALL=ko_KR.UTF-8
EOF

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

# EPEL 리포지터리 설치

# EPEL 리포지터리 다운로드 경로
EPEL_DOWNLOAD_URL=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

wget ${EPEL_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/epel-release.rpm && \
rpm -ivh ${TEMP_PATH}/epel-release.rpm

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
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/zlib.tar.gz && \
tar -zxf ${TEMP_PATH}/zlib.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep zlib-) \
   ${TEMP_PATH}/zlib \
   ${TEMP_PATH}/zlib-*

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
# cp 시 overwrite 가 안되는 케이스가 있어 미리 제거
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
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/pcre.tar.gz && \
tar -zxf ${TEMP_PATH}/pcre.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep pcre-) \
   ${TEMP_PATH}/pcre \
   ${TEMP_PATH}/pcre-*

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
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/openssl.tar.gz && \
tar -zxf ${TEMP_PATH}/openssl.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep openssl-) \
   ${TEMP_PATH}/openssl \
   ${TEMP_PATH}/openssl-*

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
#   => GCP centos 에 뭔가 다른 설정이 있는 듯..

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

# openssl 실행 위한 lib 파일 복사 :/etc/ld.so.conf 에 라이브러리 경로 지정했으면 불필요
# http://mapoo.net/os/oslinux/openssl-source-install/
# https://sarc.io/index.php/httpd/1252-openssl
# cp /usr/local/lib64/libssl.so.1.1 \
#    /usr/lib64/libssl.so.1.1 && \
# cp /usr/local/lib64/libcrypto.so.1.1 \
#    /usr/lib64/libcrypto.so.1.1

##############################################################################

# openSSH 최신버전 설치

# 최초 설치후 ssh -V 로 확인한 버전 : OpenSSH_7.4p1, OpenSSL 1.0.2k-fips  26 Jan 2017

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

# Docker 설치 / 서비스 등록

# container-selinux : docker 설치시 의존 패키지임, 선설치 필요

# container-selinux 다운로드 경로 : container-selinux-2.107-1 ( 2019-08-05 )
CONTAINEDR_SELINUX_DOWNLOAD_URL=http://mirror.centos.org/centos/7/extras/x86_64/Packages/container-selinux-2.107-1.el7_6.noarch.rpm

# Docker-ce 다운로드 경로 : docker-ce-18.09.7-3 ( 2019-06-27 )
DOCKER_CE_DOWNLOAD_URL=https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-18.09.7-3.el7.x86_64.rpm

# Docker-ce-cli 다운로드 경로 : docker-ce-cli-18.09.7-3 ( 2019-06-27 )
DOCKER_CE_CLI_DOWNLOAD_URL=https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-cli-18.09.7-3.el7.x86_64.rpm

# containerd.io 다운로드 경로 : containerd.io-1.2.6-3.3 ( 2019-06-27 )
CONTAINEDR_IO_DOWNLOAD_URL=https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm

# 기존 Docker 제거
yum remove -y \
   docker \
   docker-client \
   docker-client-latest \
   docker-common \
   docker-latest \
   docker-latest-logrotate \
   docker-logrotate \
   docker-selinux \
   docker-engine-selinux \
   container-selinux \
   docker-engine \
   docker-ce && \
rm -rf /var/lib/docker && \
rm -rf /etc/yum.repos.d/docker-ce.repo

wget ${CONTAINEDR_SELINUX_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/container-selinux.rpm && \
wget ${DOCKER_CE_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/docker-ce.rpm && \
wget ${DOCKER_CE_CLI_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/docker-ce-cli.rpm && \
wget ${CONTAINEDR_IO_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/containerd.io.rpm

# 도커 설치 전 의존 패키지 먼저 설치
rpm -Uvh \
   ${TEMP_PATH}/container-selinux.rpm

rpm -Uvh \
   ${TEMP_PATH}/docker-ce.rpm \
   ${TEMP_PATH}/docker-ce-cli.rpm \
   ${TEMP_PATH}/containerd.io.rpm

# docker 그룹 추가 : 보통 도커 설치시 자동으로 추가됨
# groupadd docker

# docker 그룹의 gid 를 ${DOCKER_GROUP_ID} 로 변경
groupmod -g ${DOCKER_GROUP_ID} docker

# docker 그룹에 사용자 추가
usermod -aG docker ${NEW_USER}

systemctl enable docker && \
systemctl start docker

##############################################################################

# VSFTPD 다운로드 경로 : V3.0.3 ( 2015-07 )
VSFTPD_DOWNLOAD_URL=https://security.appspot.com/downloads/vsftpd-3.0.3.tar.gz

# DB4 rpm 다운로드 경로 : 4.8.30-13
DB4_DOWNLOAD_URL=http://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/l/libdb4-4.8.30-13.el7.x86_64.rpm

# DB4-UTILS rpm 다운로드 경로 : 4.8.30-13
DB4_UTILS_DOWNLOAD_URL=http://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/l/libdb4-utils-4.8.30-13.el7.x86_64.rpm

# VSFTPD 다운로드 / 압축 해제
wget ${VSFTPD_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/vsftpd.tar.gz && \
tar -zxf ${TEMP_PATH}/vsftpd.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep vsftpd-) \
   ${TEMP_PATH}/vsftpd \
   ${TEMP_PATH}/vsftpd-*

# DB4, DB4-UTILS 다운로드 / 설치
wget ${DB4_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/db4.rpm && \
wget ${DB4_UTILS_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/db4-utils.rpm

rpm -Uvh \
   ${TEMP_PATH}/db4.rpm \
   ${TEMP_PATH}/db4-utils.rpm

##############################################################################

# 사용자 전용 GIT 설치

# Git 다운로드 경로 : git-2.22.0 ( 2019-06-07 )
GIT_DOWNLOAD_URL=https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.22.0.tar.gz

# GIT_MAIN_PATH 내 git 설치 디렉토리
GIT_INSTALL_DIRECTORY_NAME=git

# yum 으로 설치된 기존 git 삭제
yum remove -y \
   git

# GIT 의존 패키지 설치
# 설치 참조 : https://git-scm.com/book/ko/v1/%EC%8B%9C%EC%9E%91%ED%95%98%EA%B8%B0-Git-%EC%84%A4%EC%B9%98
yum install -y \
   curl-devel \
   expat-devel \
   gettext-devel \
   openssl-devel \
   zlib-devel

wget ${GIT_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/git.tar.gz && \
tar -zxf ${TEMP_PATH}/git.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep git-) \
   ${TEMP_PATH}/git \
   ${TEMP_PATH}/git-*

cd git

make \
   prefix=${GIT_MAIN_PATH}/${GIT_INSTALL_DIRECTORY_NAME} \
   all

make \
   prefix=${GIT_MAIN_PATH}/${GIT_INSTALL_DIRECTORY_NAME} \
   install

cd ..

# GIT 심볼릭 링크를 사용자 bin 디렉토리에 추가
ln -sf ${GIT_MAIN_PATH}/${GIT_INSTALL_DIRECTORY_NAME}/bin/git \
   /home/${NEW_USER}/bin/git

##############################################################################

# Redis 설치

# Redis Binary 다운로드 경로 : Redis 5.0.5 ( 2019-05-15 )
REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-5.0.5.tar.gz

# REDIS_USER 생성
useradd ${REDIS_USER} \
   --shell /sbin/nologin \
   --no-create-home

# DB_USER_GROUP 에 REDIS_USER 추가
usermod -aG ${DB_USER_GROUP} ${REDIS_USER}

# Redis 설치 / 디렉토리 / 포트
REDIS_INSTALL_DIRECTORY_NAME=redis-MASTER
REDIS_DATA_DIRECTORY_NAME=redis-MASTER-data
REDIS_LOG_DIRECTORY_NAME=redis-MASTER-log
REDIS_PORT=6379

REDIS_INSTALL_PATH=${DATABASE_MAIN_PATH}/${REDIS_INSTALL_DIRECTORY_NAME}
REDIS_DATA_PATH=${DATABASE_MAIN_PATH}/${REDIS_DATA_DIRECTORY_NAME}
REDIS_LOG_PATH=${REDIS_INSTALL_PATH}/${REDIS_LOG_DIRECTORY_NAME}
REDIS_BIN_PATH=${REDIS_INSTALL_PATH}/bin
REDIS_PID_PATH=${REDIS_INSTALL_PATH}/pid

mkdir -p ${REDIS_INSTALL_PATH}
mkdir -p ${REDIS_DATA_PATH}
mkdir -p ${REDIS_LOG_PATH}
mkdir -p ${REDIS_BIN_PATH}
mkdir -p ${REDIS_PID_PATH}

REDIS_CONFIG_FILE_PATH=${REDIS_INSTALL_PATH}/redis.conf
REDIS_LOG_FILE_PATH=${REDIS_LOG_PATH}/redis.log
REDIS_EXEC_FILE_PATH=${REDIS_BIN_PATH}/redis-server
REDIS_CLI_EXEC_FILE_PATH=${REDIS_BIN_PATH}/redis-cli
REDIS_PID_FILE_PATH=${REDIS_PID_PATH}/redis.pid

wget ${REDIS_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/redis.tar.gz && \
tar -zxf ${TEMP_PATH}/redis.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep redis-) \
   ${TEMP_PATH}/redis \
   ${TEMP_PATH}/redis-*

cd redis

make

make PREFIX=${REDIS_INSTALL_PATH} install

cd ..

cp -r /tmp/redis/* \
    ${REDIS_INSTALL_PATH}

echo -e \ "${REDIS_PORT}\n\
    ${REDIS_CONFIG_FILE_PATH}\n\
    ${REDIS_LOG_FILE_PATH}\n\
    ${REDIS_DATA_PATH}\n\
    ${REDIS_EXEC_FILE_PATH}\n
    ${REDIS_CLI_EXEC_FILE_PATH}\n" | \
    ${REDIS_INSTALL_PATH}/utils/install_server.sh

cat > ${REDIS_CONFIG_FILE_PATH} \
<<EOF
# default : localhost(127.0.0.1)에서만 접근
# bind 0.0.0.0 라고 설정하거나 bind 부분을 주석처리(#) : 모든 ip에서 접근 가능
bind 127.0.0.1   

protected-mode yes

port 6379

tcp-backlog 511

# 연결된 클라이언트의 idle 대기 시간 설정을 초 단위로 한다. 
# 해당 시간동안 송 수신이 발생하지 않으면 클라이언트의 연결을 끊는다. 
# 0으로 설정하면 사용하지 않음.
timeout 0  

tcp-keepalive 300

# By default Redis does not run as a daemon. Use 'yes' if you need it.
# Note that Redis will write a pid file in /var/run/redis.pid when daemonized.

daemonize yes

#   supervised no      - no supervision interaction
#   supervised upstart - signal upstart by putting Redis into SIGSTOP mode
#   supervised systemd - signal systemd by writing READY=1 to $NOTIFY_SOCKET
#   supervised auto    - detect upstart or systemd method based on
#                        UPSTART_JOB or NOTIFY_SOCKET environment variables

supervised systemd

pidfile ${REDIS_PID_FILE_PATH}

# 인스턴스 동작 중에 출력하는 로그의 레벨을 지정 함. 
# debug/verbose,notice,warning 중에 선택 할 수 있음)
loglevel notice

# 로그가 저장되는 경로와 파일명을 지정함
logfile ${REDIS_LOG_FILE_PATH}
databases 16
always-show-logo yes

save 900 1
save 300 10
save 60 10000

stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir ${REDIS_DATA_PATH}

replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
replica-priority 100

lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no

appendonly no

# The name of the append only file (default: "appendonly.aof")
appendfilename "appendonly.aof"

# appendfsync always
appendfsync everysec
# appendfsync no

no-appendfsync-on-rewrite no

auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

aof-load-truncated yes

aof-use-rdb-preamble yes

lua-time-limit 5000

slowlog-log-slower-than 10000

slowlog-max-len 128

latency-monitor-threshold 0

notify-keyspace-events ""

hash-max-ziplist-entries 512
hash-max-ziplist-value 64

list-max-ziplist-size -2

list-compress-depth 0

set-max-intset-entries 512

zset-max-ziplist-entries 128
zset-max-ziplist-value 64

hll-sparse-max-bytes 3000

stream-node-max-bytes 4096
stream-node-max-entries 100

activerehashing yes

client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60

hz 10

dynamic-hz yes
aof-rewrite-incremental-fsync yes

rdb-save-incremental-fsync yes

EOF

cat > /usr/lib/systemd/system/${NEW_USER}_${REDIS_INSTALL_DIRECTORY_NAME}.service \
<<EOF
[Unit]
Description=${NEW_USER}_${REDIS_INSTALL_DIRECTORY_NAME}
After=syslog.target network.target

[Service]
Type=notify 
User=${REDIS_USER}
Group=${DB_USER_GROUP}
# PIDFile=${REDIS_PID_FILE_PATH}
TimeoutStartSec=0
TimeoutStopSec=0
PermissionsStartOnly=true
ExecStart=${REDIS_EXEC_FILE_PATH} ${REDIS_CONFIG_FILE_PATH} --supervised systemd
ExecStop=${REDIS_CLI_EXEC_FILE_PATH} shutdown
ExecStopPost=/bin/rm -f ${REDIS_PID_FILE_PATH}

[Install]
WantedBy=multi-user.target graphical.target
EOF

systemctl daemon-reload
systemctl enable ${NEW_USER}_${REDIS_INSTALL_DIRECTORY_NAME}

chown -R ${REDIS_USER}:${DB_USER_GROUP} \
   ${REDIS_INSTALL_PATH}

chown -R ${REDIS_USER}:${DB_USER_GROUP} \
   ${REDIS_DATA_PATH}

##############################################################################

# Redis Desktop Manager 설치

# Redis Desktop Manager 다운로드 경로 : 2019.2 ( 2019-07-17 )
REDIS_DESKTOP_MANAGER_DOWNLOAD_URL=https://github.com/uglide/RedisDesktopManager/archive/2019.2.tar.gz

wget ${REDIS_DESKTOP_MANAGER_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/RedisDesktopManager.tar.gz && \
tar -zxf ${TEMP_PATH}/RedisDesktopManager.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep RedisDesktopManager-) \
   ${TEMP_PATH}/redisDesktopManager \
   ${TEMP_PATH}/RedisDesktopManager-*

# cd redisDesktopManager/src
# ./configure
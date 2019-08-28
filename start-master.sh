#!/bin/bash
#
# sudo passwd => 최초 vm 생성 후 root 계정 암호 설정
# su root => root 계정 접속
# vi ./start.sh => i 클릭 후 전체 내용 복붙, esc 클릭, : 클릭, wq 클릭
# chmod o+x ./start.sh  => 실행 권한 부여
# ./start.sh developer 1200 dev dev  => 다음으로 실행

NEW_GROUP=developer
NEW_GROUP_ID=1200
NEW_USER=dev
NEW_USER_PASSWORD=dev

MARIADB_USER=${NEW_USER}_mysql
REDIS_USER=${NEW_USER}_redis
NGINX_USER=${NEW_USER}_nginx
TOMCAT_USER=${NEW_USER}_tomcat
NEXUS_USER=${NEW_USER}_nexus
NODEJS_USER=${NEW_USER}_nodejs

DB_USER_GROUP=${NEW_USER}_db_group
NGINX_USER_GROUP=${NEW_USER}_nginx_group
SERVER_USER_GROUP=${NEW_USER}_server_group

NEW_DB_SCHEMA_NAME=demo

REAL_DOMAIN=jhpark.gq

NEXUS_DOMAIN_PREFIX=nexus
NEXUS_DOMAIN=${NEXUS_DOMAIN_PREFIX}.${REAL_DOMAIN}

DEV_DOMAIN_PREFIX=dev
DEV_DOMAIN=${DEV_DOMAIN_PREFIX}.${REAL_DOMAIN}

WEBDAV_DOMAIN_PREFIX=webdav
WEBDAV_DOMAIN=${WEBDAV_DOMAIN_PREFIX}.${REAL_DOMAIN}

REAL_SERVER_LOCAL_PORT=8080
DEV_SERVER_LOCAL_PORT=8081
NEXUS_SERVER_LOCAL_PORT=8090

DOCKER_GROUP_ID=1205

# 설치시 사용할 임시 작업 디렉토리 경로
TEMP_PATH=/tmp

##############################################################################

# 사용자 그룹 / 유저 생성 / 유저 패스워드 변경
groupadd -g ${NEW_GROUP_ID} ${NEW_GROUP} && \
useradd -g ${NEW_GROUP} ${NEW_USER} && \
echo ${NEW_USER_PASSWORD} | passwd ${NEW_USER} --stdin

# 사용자 전용 bin 디렉토리 생성
mkdir -p /home/${NEW_USER}/bin

# DB_USER_GROUP, NGINX_USER_GROUP, SERVER_USER_GROUP 생성
groupadd ${DB_USER_GROUP} && \
groupadd ${NGINX_USER_GROUP} && \
groupadd ${SERVER_USER_GROUP}

# NEW_USER 를 각 그룹에 추가
usermod -aG ${DB_USER_GROUP} ${NEW_USER} && \
usermod -aG ${NGINX_USER_GROUP} ${NEW_USER} && \
usermod -aG ${SERVER_USER_GROUP} ${NEW_USER}

##############################################################################

# 개발환경 디렉토리 경로
DEV_TOOLS_PATH=/dev_tools           # NEW_USER : NEW_USER_GROUO 소유

DATABASE_MAIN_PATH=/dev_db          # NEW_USER : DB_USER_GROUP 소유
                                    # 디렉토리 내에서 다시 소유자 달라짐

LIBRARY_MAIN_PATH=/dev_lib          # NEW_USER : NEW_USER_GROUO 소유
                                    # 다른 사용자 읽기/실행 가능

SERVER_MAIN_PATH=/dev_server        # NEW_USER : SERVER_USER_GROUP 소유
                                    # 디렉토리 내에서 다시 소유자 달라짐

STATIC_FILE_MAIN_PATH=/dev_static   # NEW_USER : NGINX_USER_GROUP 소유

mkdir -p ${DEV_TOOLS_PATH}
mkdir -p ${DATABASE_MAIN_PATH}
mkdir -p ${LIBRARY_MAIN_PATH}
mkdir -p ${SERVER_MAIN_PATH}
mkdir -p ${STATIC_FILE_MAIN_PATH}

##############################################################################

# DEV_TOOLS_PATH 내 설치 경로
GIT_MAIN_PATH=${DEV_TOOLS_PATH}/GIT
STS_WORKSPACE_PATH=${DEV_TOOLS_PATH}/WORKSPACE
BUILD_MAIN_PATH=${DEV_TOOLS_PATH}/BUILD
DEPENDENCY_MAIN_PATH=${DEV_TOOLS_PATH}/DEPENDENCY
UTILS_MAIN_PATH=${DEV_TOOLS_PATH}/UTILS

mkdir -p ${GIT_MAIN_PATH}
mkdir -p ${STS_WORKSPACE_PATH}
mkdir -p ${BUILD_MAIN_PATH}
mkdir -p ${DEPENDENCY_MAIN_PATH}
mkdir -p ${UTILS_MAIN_PATH}

##############################################################################

chown -R ${NEW_USER}:${NEW_GROUP} ${DEV_TOOLS_PATH}
chown -R ${NEW_USER}:${DB_USER_GROUP} ${DATABASE_MAIN_PATH}
chown -R ${NEW_USER}:${NEW_GROUP} ${LIBRARY_MAIN_PATH}
chown -R ${NEW_USER}:${SERVER_USER_GROUP} ${SERVER_MAIN_PATH}
chown -R ${NEW_USER}:${NGINX_USER_GROUP} ${STATIC_FILE_MAIN_PATH}

# LIBRARY_MAIN_PATH 는 모든 사용자가 읽기/실행 가능, 단 쓰기는 소유자만 가능
chmod 755 ${LIBRARY_MAIN_PATH}

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
   perl \
   gcc \
   gcc++ \
   gcc-c++ \
   make \
   vim \
   gedit \
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
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/D2Coding.zip && \
mkdir -p ${TEMP_PATH}/D2Coding && \
unzip ${TEMP_PATH}/D2Coding.zip \
   -d ${TEMP_PATH}/D2Coding && \
mkdir -p /usr/share/fonts/D2Coding && \
cp ${TEMP_PATH}/D2Coding/D2Coding/* \
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

# 파이어폭스 설치
# 설치 참조 : https://libre-software.net/how-to-install-firefox-on-ubuntu-linux-mint/
# https://www.itzgeek.com/how-tos/linux/centos-how-tos/install-latest-firefox-32-on-centos-7-rhel-7.html

# 파이어폭스 다운로드 경로 : Version 67.0.3 ( 2019-06-18 )
FIREFOX_DOWNLOAD_URL=http://ftp.mozilla.org/pub/firefox/releases/67.0.3/linux-x86_64/ko/firefox-67.0.3.tar.bz2

# UTILS_MAIN_PATH 내 파이어폭스 설치 디렉토리
FIREFOX_INSTALL_DIRECTORY_NAME=firefox
FIREFOX_INSTALL_PATH=${UTILS_MAIN_PATH}/${FIREFOX_INSTALL_DIRECTORY_NAME}

mkdir -p ${FIREFOX_INSTALL_PATH}

wget ${FIREFOX_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/firefox.tar.bz2 && \
tar -jxf ${TEMP_PATH}/firefox.tar.bz2 \
   -C ${FIREFOX_INSTALL_PATH} \
   --strip-components 1

# 숨김파일도 이동 처리되도록 설정
shopt -s dotglob

# 기존 firefox 실행파일 제거
rm -rf /usr/bin/firefox

# 파이어폭스 심볼릭 링크를 사용자 bin 디렉토리에 추가
ln -s ${FIREFOX_INSTALL_PATH}/firefox \
   /home/${NEW_USER}/bin/firefox

##############################################################################

# rclone 설치

# rclone 다운로드 경로 : v1.48.0 ( 2019-06-16)
RCLONE_DOWNLOAD_URL=https://downloads.rclone.org/v1.48.0/rclone-v1.48.0-linux-amd64.zip

RCLONE_INSTALL_DIRECTORY_NAME=rclone
RCLONE_INSTALL_PATH=${UTILS_MAIN_PATH}/${RCLONE_INSTALL_DIRECTORY_NAME}

mkdir -p ${RCLONE_INSTALL_PATH}

wget ${RCLONE_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/rclone.zip && \
unzip ${TEMP_PATH}/rclone.zip && \
mv ${TEMP_PATH}/$( ls ${TEMP_PATH} | grep rclone- )/* \
   ${RCLONE_INSTALL_PATH}

# rclone 심볼릭 링크를 사용자 bin 디렉토리에 추가
ln -s ${RCLONE_INSTALL_PATH}/rclone \
   /home/${NEW_USER}/bin/rclone

##############################################################################

# postman 설치

# postman 다운로드 경로 : 7.5.0 ( 2019-08-12 )
POSTMAN_DOWNLOAD_URL=https://dl.pstmn.io/download/version/7.5.0/linux64

POSTMAN_INSTALL_DIRECTORY_NAME=postman
POSTMAN_INSTALL_PATH=${UTILS_MAIN_PATH}/${POSTMAN_INSTALL_DIRECTORY_NAME}

mkdir -p ${POSTMAN_INSTALL_PATH}

# postman 다운로드 / POSTMAN_INSTALL_PATH 에 설치
wget ${POSTMAN_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/postman.tar.gz && \
tar -zxf ${TEMP_PATH}/postman.tar.gz \
   -C ${POSTMAN_INSTALL_PATH} \
   --strip-components 1

# Postman 심볼릭 링크를 사용자 bin 디렉토리에 추가
ln -s ${POSTMAN_INSTALL_PATH}/Postman \
   /home/${NEW_USER}/bin/Postman

##############################################################################

# https://gnupg.org/download/ 
# https://gist.github.com/simbo1905/ba3e8af9a45435db6093aea35c6150e8


# GnuPG 의존 라이브러리 설치

# Libgpg-error : 1.36 ( 2019-03-19 )
Libgpg-error_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.36.tar.bz2

# Libgcrypt    : 1.8.4 ( 2018-10-26 )
Libgcrypt_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.8.4.tar.bz2

# Libksba      : 1.3.5	( 2016-08-22 )
Libksba_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/libksba/libksba-1.3.5.tar.bz2

# Libassuan    : 2.5.3 ( 2019-02-11 )
Libassuan_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/libassuan/libassuan-2.5.3.tar.bz2

# ntbTLS       : 0.1.2 ( 2017-09-19 )
ntbTLS_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/ntbtls/ntbtls-0.1.2.tar.bz2

# nPth         : 1.6 ( 2018-07-16 ) 
nPth_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/npth/npth-1.6.tar.bz2

# Pinentry     : 1.1.0 ( 2017-12-03 )
#     a collection of passphrase entry dialogs which is required for almost all usages of GnuPG
Pinentry_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/pinentry/pinentry-1.1.0.tar.bz2

# GPGME        : 1.13.1 ( 2019-06-13 )
#     the standard library to access GnuPG functions from programming languages
GPGME_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/gpgme/gpgme-1.13.1.tar.bz2

# GPA          : 0.10.0 ( 2018-10-16 )
#     a graphical frontend to GnuPG
GPA_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/gpa/gpa-0.10.0.tar.bz2

GNU_PG_TEMP_DOWNLOAD_PATH=${TEMP_PATH}/gnupg-temp

mkdir -p ${GNU_PG_TEMP_DOWNLOAD_PATH}

cd ${GNU_PG_TEMP_DOWNLOAD_PATH}

wget -c ${Libgpg-error_DOWNLOAD_URL} \
   -O ./Libgpg-error.tar.bz2 && \
wget -c ${Libgcrypt_DOWNLOAD_URL} \
   -O ./Libgcrypt.tar.bz2 && \
wget -c ${Libksba_DOWNLOAD_URL} \
   -O ./Libksba.tar.bz2 && \
wget -c ${Libassuan_DOWNLOAD_URL} \
   -O ./Libassuan.tar.bz2 && \
wget -c ${ntbTLS_DOWNLOAD_URL} \
   -O ./ntbTLS.tar.bz2 && \
wget -c ${nPth_DOWNLOAD_URL} \
   -O ./nPth.tar.bz2 && \
wget -c ${Pinentry_DOWNLOAD_URL} \
   -O ./Pinentry.tar.bz2 && \
wget -c ${GPGME_DOWNLOAD_URL} \
   -O ./GPGME.tar.bz2 && \
wget -c ${GPA_DOWNLOAD_URL} \
   -O ./GPA.tar.bz2

tar -xzf Libgpg-error.tar.bz2 && \
tar -xzf Libgcrypt.tar.bz2 && \
tar -xjf Libksba.tar.bz2 && \
tar -xjf Libassuan.tar.bz2 && \
tar -xjf ntbTLS.tar.bz2 && \
tar -xjf nPth.tar.bz2 && \
tar -xjf Pinentry.tar.bz2 && \
tar -xjf GPGME.tar.bz2 && \
tar -xjf GPA.tar.bz2


##############################################################################


# GnuPG 다운로드 경로 : 2.2.17 ( 2019-07-09 )
GNU_PG_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.2.17.tar.bz2

# UTILS_MAIN_PATH 내 GnuPG 설치 디렉토리
GNU_PG_INSTALL_DIRECTORY_NAME=gnupg
GNU_PG_INSTALL_PATH=${UTILS_MAIN_PATH}/${GNU_PG_INSTALL_DIRECTORY_NAME}

mkdir -p ${GNU_PG_INSTALL_PATH}

wget ${GNU_PG_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/gnupg.tar.bz2 && \
tar -jxf ${TEMP_PATH}/gnupg.tar.bz2 \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep gnupg-) \
   ${TEMP_PATH}/gnupg \
   ${TEMP_PATH}/gnupg-*

cd gnupg

# ./configure --sysconfdir=/etc --localstatedir=/var

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

# 전역으로 git 설치 방법 : wandisco 리포지터리 이용
# yum remove -y \
#     git && \
# wget http://opensource.wandisco.com/centos/7/git/x86_64/wandisco-git-release-7-2.noarch.rpm \
#     -P "${TEMP_PATH}" \
#     -O "${TEMP_PATH}/git-release.rpm" && \
# rpm -ivh \
#     ${TEMP_PATH}/git-release.rpm && \
# yum install -y \
#     git

##############################################################################

# Docker 설치 / 서비스 등록

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

wget ${DOCKER_CE_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/docker-ce.rpm && \
wget ${DOCKER_CE_CLI_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/docker-ce-cli.rpm && \
wget ${CONTAINEDR_IO_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/containerd.io.rpm

yum localinstall -y \
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

# LIBRARY_MAIN_PATH 내 OPENJDK 설치

# OPENJDK 다운로드 : 1.8, 1.11, 1.12 LTS 버전

# OPENJDK 1.8 다운로드 경로 : OpenJDK8U-jdk_x64_linux_hotspot_8u222b10 ( 2019-07-18 )
OPENJDK_8_DOWNLOAD_URL=https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u222-b10/OpenJDK8U-jdk_x64_linux_hotspot_8u222b10.tar.gz

# OPENJDK 1.11 다운로드 경로 : OpenJDK11U-jdk_x64_linux_hotspot_11.0.4_11 ( 2019-07-18 )
OPENJDK_11_DOWNLOAD_URL=https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.4%2B11/OpenJDK11U-jdk_x64_linux_hotspot_11.0.4_11.tar.gz

# OPENJDK 1.12 다운로드 경로 : OpenJDK12U-jdk_x64_linux_hotspot_12.0.2_10 ( 2019-07-19 )
OPENJDK_12_DOWNLOAD_URL=https://github.com/AdoptOpenJDK/openjdk12-binaries/releases/download/jdk-12.0.2%2B10/OpenJDK12U-jdk_x64_linux_hotspot_12.0.2_10.tar.gz

# OPENJDK 1.8 설치 디렉토리
OPENJDK_8_INSTALL_DIRECTORY_NAME=java_1.8
OPENJDK_8_JAVA_HOME_PATH=${LIBRARY_MAIN_PATH}/${OPENJDK_8_INSTALL_DIRECTORY_NAME}

# OPENJDK 1.11 설치 디렉토리
OPENJDK_11_INSTALL_DIRECTORY_NAME=java_1.11
OPENJDK_11_JAVA_HOME_PATH=${LIBRARY_MAIN_PATH}/${OPENJDK_11_INSTALL_DIRECTORY_NAME}

# OPENJDK 1.12 설치 디렉토리
OPENJDK_12_INSTALL_DIRECTORY_NAME=java_1.12
OPENJDK_12_JAVA_HOME_PATH=${LIBRARY_MAIN_PATH}/${OPENJDK_12_INSTALL_DIRECTORY_NAME}

# OPENJDK 심볼릭 링크 폴더 : JDK 설치 후 심볼릭 링크 생성
OPENJDK_LINK_DIRECTORY_NAME=openjdk
OPENJDK_LINK_PATH=${LIBRARY_MAIN_PATH}/${OPENJDK_LINK_DIRECTORY_NAME}

mkdir -p ${OPENJDK_8_JAVA_HOME_PATH}
mkdir -p ${OPENJDK_11_JAVA_HOME_PATH}
mkdir -p ${OPENJDK_12_JAVA_HOME_PATH}


# OPENJDK 1.8 다운로드 / OPENJDK_8_JAVA_HOME_PATH 에 설치
wget ${OPENJDK_8_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/jdk1_8.tar.gz && \
tar -zxf ${TEMP_PATH}/jdk1_8.tar.gz \
   -C ${OPENJDK_8_JAVA_HOME_PATH} \
   --strip-components 1

# OPENJDK 1.11 다운로드 / OPENJDK_11_JAVA_HOME_PATH 에 설치
wget ${OPENJDK_11_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/jdk1_11.tar.gz && \
tar -zxf ${TEMP_PATH}/jdk1_11.tar.gz \
   -C ${OPENJDK_11_JAVA_HOME_PATH} \
   --strip-components 1

# OPENJDK 1.12 다운로드 / OPENJDK_12_JAVA_HOME_PATH 에 설치
wget ${OPENJDK_12_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/jdk1_12.tar.gz && \
tar -zxf ${TEMP_PATH}/jdk1_12.tar.gz \
   -C ${OPENJDK_12_JAVA_HOME_PATH} \
   --strip-components 1

# JDK 1.8 버전 => OPENJDK_LINK_PATH 로 심볼릭 링크 생성
ln -sf ${OPENJDK_8_JAVA_HOME_PATH} \
   ${OPENJDK_LINK_PATH}

# java 심볼릭 링크를 사용자 bin 디렉토리에 추가
ln -sf ${OPENJDK_LINK_PATH}/bin/java \
   /home/${NEW_USER}/bin/java

# javac 심볼릭 링크를 사용자 bin 디렉토리에 추가
ln -sf ${OPENJDK_LINK_PATH}/bin/javac \
   /home/${NEW_USER}/bin/javac

chown -R ${NEW_USER}:${NEW_GROUP} ${LIBRARY_MAIN_PATH}

##############################################################################

# STS 설치

# STS 다운로드 경로 : Spring Tools 4.2.2 ( 2019-05-24 )
STS_DOWNLOAD_URL=https://download.springsource.com/release/STS4/4.2.2.RELEASE/dist/e4.11/spring-tool-suite-4-4.2.2.RELEASE-e4.11.0-linux.gtk.x86_64.tar.gz

# STS 설치 디렉토리명 / 경로
STS_INSTALL_DIRECTORY_NAME=STS
STS_INSTALL_PATH=${DEV_TOOLS_PATH}/${STS_INSTALL_DIRECTORY_NAME}

mkdir -p ${STS_INSTALL_PATH}

wget ${STS_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/sts.tar.gz && \
tar -zxf ${TEMP_PATH}/sts.tar.gz \
   -C ${STS_INSTALL_PATH} \
   --strip-components 1

# STS SpringToolSuite4.ini 파일에 추가
cat > ${STS_INSTALL_PATH}/SpringToolSuite4.ini \
<<EOF
#-Xverify:none
-XX:+AggressiveOpts
-XX:-UseConcMarkSweepGC
-Dosgi.module.lock.timeout=10
-XX:PermSize=256M
-XX:MaxPermSize=256M
-XX:MaxNewSize=256M
-XX:NewSize=256M
-Dfile.encoding=UTF-8
EOF

# STS 워크스페이스 지정
mkdir -p ${STS_INSTALL_PATH}/configuration/.settings && \
cat > ${STS_INSTALL_PATH}/configuration/.settings/org.eclipse.ui.ide.prefs \
<<EOF
MAX_RECENT_WORKSPACES=3
RECENT_WORKSPACES=${STS_WORKSPACE_PATH}
RECENT_WORKSPACES_PROTOCOL=3
SHOW_RECENT_WORKSPACES=false
SHOW_WORKSPACE_SELECTION_DIALOG=false
eclipse.preferences.version=1
EOF

##############################################################################

# lombok 설치

# lombok vs STS 
# cli 로 install 시 STS4 버전은 v1.18.0 ( 2018-06-05 ) 부터 가능

# https://snworks.tistory.com/263

# lombok 다운로드 경로 : v1.18.0 ( 2018-06-05 )
LOMBOK_DOWNLOAD_URL=https://projectlombok.org/downloads/lombok-1.18.0.jar

wget ${LOMBOK_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/lombok.jar && \

${OPENJDK_LINK_PATH}/bin/java -jar \
   ${TEMP_PATH}/lombok.jar install \
   ${STS_INSTALL_PATH}/SpringToolSuite4.ini

##############################################################################

# Visual Studio Code 설치

# Visual Studio Code 다운로드 경로 : 2019-05 (version 1.35.1)
VSCODE_DOWNLOAD_URL=https://update.code.visualstudio.com/1.35.1/linux-x64/stable

wget ${VSCODE_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/vscode.tar.gz && \
mkdir -p ${DEV_TOOLS_PATH}/VSCODE && \
tar -zxf ${TEMP_PATH}/vscode.tar.gz \
   -C ${DEV_TOOLS_PATH}/VSCODE \
   --strip-components 1

mkdir -p ${DEV_TOOLS_PATH}/VSCODE/data
mkdir -p ${DEV_TOOLS_PATH}/VSCODE/data/extensions
mkdir -p ${DEV_TOOLS_PATH}/VSCODE/data/tmp
mkdir -p ${DEV_TOOLS_PATH}/VSCODE/data/user-data

##############################################################################

# IntelliJ 설치

# IntelliJ 커뮤니티 버전 다운로드 경로 : 2019.1 ( 2019-03-27 )
INTELLIJ_DOWNLOAD_URL=https://download.jetbrains.com/idea/ideaIC-2019.1.3-no-jbr.tar.gz

wget ${INTELLIJ_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/intellij.tar.gz && \
mkdir -p ${DEV_TOOLS_PATH}/INTELLI_J && \
tar -zxf ${TEMP_PATH}/intellij.tar.gz \
   -C ${DEV_TOOLS_PATH}/INTELLI_J \
   --strip-components 1

##############################################################################

# DBeaver 커뮤니티 버전 설치

# DBeaver 커뮤니티 버전 다운로드 경로 : dbeaver-ce-6.1.0 ( 2019-06-10 )
DBEAVER_DOWNLOAD_URL=https://github.com/dbeaver/dbeaver/releases/download/6.1.0/dbeaver-ce-6.1.0-linux.gtk.x86_64.tar.gz

wget ${DBEAVER_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/dbeaver.tar.gz && \
mkdir -p ${DEV_TOOLS_PATH}/DBEAVER-ce && \
tar -zxf ${TEMP_PATH}/dbeaver.tar.gz \
   -C ${DEV_TOOLS_PATH}/DBEAVER-ce \
   --strip-components 1

##############################################################################

# Maven 설치

# Maven 다운로드 경로 : 3.6.1 ( 2019-04-05 )
MAVEN_DOWNLOAD_URL=http://apache.mirror.cdnetworks.com/maven/maven-3/3.6.1/binaries/apache-maven-3.6.1-bin.tar.gz

# BUILD_MAIN_PATH 내 maven 설치 디렉토리
MAVEN_INSTALL_DIRECTORY_NAME=maven-3.6.1
MAVEN_INSTALL_PATH=${BUILD_MAIN_PATH}/${MAVEN_INSTALL_DIRECTORY_NAME}

# DEPENDENCY_MAIN_PATH 내 maven 저장소 디렉토리
MAVEN_REPOSITORY_DIRECTORY_NAME=.m2
MAVEN_REPOSITORY_PATH=${DEPENDENCY_MAIN_PATH}/${MAVEN_REPOSITORY_DIRECTORY_NAME}

mkdir -p ${MAVEN_INSTALL_PATH}
mkdir -p ${MAVEN_REPOSITORY_PATH}

wget ${MAVEN_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/maven.tar.gz && \
tar -zxf ${TEMP_PATH}/maven.tar.gz \
   -C ${MAVEN_INSTALL_PATH} \
   --strip-components 1

##############################################################################

# Gradle 설치 

# Gradle 다운로드 경로 : 5.4.1 ( 2019-04-26 )
GRADLE_DOWNLOAD_URL=https://services.gradle.org/distributions/gradle-5.4.1-bin.zip

# BUILD_MAIN_PATH 내 gradle 설치 디렉토리
GRADLE_INSTALL_DIRECTORY_NAME=gradle-5.4.1
GRADLE_INSTALL_PATH=${BUILD_MAIN_PATH}/${GRADLE_INSTALL_DIRECTORY_NAME}

# DEPENDENCY_MAIN_PATH 내 gradle 저장소 디렉토리
GRADLE_REPOSITORY_DIRECTORY_NAME=.gradle
GRADLE_REPOSITORY_PATH=${DEPENDENCY_MAIN_PATH}/${GRADLE_REPOSITORY_DIRECTORY_NAME}

mkdir -p ${GRADLE_INSTALL_PATH}
mkdir -p ${GRADLE_REPOSITORY_PATH}

# 숨김파일도 이동 처리되도록 설정
shopt -s dotglob

wget ${GRADLE_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/gradle.zip && \
unzip ${TEMP_PATH}/gradle.zip && \
mv ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep gradle-)/* \
   ${GRADLE_INSTALL_PATH}

##############################################################################

# 마리아 DB 설치

# 참조 URL 
# https://xinet.kr/?p=1279
# http://coolx.net/m/cboard/read.jsp?db=develop&mode=read&num=798&_currPage=1&listCnt=20&category=-1&fval=
# https://xinet.kr/?p=307
# https://algo79.tistory.com/entry/MySQL-%EC%97%90%EB%9F%AC
# https://gist.github.com/Mins/4602864

# MaraiDB Binary 다운로드 경로 : 10.3.16 ( 2019-06-17 )
MARIA_DB_DOWNLOAD_URL=https://downloads.mariadb.com/MariaDB/mariadb-10.3.16/bintar-linux-x86_64/mariadb-10.3.16-linux-x86_64.tar.gz

# MARIADB_USER 생성
useradd ${MARIADB_USER} \
   --shell /sbin/nologin \
   --no-create-home

# DB_USER_GROUP 에 MARIADB_USER 추가
usermod -aG ${DB_USER_GROUP} ${MARIADB_USER}

# 마리아DB 데이터베이스 관리자 계정 정보
NEW_DB_ADMIN_USER=dev
NEW_DB_ADMIN_USER_PASSWORD=dev

# 마리아DB 데이터베이스 root 계정 암호
ROOT_USER_PASSWORD=dev

# 마리아DB 설치 / 디렉토리 이름
MARIA_DB_INSTALL_DIRECTORY_NAME=mariaDB-MASTER
MARIA_DB_DATA_DIRECTORY_NAME=mariaDB-MASTER-data
MARIA_DB_LOG_DIRECTORY_NAME=mariaDB-MASTER-log
MARIA_DB_TEMP_DIRECTORY_NAME=mariaDB-MASTER-tmp

MARIA_DB_INSTALL_PATH=${DATABASE_MAIN_PATH}/${MARIA_DB_INSTALL_DIRECTORY_NAME}
MARIA_DB_DATA_PATH=${DATABASE_MAIN_PATH}/${MARIA_DB_DATA_DIRECTORY_NAME}
MARIA_DB_LOG_PATH=${MARIA_DB_INSTALL_PATH}/${MARIA_DB_LOG_DIRECTORY_NAME}
MARIA_DB_TEMP_PATH=${MARIA_DB_INSTALL_PATH}/${MARIA_DB_TEMP_DIRECTORY_NAME}

mkdir -p ${MARIA_DB_INSTALL_PATH}
mkdir -p ${MARIA_DB_DATA_PATH}
mkdir -p ${MARIA_DB_LOG_PATH}
mkdir -p ${MARIA_DB_TEMP_PATH}

wget ${MARIA_DB_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/mariadb-binary.tar.gz

tar -zxf ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep mariadb-) \
   -C ${MARIA_DB_INSTALL_PATH} \
   --strip-components 1

rm -rf /etc/my.cnf

cat > ${MARIA_DB_INSTALL_PATH}/data/my.cnf \
<<EOF
[client-server]
[mysqld]
user = ${MARIADB_USER}
core-file
port = 3306
basedir = ${MARIA_DB_INSTALL_PATH}
datadir = ${MARIA_DB_DATA_PATH}
tmpdir = ${MARIA_DB_TEMP_PATH}
socket = ${MARIA_DB_TEMP_PATH}/mysqld.sock
pid-file = ${MARIA_DB_TEMP_PATH}/mysqld.pid
log-error = ${MARIA_DB_LOG_PATH}/error.log
# log = ${MARIA_DB_LOG_PATH}/query.log
default_storage_engine='InnoDB'
sysdate-is-now
skip-character-set-client-handshake
character_set_server = utf8mb4
collation_server = utf8mb4_bin
init_connect='SET collation_connection = utf8mb4_bin'
init_connect='SET NAMES utf8mb4'

[mysql]
default-character-set = 'utf8mb4'
no-auto-rehash
local-infile = ON
enable-secure-auth
prompt=(\U){\h}[\d]\_\R:\m:\\s>\_
pager=less -n -i -F -X -E
show-warnings

[client]
port   = 3306
socket = ${MARIA_DB_TEMP_PATH}/mysqld.sock
default-character-set=utf8mb4
EOF

chown -R ${MARIADB_USER}:${DB_USER_GROUP} ${MARIA_DB_INSTALL_PATH}

${MARIA_DB_INSTALL_PATH}/scripts/mysql_install_db \
   --defaults-file=${MARIA_DB_INSTALL_PATH}/data/my.cnf \
   --user=${MARIADB_USER}

${MARIA_DB_INSTALL_PATH}/bin/mysqld_safe \
    --defaults-file=${MARIA_DB_INSTALL_PATH}/data/my.cnf \
    --user=${MARIADB_USER} &

sleep 5

${MARIA_DB_INSTALL_PATH}/bin/mysqladmin \
   --defaults-file=${MARIA_DB_INSTALL_PATH}/data/my.cnf \
   -u root password ${ROOT_USER_PASSWORD}

# cleanup unnecessary user and schema &&
# Install the MariaDB plug-in(s) to help to DB administration.
INIT_SQL=$(cat <<EOF
DELETE FROM mysql.user WHERE Password = '';
DROP SCHEMA test;
CREATE DATABASE ${NEW_DB_SCHEMA_NAME};
FLUSH PRIVILEGES;
INSTALL SONAME 'metadata_lock_info';
INSTALL PLUGIN query_cache_info SONAME 'query_cache_info';
INSTALL SONAME 'locales';
INSTALL SONAME 'query_response_time';
INSTALL PLUGIN SQL_ERROR_LOG SONAME 'sql_errlog';
INSTALL PLUGIN Mroonga SONAME 'ha_mroonga.so';
CREATE USER '${NEW_DB_ADMIN_USER}'@'%' IDENTIFIED BY '${NEW_DB_ADMIN_USER_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* to '${NEW_DB_ADMIN_USER}'@'%';
COMMIT;
FLUSH PRIVILEGES;
EOF
)

${MARIA_DB_INSTALL_PATH}/bin/mysql \
   -S ${MARIA_DB_TEMP_PATH}/mysqld.sock \
   -uroot -p${ROOT_USER_PASSWORD} << EOF
${INIT_SQL}
EOF

cat > /usr/lib/systemd/system/${NEW_USER}_${MARIA_DB_INSTALL_DIRECTORY_NAME}.service \
<<EOF
[Unit]
Description=${NEW_USER}_${MARIA_DB_INSTALL_DIRECTORY_NAME}
After=syslog.target network.target

[Service]
Type=forking
User=${MARIADB_USER}
Group=${DB_USER_GROUP}
PIDFile=${MARIA_DB_TEMP_PATH}/mysqld.pid
TimeoutStartSec=0
TimeoutStopSec=0
ExecStart=${MARIA_DB_INSTALL_PATH}/bin/mysqld_safe --defaults-file=${MARIA_DB_INSTALL_PATH}/data/my.cnf --user=${MARIADB_USER}
ExecStop=${MARIA_DB_INSTALL_PATH}/bin/mysqladmin -S ${MARIA_DB_TEMP_PATH}/mysqld.sock -uroot -p shutdown

[Install]
WantedBy=multi-user.target graphical.target
EOF

chown -R ${MARIADB_USER}:${DB_USER_GROUP} \
   ${MARIA_DB_INSTALL_PATH}

chown -R ${MARIADB_USER}:${DB_USER_GROUP} \
   ${MARIA_DB_DATA_PATH}

systemctl daemon-reload
systemctl enable ${NEW_USER}_${MARIA_DB_INSTALL_DIRECTORY_NAME}

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

# Tomcat 설치

# Tomcat 다운로드 경로 : apache-tomcat-9.0.24 ( 2019-08-14 )
TOMCAT_DOWNLOAD_URL=https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.24/bin/apache-tomcat-9.0.24.tar.gz

# TOMCAT_USER 생성
useradd ${TOMCAT_USER} \
   --shell /sbin/nologin \
   --no-create-home

# SERVER_USER_GROUP 그룹에 TOMCAT_USER 추가
usermod -aG ${SERVER_USER_GROUP} ${TOMCAT_USER}

# Tomcat 설치 경로 / 폴더 / PID / 포트
TOMCAT_INSTALL_DIRECTORY_NAME=tomcat-MASTER
TOMCAT_INSTALL_PATH=${SERVER_MAIN_PATH}/${TOMCAT_INSTALL_DIRECTORY_NAME}
TOMCAT_PID_PATH=${TOMCAT_INSTALL_PATH}/pid
TOMCAT_PORT=${REAL_SERVER_LOCAL_PORT}

# host-manager 에 적용되는 admin 계정
TOMCAT_ADMIN_ID=admin
TOMCAT_ADMIN_PASSWORD=admin123

# manager 에 적용되는 manager 계정
TOMCAT_MANAGER_ID=admin
TOMCAT_MANAGER_PASSWORD=admin123

mkdir -p ${TOMCAT_PID_PATH}

wget ${TOMCAT_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/tomcat.tar.gz && \
tar -zxf ${TEMP_PATH}/tomcat.tar.gz \
   -C ${TOMCAT_INSTALL_PATH} \
   --strip-components 1

# ${TOMCAT_INSTALL_PATH}/conf/server.xml 에서 톰캣 가동 포트 변경
LINE_NO=`grep -n "<Connector port=" \
   ${TOMCAT_INSTALL_PATH}/conf/server.xml | cut -d: -f1 | head -1`

LINE_CONTENT="    <Connector port=\"${TOMCAT_PORT}\" protocol=\"HTTP/1.1\""

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${TOMCAT_INSTALL_PATH}/conf/server.xml

# ${TOMCAT_INSTALL_PATH}/conf/tomcat-users.xml 에서 </tomcat-users> 닫는 태그 제거
LINE_NO=`grep -n "</tomcat-users>" \
   ${TOMCAT_INSTALL_PATH}/conf/tomcat-users.xml | cut -d: -f1 | head -1`

LINE_CONTENT=""

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${TOMCAT_INSTALL_PATH}/conf/tomcat-users.xml


# ${TOMCAT_INSTALL_PATH}/conf/tomcat-users.xml 에 톰캣 관리자 Role / 계정 추가
cat >> /${TOMCAT_INSTALL_PATH}/conf/tomcat-users.xml \
<<EOF
<!-- https://www.lesstif.com/pages/viewpage.action?pageId=18219510 -->

<role rolename="admin"/>
<role rolename="admin-gui"/>
<role rolename="admin-script"/>

<role rolename="manager"/>
<role rolename="manager-gui"/>
<role rolename="manager-script"/>
<role rolename="manager-jmx"/>
<role rolename="manager-status"/>

<user username="${TOMCAT_ADMIN_ID}" password="${TOMCAT_ADMIN_PASSWORD}" 
   roles="admin, admin-gui,admin-script"/>

<user username="${TOMCAT_MANAGER_ID}" password="${TOMCAT_MANAGER_PASSWORD}" 
   roles="manager, manager-gui, manager-script, manager-jmx, manager-status"/>

</tomcat-users>
EOF

mkdir -p ${TOMCAT_INSTALL_PATH}/conf/Catalina/localhost

# ${TOMCAT_INSTALL_PATH}/conf/Catalina/localhost/manager.xml 추가 : 모든 연결 허용
cat > /${TOMCAT_INSTALL_PATH}/conf/Catalina/localhost/manager.xml \
<<EOF
<Context privileged="true" antiResourceLocking="false" docBase="\${catalina.home}/webapps/manager">
   <Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="^.*\$" />
</Context>
EOF




chown -R ${TOMCAT_USER}:${SERVER_USER_GROUP} ${TOMCAT_INSTALL_PATH}

cat > /usr/lib/systemd/system/${NEW_USER}_${TOMCAT_INSTALL_DIRECTORY_NAME}.service \
<<EOF
[Unit]
Description=${NEW_USER}_${TOMCAT_INSTALL_DIRECTORY_NAME}
After=syslog.target network.target

[Service]
Type=forking
User=${TOMCAT_USER}
Group=${SERVER_USER_GROUP}
PIDFile=${TOMCAT_PID_PATH}/tomcat.pid

Environment="JAVA_HOME=${OPENJDK_LINK_PATH}"
Environment="CATALINA_PID=${TOMCAT_PID_PATH}/tomcat.pid"
Environment="CATALINA_HOME=${TOMCAT_INSTALL_PATH}"
Environment="CATALINA_BASE=${TOMCAT_INSTALL_PATH}"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
# Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom"

ExecStart=${TOMCAT_INSTALL_PATH}/bin/startup.sh
ExecStop=${TOMCAT_INSTALL_PATH}/bin/shutdown.sh
ExecStopPost=/bin/rm -f ${TOMCAT_PID_PATH}/tomcat.pid

UMask=0007
RestartSec=30
Restart=always

[Install]
WantedBy=multi-user.target graphical.target
EOF

systemctl daemon-reload
systemctl enable ${NEW_USER}_${TOMCAT_INSTALL_DIRECTORY_NAME}

##############################################################################

# Node.js / npm 설치

# Node.js / npm 다운로드 경로 : 10.16.2 (includes npm 6.9.0) ( 2019-08-06 )
NODEJS_DOWNLOAD_URL=https://nodejs.org/dist/v10.16.2/node-v10.16.2-linux-x64.tar.xz

# DEPENDENCY_MAIN_PATH 내 NPM 저장소 디렉토리
NPM_REPOSITORY_DIRECTORY_NAME=npm
NPM_REPOSITORY_PATH=${DEPENDENCY_MAIN_PATH}/${NPM_REPOSITORY_DIRECTORY_NAME}

mkdir -p ${NPM_REPOSITORY_PATH}

# NODEJS_USER 생성
useradd ${NODEJS_USER} \
   --shell /sbin/nologin \
   --no-create-home

# SERVER_USER_GROUP 그룹에 NODEJS_USER 추가
usermod -aG ${SERVER_USER_GROUP} ${NODEJS_USER}

# Node.js 설치 경로 / 폴더 구성
NODEJS_INSTALL_DIRECTORY_NAME=nodejs-MASTER
NODEJS_INSTALL_PATH=${SERVER_MAIN_PATH}/${NODEJS_INSTALL_DIRECTORY_NAME}

mkdir -p ${NODEJS_INSTALL_PATH}

# -xf 옵션으로 풀 것 : gzip 포맷 아님
wget ${NODEJS_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/nodejs.tar.gz && \
tar -xf ${TEMP_PATH}/nodejs.tar.gz \
   -C ${NODEJS_INSTALL_PATH} \
   --strip-components 1

chown -R ${NODEJS_USER}:${SERVER_USER_GROUP} ${NODEJS_INSTALL_PATH}

# export PATH=\$PATH:${NODEJS_INSTALL_PATH}/bin

# runuser -l ${NEW_USER} \
#    -c '${NODEJS_INSTALL_PATH}/bin/npm config set prefix ${NPM_REPOSITORY_PATH}'

##############################################################################

# Nexus 설치

# NEXUS 다운로드 경로 : 3.18.0-01 ( 2019-07-26 )
NEXUS_DOWNLOAD_URL=http://download.sonatype.com/nexus/3/nexus-3.18.0-01-unix.tar.gz

# NEXUS_USER 생성
useradd ${NEXUS_USER} \
   --shell /sbin/nologin \
   --no-create-home

# SERVER_USER_GROUP 그룹에 NEXUS_USER 추가
usermod -aG ${SERVER_USER_GROUP} ${NEXUS_USER}

# Nexus 설치 경로 / 폴더 / 포트

NEXUS_INSTALL_DIRECTORY_NAME=nexus
NEXUS_DATA_DIRECTORY_NAME=nexus-data
NEXUS_PORT=${NEXUS_SERVER_LOCAL_PORT}
# NEXUS_INITIAL_ADMIN_PASSWORD=admin123

NEXUS_PATH=${SERVER_MAIN_PATH}/${NEXUS_INSTALL_DIRECTORY_NAME}
NEXUS_DATA_PATH=${SERVER_MAIN_PATH}/${NEXUS_DATA_DIRECTORY_NAME}
NEXUS_PID_PATH=${NEXUS_PATH}/pid

mkdir -p ${NEXUS_PATH}
mkdir -p ${NEXUS_DATA_PATH}
mkdir -p ${NEXUS_PID_PATH}

wget ${NEXUS_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/nexus.tar.gz && \
tar -zxf ${TEMP_PATH}/nexus.tar.gz \
   -C ${TEMP_PATH} \

# 숨김파일도 이동 처리되도록 설정
shopt -s dotglob

# nexus-버전명 디렉토리 내 모든 파일을 NEXUS_PATH 으로 이동
mv ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep nexus-)/* \
   ${NEXUS_PATH}

# sonatype-work 디렉토리 내 모든 파일을 NEXUS_DATA_PATH 으로 이동
mv ${TEMP_PATH}/sonatype-work/* \
   ${NEXUS_DATA_PATH}

# ${NEXUS_PATH}/bin/nexus 내 INSTALL4J_JAVA_HOME_OVERRIDE 설정
LINE_NO=`grep -n "INSTALL4J_JAVA_HOME_OVERRIDE" \
   ${NEXUS_PATH}/bin/nexus | cut -d: -f1 | head -1`

LINE_CONTENT="INSTALL4J_JAVA_HOME_OVERRIDE=${OPENJDK_LINK_PATH}"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NEXUS_PATH}/bin/nexus

# ${NEXUS_PATH}/bin/nexus.rc 설정
cat > ${NEXUS_PATH}/bin/nexus.rc \
<<EOF
run_as_user=${NEXUS_USER}
EOF

# ${NEXUS_PATH}/bin/nexus.vmoptions 설정
cat > ${NEXUS_PATH}/bin/nexus.vmoptions \
<<EOF
-Xms2703m
-Xmx2703m
-XX:MaxDirectMemorySize=2703m
-XX:+UnlockDiagnosticVMOptions
-XX:+UnsyncloadClass
-XX:+LogVMOutput
-XX:LogFile=${NEXUS_DATA_PATH}/nexus3/log/jvm.log
-XX:-OmitStackTraceInFastThrow
-Djava.net.preferIPv4Stack=true
-Dkaraf.home=.
-Dkaraf.base=.
-Dkaraf.etc=etc/karaf
-Djava.util.logging.config.file=etc/karaf/java.util.logging.properties
-Dkaraf.data=${NEXUS_DATA_PATH}/nexus3
-Djava.io.tmpdir=${NEXUS_DATA_PATH}/nexus3/tmp
-Dkaraf.startLocalConsole=false
-Dinstall4j.pidDir=${NEXUS_PID_PATH}
EOF

# 기존 nexus-default.properties 백업
mv ${NEXUS_PATH}/etc/nexus-default.properties \
   ${NEXUS_PATH}/etc/nexus-default_origin.properties

# ${NEXUS_PATH}/etc/nexus-default.properties 설정
cat > ${NEXUS_PATH}/etc/nexus-default.properties \
<<EOF
# Jetty section
application-port=${NEXUS_PORT}
application-host=0.0.0.0
nexus-args=\${jetty.etc}/jetty.xml,\${jetty.etc}/jetty-http.xml,\${jetty.etc}/jetty-requestlog.xml
nexus-context-path=/

# Nexus section
nexus-edition=nexus-oss-edition
nexus-features=\
 nexus-oss-feature
EOF

# 넥서스 초기 관리자 비밀번호 생성
# cat > ${NEXUS_DATA_PATH}/nexus3/admin.password \
# <<EOF
# ${NEXUS_INITIAL_ADMIN_PASSWORD}
# EOF

chown -R ${NEXUS_USER}:${SERVER_USER_GROUP} \
   ${NEXUS_PATH}

chown -R ${NEXUS_USER}:${SERVER_USER_GROUP} \
   ${NEXUS_DATA_PATH}

cat > /usr/lib/systemd/system/${NEW_USER}_${NEXUS_INSTALL_DIRECTORY_NAME}.service \
<<EOF
# https://help.sonatype.com/repomanager3/installation/run-as-a-service#RunasaService-systemd

[Unit]
Description=${NEW_USER}_${NEXUS_INSTALL_DIRECTORY_NAME}
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
User=${NEXUS_USER}
Group=${SERVER_USER_GROUP}

PIDFile=${NEXUS_PID_PATH}/i4jdaemon__${SERVER_MAIN_PATH}_${NEXUS_DATA_DIRECTORY_NAME}_bin_nexus.pid
TimeoutStartSec=0
TimeoutStopSec=0
PermissionsStartOnly=true
ExecStart=${NEXUS_PATH}/bin/nexus start
ExecStop=${NEXUS_PATH}/bin/nexus stop
ExecStopPost=/bin/rm -f ${NEXUS_PID_PATH}/nexus.pid
Restart=on-abort

[Install]
WantedBy=multi-user.target graphical.target

EOF

systemctl daemon-reload
systemctl enable ${NEW_USER}_${NEXUS_INSTALL_DIRECTORY_NAME}.service

##############################################################################

# openssl 컴파일 버전 다운로드 / 설치 ( NGINX Dependencies : openssl, PCRE, ZLIB )

# openssl 다운로드 경로 : 1.1.1c( 2019-05-28 )
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source/openssl-1.1.1c.tar.gz

# OPENSSL 컴파일 설치
# 참조 https://blanche-star.tistory.com/entry/APM-%EC%84%A4%EC%B9%98-openssl-%EC%B5%9C%EC%8B%A0%EB%B2%84%EC%A0%84%EC%84%A4%EC%B9%98%EC%86%8C%EC%8A%A4%EC%84%A4%EC%B9%98-shared%EC%84%A4%EC%B9%98

# 기존 openssl 제거
yum remove -y \
   openssl

yum install -y \
   zlib-devel \
   libssl-dev

wget ${OPENSSL_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/openssl.tar.gz && \
tar -zxf ${TEMP_PATH}/openssl.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep openssl-) \
   ${TEMP_PATH}/openssl \
   ${TEMP_PATH}/openssl-*

# https://www.lesstif.com/pages/viewpage.action?pageId=6291508
# -prefix 옵션을 주지 않으면 기본적으로 /usr/local/ 밑에 나눠서 들어간다. 
# header (.h)는 /usr/local/include/openssl, 
# openssl 실행 파일은 /usr/local/bin
#   => 일반적으로 $PATH 에 기본 등록되는 경로이므로 별도 PATH 등록 불필요
# library 는 /usr/local/lib/openssl 폴더에 설치된다. (고 한다..)
#   => 근데 openssl 폴더가 없다??
#   => 아래 설정으로 설치시에는 /usr/local/lib64 에 설치되는 것이 아닌가 추측됨
# (추가) 인증서비스를 위한 파일 : /usr/local/openssl 에 설치된다.

cd openssl

# Configure 의 C 가 대문자여야 실행됨
./Configure \
    linux-x86_64 \
    shared \
    no-idea no-md2 no-mdc2 no-rc5 no-rc4 \
    --prefix=/usr/local \
    --openssldir=/usr/local/openssl

make
make install

cd ..

# openssl 실행 위한 lib 파일 복사
# http://mapoo.net/os/oslinux/openssl-source-install/
# https://sarc.io/index.php/httpd/1252-openssl
cp /usr/local/lib64/libssl.so.1.1 \
   /usr/lib64/libssl.so.1.1 && \
cp /usr/local/lib64/libcrypto.so.1.1 \
   /usr/lib64/libcrypto.so.1.1

##############################################################################

# PCRE 컴파일 버전 다운로드 ( NGINX Dependencies : openssl, PCRE, ZLIB )

# PCRE 다운로드 경로 : 8.43 ( 2019-02-23 )
PCRE_DOWNLOAD_URL=https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz

# 기존 pcre 제거
yum remove -y \
   pcre

wget ${PCRE_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/pcre.tar.gz && \
tar -zxf ${TEMP_PATH}/pcre.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep pcre-) \
   ${TEMP_PATH}/pcre \
   ${TEMP_PATH}/pcre-*

cd pcre

./configure \
   --prefix=/usr/local

make
make install
cd ..

##############################################################################

# zlib 컴파일 버전 다운로드 ( NGINX Dependencies : openssl, PCRE, ZLIB )

# zlib 다운로드 경로 : 1.2.11 ( 2017-01-15 )
ZLIB_DOWNLOAD_URL=http://zlib.net/zlib-1.2.11.tar.gz

# 기존 zlib 제거
yum remove -y \
   zlib

wget ${ZLIB_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/zlib.tar.gz && \
tar -zxf ${TEMP_PATH}/zlib.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep zlib-) \
   ${TEMP_PATH}/zlib \
   ${TEMP_PATH}/zlib-*

cd zlib

./configure \
   --prefix=/usr/local

make
make install

cd ..

##############################################################################

# NGINX 컴파일 설치

# https://docs.nginx.com/nginx/admin-guide/installing-nginx/installing-nginx-open-source/
# https://extrememanual.net/9910#idx-8
# https://m.blog.naver.com/PostView.nhn?blogId=kletgdgo&logNo=221249484040&proxyReferer=https%3A%2F%2Fwww.google.com%2F
# https://webdir.tistory.com/238
# https://blog.naver.com/writer0713/221460840636

# NGINX 다운로드 경로 : Mainline 1.17.1 ( 2019-06-25 )
NGINX_DOWNLOAD_URL=http://nginx.org/download/nginx-1.17.1.tar.gz

# nginx-dav-ext-module 다운로드 경로 : release-v3.0.0 ( 2018-12-17 )
NGINX_DAV_EXT_MODULE_DOWNLOAD_URL=https://github.com/arut/nginx-dav-ext-module/archive/v3.0.0.tar.gz

# nginx-rtmp-module 다운로드 경로 : v1.2.1 ( 2017-11-29  )
NGINX_RTMP_MODULE_DOWNLOAD_URL=https://github.com/arut/nginx-rtmp-module/archive/v1.2.1.tar.gz

# NGINX_USER 생성
useradd ${NGINX_USER} \
    --shell /sbin/nologin \
    --no-create-home

# NGINX_USER 를 NGINX_USER_GROUP, SERVER_USER_GROUP 에 추가
usermod -aG ${NGINX_USER_GROUP} ${NGINX_USER}
usermod -aG ${SERVER_USER_GROUP} ${NGINX_USER}

# Nginx 설치 경로 / 폴더 구성
NGINX_INSTALL_DIRECTORY_NAME=nginx-MASTER

NGINX_PATH=${SERVER_MAIN_PATH}/${NGINX_INSTALL_DIRECTORY_NAME}
NGINX_ACCESS_LOG_PATH=${NGINX_PATH}/log/access
NGINX_ERROR_LOG_PATH=${NGINX_PATH}/log/error
NGINX_TEMP_PATH=${NGINX_PATH}/temp
NGINX_SBIN_PATH=${NGINX_PATH}/sbin
NGINX_RUN_PATH=${NGINX_PATH}/run
NGINX_MODULES_PATH=${NGINX_PATH}/modules
NGINX_SITES_ENABLED_PATH=${NGINX_PATH}/sites-enabled
NGINX_SITES_AVAILABLE_PATH=${NGINX_PATH}/sites-available

# Nginx 설치 / 로그 / TEMP / 실행파일 / RUN / MODULES / SITES 디렉토리 생성
mkdir -p ${NGINX_PATH}
mkdir -p ${NGINX_ACCESS_LOG_PATH}
mkdir -p ${NGINX_ERROR_LOG_PATH}
mkdir -p ${NGINX_TEMP_PATH}
mkdir -p ${NGINX_SBIN_PATH}
mkdir -p ${NGINX_RUN_PATH}
mkdir -p ${NGINX_MODULES_PATH}
mkdir -p ${NGINX_SITES_ENABLED_PATH}
mkdir -p ${NGINX_SITES_AVAILABLE_PATH}

# STATIC_FILE_MAIN_PATH 설치 경로
NGINX_STORE_MAIN_PATH=${STATIC_FILE_MAIN_PATH}/WWW
mkdir -p ${NGINX_STORE_MAIN_PATH}

##############################################################################

# NGINX Dependencies 컴파일 설치 위한 라이브러리
yum install -y \
   gcc-c++ \
   libxml2-devel \
   libxslt-devel \
   gd \
   gd-devel \
   perl-ExtUtils-Embed \
   GeoIP-devel \
   gperftools-devel

wget ${NGINX_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/nginx.tar.gz && \
tar -zxf ${TEMP_PATH}/nginx.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep nginx-) \
   ${TEMP_PATH}/nginx \
   ${TEMP_PATH}/nginx-*

# nginx-dav-ext-module : ${TEMP_PATH}/nginx/nginx-dav-ext-module 경로에 모듈 다운로드
wget ${NGINX_DAV_EXT_MODULE_DOWNLOAD_URL} \
   -P ${TEMP_PATH}/nginx \
   -O ${TEMP_PATH}/nginx/nginx-dav-ext-module.tar.gz && \
tar -zxf ${TEMP_PATH}/nginx/nginx-dav-ext-module.tar.gz \
   -C ${TEMP_PATH}/nginx

rename ${TEMP_PATH}/nginx/$(ls ${TEMP_PATH}/nginx | grep nginx-dav-ext-module-) \
   ${TEMP_PATH}/nginx/nginx-dav-ext-module \
   ${TEMP_PATH}/nginx/nginx-dav-ext-module-*

# nginx-rtmp-module : ${TEMP_PATH}/nginx/nginx-rtmp-module 경로에 모듈 다운로드
wget ${NGINX_RTMP_MODULE_DOWNLOAD_URL} \
   -P ${TEMP_PATH}/nginx \
   -O ${TEMP_PATH}/nginx/nginx-rtmp-module.tar.gz && \
tar -zxf ${TEMP_PATH}/nginx/nginx-rtmp-module.tar.gz \
   -C ${TEMP_PATH}/nginx

rename ${TEMP_PATH}/nginx/$(ls ${TEMP_PATH}/nginx | grep nginx-rtmp-module-) \
   ${TEMP_PATH}/nginx/nginx-rtmp-module \
   ${TEMP_PATH}/nginx/nginx-rtmp-module-*

cd nginx

# with-openssl / pcre / zlib 옵션을 설치경로가 아닌 압축 해제 경로로 지정해야 실행됨
./configure \
--prefix=${NGINX_PATH} \
--conf-path=${NGINX_PATH}/nginx.conf \
--user=${NGINX_USER} \
--group=${NGINX_USER_GROUP} \
--error-log-path=${NGINX_ERROR_LOG_PATH}/error.log \
--http-log-path=${NGINX_ACCESS_LOG_PATH}/access.log \
--sbin-path=${NGINX_SBIN_PATH}/nginx \
--pid-path=${NGINX_RUN_PATH}/nginx.pid \
--lock-path=${NGINX_RUN_PATH}/nginx.lock \
--modules-path=${NGINX_MODULES_PATH} \
--http-client-body-temp-path=${NGINX_TEMP_PATH}/client_temp \
--http-proxy-temp-path=${NGINX_TEMP_PATH}/proxy_temp \
--http-fastcgi-temp-path=${NGINX_TEMP_PATH}/fastcgi_temp \
--http-uwsgi-temp-path=${NGINX_TEMP_PATH}/uwsgi_temp \
--http-scgi-temp-path=${NGINX_TEMP_PATH}/scgi_temp \
--with-openssl=${TEMP_PATH}/openssl \
--with-pcre=${TEMP_PATH}/pcre \
--with-zlib=${TEMP_PATH}/zlib \
--add-module=./nginx-rtmp-module \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_xslt_module \
--with-http_image_filter_module \
--with-http_geoip_module \
--with-http_sub_module \
--with-http_dav_module \
--add-module=./nginx-dav-ext-module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_auth_request_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_slice_module \
--with-http_degradation_module \
--with-http_stub_status_module \
--with-http_perl_module \
--with-mail \
--with-mail_ssl_module \
--with-stream \
--with-stream_ssl_module \
--with-google_perftools_module \
--with-cpp_test_module \
--with-debug

make
make install
  
cd ..

##############################################################################
# nginx.conf 원본 파일 백업
cp ${NGINX_PATH}/nginx.conf \
   ${NGINX_PATH}/nginx_origin_backup.conf

cat > ${NGINX_PATH}/nginx.conf \
<<EOF
# https://www.nginx.com/resources/wiki/start/topics/examples/full/

user ${NGINX_USER} ${NGINX_USER_GROUP};

worker_processes  1;
pid    ${NGINX_RUN_PATH}/nginx.pid;

events {
    worker_connections  1024;
}

http {
   access_log     off;
   log_not_found  off;
   server_tokens  off;
   sendfile       on;

   server_names_hash_bucket_size  64;   # 기본값:32
   server_names_hash_max_size     2048; # 기본값:512
   client_max_body_size           10M;
   keepalive_timeout              10;

   # https://www.lesstif.com/pages/viewpage.action?pageId=59343019

   gzip             on;
   gzip_disable     "msie6";

   gzip_comp_level  6;
   gzip_min_length  500;
   gzip_buffers     16 8k;
   gzip_proxied     any;

   gzip_types
      text/plain
      text/css
      text/js
      text/xml
      text/javascript
      application/javascript
      application/x-javascript
      application/json
      application/xml
      application/rss+xml
      image/svg+xml;

    # error 로그는 도메인 상관없이 통합으로 관리함
    error_log ${NGINX_ERROR_LOG_PATH}/error.log crit;

    include       mime.types;
    default_type  application/octet-stream;

    include ${NGINX_SITES_ENABLED_PATH}/*;

    log_format   main '\$remote_addr - \$remote_user [\$time_local]  \$status '
        '"\$request" \$body_bytes_sent "\$http_referer" '
        '"\$http_user_agent" "\$http_x_forwarded_for"';

}
EOF

##############################################################################

# 도메인 디렉토리 생성 : REAL_DOMAIN 운영 도메인 
mkdir -p ${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN}

# REAL_DOMAIN : http 연결 설정
cat > ${NGINX_SITES_AVAILABLE_PATH}/${REAL_DOMAIN} \
<<EOF
server {
   listen       80;
   listen       [::]:80;
   server_name  ${REAL_DOMAIN} www.${REAL_DOMAIN};
   charset      utf-8;

   access_log   ${NGINX_ACCESS_LOG_PATH}/main_access.log;
   error_page   500 502 503 504  /50x.html;

   location / {
      root   ${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN};
      index  index.html index.htm;
   }

   # certbot --webroot 인증을 위한 설정
   location ^~/.well-known/acme-challenge/ {
      default_type  "text/plain";
      root          ${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN};
   }

   # return   301 https://\$host\$request_uri;

}

EOF

ln -s ${NGINX_SITES_AVAILABLE_PATH}/${REAL_DOMAIN} \
   ${NGINX_SITES_ENABLED_PATH}/${REAL_DOMAIN}

cp ${NGINX_PATH}/html/index.html \
   ${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN}/index.html

# 
LINE_NO=`grep -n "<h1>Welcome to nginx!</h1>" \
   ${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN}/index.html | cut -d: -f1 | head -1`

LINE_CONTENT="<h1>Welcome to nginx! - MAIN (운영)</h1>"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN}/index.html

# 
cp ${NGINX_PATH}/html/50x.html \
   ${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN}/50x.html

##############################################################################

# NEXUS_DOMAIN : http 연결 설정
cat > ${NGINX_SITES_AVAILABLE_PATH}/${NEXUS_DOMAIN} \
<<EOF
# https://help.sonatype.com/repomanager3/installation/run-behind-a-reverse-proxy#RunBehindaReverseProxy-nginx

server {
   listen       80;
   listen       [::]:80;
   server_name  ${NEXUS_DOMAIN};
   charset      utf-8;

   access_log   ${NGINX_ACCESS_LOG_PATH}/${NEXUS_DOMAIN_PREFIX}_access.log;
   error_page   500 502 503 504  /50x.html;

   proxy_send_timeout  120;
   proxy_read_timeout  300;
   proxy_buffering     off;
   keepalive_timeout   5 5;
   tcp_nodelay         on;

   # allow large uploads of files
   client_max_body_size 1G;
  
   # optimize downloading files larger than 1G
   # proxy_max_temp_file_size 2G;

   location / {
      proxy_pass        http://127.0.0.1:${NEXUS_PORT};

      proxy_set_header  Host \$host;
      proxy_set_header  X-Real-IP \$remote_addr;
      proxy_set_header  X-Forwarded-For \$proxy_add_x_forwarded_for;
   }

   # certbot --webroot 인증을 위한 설정
   # 넥서스 도메인 인증시 root 는 nginx 설치 디렉토리 내 html 로 지정함
   location ^~/.well-known/acme-challenge/ {
      default_type  "text/plain";
      root          html;
   }

   # return   301 https://\$host\$request_uri;

}

EOF

ln -s ${NGINX_SITES_AVAILABLE_PATH}/${NEXUS_DOMAIN} \
   ${NGINX_SITES_ENABLED_PATH}/${NEXUS_DOMAIN}

##############################################################################

# 도메인 디렉토리 생성 : DEV_DOMAIN 개발 도메인
mkdir -p ${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN}

# DEV_DOMAIN : http 연결 설정
cat > ${NGINX_SITES_AVAILABLE_PATH}/${DEV_DOMAIN} \
<<EOF
server {
   listen       80;
   listen       [::]:80;
   server_name  ${DEV_DOMAIN};
   charset      utf-8;

   access_log   ${NGINX_ACCESS_LOG_PATH}/${DEV_DOMAIN_PREFIX}_access.log;
   error_page   500 502 503 504  /50x.html;

   location / {
      root   ${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN};
      index  index.html index.htm;
   }

   # certbot --webroot 인증을 위한 설정
   location ^~/.well-known/acme-challenge/ {
      default_type  "text/plain";
      root          ${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN};
   }

   # return   301 https://\$host\$request_uri;

}

EOF

ln -s ${NGINX_SITES_AVAILABLE_PATH}/${DEV_DOMAIN} \
   ${NGINX_SITES_ENABLED_PATH}/${DEV_DOMAIN}

cp ${NGINX_PATH}/html/index.html \
   ${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN}/index.html

# 
LINE_NO=`grep -n "<h1>Welcome to nginx!</h1>" \
   ${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN}/index.html | cut -d: -f1 | head -1`

LINE_CONTENT="<h1>Welcome to nginx! - DEV (개발)</h1>"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN}/index.html

# 
cp ${NGINX_PATH}/html/50x.html \
   ${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN}/50x.html

##############################################################################

# STATIC_FILE_MAIN_PATH 내 WEBDAV 관련 임시 디렉토리 생성 : 모든 WEBDAV 저장소가 공용으로 사용
NGINX_WEBDAV_CLIENT_BODY_TEMP_DIRECTORY_NAME=WEBDAV-temp
NGINX_WEBDAV_CLIENT_BODY_TEMP_PATH=${STATIC_FILE_MAIN_PATH}/${NGINX_WEBDAV_CLIENT_BODY_TEMP_DIRECTORY_NAME}

# STATIC_FILE_MAIN_PATH 내 WEBDAV 관련 디렉토리 생성
NGINX_WEBDAV_MAIN_DIRECTORY_NAME=WEBDAV-MAIN
NGINX_WEBDAV_MAIN_PATH=${STATIC_FILE_MAIN_PATH}/${NGINX_WEBDAV_MAIN_DIRECTORY_NAME}
NGINX_WEBDAV_MAIN_REPO_URL=main

mkdir -p ${NGINX_WEBDAV_MAIN_PATH}
mkdir -p ${NGINX_WEBDAV_CLIENT_BODY_TEMP_PATH}

# 톰캣에 수동 배포 위해 TOMCAT_INSTALL_PATH 의 webapps 심볼릭 링크 생성
TOMCAT_WEBAPPS_PATH=${TOMCAT_INSTALL_PATH}/webapps
TOMCAT_WEBAPPS_LINK_NAME=TOMCAT-WEBAPPS
NGINX_WEBAPPS_REPO_URL=webapps
ln -s ${TOMCAT_INSTALL_PATH}/webapps \
   ${STATIC_FILE_MAIN_PATH}/${TOMCAT_WEBAPPS_LINK_NAME}

# 운영 서버 도메인 정적 파일 저장 경로
REAL_DOMAIN_REPO_PATH=${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN}

# 개발 서버 도메인 정적파일 저장 경로
DEV_DOMAIN_REPO_PATH=${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN}

# WEBDAV 계정 정보 저장할 디렉토리 생성
NGINX_WEBDAV_PASSWD_LIST_DIRECTORY_NAME=.passwd
NGINX_WEBDAV_PASSWD_LIST_PATH=${NGINX_PATH}/${NGINX_WEBDAV_PASSWD_LIST_DIRECTORY_NAME}

mkdir -p ${NGINX_WEBDAV_PASSWD_LIST_PATH}

##############################################################################

# openssl 설치시 실행 파일은 /usr/local/bin 에 생성 : 별도 path 불필요 
# echo "계정이름:$(openssl passwd -crypt 비밀번호)" >> (...)/(계정 저장 파일명)

# WEBDAV 디렉토리 접속할 계정 정보 / WEBDAV 계정 파일 생성
NGINX_WEBDAV_USER_ID=admin
NGINX_WEBDAV_USER_PASSWORD=admin123

NGINX_WEBDAV_PASSWD_LIST_NAME=.htpasswd-${NGINX_WEBDAV_MAIN_DIRECTORY_NAME}

echo "${NGINX_WEBDAV_USER_ID}:$(openssl passwd -crypt ${NGINX_WEBDAV_USER_PASSWORD})" >> \
    ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_WEBDAV_PASSWD_LIST_NAME}

# 톰캣 WEBAPPS 링크 디렉토리 접속할 계정 정보 / WEBAPPS 계정 파일 생성
NGINX_WEBAPPS_USER_ID=admin
NGINX_WEBAPPS_USER_PASSWORD=admin123

NGINX_WEBAPPS_PASSWD_LIST_NAME=.htpasswd-${TOMCAT_WEBAPPS_LINK_NAME}

echo "${NGINX_WEBAPPS_USER_ID}:$(openssl passwd -crypt ${NGINX_WEBAPPS_USER_PASSWORD})" >> \
    ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_WEBAPPS_PASSWD_LIST_NAME}

# 개발 도메인의 정적 파일 저장 디렉토리 접속할 계정 정보 / 계정 파일 생성
NGINX_DEV_REPO_USER_ID=admin
NGINX_DEV_REPO_USER_PASSWORD=admin123

NGINX_DEV_REPO_URL=dev
NGINX_DEV_REPO_PASSWD_LIST_NAME=.htpasswd-${NGINX_DEV_REPO_URL}

echo "${NGINX_DEV_REPO_USER_ID}:$(openssl passwd -crypt ${NGINX_DEV_REPO_USER_PASSWORD})" >> \
    ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_DEV_REPO_PASSWD_LIST_NAME}

# 운영 도메인 정적 파일 저장 디렉토리 접속할 계정 정보 / 계정 파일 생성
NGINX_REAL_REPO_USER_ID=admin
NGINX_REAL_REPO_USER_PASSWORD=admin123

NGINX_REAL_REPO_URL=real
NGINX_REAL_REPO_PASSWD_LIST_NAME=.htpasswd-${NGINX_REAL_REPO_URL}

echo "${NGINX_REAL_REPO_USER_ID}:$(openssl passwd -crypt ${NGINX_REAL_REPO_USER_PASSWORD})" >> \
    ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_REAL_REPO_PASSWD_LIST_NAME}

# WEBDAV_DOMAIN : http 연결 설정
cat > ${NGINX_SITES_AVAILABLE_PATH}/${WEBDAV_DOMAIN} \
<<EOF
server {
   listen       80;
   listen       [::]:80;
   server_name  ${WEBDAV_DOMAIN};
   charset      utf-8;

   error_page   500 502 503 504  /50x.html;

   dav_methods            PUT DELETE MKCOL COPY MOVE;
   dav_ext_methods        PROPFIND OPTIONS;
   dav_access             user:rw  group:rw  all:r;
   autoindex              on;

   client_body_temp_path  ${NGINX_WEBDAV_CLIENT_BODY_TEMP_PATH};
   create_full_put_path   on;
   client_max_body_size   0;

   location / {
      deny  all;
   }

   location /${NGINX_WEBDAV_MAIN_REPO_URL} {
      autoindex              on;
      index                  main_index.html;
      access_log             ${NGINX_ACCESS_LOG_PATH}/${WEBDAV_DOMAIN_PREFIX}_${NGINX_WEBDAV_MAIN_REPO_URL}_access.log;
      alias                  ${NGINX_WEBDAV_MAIN_PATH};   # WEBDAV 메인 디렉토리        
      auth_basic             "WEBDAV MAIN Access";
      auth_basic_user_file   ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_WEBDAV_PASSWD_LIST_NAME};
      try_files              \$uri \$uri/ =404;

   }

   location /${NGINX_WEBAPPS_REPO_URL}  {
      autoindex              on;
      # index                webapps_index.html;
      access_log             ${NGINX_ACCESS_LOG_PATH}/${WEBDAV_DOMAIN_PREFIX}_${NGINX_WEBAPPS_REPO_URL}_access.log;
      alias                  ${STATIC_FILE_MAIN_PATH}/${TOMCAT_WEBAPPS_LINK_NAME};   # webapps 링크 디렉토리        
      auth_basic             "WEBAPPS Access";
      auth_basic_user_file   ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_WEBAPPS_PASSWD_LIST_NAME};
      try_files              \$uri \$uri/ =404;

   }

   location /${NGINX_DEV_REPO_URL}  {
      autoindex              on;
      index                  ${NGINX_DEV_REPO_URL}-index.html;
      access_log             ${NGINX_ACCESS_LOG_PATH}/${WEBDAV_DOMAIN_PREFIX}_${NGINX_DEV_REPO_URL}_access.log;
      alias                  ${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN};   # DEV-REPO 디렉토리        
      auth_basic             "DEV-REPO Access";
      auth_basic_user_file   ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_DEV_REPO_PASSWD_LIST_NAME};
      try_files              \$uri \$uri/ =404;

   }

   location /${NGINX_REAL_REPO_URL} {
      autoindex              on;
      index                  ${NGINX_REAL_REPO_URL}-index.html;
      access_log             ${NGINX_ACCESS_LOG_PATH}/${WEBDAV_DOMAIN_PREFIX}_${NGINX_REAL_REPO_URL}_access.log;
      alias                  ${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN};   # REAL-REPO 디렉토리        
      auth_basic             "REAL-REPO Access";
      auth_basic_user_file   ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_REAL_REPO_PASSWD_LIST_NAME};
      try_files              \$uri \$uri/ =404;

   }

   # certbot --webroot 인증을 위한 설정
   location ^~/.well-known/acme-challenge/ {
      default_type  "text/plain";
      root          ${NGINX_WEBDAV_MAIN_PATH};
   }

   # return   301 https://\$host\$request_uri;

}

EOF

ln -s ${NGINX_SITES_AVAILABLE_PATH}/${WEBDAV_DOMAIN} \
   ${NGINX_SITES_ENABLED_PATH}/${WEBDAV_DOMAIN}

##############################################################################

# 일반 유저로 nginx 80 포트 사용 : libcap 패키지 필요
/usr/sbin/setcap 'cap_net_bind_service=+ep' ${NGINX_SBIN_PATH}/nginx

# Let's Encrypt 인증서 발급 위해 nginx 수동 실행
${NGINX_SBIN_PATH}/nginx -c ${NGINX_PATH}/nginx.conf

# NGINX_USER, NGINX_USER_GROUP 으로 소유 변경
chown -R ${NGINX_USER}:${NGINX_USER_GROUP} \
   ${NGINX_PATH}

chown -R ${NGINX_USER}:${NGINX_USER_GROUP} \
   ${NGINX_STORE_MAIN_PATH}

# NGINX_USER, NGINX_USER_GROUP 으로 소유 변경
chown -R ${NGINX_USER}:${NGINX_USER_GROUP} \
   ${NGINX_WEBDAV_MAIN_PATH}

chown -R ${NGINX_USER}:${NGINX_USER_GROUP} \
   ${NGINX_WEBDAV_CLIENT_BODY_TEMP_PATH}

cat > /usr/lib/systemd/system/${NEW_USER}_${NGINX_INSTALL_DIRECTORY_NAME}.service \
<<EOF
## see https://www.nginx.com/resources/wiki/start/topics/examples/systemd/

[Unit]
Description=${NEW_USER}_${NGINX_INSTALL_DIRECTORY_NAME}
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
User=${NGINX_USER}
Group=${NGINX_USER_GROUP}
PIDFile=${NGINX_RUN_PATH}/nginx.pid
TimeoutStartSec=0
TimeoutStopSec=0
PermissionsStartOnly=true
ExecStartPre=/usr/sbin/setcap 'cap_net_bind_service=+ep' ${NGINX_SBIN_PATH}/nginx
ExecStart=${NGINX_SBIN_PATH}/nginx -c ${NGINX_PATH}/nginx.conf
ExecReload=${NGINX_SBIN_PATH}/nginx -s reload
ExecStop=${NGINX_SBIN_PATH}/nginx -s stop
ExecStopPost=/bin/rm -f ${NGINX_RUN_PATH}/nginx.pid

[Install]
WantedBy=multi-user.target graphical.target
EOF

systemctl daemon-reload
systemctl enable ${NEW_USER}_${NGINX_INSTALL_DIRECTORY_NAME}.service

##############################################################################

# https://medium.com/bros/enabling-https-with-lets-encrypt-over-docker-9cad06bdb82b

# Let's Encrypt 설치용 CERTBOT 도커 버전 다운로드
docker pull certbot/certbot:latest

# UTILS_MAIN_PATH 내 Let's Encrypt 설치 디렉토리 / 경로
LETS_ENCRYPT_INSTALL_DIRECTORY_NAME=letsencrypt
LETS_ENCRYPT_INSTALL_PATH=${UTILS_MAIN_PATH}/${LETS_ENCRYPT_INSTALL_DIRECTORY_NAME}

LETS_ENCRYPT_EMAIL=reverse32@naver.com

##############################################################################

# docker -v 옵션 지정시 호스트에 디렉토리가 없으면 docker 가 자동 생성함

# REAL_DOMAIN 운영 도메인 인증
docker run -it --rm --name certbot \
   -v "${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN}:/var/www" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}:/etc/letsencrypt" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}/lib:/var/lib/letsencrypt" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}/log:/var/log/letsencrypt" \
   certbot/certbot certonly --webroot \
   --webroot-path /var/www \
   -d ${REAL_DOMAIN} \
   -d www.${REAL_DOMAIN} \
   --agree-tos \
   --manual-public-ip-logging-ok \
   --email ${LETS_ENCRYPT_EMAIL} \
   --no-eff-email

chmod 701 ${LETS_ENCRYPT_INSTALL_PATH}/live
chmod 604 ${LETS_ENCRYPT_INSTALL_PATH}/archive/${REAL_DOMAIN}/privkey1.pem
chmod 701 ${LETS_ENCRYPT_INSTALL_PATH}/archive

# 
LINE_NO=`grep -n "return" \
   ${NGINX_SITES_AVAILABLE_PATH}/${REAL_DOMAIN} | cut -d: -f1 | head -1`

LINE_CONTENT="return   301 https://\$host\$request_uri;"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NGINX_SITES_AVAILABLE_PATH}/${REAL_DOMAIN}

# 
LINE_NO=`grep -n "access_log" \
   ${NGINX_SITES_AVAILABLE_PATH}/${REAL_DOMAIN} | cut -d: -f1 | head -1`

LINE_CONTENT="#  access_log   ${NGINX_ACCESS_LOG_PATH}/main_access.log;"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NGINX_SITES_AVAILABLE_PATH}/${REAL_DOMAIN}

# REAL_DOMAIN 운영 도메인 : 리버스 프록시 설정
cat >> ${NGINX_SITES_AVAILABLE_PATH}/${REAL_DOMAIN} \
<<EOF
# 
# HTTPS server
# 
server {
   listen       443 ssl default_server;
   listen       [::]:443 ssl default_server;

   server_name  ${REAL_DOMAIN} www.${REAL_DOMAIN};
   charset      utf-8;

   access_log   ${NGINX_ACCESS_LOG_PATH}/main_access.log;

   # allow large uploads of files
   client_max_body_size 1G;
   
   # optimize downloading files larger than 1G
   # proxy_max_temp_file_size 2G;

   ssl_certificate     ${LETS_ENCRYPT_INSTALL_PATH}/live/${REAL_DOMAIN}/fullchain.pem;
   ssl_certificate_key ${LETS_ENCRYPT_INSTALL_PATH}/live/${REAL_DOMAIN}/privkey.pem;

   ssl  on;
   ssl_session_timeout  5m;
   ssl_protocols        TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
   ssl_ciphers          ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
   ssl_ecdh_curve       secp384r1;
   ssl_session_cache    shared:SSL:1m;
   ssl_prefer_server_ciphers   on;
   ssl_stapling                on;
   ssl_stapling_verify         on;


   location / {
      proxy_pass         http://127.0.0.1:${TOMCAT_PORT};

      proxy_set_header   Host \$host;
      proxy_set_header   X-Real-IP \$remote_addr;
      proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto "https";
      # proxy_pass_header  Server;
   }

}
EOF

##############################################################################

# DEV_DOMAIN 개발 도메인 인증
docker run -it --rm --name certbot \
   -v "${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN}:/var/www" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}:/etc/letsencrypt" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}/lib:/var/lib/letsencrypt" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}/log:/var/log/letsencrypt" \
   certbot/certbot certonly --webroot \
   --webroot-path /var/www \
   -d ${DEV_DOMAIN} \
   --agree-tos \
   --manual-public-ip-logging-ok \
   --email ${LETS_ENCRYPT_EMAIL} \
   --no-eff-email

chmod 701 ${LETS_ENCRYPT_INSTALL_PATH}/live
chmod 604 ${LETS_ENCRYPT_INSTALL_PATH}/archive/${DEV_DOMAIN}/privkey1.pem
chmod 701 ${LETS_ENCRYPT_INSTALL_PATH}/archive

# 
LINE_NO=`grep -n "return" \
   ${NGINX_SITES_AVAILABLE_PATH}/${DEV_DOMAIN} | cut -d: -f1 | head -1`

LINE_CONTENT="return   301 https://\$host\$request_uri;"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NGINX_SITES_AVAILABLE_PATH}/${DEV_DOMAIN}

# 
LINE_NO=`grep -n "access_log" \
   ${NGINX_SITES_AVAILABLE_PATH}/${DEV_DOMAIN} | cut -d: -f1 | head -1`

LINE_CONTENT="#  access_log   ${NGINX_ACCESS_LOG_PATH}/${DEV_DOMAIN_PREFIX}_access.log;"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NGINX_SITES_AVAILABLE_PATH}/${DEV_DOMAIN}

# DEV_DOMAIN 개발 도메인 : 리버스 프록시 설정
cat >> ${NGINX_SITES_AVAILABLE_PATH}/${DEV_DOMAIN} \
<<EOF
# https://help.sonatype.com/repomanager3/installation/run-behind-a-reverse-proxy

server {
   listen       443 ssl;
   listen       [::]:443 ssl;

   server_name  ${DEV_DOMAIN};
   charset      utf-8;

   access_log   ${NGINX_ACCESS_LOG_PATH}/${DEV_DOMAIN_PREFIX}_access.log;

   # allow large uploads of files
   client_max_body_size 1G;
   
   # optimize downloading files larger than 1G
   # proxy_max_temp_file_size 2G;


   ssl_certificate     ${LETS_ENCRYPT_INSTALL_PATH}/live/${DEV_DOMAIN}/fullchain.pem;
   ssl_certificate_key ${LETS_ENCRYPT_INSTALL_PATH}/live/${DEV_DOMAIN}/privkey.pem;

   ssl  on;
   ssl_session_timeout  5m;
   ssl_protocols        TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
   ssl_ciphers          ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
   ssl_ecdh_curve       secp384r1;
   ssl_session_cache    shared:SSL:1m;
   ssl_prefer_server_ciphers  on;
   ssl_stapling               on;
   ssl_stapling_verify        on;

   location / {
      proxy_pass         http://127.0.0.1:${DEV_SERVER_LOCAL_PORT};
 
      proxy_set_header   Host \$host;
      proxy_set_header   X-Real-IP \$remote_addr;
      proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto "https";
      # proxy_pass_header  Server;
   }
}
EOF


##############################################################################

# WEBDAV_DOMAIN 도메인 인증
docker run -it --rm --name certbot \
   -v "${NGINX_WEBDAV_MAIN_PATH}:/var/www" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}:/etc/letsencrypt" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}/lib:/var/lib/letsencrypt" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}/log:/var/log/letsencrypt" \
   certbot/certbot certonly --webroot \
   --webroot-path /var/www \
   -d ${WEBDAV_DOMAIN} \
   --agree-tos \
   --manual-public-ip-logging-ok \
   --email ${LETS_ENCRYPT_EMAIL} \
   --no-eff-email

chmod 701 ${LETS_ENCRYPT_INSTALL_PATH}/live
chmod 604 ${LETS_ENCRYPT_INSTALL_PATH}/archive/${WEBDAV_DOMAIN}/privkey1.pem
chmod 701 ${LETS_ENCRYPT_INSTALL_PATH}/archive

# 
LINE_NO=`grep -n "return" \
   ${NGINX_SITES_AVAILABLE_PATH}/${WEBDAV_DOMAIN} | cut -d: -f1 | head -1`

LINE_CONTENT="return   301 https://\$host\$request_uri;"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NGINX_SITES_AVAILABLE_PATH}/${WEBDAV_DOMAIN}

# 
# LINE_NO=`grep -n "access_log" \
#    ${NGINX_SITES_AVAILABLE_PATH}/${WEBDAV_DOMAIN} | cut -d: -f1 | head -1`

# LINE_CONTENT="#  access_log   ${NGINX_ACCESS_LOG_PATH}/${WEBDAV_DOMAIN_PREFIX}_access.log;"

# sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
#    ${NGINX_SITES_AVAILABLE_PATH}/${WEBDAV_DOMAIN}

# WEBDAV_DOMAIN 도메인 : 리버스 프록시 설정
cat >> ${NGINX_SITES_AVAILABLE_PATH}/${WEBDAV_DOMAIN} \
<<EOF
# https://help.sonatype.com/repomanager3/installation/run-behind-a-reverse-proxy

server {
   listen       443 ssl;
   listen       [::]:443 ssl;

   server_name  ${WEBDAV_DOMAIN};
   charset      utf-8;

   # allow large uploads of files
   client_max_body_size 1G;
   
   # optimize downloading files larger than 1G
   # proxy_max_temp_file_size 2G;
   # Disable gzip to avoid the removal of the ETag header
   gzip off;

   ssl_certificate     ${LETS_ENCRYPT_INSTALL_PATH}/live/${WEBDAV_DOMAIN}/fullchain.pem;
   ssl_certificate_key ${LETS_ENCRYPT_INSTALL_PATH}/live/${WEBDAV_DOMAIN}/privkey.pem;

   ssl  on;
   ssl_session_timeout  5m;
   ssl_protocols        TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
   ssl_ciphers          ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
   ssl_ecdh_curve       secp384r1;
   ssl_session_cache    shared:SSL:1m;
   ssl_prefer_server_ciphers  on;
   ssl_stapling               on;
   ssl_stapling_verify        on;

   dav_methods            PUT DELETE MKCOL COPY MOVE;
   dav_ext_methods        PROPFIND OPTIONS;
   dav_access             user:rw group:rw all:r;
   autoindex              on;

   client_body_temp_path  ${NGINX_WEBDAV_CLIENT_BODY_TEMP_PATH};
   create_full_put_path   on;
   client_max_body_size   0;

   location / {
      access_log             ${NGINX_ACCESS_LOG_PATH}/${WEBDAV_DOMAIN_PREFIX}_access.log;
      root                   ${NGINX_WEBDAV_MAIN_PATH};   # WEBDAV 메인 디렉토리        
      auth_basic             "WEBDAV Access";
      auth_basic_user_file   ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_WEBDAV_PASSWD_LIST_NAME};
   }

   location /${NGINX_WEBAPPS_REPO_URL}  {
      access_log             ${NGINX_ACCESS_LOG_PATH}/${WEBDAV_DOMAIN_PREFIX}_${NGINX_WEBAPPS_REPO_URL}_access.log;
      root                   ${STATIC_FILE_MAIN_PATH}/${TOMCAT_WEBAPPS_LINK_NAME};   # webapps 링크 디렉토리        
      auth_basic             "WEBAPPS Access";
      auth_basic_user_file   ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_WEBAPPS_PASSWD_LIST_NAME};
   }

   location /${NGINX_DEV_REPO_URL}  {
      access_log             ${NGINX_ACCESS_LOG_PATH}/${WEBDAV_DOMAIN_PREFIX}_${NGINX_DEV_REPO_URL}_access.log;
      root                   ${NGINX_STORE_MAIN_PATH}/${DEV_DOMAIN};   # DEV-REPO 디렉토리        
      auth_basic             "DEV-REPO Access";
      auth_basic_user_file   ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_DEV_REPO_PASSWD_LIST_NAME};
   }

   location /${NGINX_REAL_REPO_URL} {
      access_log             ${NGINX_ACCESS_LOG_PATH}/${WEBDAV_DOMAIN_PREFIX}_${NGINX_REAL_REPO_URL}_access.log;
      root                   ${NGINX_STORE_MAIN_PATH}/${REAL_DOMAIN};   # REAL-REPO 디렉토리        
      auth_basic             "REAL-REPO Access";
      auth_basic_user_file   ${NGINX_WEBDAV_PASSWD_LIST_PATH}/${NGINX_REAL_REPO_PASSWD_LIST_NAME};
   }

}
EOF

##############################################################################

# NEXUS_DOMAIN 넥서스 도메인 인증
docker run -it --rm --name certbot \
   -v "${NGINX_PATH}/html:/var/www" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}:/etc/letsencrypt" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}/lib:/var/lib/letsencrypt" \
   -v "${LETS_ENCRYPT_INSTALL_PATH}/log:/var/log/letsencrypt" \
   certbot/certbot certonly --webroot \
   --webroot-path /var/www \
   -d ${NEXUS_DOMAIN} \
   --agree-tos \
   --manual-public-ip-logging-ok \
   --email ${LETS_ENCRYPT_EMAIL} \
   --no-eff-email

chmod 701 ${LETS_ENCRYPT_INSTALL_PATH}/live
chmod 604 ${LETS_ENCRYPT_INSTALL_PATH}/archive/${NEXUS_DOMAIN}/privkey1.pem
chmod 701 ${LETS_ENCRYPT_INSTALL_PATH}/archive

# 
LINE_NO=`grep -n "return" \
   ${NGINX_SITES_AVAILABLE_PATH}/${NEXUS_DOMAIN} | cut -d: -f1 | head -1`

LINE_CONTENT="return   301 https://\$host\$request_uri;"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NGINX_SITES_AVAILABLE_PATH}/${NEXUS_DOMAIN}

# 
LINE_NO=`grep -n "access_log" \
   ${NGINX_SITES_AVAILABLE_PATH}/${NEXUS_DOMAIN} | cut -d: -f1 | head -1`

LINE_CONTENT="#  access_log   ${NGINX_ACCESS_LOG_PATH}/${NEXUS_DOMAIN_PREFIX}_access.log;"

sed -i "${LINE_NO}s@.*@${LINE_CONTENT}@" \
   ${NGINX_SITES_AVAILABLE_PATH}/${NEXUS_DOMAIN}

# NEXUS_DOMAIN  넥서스 도메인 : 리버스 프록시 설정
cat >> ${NGINX_SITES_AVAILABLE_PATH}/${NEXUS_DOMAIN} \
<<EOF
# https://help.sonatype.com/repomanager3/installation/run-behind-a-reverse-proxy

server {
   listen       443 ssl;
   listen       [::]:443 ssl;

   server_name  ${NEXUS_DOMAIN};
   charset      utf-8;

   access_log   ${NGINX_ACCESS_LOG_PATH}/${NEXUS_DOMAIN_PREFIX}_access.log;

   proxy_send_timeout  120;
   proxy_read_timeout  300;
   proxy_buffering     off;
   keepalive_timeout   5 5;
   tcp_nodelay         on;

   # allow large uploads of files
   client_max_body_size  1G;
  
   # optimize downloading files larger than 1G
   # proxy_max_temp_file_size  2G;

   ssl_certificate     ${LETS_ENCRYPT_INSTALL_PATH}/live/${NEXUS_DOMAIN}/fullchain.pem;
   ssl_certificate_key ${LETS_ENCRYPT_INSTALL_PATH}/live/${NEXUS_DOMAIN}/privkey.pem;

   ssl  on;
   ssl_session_timeout  5m;
   ssl_protocols        TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
   ssl_ciphers          ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;
   ssl_ecdh_curve       secp384r1;
   ssl_session_cache    shared:SSL:1m;
   ssl_prefer_server_ciphers  on;
   ssl_stapling               on;
   ssl_stapling_verify        on;

   location / {
      proxy_pass         http://127.0.0.1:${NEXUS_PORT};
 
      proxy_set_header   Host \$host;
      proxy_set_header   X-Real-IP \$remote_addr;
      proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto "https";
      # proxy_pass_header  Server;
   }
}
EOF

##############################################################################

# manual 방식으로 와일드카드 도메인 인증

# docker run -it --rm --name certbot \
#    -v "/etc/letsencrypt:/etc/letsencrypt" \
#    -v "/var/lib/letsencrypt:/var/lib/letsencrypt" \
#    -v "/var/log/letsencrypt:/var/log/letsencrypt" \
#    certbot/certbot certonly --manual \
#    -d jhpark.ml \
#    -d *.jhpark.ml \
#    --preferred-challenges dns \
#    --server https://acme-v02.api.letsencrypt.org/directory \
#    --agree-tos \
#    --manual-public-ip-logging-ok \
#    --email reverse32@naver.com \
#    --no-eff-email

##############################################################################

# 기존 .bash_profile 백업
mv /home/${NEW_USER}/.bash_profile \
   /home/${NEW_USER}/.bash_profile_origin

cat > /home/${NEW_USER}/.bash_profile \
<<EOF
# 사용자 .bash_profile 수정

# .bashrc 실행 스크립트
if [ -f ~/.bashrc ]; then
   . ~/.bashrc
fi

# 사용자 JAVA_HOME 환경변수 추가 : OPENJDK_LINK_PATH 심볼릭 링크로 연결
export JAVA_HOME=${OPENJDK_LINK_PATH}

# 사용자 MAVEN_HOME 환경변수 추가
export MAVEN_HOME=${BUILD_MAIN_PATH}/${MAVEN_INSTALL_DIRECTORY_NAME}

# 사용자 GRADLE_HOME 환경변수 추가
export GRADLE_HOME=${DEPENDENCY_MAIN_PATH}/${GRADLE_REPOSITORY_DIRECTORY_NAME}

# 사용자 GIT_HOME 환경변수 추가
export GIT_HOME=${GIT_MAIN_PATH}/${GIT_INSTALL_DIRECTORY_NAME}

# 사용자 MARIADB_BASE 환경변수 추가
export MARIADB_BASE=${MARIA_DB_INSTALL_PATH}

# 사용자 REDIS_BASE 환경변수 추가
export REDIS_BASE=${REDIS_INSTALL_PATH}

# 사용자 CATALINA_HOME 환경변수 추가 : tomcat 설치 경로 
export CATALINA_HOME=${TOMCAT_INSTALL_PATH}

# 사용자 NODEJS_HOME 환경변수 추가 : node.js 설치 경로 
export NODEJS_HOME=${NODEJS_INSTALL_PATH}

# 사용자 CLASSPATH 환경변수 추가
CLASSPATH=.:\$JAVA_HOME/lib
CLASSPATH=\$CLASSPATH:\$JAVA_HOME/jre/lib
CLASSPATH=\$CLASSPATH:\$JAVA_HOME/jre/lib/ext
CLASSPATH=\$CLASSPATH:\$CATALINA_HOME/lib
CLASSPATH=\$CLASSPATH:\$NODEJS_HOME/lib
CLASSPATH=\$CLASSPATH:\$NODEJS_HOME/lib/node_modules
export CLASSPATH

# 사용자 PATH 환경변수 추가
PATH=\$PATH:\$HOME/.local/bin:\$HOME/bin
PATH=\$PATH:\$GIT_HOME/bin
PATH=\$PATH:\$JAVA_HOME/bin
PATH=\$PATH:\$MAVEN_HOME/bin
PATH=\$PATH:${BUILD_MAIN_PATH}/${GRADLE_INSTALL_DIRECTORY_NAME}/bin
PATH=\$PATH:\$MARIADB_BASE/bin
PATH=\$PATH:\$REDIS_BASE/bin
PATH=\$PATH:\$NODEJS_HOME/bin
PATH=\$PATH:\$CATALINA_HOME/bin
PATH=\$PATH:${NGINX_SBIN_PATH}
export PATH

EOF

chown -R ${NEW_USER}:${NEW_GROUP} \
   /home/${NEW_USER}/.bash_profile

source /home/${NEW_USER}/.bash_profile

##############################################################################

# 초기화
yum update -y && \
   yum upgrade && \
   yum clean all && \
   rm -rf /var/cache/yum/* 
#   \ rm -rf ${TEMP_PATH}/*

# 개발환경 디렉토리의 소유자/그룹 일괄 변경
chown -R ${NEW_USER}:${NEW_GROUP} \
   ${DEV_TOOLS_PATH}

# 사용자 home 디렉토리의 bin 소유자/그룹 일괄 변경
chown -R ${NEW_USER}:${NEW_GROUP} \
   /home/${NEW_USER}/bin

# 
chown -R ${NGINX_USER}:${SERVER_USER_GROUP} \
   ${SERVER_MAIN_PATH}/${NGINX_INSTALL_DIRECTORY_NAME}

# 
chown -R ${NGINX_USER}:${NGINX_USER_GROUP} \
   ${NGINX_WEBDAV_MAIN_PATH}

chown -R ${NGINX_USER}:${NGINX_USER_GROUP} \
   ${NGINX_WEBDAV_CLIENT_BODY_TEMP_PATH}

# reboot
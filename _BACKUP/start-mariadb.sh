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

MAIN_DOMAIN=jhpark.gq

NEXUS_DOMAIN_PREFIX=nexus
NEXUS_DOMAIN=${NEXUS_DOMAIN_PREFIX}.${MAIN_DOMAIN}

DEV_DOMAIN_PREFIX=dev
DEV_DOMAIN=${DEV_DOMAIN_PREFIX}.${MAIN_DOMAIN}

WEBDAV_DOMAIN_PREFIX=webdav
WEBDAV_DOMAIN=${WEBDAV_DOMAIN_PREFIX}.${MAIN_DOMAIN}

REAL_SERVER_LOCAL_PORT=8080
DEV_SERVER_LOCAL_PORT=8081
NEXUS_SERVER_LOCAL_PORT=8090

DOCKER_GROUP_ID=1205

# 설치시 사용할 임시 작업 디렉토리 경로
WORK_DIR=/tmp

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
DEV_TOOLS_PATH=/dev_tools        # NEW_USER : NEW_USER_GROUO 소유

DATABASE_MAIN_PATH=/dev_db       # NEW_USER : DB_USER_GROUP 소유
                                 # 디렉토리 내에서 다시 소유자 달라짐

LIBRARY_MAIN_PATH=/dev_lib       # NEW_USER : NEW_USER_GROUO 소유
                                 # 다른 사용자 읽기/실행 가능

SERVER_MAIN_PATH=/dev_server     # NEW_USER : SERVER_USER_GROUP 소유
                                 # 디렉토리 내에서 다시 소유자 달라짐

REPOSITORY_MAIN_PATH=/dev_repo   # NEW_USER : NGINX_USER_GROUP 소유

mkdir -p ${DEV_TOOLS_PATH}
mkdir -p ${DATABASE_MAIN_PATH}
mkdir -p ${LIBRARY_MAIN_PATH}
mkdir -p ${SERVER_MAIN_PATH}
mkdir -p ${REPOSITORY_MAIN_PATH}

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
chown -R ${NEW_USER}:${NGINX_USER_GROUP} ${REPOSITORY_MAIN_PATH}

# LIBRARY_MAIN_PATH 는 모든 사용자가 읽기/실행 가능, 단 쓰기는 소유자만 가능
chmod 755 ${LIBRARY_MAIN_PATH}

##############################################################################

# 임시 작업 디렉토리로 이동
cd ${WORK_DIR}

# 기존 시간대 설정 파일 백업 / 시간대 변경
# mv /etc/localtime /etc/localtime_org && \
# ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/epel-release.rpm && \
rpm -ivh ${WORK_DIR}/epel-release.rpm

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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/firefox.tar.bz2 && \
tar -jxf ${WORK_DIR}/firefox.tar.bz2 \
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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/rclone.zip && \
unzip ${WORK_DIR}/rclone.zip && \
mv ${WORK_DIR}/$( ls ${WORK_DIR} | grep rclone- )/* \
   ${RCLONE_INSTALL_PATH}

# rclone 심볼릭 링크를 사용자 bin 디렉토리에 추가
ln -s ${RCLONE_INSTALL_PATH}/rclone \
   /home/${NEW_USER}/bin/rclone

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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/git.tar.gz && \
tar -zxf ${WORK_DIR}/git.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep git-) \
   ${WORK_DIR}/git \
   ${WORK_DIR}/git-*

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
#     -P "${WORK_DIR}" \
#     -O "${WORK_DIR}/git-release.rpm" && \
# rpm -ivh \
#     ${WORK_DIR}/git-release.rpm && \
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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/docker-ce.rpm && \
wget ${DOCKER_CE_CLI_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/docker-ce-cli.rpm && \
wget ${CONTAINEDR_IO_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/containerd.io.rpm

yum localinstall -y \
   ${WORK_DIR}/docker-ce.rpm \
   ${WORK_DIR}/docker-ce-cli.rpm \
   ${WORK_DIR}/containerd.io.rpm

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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/jdk1.8.tar.gz && \
tar -zxf ${WORK_DIR}/jdk1.8.tar.gz \
   -C ${OPENJDK_8_JAVA_HOME_PATH} \
   --strip-components 1

# OPENJDK 1.11 다운로드 / OPENJDK_11_JAVA_HOME_PATH 에 설치
wget ${OPENJDK_11_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/jdk1.11.tar.gz && \
tar -zxf ${WORK_DIR}/jdk1.11.tar.gz \
   -C ${OPENJDK_11_JAVA_HOME_PATH} \
   --strip-components 1

# OPENJDK 1.12 다운로드 / OPENJDK_12_JAVA_HOME_PATH 에 설치
wget ${OPENJDK_12_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/jdk1.12.tar.gz && \
tar -zxf ${WORK_DIR}/jdk1.12.tar.gz \
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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/sts.tar.gz && \
tar -zxf ${WORK_DIR}/sts.tar.gz \
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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/lombok.jar && \

${OPENJDK_LINK_PATH}/bin/java -jar \
   ${WORK_DIR}/lombok.jar install \
   ${STS_INSTALL_PATH}/SpringToolSuite4.ini

##############################################################################

# Visual Studio Code 설치

# Visual Studio Code 다운로드 경로 : 2019-05 (version 1.35.1)
VSCODE_DOWNLOAD_URL=https://update.code.visualstudio.com/1.35.1/linux-x64/stable

wget ${VSCODE_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/vscode.tar.gz && \
mkdir -p ${DEV_TOOLS_PATH}/VSCODE && \
tar -zxf ${WORK_DIR}/vscode.tar.gz \
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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/intellij.tar.gz && \
mkdir -p ${DEV_TOOLS_PATH}/INTELLI_J && \
tar -zxf ${WORK_DIR}/intellij.tar.gz \
   -C ${DEV_TOOLS_PATH}/INTELLI_J \
   --strip-components 1

##############################################################################

# DBeaver 커뮤니티 버전 설치

# DBeaver 커뮤니티 버전 다운로드 경로 : dbeaver-ce-6.1.0 ( 2019-06-10 )
DBEAVER_DOWNLOAD_URL=https://github.com/dbeaver/dbeaver/releases/download/6.1.0/dbeaver-ce-6.1.0-linux.gtk.x86_64.tar.gz

wget ${DBEAVER_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/dbeaver.tar.gz && \
mkdir -p ${DEV_TOOLS_PATH}/DBEAVER-ce && \
tar -zxf ${WORK_DIR}/dbeaver.tar.gz \
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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/maven.tar.gz && \
tar -zxf ${WORK_DIR}/maven.tar.gz \
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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/gradle.zip && \
unzip ${WORK_DIR}/gradle.zip && \
mv ${WORK_DIR}/$(ls ${WORK_DIR} | grep gradle-)/* \
   ${GRADLE_INSTALL_PATH}

##############################################################################

# 마리아 DB 설치

# 참조 URL 
# https://xinet.kr/?p=1279
# http://coolx.net/m/cboard/read.jsp?db=develop&mode=read&num=798&_currPage=1&listCnt=20&category=-1&fval=
# https://xinet.kr/?p=307
# https://algo79.tistory.com/entry/MySQL-%EC%97%90%EB%9F%AC
# https://gist.github.com/Mins/4602864

# MaraiDB Binary 다운로드 경로 : 10.3.18 ( 2019-10-17 )
MARIA_DB_DOWNLOAD_URL=https://downloads.mariadb.com/MariaDB/mariadb-10.3.18/bintar-linux-x86_64/mariadb-10.3.18-linux-x86_64.tar.gz

# MARIADB_USER 생성
useradd ${MARIADB_USER} \
   --shell /sbin/nologin \
   --no-create-home

# DB_USER_GROUP 에 MARIADB_USER 추가
usermod -aG ${DB_USER_GROUP} ${MARIADB_USER}

# 마리아DB 데이터베이스 관리자 계정 정보
NEW_DB_ADMIN_USER=dev_daou
NEW_DB_ADMIN_USER_PASSWORD=dev1234!@#$

# 마리아DB 데이터베이스 root 계정 암호
ROOT_USER_PASSWORD=dev1234!@#$

# 마리아DB 설치 / 디렉토리 이름
MARIA_DB_INSTALL_DIRECTORY_NAME=mariaDB-MASTER
MARIA_DB_DATA_DIRECTORY_NAME=mariaDB-MASTER-data
MARIA_DB_LOG_DIRECTORY_NAME=mariaDB-MASTER-log
MARIA_DB_TEMP_DIRECTORY_NAME=mariaDB-MASTER-tmp

MARIA_DB_INSTALL_PATH=${DATABASE_MAIN_PATH}/${MARIA_DB_INSTALL_DIRECTORY_NAME}
MARIA_DB_DATA_PATH=${DATABASE_MAIN_PATH}/${MARIA_DB_DATA_DIRECTORY_NAME}
MARIA_DB_LOG_PATH=${MARIA_DB_INSTALL_PATH}/${MARIA_DB_LOG_DIRECTORY_NAME}
MARIA_DB_WORK_DIR=${MARIA_DB_INSTALL_PATH}/${MARIA_DB_TEMP_DIRECTORY_NAME}

mkdir -p ${MARIA_DB_INSTALL_PATH}
mkdir -p ${MARIA_DB_DATA_PATH}
mkdir -p ${MARIA_DB_LOG_PATH}
mkdir -p ${MARIA_DB_WORK_DIR}

wget ${MARIA_DB_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/mariadb-binary.tar.gz

tar -zxf ${WORK_DIR}/$(ls ${WORK_DIR} | grep mariadb-) \
   -C ${MARIA_DB_INSTALL_PATH} \
   --strip-components 1

rm -rf /etc/my.cnf

cat > ${MARIA_DB_INSTALL_PATH}/data/my.cnf \
<<EOF
[client-server]
[mysqld]
user = ${MARIADB_USER}
core-file
port = 3300
basedir = ${MARIA_DB_INSTALL_PATH}
datadir = ${MARIA_DB_DATA_PATH}
tmpdir = ${MARIA_DB_WORK_DIR}
socket = ${MARIA_DB_WORK_DIR}/mysqld.sock
pid-file = ${MARIA_DB_WORK_DIR}/mysqld.pid
log-error = ${MARIA_DB_LOG_PATH}/error.log
# log = ${MARIA_DB_LOG_PATH}/query.log
default_storage_engine='InnoDB'
sysdate-is-now
skip-character-set-client-handshake
character_set_server = utf8mb4
collation_server = utf8mb4_bin
init_connect='SET collation_connection = utf8mb4_bin'
init_connect='SET NAMES utf8mb4'

# https://zetawiki.com/wiki/MySQL_%EC%84%A4%EC%A0%95%ED%8C%8C%EC%9D%BC_my.cnf
max_connections=100
wait_timeout=200
interactive_timeout=200

[mysql]
default-character-set = 'utf8mb4'
no-auto-rehash
local-infile = ON
enable-secure-auth
prompt=(\U){\h}[\d]\_\R:\m:\\s>\_
pager=less -n -i -F -X -E
show-warnings

[client]
port   = 3300
socket = ${MARIA_DB_WORK_DIR}/mysqld.sock
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
   -S ${MARIA_DB_WORK_DIR}/mysqld.sock \
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
PIDFile=${MARIA_DB_WORK_DIR}/mysqld.pid
TimeoutStartSec=0
TimeoutStopSec=0
ExecStart=${MARIA_DB_INSTALL_PATH}/bin/mysqld_safe --defaults-file=${MARIA_DB_INSTALL_PATH}/data/my.cnf --user=${MARIADB_USER}
ExecStop=${MARIA_DB_INSTALL_PATH}/bin/mysqladmin -S ${MARIA_DB_WORK_DIR}/mysqld.sock -uroot -p shutdown

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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/redis.tar.gz && \
tar -zxf ${WORK_DIR}/redis.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep redis-) \
   ${WORK_DIR}/redis \
   ${WORK_DIR}/redis-*

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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/nodejs.tar.gz && \
tar -xf ${WORK_DIR}/nodejs.tar.gz \
   -C ${NODEJS_INSTALL_PATH} \
   --strip-components 1

chown -R ${NODEJS_USER}:${SERVER_USER_GROUP} ${NODEJS_INSTALL_PATH}

# export PATH=\$PATH:${NODEJS_INSTALL_PATH}/bin

# runuser -l ${NEW_USER} \
#    -c '${NODEJS_INSTALL_PATH}/bin/npm config set prefix ${NPM_REPOSITORY_PATH}'

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
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/openssl.tar.gz && \
tar -zxf ${WORK_DIR}/openssl.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep openssl-) \
   ${WORK_DIR}/openssl \
   ${WORK_DIR}/openssl-*

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

wget ${PCRE_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/pcre.tar.gz && \
tar -zxf ${WORK_DIR}/pcre.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep pcre-) \
   ${WORK_DIR}/pcre \
   ${WORK_DIR}/pcre-*

# cd pcre

# ./configure \
#     --prefix=/usr/local

# make
# make install
# 
# cd ..

##############################################################################

# zlib 컴파일 버전 다운로드 ( NGINX Dependencies : openssl, PCRE, ZLIB )

# ZLIB 다운로드 경로 : 1.2.11 ( 2017-01-15 )
ZLIB_DOWNLOAD_URL=http://zlib.net/zlib-1.2.11.tar.gz

wget ${ZLIB_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/zlib.tar.gz && \
tar -zxf ${WORK_DIR}/zlib.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep zlib-) \
   ${WORK_DIR}/zlib \
   ${WORK_DIR}/zlib-*

# cd zlib

# ./configure \
#    --prefix=/usr/local

# make
# make install

# cd ..

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
export CATALINA_HOME=${TOMCAT_PATH}

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
#   \ rm -rf ${WORK_DIR}/*

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
   ${NGINX_WEBDAV_CLIENT_BODY_WORK_DIR}

# reboot
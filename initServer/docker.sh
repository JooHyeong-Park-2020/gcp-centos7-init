#!/bin/bash

# CENTOS 서버 세팅 정보 load
source ${WORK_DIR}/settingInfo.sh


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

# 기존 Docker 제거 : yum 설치 패키지, 리포지터리 정보 제거
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
   docker-ce

rm -rf /var/lib/docker

rm -rf /etc/yum.repos.d/docker-ce.repo

wget ${CONTAINEDR_SELINUX_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/container-selinux.rpm && \
wget ${DOCKER_CE_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/docker-ce.rpm && \
wget ${DOCKER_CE_CLI_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/docker-ce-cli.rpm && \
wget ${CONTAINEDR_IO_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/containerd.io.rpm

# 도커 설치 전 의존 패키지 먼저 설치
rpm -Uvh \
   ${WORK_DIR}/container-selinux.rpm

# 도커 설치
rpm -Uvh \
   ${WORK_DIR}/docker-ce.rpm \
   ${WORK_DIR}/docker-ce-cli.rpm \
   ${WORK_DIR}/containerd.io.rpm

# docker 그룹 추가 : 도커 설치시 자동으로 추가됨
# groupadd docker

# docker 그룹의 gid 를 ${DOCKER_GROUP_ID} 로 변경
groupmod -g ${DOCKER_GROUP_ID} docker

# docker 그룹에 사용자 추가
usermod -aG docker ${NEW_USER}

systemctl enable docker && \
systemctl start docker

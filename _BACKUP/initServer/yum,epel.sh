#!/bin/bash

# CENTOS 서버 세팅 정보 load
source ${WORK_DIR}/${SETTING_INFO}.sh


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

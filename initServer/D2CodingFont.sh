#!/bin/bash

# CENTOS 서버 세팅 정보 load
source ${WORK_DIR}/settingInfo.sh


##############################################################################

# D2Coding 폰트 설치

# D2Codion 폰트 다운로드 경로
D2CODING_FONT_DOWNLOAD_URL=https://github.com/naver/d2codingfont/releases/download/VER1.3.2/D2Coding-Ver1.3.2-20180524.zip

wget ${D2CODING_FONT_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/D2Coding.zip

mkdir -p ${WORK_DIR}/D2Coding

unzip ${WORK_DIR}/D2Coding.zip \
   -d ${WORK_DIR}/D2Coding

mkdir -p /usr/share/fonts/D2Coding

cp ${WORK_DIR}/D2Coding/D2Coding/* \
   /usr/share/fonts/D2Coding

fc-cache -f -v
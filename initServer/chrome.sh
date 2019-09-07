#!/bin/bash

# CENTOS 서버 세팅 정보 load
source ${WORK_DIR}/${SETTING_INFO}.sh


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
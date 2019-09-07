#!/bin/bash

# CENTOS 서버 세팅 정보 load
source ${WORK_DIR}/${SETTING_INFO}.sh


##############################################################################

# RDP 관련 패키지 설치 : tigervnc, xrdp, supervisor
# RDP 관련 한글 입력 패키지 설치
# RDP 관련 그룹 패키지 설치 : X Window Systemw, Xfce

yum install -y \
   tigervnc-server \
   xrdp \
   supervisor \
   ibus \
   ibus-hangul \
   ibus-anthy \
   im-chooser

yum groupinstall -y \
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

firewall-cmd \
    --permanent \
    --zone=public \
    --add-port=${RDP_CONNECTION_PORT}/tcp && \
firewall-cmd --reload

# xrdp 서비스 등록
systemctl enable xrdp.service && \
systemctl start xrdp.service

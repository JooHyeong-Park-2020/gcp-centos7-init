#!/bin/bash

# CENTOS 서버 세팅 정보 load
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


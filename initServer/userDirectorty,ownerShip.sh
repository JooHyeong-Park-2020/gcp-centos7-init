#!/bin/bash

# CENTOS 서버 세팅 정보 load / 작업 디렉토리로 이동
# source ${TEMP_PATH}/${SETTING_INFO}.sh


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

#!/bin/bash

# CENTOS 서버 세팅 정보 load
source ${WORK_DIR}/${SETTING_INFO}.sh


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


#!/bin/bash

#################################################################
# 신규 사용자 계정 설정
#################################################################
NEW_GROUP=developer
NEW_GROUP_ID=1200
NEW_USER=dev
NEW_USER_PASSWORD=dev


######################################
# Centos 서버 설정
######################################
# 설치시 사용할 임시 작업 디렉토리 경로
WORK_DIR=/tmp

export WORK_DIR

SSH_CONNECTION_PORT=2435
DOCKER_GROUP_ID=1205


######################################
# 개발환경 디렉토리 설정 : 개발관련 tool
######################################
# 개발환경 디렉토리 경로
DEV_TOOLS_PATH=/${NEW_USER}_tools           # NEW_USER : NEW_USER_GROUO 소유

# 개발환경 디렉토리 내 개발 tool 설치 경로
GIT_MAIN_PATH=${DEV_TOOLS_PATH}/GIT
STS_WORKSPACE_PATH=${DEV_TOOLS_PATH}/WORKSPACE
BUILD_MAIN_PATH=${DEV_TOOLS_PATH}/BUILD
DEPENDENCY_MAIN_PATH=${DEV_TOOLS_PATH}/DEPENDENCY
UTILS_MAIN_PATH=${DEV_TOOLS_PATH}/UTILS

######################################
# DEPENDENCY_MAIN_PATH 내 저장소별 디렉토리 : Maven, Gradle, Npm 설치시 지정
######################################

######################################
# 라이브러리 디렉토리 설정
######################################
# Maven, Gradle, Npm 라이브러리 경로
LIBRARY_MAIN_PATH=/${NEW_USER}_lib          # NEW_USER : NEW_USER_GROUP 소유
                                            # 다른 사용자 읽기/실행 가능


######################################
# Nginx 관련 설정
######################################
NGINX_USER_GROUP=${NEW_USER}_nginx_group
NGINX_USER=${NEW_USER}_nginx

STATIC_FILE_MAIN_PATH=/${NEW_USER}_static   # NEW_USER : NGINX_USER_GROUP 소유


######################################
# 웹서버 관련 설정
######################################
SERVER_USER_GROUP=${NEW_USER}_server_group

TOMCAT_USER=${NEW_USER}_tomcat
NODEJS_USER=${NEW_USER}_nodejs
NEXUS_USER=${NEW_USER}_nexus

SERVER_MAIN_PATH=/${NEW_USER}_server      # NEW_USER : SERVER_USER_GROUP 소유
                                          # 디렉토리 내에서 서버마다 다시 소유자 달라짐


######################################
# 도메인 / 접속 포트 관련 설정
######################################
REAL_DOMAIN=jhpark.gq
REAL_SERVER_LOCAL_PORT=8080

DEV_DOMAIN_PREFIX=dev
DEV_DOMAIN=${DEV_DOMAIN_PREFIX}.${REAL_DOMAIN}
DEV_SERVER_LOCAL_PORT=8081

NEXUS_DOMAIN_PREFIX=nexus
NEXUS_DOMAIN=${NEXUS_DOMAIN_PREFIX}.${REAL_DOMAIN}
NEXUS_SERVER_LOCAL_PORT=8090

WEBDAV_DOMAIN_PREFIX=webdav
WEBDAV_DOMAIN=${WEBDAV_DOMAIN_PREFIX}.${REAL_DOMAIN}


######################################
# 데이터베이스 관련 설정
######################################
DB_USER_GROUP=${NEW_USER}_db_group

MARIADB_USER=${NEW_USER}_mysql
REDIS_USER=${NEW_USER}_redis

NEW_DB_SCHEMA_NAME=demo

DATABASE_MAIN_PATH=/${NEW_USER}_db     # NEW_USER : DB_USER_GROUP 소유
                                       # 디렉토리 내에서 DB 마다 다시 소유자 달라짐

##############################################################################

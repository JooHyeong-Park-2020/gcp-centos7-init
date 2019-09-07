#!/bin/bash

# CENTOS 서버 세팅 정보 down 후 작업 디렉토리에 복사 / 작업 디렉토리로 이동

curl ${GIT_REPO_PATH}/settingInfo/${SETTING_INFO_NAME}.sh \
    > ./${SETTING_INFO_NAME}.sh

cp ./${SETTING_INFO_NAME}.sh ${TEMP_PATH}/${SETTING_INFO_NAME}.sh

source ${TEMP_PATH}/${SETTING_INFO_NAME}.sh

cd ${TEMP_PATH}

# 
workName=initServer

scriptList=( \
    "userDirectorty,ownerShip" \
    "yum,epel" \
    "time,language,libraryPath" \
    "zlib,pcre,openssl" \
    "openssh,sshd_config" \
)

mkdir -p ${TEMP_PATH}/${workName}

curl "${GIT_REPO_PATH}/${workName}/00-${workName}.sh" \
    > ${TEMP_PATH}/${workName}/00-${workName}.sh

chmod 700 ${TEMP_PATH}/${workName}/00-${workName}.sh

${TEMP_PATH}/${workName}/00-${workName}.sh ${workName} "${scriptList[@]}"
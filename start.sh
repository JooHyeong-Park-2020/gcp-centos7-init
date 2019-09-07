#!/bin/bash

# CENTOS 서버 세팅 정보 down 후 작업 디렉토리에 복사 / 작업 디렉토리로 이동

curl ${GIT_REPO_PATH}/settingInfo/${SETTING_INFO_NAME}.sh \
    > ./${SETTING_INFO_NAME}.sh

cp ./${SETTING_INFO_NAME}.sh ${TEMP_PATH}/${SETTING_INFO_NAME}.sh

source ${TEMP_PATH}/${SETTING_INFO_NAME}.sh

cd ${TEMP_PATH}

######################################

SCRIPT_LIST_POSTFIX=_scriptList

for workName in ${workList[@]}; do

    mkdir -p ${TEMP_PATH}/${workName}

    eval scriptList=\( \${${workName}${SCRIPT_LIST_POSTFIX}[@]} \)

    for scriptName in $scriptList; do

        curl ${GIT_REPO_PATH}/${workName}/${scriptName}.sh \
            > ${TEMP_PATH}/${workName}/${scriptName}.sh

        chmod 700 ${TEMP_PATH}/${workName}/${scriptName}.sh

        ${TEMP_PATH}/${workName}/${scriptName}.sh

    done

done

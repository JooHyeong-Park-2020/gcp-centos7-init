#!/bin/bash

# CENTOS 서버 세팅 정보 down 후 작업 디렉토리에 복사 / 작업 디렉토리로 이동

curl ${GIT_REPO_PATH}/${SETTING_INFO_DIRECTORY_PATH}/${SETTING_INFO_NAME}.sh \
    > ./${SETTING_INFO_NAME}.sh

cp ./${SETTING_INFO_NAME}.sh ${WORK_DIR}/${SETTING_INFO_NAME}.sh

source ${WORK_DIR}/${SETTING_INFO_NAME}.sh

cd ${WORK_DIR}

######################################

SCRIPT_LIST_POSTFIX=_scriptList

for workName in ${workList[@]}; do

    mkdir -p ${WORK_DIR}/${workName}

    eval scriptList=\( \${${workName}${SCRIPT_LIST_POSTFIX}[@]} \)

    for scriptName in ${scriptList[@]}; do

        echo "---------"${scriptName}"---------"

        curl ${GIT_REPO_PATH}/${workName}/${scriptName}.sh \
            > ${WORK_DIR}/${workName}/${scriptName}.sh

        chmod 700 ${WORK_DIR}/${workName}/${scriptName}.sh

        ${WORK_DIR}/${workName}/${scriptName}.sh

    done

done

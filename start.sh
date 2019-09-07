#!/bin/bash

# CENTOS 서버 세팅 정보 down 후 작업 디렉토리에 복사 / 작업 디렉토리로 이동

curl ${GIT_REPO_PATH}/settingInfo/${SETTING_INFO_NAME}.sh \
    > ./${SETTING_INFO_NAME}.sh

cp ./${SETTING_INFO_NAME}.sh ${TEMP_PATH}/${SETTING_INFO_NAME}.sh

source ${TEMP_PATH}/${SETTING_INFO_NAME}.sh

cd ${TEMP_PATH}

######################################

executeScript()
{
    local scriptName=$1

    curl ${GIT_REPO_PATH}/${workName}/${scriptName}.sh \
        > ${TEMP_PATH}/${workName}/${scriptName}.sh
    chmod 700 ${TEMP_PATH}/${workName}/${scriptName}.sh
    ${TEMP_PATH}/${workName}/${scriptName}.sh

}

######################################


for workName in ${workList[@]}; do

    echo "--------------"$workName" 실행--------------"
    mkdir -p ${TEMP_PATH}/${workName}

    scriptList="$workName__scriptList"

    for scriptName in $scriptList; do

        echo "-----"$scriptName" 실행-----"
        executeScript $scriptName

    done

done

######################################




# curl "${GIT_REPO_PATH}/${workName}/00-${workName}.sh" \
#     > ${TEMP_PATH}/${workName}/00-${workName}.sh

# chmod 700 ${TEMP_PATH}/${workName}/00-${workName}.sh

# ${TEMP_PATH}/${workName}/00-${workName}.sh ${workName} "${scriptList[@]}"
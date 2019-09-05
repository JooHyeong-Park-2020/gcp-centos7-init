# CENTOS 서버 세팅 정보 load / 작업 디렉토리로 이동

curl ${GIT_REPO_PATH}/settingInfo/${SETTING_INFO_NAME}.sh \
    > ./${SETTING_INFO_NAME}.sh

cp ./${SETTING_INFO_NAME}.sh ${TEMP_PATH}/${SETTING_INFO_NAME}.sh

source ${TEMP_PATH}/${SETTING_INFO_NAME}.sh

cd ${TEMP_PATH}

directoryName=initServer
scriptList=("directorty,ownership" "yum,epel" "time,language,libraryPath")

mkdir -p ${TEMP_PATH}/${directoryName}

curl "${GIT_REPO_PATH}/${directoryName}/00-${directoryName}.sh" \
    > ${TEMP_PATH}/${directoryName}/00-${directoryName}.sh

chmod 700 ${TEMP_PATH}/${directoryName}/00-${directoryName}.sh

${TEMP_PATH}/${directoryName}/00-${directoryName}.sh ${directoryName} "${scriptList[@]}"
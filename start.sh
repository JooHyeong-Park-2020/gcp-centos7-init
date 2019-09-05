# CENTOS 서버 세팅 정보 load / 작업 디렉토리로 이동

curl ${GIT_REPO_PATH}/settingInfo/${SETTING_INFO}.sh \
    > ./${SETTING_INFO}.sh

cp ./${SETTING_INFO}.sh ${TEMP_PATH}/${SETTING_INFO}.sh

source ${TEMP_PATH}/${SETTING_INFO}.sh

cd ${TEMP_PATH}

directoryName=initServer
scriptList=("directorty,ownership" "yum,epel")

mkdir -p ${TEMP_PATH}/${directoryName}

curl "${GIT_REPO_PATH}/${directoryName}/00-${directoryName}.sh" \
    > ${TEMP_PATH}/${directoryName}/00-${directoryName}.sh

chmod 700 ${TEMP_PATH}/${directoryName}/00-${directoryName}.sh

${TEMP_PATH}/${directoryName}/00-${directoryName}.sh ${directoryName} ${scriptList}
# CENTOS 서버 세팅 정보 load / 작업 디렉토리로 이동

GIT_REPO_PATH=https://raw.githubusercontent.com/JooHyeong-Park-2020/gcp-centos7-init/master

curl ${GIT_REPO_PATH}/settingInfo.sh \
    > ./settingInfo.sh

cp ./settingInfo.sh ${TEMP_PATH}/settingInfo.sh

source ${TEMP_PATH}/settingInfo.sh

cd ${TEMP_PATH}

directoryName=centos7-initServer

mkdir -p ${TEMP_PATH}/${directoryName}

curl ${GIT_REPO_PATH}/${directoryName}/0-initServer.sh \
    > ${TEMP_PATH}/${directoryName}/0-initServer.sh

chmod 700 ${TEMP_PATH}/${directoryName}/0-initServer.sh
${TEMP_PATH}/${directoryName}/0-initServer.sh ${GIT_REPO_PATH} ${directoryName}

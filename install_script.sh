export GIT_REPO_PATH=https://raw.githubusercontent.com/JooHyeong-Park-2020/gcp-centos7-init/master && \
export TEMP_PATH=/tmp && \
export SETTING_INFO=settingInfo && \
curl ${GIT_REPO_PATH}/start.sh \
    > start.sh && \
chmod 700 ./start.sh && \
./start.sh
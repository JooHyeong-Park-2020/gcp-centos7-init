#!/bin/bash

# 1. directorty,ownership.sh 
# 2. yum,epel.sh
# 3. time,language,libraryPath.sh
# 4. zlib,pcre,openssl.sh
# 5. openssh,sshPort.sh
# 6. openssh,sshd_config.sh
# 7. 

directoryName=$1

function executeScript()
{
    local gitRepoPath=https://raw.githubusercontent.com/JooHyeong-Park-2020/gcp-centos7-init/master
    local scriptName=$1

    curl ${gitRepoPath}/${directoryName}/${scriptName}.sh \
        > ${TEMP_PATH}/${directoryName}/${scriptName}.sh
    chmod 700 ${TEMP_PATH}/${directoryName}/${scriptName}.sh
    ${TEMP_PATH}/${directoryName}/${scriptName}.sh

}

executeScript "directorty,ownership"
executeScript "yum,epel"


##############################################################################




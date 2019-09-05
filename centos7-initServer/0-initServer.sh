#!/bin/bash

# 1. directorty,ownership.sh 
# 2. yum,epel.sh
# 3. time,language,libraryPath.sh
# 4. zlib,pcre,openssl.sh
# 5. openssh,sshPort.sh
# 6. openssh,sshd_config.sh
# 7. 

directoryName=centos7-initServer

mkdir -p ${TEMP_PATH}/${directoryName}

function executeScript( directoryName, scriptName ){

    local gitRepoPath=https://raw.githubusercontent.com/JooHyeong-Park-2020/gcp-centos7-init/master

    curl ${gitRepoPath}/${directoryName}/${scriptName}.sh \
        >> ${TEMP_PATH}/${directoryName}/${scriptName}.sh
    chmod 700 ${TEMP_PATH}/${directoryName}/${scriptName}.sh
    ${TEMP_PATH}/${directoryName}/${scriptName}.sh

}

executeScript( ${directoryName}, "directorty%2Cownership" )
executeScript( ${directoryName}, "yum%2Cepel" )


##############################################################################




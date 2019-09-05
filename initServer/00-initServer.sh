#!/bin/bash

# 1. directorty,ownership.sh 
# 2. yum,epel.sh
# 3. time,language,libraryPath.sh
# 4. zlib,pcre,openssl.sh
# 5. openssh,sshPort.sh
# 6. openssh,sshd_config.sh
# 7. 

directoryName=$1
scriptList=( "$@" )

function executeScript()
{
    local scriptName=$1

    source ${TEMP_PATH}/${SETTING_INFO_NAME}.sh

    curl ${GIT_REPO_PATH}/${directoryName}/${scriptName}.sh \
        > ${TEMP_PATH}/${directoryName}/${scriptName}.sh
    chmod 700 ${TEMP_PATH}/${directoryName}/${scriptName}.sh
    ${TEMP_PATH}/${directoryName}/${scriptName}.sh

}

for scriptName in ${scriptList[@]}

do

echo "-----"$scriptName" 실행-------"

executeScript $scriptName

done

##############################################################################




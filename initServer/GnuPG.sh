#!/bin/bash

# CENTOS 서버 세팅 정보 load
source ${WORK_DIR}/${SETTING_INFO}.sh


##############################################################################

# https://gnupg.org/download/
# https://gist.github.com/simbo1905/ba3e8af9a45435db6093aea35c6150e8

# GnuPG 의존 라이브러리 설치

# Libgpg-error :  1.36 ( 2019-03-19 )
Libgpg_error_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.36.tar.bz2

# Libgcrypt    :  1.8.4 ( 2018-10-26 )
Libgcrypt_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.8.4.tar.bz2

# Libksba      :  1.3.5	( 2016-08-22 )
Libksba_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/libksba/libksba-1.3.5.tar.bz2

# Libassuan    :  2.5.3 ( 2019-02-11 )
Libassuan_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/libassuan/libassuan-2.5.3.tar.bz2

# ntbTLS       :  0.1.2 ( 2017-09-19 )
ntbTLS_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/ntbtls/ntbtls-0.1.2.tar.bz2

# nPth         :  1.6 ( 2018-07-16 ) 
nPth_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/npth/npth-1.6.tar.bz2

# Pinentry     :  1.1.0 ( 2017-12-03 )
#     a collection of passphrase entry dialogs which is required for almost all usages of GnuPG
Pinentry_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/pinentry/pinentry-1.1.0.tar.bz2


# GnuPG 의존 라이브러리 다운받을 temp 디렉토리 생성
# 이름이 gnupg- 로 시작하면 gunpg 압축 해제시 디렉토리명과 중복됨, 겹치지 않도록 할 것
GNU_PG_TEMP_DOWNLOAD_PATH=${WORK_DIR}/gnupg_temp
mkdir -p ${GNU_PG_TEMP_DOWNLOAD_PATH}

# zlib-devel : ntbTLS 설치시 필요
# ncurses-devel : pinentry 설치시 필요
yum install -y \
   zlib-devel \
   ncurses-devel

wget -c ${Libgpg_error_DOWNLOAD_URL} \
   -O ${GNU_PG_TEMP_DOWNLOAD_PATH}/libgpg-error.tar.bz2
wget -c ${Libgcrypt_DOWNLOAD_URL} \
   -O ${GNU_PG_TEMP_DOWNLOAD_PATH}/libgcrypt.tar.bz2
wget -c ${Libksba_DOWNLOAD_URL} \
   -O ${GNU_PG_TEMP_DOWNLOAD_PATH}/libksba.tar.bz2
wget -c ${Libassuan_DOWNLOAD_URL} \
   -O ${GNU_PG_TEMP_DOWNLOAD_PATH}/libassuan.tar.bz2
wget -c ${ntbTLS_DOWNLOAD_URL} \
   -O ${GNU_PG_TEMP_DOWNLOAD_PATH}/ntbtls.tar.bz2
wget -c ${nPth_DOWNLOAD_URL} \
   -O ${GNU_PG_TEMP_DOWNLOAD_PATH}/npth.tar.bz2
wget -c ${Pinentry_DOWNLOAD_URL} \
   -O ${GNU_PG_TEMP_DOWNLOAD_PATH}/pinentry.tar.bz2

cd ${GNU_PG_TEMP_DOWNLOAD_PATH}

tar -jxf libgpg-error.tar.bz2
tar -jxf libgcrypt.tar.bz2
tar -jxf libksba.tar.bz2
tar -jxf libassuan.tar.bz2
tar -jxf ntbtls.tar.bz2
tar -jxf npth.tar.bz2
tar -jxf pinentry.tar.bz2

cd ${GNU_PG_TEMP_DOWNLOAD_PATH}/$(ls ${GNU_PG_TEMP_DOWNLOAD_PATH} | grep libgpg-error-)
./configure && make && make install

cd ${GNU_PG_TEMP_DOWNLOAD_PATH}/$(ls ${GNU_PG_TEMP_DOWNLOAD_PATH} | grep libgcrypt-)
./configure && make && make install

cd ${GNU_PG_TEMP_DOWNLOAD_PATH}/$(ls ${GNU_PG_TEMP_DOWNLOAD_PATH} | grep libksba-)
./configure && make && make install

cd ${GNU_PG_TEMP_DOWNLOAD_PATH}/$(ls ${GNU_PG_TEMP_DOWNLOAD_PATH} | grep libassuan-)
./configure && make && make install

cd ${GNU_PG_TEMP_DOWNLOAD_PATH}/$(ls ${GNU_PG_TEMP_DOWNLOAD_PATH} | grep ntbtls-)
./configure && make && make install

cd ${GNU_PG_TEMP_DOWNLOAD_PATH}/$(ls ${GNU_PG_TEMP_DOWNLOAD_PATH} | grep npth-)
./configure && make && make install

cd ${GNU_PG_TEMP_DOWNLOAD_PATH}/$(ls ${GNU_PG_TEMP_DOWNLOAD_PATH} | grep pinentry-)
./configure --enable-pinentry-curses --enable-pinentry-tty && make && make install

##############################################################################

# https://github.com/nhorman/rng-tools/releases
# https://centos.pkgs.org/7/centos-x86_64/rng-tools-6.3.1-3.el7.x86_64.rpm.html

# 	rng-tools 다운로드 경로 ( rpm ) : 6.3.1 ( 2018-07-14 )
RNG_TOOLS_DOWNLOAD_URL=http://mirror.centos.org/centos/7/os/x86_64/Packages/rng-tools-6.3.1-3.el7.x86_64.rpm

wget -c ${RNG_TOOLS_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/rng-tools.rpm

yum localinstall -y \
   ${WORK_DIR}/rng-tools.rpm

# https://it.toolbox.com/blogs/edmonbegoli/how-to-generate-enough-entropy-for-gpg-key-generation-process-on-fedora-linux-041410
# http://egloos.zum.com/dmlim/v/4360902
# http://blog.naver.com/PostView.nhn?blogId=solvage&logNo=220852336686&parentCategoryNo=&categoryNo=24&viewDate=&isShowPopularPosts=true&from=search
rngd -r /dev/random

# 키 생성시 필요한 엔트로피 수치 확인 명령어 : rngd -r /dev/random 실행 전후로 확인시 엔트로피 수치 증가 확인됨
# cat /proc/sys/kernel/random/entropy_avail

##############################################################################

# GnuPG 다운로드 경로 : 2.2.17 ( 2019-07-09 )
GNU_PG_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.2.17.tar.bz2

wget -c ${GNU_PG_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/gnupg.tar.bz2

tar -jxf ${WORK_DIR}/gnupg.tar.bz2 \
   -C ${WORK_DIR}

# http://www.linuxfromscratch.org/blfs/view/svn/postlfs/gnupg.html

# gpg-zip 설치하도록 Makefile 수정
sed -e '/noinst_SCRIPTS = gpg-zip/c sbin_SCRIPTS += gpg-zip' \
    -i ${WORK_DIR}/$(ls ${WORK_DIR} | grep gnupg-)/tools/Makefile.in

#  prefix 는 기본값 /usr/local 과 동일하게 지정
cd ${WORK_DIR}/$(ls ${WORK_DIR} | grep gnupg-) && \
./configure \
   --prefix=/usr/local \
   --enable-symcryptrun \
   --enable-g13

make
make install

# /etc/ld.so.conf 에 /usr/local/lib 경로 없는 경우 다음 명령어로 지정함
# echo "/usr/local/lib" > /etc/ld.so.conf.d/gpg2.conf && ldconfig -v

# 라이브러리 경로 미지정시 다음과 같은 에러 메시지 출력됨
# gpg: error while loading shared libraries: libgcrypt.so.20: cannot open shared object file: No such file or directory

cd ..

##############################################################################

# https://gist.github.com/woods/8970150
# https://johngrib.github.io/wiki/gpg/
# https://www.gnupg.org/documentation/manuals/gnupg-devel/Unattended-GPG-key-generation.html

cat > ${WORK_DIR}/gen-key-script \
<<EOF
%echo Generating a basic OpenPGP key
Key-Type: DSA
Key-Length: 1024
Subkey-Type: ELG-E
Subkey-Length: 1024
Name-Real: Joe Tester
Name-Comment: with stupid passphrase
Name-Email: joe@foo.bar
Expire-Date: 0
Passphrase: abc
# Do a commit here, so that we can later print "done" :-)
%commit
%echo done
EOF

# chown dev:developer ${WORK_DIR}/gen-key-script

# sudo -i -u dev bash << EOF
# whoami
# gpg --verbose --batch --gen-key ${WORK_DIR}/gen-key-script
# EOF

##############################################################################

# PASS 다운로드 경로 : 1.7.3 ( 2018-08-03 )
PASS_DOWNLOAD_URL=https://git.zx2c4.com/password-store/snapshot/password-store-1.7.3.tar.xz

# UTILS_MAIN_PATH 내 PASS 설치 디렉토리
PASS_INSTALL_DIRECTORY_NAME=pass
PASS_INSTALL_PATH=${UTILS_MAIN_PATH}/${PASS_INSTALL_DIRECTORY_NAME}

mkdir -p ${PASS_INSTALL_PATH}

# -xf 옵션으로 풀 것
wget ${PASS_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/pass.tar.xz && \
tar -xf ${WORK_DIR}/pass.tar.xz \
   -C ${PASS_INSTALL_PATH} \
   --strip-components 1

##############################################################################

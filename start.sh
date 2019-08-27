#!/bin/bash
#
# sudo passwd => 최초 vm 생성 후 root 계정 암호 설정
# su root => root 계정 접속
# vi ./start.sh => i 클릭 후 전체 내용 복붙, esc 클릭, : 클릭, wq 클릭
# chmod o+x ./start.sh  => 실행 권한 부여
# ./start.sh developer 1200 dev dev  => 다음으로 실행

NEW_GROUP=developer
NEW_GROUP_ID=1200
NEW_USER=dev
NEW_USER_PASSWORD=dev

MARIADB_USER=${NEW_USER}_mysql
REDIS_USER=${NEW_USER}_redis
NGINX_USER=${NEW_USER}_nginx
TOMCAT_USER=${NEW_USER}_tomcat
NEXUS_USER=${NEW_USER}_nexus
NODEJS_USER=${NEW_USER}_nodejs

DB_USER_GROUP=${NEW_USER}_db_group
NGINX_USER_GROUP=${NEW_USER}_nginx_group
SERVER_USER_GROUP=${NEW_USER}_server_group

NEW_DB_SCHEMA_NAME=demo

REAL_DOMAIN=jhpark.gq

NEXUS_DOMAIN_PREFIX=nexus
NEXUS_DOMAIN=${NEXUS_DOMAIN_PREFIX}.${REAL_DOMAIN}

DEV_DOMAIN_PREFIX=dev
DEV_DOMAIN=${DEV_DOMAIN_PREFIX}.${REAL_DOMAIN}

WEBDAV_DOMAIN_PREFIX=webdav
WEBDAV_DOMAIN=${WEBDAV_DOMAIN_PREFIX}.${REAL_DOMAIN}

REAL_SERVER_LOCAL_PORT=8080
DEV_SERVER_LOCAL_PORT=8081
NEXUS_SERVER_LOCAL_PORT=8090

DOCKER_GROUP_ID=1205

# 설치시 사용할 임시 작업 디렉토리 경로
TEMP_PATH=/tmp

##############################################################################

# 사용자 그룹 / 유저 생성 / 유저 패스워드 변경
groupadd -g ${NEW_GROUP_ID} ${NEW_GROUP} && \
useradd -g ${NEW_GROUP} ${NEW_USER} && \
echo ${NEW_USER_PASSWORD} | passwd ${NEW_USER} --stdin

# 사용자 전용 bin 디렉토리 생성
mkdir -p /home/${NEW_USER}/bin

# DB_USER_GROUP, NGINX_USER_GROUP, SERVER_USER_GROUP 생성
groupadd ${DB_USER_GROUP} && \
groupadd ${NGINX_USER_GROUP} && \
groupadd ${SERVER_USER_GROUP}

# NEW_USER 를 각 그룹에 추가
usermod -aG ${DB_USER_GROUP} ${NEW_USER} && \
usermod -aG ${NGINX_USER_GROUP} ${NEW_USER} && \
usermod -aG ${SERVER_USER_GROUP} ${NEW_USER}

##############################################################################

# 개발환경 디렉토리 경로
DEV_TOOLS_PATH=/dev_tools           # NEW_USER : NEW_USER_GROUO 소유

DATABASE_MAIN_PATH=/dev_db          # NEW_USER : DB_USER_GROUP 소유
                                    # 디렉토리 내에서 다시 소유자 달라짐

LIBRARY_MAIN_PATH=/dev_lib          # NEW_USER : NEW_USER_GROUO 소유
                                    # 다른 사용자 읽기/실행 가능

SERVER_MAIN_PATH=/dev_server        # NEW_USER : SERVER_USER_GROUP 소유
                                    # 디렉토리 내에서 다시 소유자 달라짐

STATIC_FILE_MAIN_PATH=/dev_static   # NEW_USER : NGINX_USER_GROUP 소유

mkdir -p ${DEV_TOOLS_PATH}
mkdir -p ${DATABASE_MAIN_PATH}
mkdir -p ${LIBRARY_MAIN_PATH}
mkdir -p ${SERVER_MAIN_PATH}
mkdir -p ${STATIC_FILE_MAIN_PATH}

##############################################################################

# DEV_TOOLS_PATH 내 설치 경로
GIT_MAIN_PATH=${DEV_TOOLS_PATH}/GIT
STS_WORKSPACE_PATH=${DEV_TOOLS_PATH}/WORKSPACE
BUILD_MAIN_PATH=${DEV_TOOLS_PATH}/BUILD
DEPENDENCY_MAIN_PATH=${DEV_TOOLS_PATH}/DEPENDENCY
UTILS_MAIN_PATH=${DEV_TOOLS_PATH}/UTILS

mkdir -p ${GIT_MAIN_PATH}
mkdir -p ${STS_WORKSPACE_PATH}
mkdir -p ${BUILD_MAIN_PATH}
mkdir -p ${DEPENDENCY_MAIN_PATH}
mkdir -p ${UTILS_MAIN_PATH}

##############################################################################

chown -R ${NEW_USER}:${NEW_GROUP} ${DEV_TOOLS_PATH}
chown -R ${NEW_USER}:${DB_USER_GROUP} ${DATABASE_MAIN_PATH}
chown -R ${NEW_USER}:${NEW_GROUP} ${LIBRARY_MAIN_PATH}
chown -R ${NEW_USER}:${SERVER_USER_GROUP} ${SERVER_MAIN_PATH}
chown -R ${NEW_USER}:${NGINX_USER_GROUP} ${STATIC_FILE_MAIN_PATH}

# LIBRARY_MAIN_PATH 는 모든 사용자가 읽기/실행 가능, 단 쓰기는 소유자만 가능
chmod 755 ${LIBRARY_MAIN_PATH}

##############################################################################

# 임시 작업 디렉토리로 이동
cd ${TEMP_PATH}

# 기존 시간대 설정 파일 백업 / 시간대 변경
mv /etc/localtime /etc/localtime_org && \
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

# 언어 설정
localedef -i ko_KR -f UTF-8 ko_KR.UTF-8 && \
export LC_ALL=ko_KR.UTF-8 && \
cat > /etc/locale.conf \
<<EOF
LANG=ko_KR.UTF-8
LC_ALL=ko_KR.UTF-8
EOF

# yum 업데이트 / 기본 패키지 설치
yum update -y && \
yum install -y \
   wget \
   bind-utils \
   zip \
   unzip \
   bzip2 \
   net-tools \
   ntp \
   perl \
   gcc \
   gcc++ \
   make \
   vim \
   gedit \
   expect \
   perl

# 시간 동기화  https://www.manualfactory.net/10147
cat > /etc/ntp.conf \
<<EOF
server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
server 3.centos.pool.ntp.org iburst
EOF

firewall-cmd --add-service=ntp --permanent && \
firewall-cmd --reload && \
systemctl start ntpd && \
systemctl enable ntpd

##############################################################################

# EPEL 리포지터리 설치

# EPEL 리포지터리 다운로드 경로
EPEL_DOWNLOAD_URL=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

wget ${EPEL_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/epel-release.rpm && \
rpm -ivh ${TEMP_PATH}/epel-release.rpm

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

# GPGME        :  1.13.1 ( 2019-06-13 )
#     the standard library to access GnuPG functions from programming languages
GPGME_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/gpgme/gpgme-1.13.1.tar.bz2

# GPA          :  0.10.0 ( 2018-10-16 )
#     a graphical frontend to GnuPG
GPA_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/gpa/gpa-0.10.0.tar.bz2

# GnuPG 의존 라이브러리 다운받을 temp 디렉토리 생성
GNU_PG_TEMP_DOWNLOAD_PATH=${TEMP_PATH}/gnupg-temp
mkdir -p ${GNU_PG_TEMP_DOWNLOAD_PATH}

# zlib-devel : ntbTLS 설치시 필요한 듯??
# ncurses-devel : pinentry 설치시 필요한 듯??
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

wget ${RNG_TOOLS_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/rng-tools.rpm && \

yum localinstall -y \
   ${TEMP_PATH}/rng-tools.rpm

cat /proc/sys/kernel/random/entropy_avail

# https://it.toolbox.com/blogs/edmonbegoli/how-to-generate-enough-entropy-for-gpg-key-generation-process-on-fedora-linux-041410
# http://egloos.zum.com/dmlim/v/4360902
# http://blog.naver.com/PostView.nhn?blogId=solvage&logNo=220852336686&parentCategoryNo=&categoryNo=24&viewDate=&isShowPopularPosts=true&from=search
rngd -r /dev/urandom

cat /proc/sys/kernel/random/entropy_avail

##############################################################################

# GnuPG 다운로드 경로 : 2.2.17 ( 2019-07-09 )
GNU_PG_DOWNLOAD_URL=https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.2.17.tar.bz2

wget ${GNU_PG_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/gnupg.tar.bz2 && \
tar -jxf ${TEMP_PATH}/gnupg.tar.bz2 \
   -C ${TEMP_PATH}

cd ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep gnupg-) && \
./configure && make && make install

# 아래 명령어를 실행하지 않는 경우 다음과 같은 에러 메시지 출력됨
# gpg: error while loading shared libraries: libgcrypt.so.20: cannot open shared object file: No such file or directory
echo "/usr/local/lib" > /etc/ld.so.conf.d/gpg2.conf && ldconfig -v

##############################################################################

# https://gist.github.com/woods/8970150
# https://johngrib.github.io/wiki/gpg/
# https://www.gnupg.org/documentation/manuals/gnupg-devel/Unattended-GPG-key-generation.html

cat > ${TEMP_PATH}/gen-key-script \
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

# chown dev:developer ${TEMP_PATH}/gen-key-script

# sudo -i -u dev bash << EOF
# whoami
# gpg --verbose --batch --gen-key ${TEMP_PATH}/gen-key-script
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
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/pass.tar.xz && \
tar -xf ${TEMP_PATH}/pass.tar.xz \
   -C ${PASS_INSTALL_PATH} \
   --strip-components 1



##############################################################################

# openssl 컴파일 버전 다운로드 / 설치 ( NGINX Dependencies : openssl, PCRE, ZLIB )

# openssl 다운로드 경로 : 1.1.1c( 2019-05-28 )
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source/openssl-1.1.1c.tar.gz

# OPENSSL 컴파일 설치
# 참조 https://blanche-star.tistory.com/entry/APM-%EC%84%A4%EC%B9%98-openssl-%EC%B5%9C%EC%8B%A0%EB%B2%84%EC%A0%84%EC%84%A4%EC%B9%98%EC%86%8C%EC%8A%A4%EC%84%A4%EC%B9%98-shared%EC%84%A4%EC%B9%98
# http://blog.naver.com/PostView.nhn?blogId=hanajava&logNo=221442593046&categoryNo=29&parentCategoryNo=0&viewDate=&currentPage=1&postListTopCurrentPage=1&from=postView


# 기존 openssl 제거
yum remove -y \
   openssl

yum install -y \
   zlib-devel \
   libssl-dev

wget ${OPENSSL_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/openssl.tar.gz && \
tar -zxf ${TEMP_PATH}/openssl.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep openssl-) \
   ${TEMP_PATH}/openssl \
   ${TEMP_PATH}/openssl-*

# https://www.lesstif.com/pages/viewpage.action?pageId=6291508
# -prefix 옵션을 주지 않으면 기본적으로 /usr/local/ 밑에 나눠서 들어간다. 
# header (.h)는 /usr/local/include/openssl, 
# openssl 실행 파일은 /usr/local/bin
#   => 일반적으로 $PATH 에 기본 등록되는 경로이므로 별도 PATH 등록 불필요
# library 는 /usr/local/lib/openssl 폴더에 설치된다. (고 한다..)
#   => 근데 openssl 폴더가 없다??
#   => 아래 설정으로 설치시에는 /usr/local/lib64 에 설치되는 것이 아닌가 추측됨
# (추가) 인증서비스를 위한 파일 : /usr/local/openssl 에 설치된다.

cd openssl

# Configure 의 C 가 대문자여야 실행됨
./Configure \
    linux-x86_64 \
    shared \
    no-idea no-md2 no-mdc2 no-rc5 no-rc4 \
    --prefix=/usr/local \
    --openssldir=/usr/local/openssl

make
make install

cd ..

# openssl 실행 위한 lib 파일 복사
# http://mapoo.net/os/oslinux/openssl-source-install/
# https://sarc.io/index.php/httpd/1252-openssl
cp /usr/local/lib64/libssl.so.1.1 \
   /usr/lib64/libssl.so.1.1 && \
cp /usr/local/lib64/libcrypto.so.1.1 \
   /usr/lib64/libcrypto.so.1.1

##############################################################################

# PCRE 컴파일 버전 다운로드 ( NGINX Dependencies : openssl, PCRE, ZLIB )

# http://blog.naver.com/PostView.nhn?blogId=apocalypsekr&logNo=150156152811

# PCRE 다운로드 경로 : 8.43 ( 2019-02-23 )
PCRE_DOWNLOAD_URL=https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz

wget ${PCRE_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/pcre.tar.gz && \
tar -zxf ${TEMP_PATH}/pcre.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep pcre-) \
   ${TEMP_PATH}/pcre \
   ${TEMP_PATH}/pcre-*

cd pcre

# prefix 는 기본값 /usr/local 과 동일하게 지정
./configure \
   --prefix=/usr/local \
   --enable-static=yes \
   --enable-utf8=yes \
   --enable-unicode-properties=yes

make
make install
cd ..

##############################################################################

# zlib 컴파일 버전 다운로드 ( NGINX Dependencies : openssl, PCRE, ZLIB )

# zlib 다운로드 경로 : 1.2.11 ( 2017-01-15 )
ZLIB_DOWNLOAD_URL=http://zlib.net/zlib-1.2.11.tar.gz

wget ${ZLIB_DOWNLOAD_URL} \
   -P ${TEMP_PATH} \
   -O ${TEMP_PATH}/zlib.tar.gz && \
tar -zxf ${TEMP_PATH}/zlib.tar.gz \
   -C ${TEMP_PATH}

rename ${TEMP_PATH}/$(ls ${TEMP_PATH} | grep zlib-) \
   ${TEMP_PATH}/zlib \
   ${TEMP_PATH}/zlib-*

cd zlib

# libz.so 관련모듈생성 : https://www.happyjung.com/lecture/788
./configure -s
make

# libz.a 생성, prefix 는 기본값 /usr/local 과 동일하게 지정
./configure \
   --prefix=/usr/local
make
make install

# libz.so* 파일들을 /usr/local/lib 로 복사 : -rf 로 모두 overwrite
# cp -rf libz.so* /usr/local/lib

cd ..

##############################################################################

# openSSH 최신버전 설치

# openSSH 다운로드 경로 : 8.0 ( 2019-04-17 )
OPENSSL_DOWNLOAD_URL=https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-8.0p1.tar.gz

# https://www.tecmint.com/install-openssh-server-from-source-in-linux/
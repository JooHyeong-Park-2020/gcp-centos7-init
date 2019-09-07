#!/bin/bash

# CENTOS 서버 세팅 정보 load / 작업 디렉토리로 이동
source ${WORK_DIR}/${SETTING_INFO}.sh


##############################################################################

# zlib 최신 버전 다운로드 / 갱신 설치

# zlib 다운로드 경로 : 1.2.11 ( 2017-01-15 )
ZLIB_DOWNLOAD_URL=http://zlib.net/zlib-1.2.11.tar.gz

wget -c ${ZLIB_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/zlib.tar.gz && \
tar -zxf ${WORK_DIR}/zlib.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep zlib-) \
   ${WORK_DIR}/zlib \
   ${WORK_DIR}/zlib-*

cd zlib

# http://www.linuxfromscratch.org/lfs/view/development/chapter06/zlib.html
# https://www.happyjung.com/lecture/788

# libz.a , libz.so 모듈 생성, prefix 는 기본값 /usr/local 과 동일하게 지정
./configure \
   --prefix=/usr/local
make
make install
make clean

# 기존 설치된 구버전 zlib rpm 제거
# 최신 버전 컴파일 설치시 기존 zlib 를 참조하므로 컴파일 설치 완료 후 구 버전을 제거해야 함
rpm -e --nodeps zlib

# 구버전 zlib 제거해도 /usr/lib64 에 기존 라이브러리 파일이 남아있음
# 신버전 cp 시 overwrite 지정해도 삭제 안되는 케이스가 있어 미리 제거
rm -rf /usr/lib64/libz.*

# /usr/local/lib 에 설치된 libz.a , libz.so 파일들을 /usr/lib64 로 복사
# 구버전 zlib 제거해도 /usr/lib64 에 기존 라이브러리 파일이 남아있음 : -f 옵션으로 overwrite
# -r 옵션 : 원본이 파일이면 그냥 복사되고 (심볼릭 링크 포함) 디렉터리라면 디렉터리 전체가 복사된다.
yes | cp -rf /usr/local/lib/libz.* /usr/lib64

# 위 명령어 실행 후 다시 yum install libz 로 구버전 설치해도 라이브러리 파일들은 최신 버전을 바라본다.

# zlib ( libz ) 라이브러리 버전 변경 확인 명령어
# ldconfig -v | grep libz

cd ..

##############################################################################

# PCRE 컴파일 버전 다운로드

# http://blog.naver.com/PostView.nhn?blogId=apocalypsekr&logNo=150156152811

# PCRE 다운로드 경로 : 8.43 ( 2019-02-23 )
PCRE_DOWNLOAD_URL=https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz

# zlib-devel : PCRE 컴파일 설치시 필요 => zlib 최신버전을 컴파일 설치했으면 불필요
# yum install -y zlib-devel

wget ${PCRE_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/pcre.tar.gz && \
tar -zxf ${WORK_DIR}/pcre.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep pcre-) \
   ${WORK_DIR}/pcre \
   ${WORK_DIR}/pcre-*

cd pcre

# prefix 는 기본값 /usr/local 과 동일하게 지정
# http://www.linuxfromscratch.org/blfs/view/cvs/general/pcre.html
./configure \
   --prefix=/usr/local \
   --enable-static \
   --enable-utf8 \
   --enable-unicode-properties \
   --enable-pcre16 \
   --enable-pcre32 \
   --enable-pcregrep-libz
make
make install
make clean

# 기존 설치된 pcre rpm 제거
# 최신 버전 컴파일 설치시 기존 pcre 를 참조하므로 컴파일 설치 완료 후 구 버전을 제거해야 함
rpm -e --nodeps pcre

# -d 옵션 : 복사할 원본이 심볼릭 링크일 때 심볼릭 자체를 복사한다. => 이건 -r 옵션으로도 적용되어 제외함
# -r 옵션 : 원본이 파일이면 그냥 복사되고 (심볼릭 링크 포함) 디렉터리라면 디렉터리 전체가 복사된다.
# -f 옵션 : 복사할 대상이 이미 있으면 강제로 지우고 복사 => 구버전 라이브러리 파일이 남아있는 경우 overwrite
yes | cp -rf /usr/local/lib/libpcre* /usr/lib64

# pcre 라이브러리 버전 변경 확인 명령어
# ldconfig -v | grep pcre

cd ..

##############################################################################

# openssl 컴파일 버전 다운로드 / 설치

# openssl 다운로드 경로 : 1.1.1c( 2019-05-28 )
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source/openssl-1.1.1c.tar.gz

# OPENSSL 컴파일 설치
# 참조 https://blanche-star.tistory.com/entry/APM-%EC%84%A4%EC%B9%98-openssl-%EC%B5%9C%EC%8B%A0%EB%B2%84%EC%A0%84%EC%84%A4%EC%B9%98%EC%86%8C%EC%8A%A4%EC%84%A4%EC%B9%98-shared%EC%84%A4%EC%B9%98
# http://blog.naver.com/PostView.nhn?blogId=hanajava&logNo=221442593046&categoryNo=29&parentCategoryNo=0&viewDate=&currentPage=1&postListTopCurrentPage=1&from=postView


wget ${OPENSSL_DOWNLOAD_URL} \
   -P ${WORK_DIR} \
   -O ${WORK_DIR}/openssl.tar.gz && \
tar -zxf ${WORK_DIR}/openssl.tar.gz \
   -C ${WORK_DIR}

rename ${WORK_DIR}/$(ls ${WORK_DIR} | grep openssl-) \
   ${WORK_DIR}/openssl \
   ${WORK_DIR}/openssl-*

# 기존 openssl 제거: openssl-libs 는 못 지움, 의존하는 곳이 너무 많음
rpm -e --nodeps openssl

# https://www.lesstif.com/pages/viewpage.action?pageId=6291508
# https://servern54l.tistory.com/entry/Server-OpenSSL-source-compile?category=563849

# -prefix 옵션을 주지 않으면 기본적으로 /usr/local/ 밑에 나눠서 들어간다. 
# header (.h)는 /usr/local/include/openssl, 
# openssl 실행 파일은 /usr/local/bin 에 생성됨
#   => 일반적으로 $PATH 에 기본 등록되는 경로이므로 별도 PATH 등록 불필요
# library 는 /usr/local/lib/openssl 폴더에 설치된다. (고 한다..)
#   => 근데 openssl 폴더가 없다??
#   => 아래 설정으로 설치시에는 /usr/lib64/openssl 에 설치되는 것으로 확인됨
#      ( find / | grep openssl 명령어로 확인 )

cd openssl

# Configure 의 C 가 대문자여야 실행됨
./Configure \
    linux-x86_64 \
    shared \
    zlib \
    no-idea no-md2 no-mdc2 no-rc5 no-rc4 \
    --prefix=/usr/local \
    --openssldir=/usr/local/openssl

make
make install
make clean

# 구버전 openssl 실행파일 경로에 최신 버전 openssl 심볼릭 링크 생성 
ln -s /usr/local/bin/openssl /usr/bin/openssl

cd ..

# openssl 실행 위한 lib 파일 복사
# /etc/ld.so.conf 에 /usr/lib64 라이브러리 경로 지정했으면 불필요

# http://mapoo.net/os/oslinux/openssl-source-install/
# https://sarc.io/index.php/httpd/1252-openssl

# cp /usr/local/lib64/libssl.so.1.1 \
#    /usr/lib64/libssl.so.1.1 && \
# cp /usr/local/lib64/libcrypto.so.1.1 \
#    /usr/lib64/libcrypto.so.1.1

##############################################################################
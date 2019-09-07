#!/bin/bash

# CENTOS 서버 세팅 정보 load
source ${TEMP_PATH}/${SETTING_INFO}.sh


##############################################################################

# 한국어 언어 설정
localedef -i ko_KR -f UTF-8 ko_KR.UTF-8 && \
export LC_ALL=ko_KR.UTF-8 && \
cat > /etc/locale.conf \
<<EOF
LANG=ko_KR.UTF-8
LC_ALL=ko_KR.UTF-8
EOF

##############################################################################

# 기존 시간대 설정 파일 백업 / 시간대 변경
mv /etc/localtime /etc/localtime_org && \
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

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

# /usr/local/lib , /usr/local/lib64 , /usr/lib64 라이브러리 경로에 추가

# http://cr3denza.blogspot.com/2015/03/ldsoconf.html
# https://www.thinkit.or.kr/linux/entry/ldconfig-%eb%8f%99%ec%a0%81-%eb%a7%81%ed%81%ac-%ec%84%a4%ec%a0%95-sbinldconfig
# https://sens.tistory.com/33

cat >> /etc/ld.so.conf \
<<EOF
/usr/local/lib
/usr/local/lib64
/usr/lib64
EOF

ldconfig

##############################################################################

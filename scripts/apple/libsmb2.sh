#!/bin/bash
# libsmb2 (https://github.com/sahlberg/libsmb2) — FFmpegKitNext 커스텀 라이브러리 빌드 스크립트.
# 워크플로우가 이 파일을 ffmpeg-kit-next/scripts/apple/libsmb2.sh 로 복사하면, 빌드 오케스트레이터가
# --enable-lib-custom-1-name=libsmb2 에 맞춰 이 스크립트를 source 한다 (speex.sh 등과 같은 규약).
#
# 오케스트레이터가 넘겨주는 것: ARCH, HOST, SDK_PATH, BASEDIR, LIB_NAME, LIB_INSTALL_PREFIX,
#   INSTALL_PKG_CONFIG_DIR, 그리고 export 된 CC/CFLAGS/CXXFLAGS/LDFLAGS (iOS arm64 크로스 플래그).
# 이 스크립트가 해야 할 것: ./configure → make → make install → .pc 를 INSTALL_PKG_CONFIG_DIR 로 복사.
#
# ffmpeg 쪽에서는 (포크된 configure 가) `pkg-config libsmb2` 로 이 라이브러리를 찾고,
# libavformat/libsmbclient.c(libsmb2 구현)가 smb:// 프로토콜을 제공한다.

# ALWAYS CLEAN THE PREVIOUS BUILD
make distclean 2>/dev/null 1>/dev/null

# libsmb2 는 configure 가 저장소에 없고 bootstrap(autoreconf) 으로 만든다.
if [[ ! -f "${BASEDIR}"/src/"${LIB_NAME}"/configure ]] || [[ ${RECONF_libsmb2} -eq 1 ]]; then
  autoreconf_library "${LIB_NAME}" 1>>"${BASEDIR}"/build.log 2>&1 || return 1
fi

# --without-libkrb5 : iOS 에 krb5 가 없다. libsmb2 내장 NTLMSSP 인증으로 충분(NAS 로그인).
# --disable-examples: 예제 실행파일은 크로스 빌드에서 링크 실패 원인이 되니 뺀다.
# --disable-werror  : 최신 clang 경고가 에러로 승격돼 빌드가 끊기는 것 방지.
./configure \
  --prefix="${LIB_INSTALL_PREFIX}" \
  --with-pic \
  --with-sysroot="${SDK_PATH}" \
  --enable-static \
  --disable-shared \
  --disable-fast-install \
  --disable-examples \
  --disable-werror \
  --without-libkrb5 \
  --host="${HOST}" || return 1

make -j$(get_cpu_count) || return 1

make install || return 1

# MANUALLY COPY PKG-CONFIG FILES
# libsmb2 는 lib/pkgconfig/libsmb2.pc 를 설치한다. ffmpeg configure 가 PKG_CONFIG_LIBDIR 에서 찾도록 복사.
cp "${LIB_INSTALL_PREFIX}"/lib/pkgconfig/libsmb2.pc "${INSTALL_PKG_CONFIG_DIR}" || return 1

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

# libsmb2 소스(alloc.c 등)가 GNU 확장 `typeof` 를 쓰는데, 이 빌드 환경의 clang 은 엄격한 ISO C 모드라
# `typeof` 를 모른다(1차 빌드 실패 원인: "expected ';'… use of undeclared identifier '__mptr'").
# 표준 철자 `__typeof__` 로 치환해 준다. 경고가 에러로 승격되는 것도 막는다.
export CFLAGS="${CFLAGS} -Dtypeof=__typeof__ -Wno-error"

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

# ★ 설치된 smb2/libsmb2.h 는 uint8_t/size_t/time_t 를 쓰면서 어떤 헤더도 include 하지 않는다
#   (HAVE_STDINT_H 같은 가드도 없음 — 3차 빌드에서 -D 를 줘도 실패한 이유).
#   ffmpeg configure 의 검사는 `#include <smb2/libsmb2.h>` 를 맨 먼저 하므로 컴파일이 깨진다.
#   헤더 가드 바로 뒤에 표준 헤더 3개를 끼워 넣어 자급자족하게 만든다 (awk = GNU/BSD sed 차이 없음).
HDR="${LIB_INSTALL_PREFIX}/include/smb2/libsmb2.h"
#   또한 libsmb2.h 는 SMB2_GUID_SIZE·smb2_lease_key 등 smb2/smb2.h 의 정의도 쓰면서 그 헤더를 include
#   하지 않는다(4차 빌드 실패). smb2.h 는 libsmb2.h 를 include 하지 않아 순환이 없으니 함께 끼운다.
if ! grep -q '^#include <stdint.h>' "${HDR}"; then
  awk '{print} /^#define _LIBSMB2_H_/ {print "#include <stdint.h>"; print "#include <stddef.h>"; print "#include <time.h>"; print "#include <smb2/smb2.h>"}' \
    "${HDR}" > "${HDR}.tmp" || return 1
  mv "${HDR}.tmp" "${HDR}" || return 1
fi
grep -n '^#include' "${HDR}" 1>>"${BASEDIR}"/build.log 2>&1

# MANUALLY COPY PKG-CONFIG FILES
# libsmb2 는 lib/pkgconfig/libsmb2.pc 를 설치한다. ffmpeg configure 가 PKG_CONFIG_LIBDIR 에서 찾도록 복사.
#
# ★ smb2/libsmb2.h 는 uint32_t/size_t 를 쓰면서 <stdint.h>/<time.h> 를 `#ifdef HAVE_STDINT_H` 뒤에
#   숨겨 놓아, 헤더만 단독 include 하면 컴파일이 안 된다 (2차 빌드 실패: "unknown type name 'uint32_t'").
#   .pc 의 Cflags 에 그 define 을 넣어 주면 ffmpeg configure 의 헤더 테스트와 libsmbclient.c 컴파일이
#   모두 통과한다 — 원래 AWS 빌드의 가짜 libsmbclient.pc 가 쓰던 바로 그 트릭.
PC_SRC="${LIB_INSTALL_PREFIX}/lib/pkgconfig/libsmb2.pc"
sed 's|^Cflags:.*|& -DHAVE_STDINT_H -DHAVE_TIME_H|' "${PC_SRC}" > "${PC_SRC}.tmp" || return 1
mv "${PC_SRC}.tmp" "${PC_SRC}" || return 1
grep '^Cflags' "${PC_SRC}" 1>>"${BASEDIR}"/build.log 2>&1
cp "${PC_SRC}" "${INSTALL_PKG_CONFIG_DIR}" || return 1

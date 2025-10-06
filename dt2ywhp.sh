#!/bin/bash
set -eu

# UTF-8 로케일 보장 (yaft는 wcwidth 계산을 위해 UTF-8 환경이 필요)
export LANG="${LANG:-C.UTF-8}"
case "$LANG" in
  *UTF-8*|*utf8*) : ;;
  *) export LANG="C.UTF-8" ;;
esac

# 인수 처리 (uninstall 포함)
KEYBOARD_LAYOUT="2"  # 기본: 두벌식

if [[ $# -ge 1 ]]; then
  case "$1" in
    "uninstall")
      echo "[!] yaft make install로 설치한 파일 삭제 중..."
      sudo rm -f /usr/bin/yaft /usr/bin/yaft_wall
      sudo rm -f /usr/share/man/man1/yaft.1
      sudo find /usr/share/terminfo -name "*yaft*" -exec rm -f {} \;
      echo "[+] yaft make install 결과물 삭제 완료"
      exit 0
      ;;
    "390"|"sebeol390")
      KEYBOARD_LAYOUT="39"
      echo "[+] 세벌식 390 자판으로 설정합니다."
      ;;
    "2"|"dubeol")
      KEYBOARD_LAYOUT="2"
      echo "[+] 두벌식(기본) 자판으로 설정합니다."
      ;;
    *|--help)
      echo "사용법: $0 [uninstall|390|sebeol390|2|dubeol]"
      exit 1
      ;;
  esac
fi

# 패키지 설치 및 yaft 디렉토리 준비
echo "[+] 필요한 패키지 설치 및 yaft 소스 준비 중..."
sudo apt update
sudo apt install -y git build-essential libhangul-dev imagemagick xz-utils
rm -rf yaft
if [ -d yaft ]; then
  echo "[!] yaft 디렉토리가 이미 존재합니다."
else
  git clone https://github.com/uobikiemukot/yaft.git
fi

# 패치 이미지 파일 절대경로 탐색
PATCH_IMG_REL="./yaft_ko_patch.png"
PATCH_IMG_ABS="$(readlink -f "$PATCH_IMG_REL")"

if [ ! -f "$PATCH_IMG_ABS" ]; then
  echo "ERROR: $PATCH_IMG_ABS 파일을 찾을 수 없습니다."
  exit 1
fi

echo "[+] yaft_ko_patch.png 위치 확인: $PATCH_IMG_ABS"

# yaft 디렉토리 진입
cd yaft

# 이미지 절대경로로 변환 및 패치 적용
convert "$PATCH_IMG_ABS" RGB:- | xz -d -c - > hangul.patch
if patch -p1 --dry-run < hangul.patch | grep -q 'Reversed (or previously applied) patch detected'; then
    echo "[!] 패치가 이미 적용되어 있으므로, 건너뜁니다."
else
    patch -p1 < hangul.patch
fi
echo "[+] 패치 완료: $PATCH_IMG_ABS → hangul.patch 적용"


# === 빌드 준비 ===
# H04.FNT 파일 생성
echo "[+] H04.FNT 파일 생성 중..."
base64 -d H04.FNT.xz.b64 | xz -d -c - > H04.FNT

# mkfont_bdf wcwidth 에러 해결을 위한 자동 패치
echo "[+] mkfont_bdf wcwidth 빌드 에러 예방 패치 적용 중..."
if ! grep -q '#define _XOPEN_SOURCE' tools/mkfont_bdf.c; then
  sed -i '1i#define _XOPEN_SOURCE 700' tools/mkfont_bdf.c
  echo "[+] tools/mkfont_bdf.c에 #define _XOPEN_SOURCE 700 추가"
fi
if ! grep -q '#include <wchar.h>' tools/mkfont_bdf.c; then
  sed -i '2i#include <wchar.h>' tools/mkfont_bdf.c
  echo "[+] tools/mkfont_bdf.c에 #include <wchar.h> 추가"
fi

# mkfont_bdf 빌드
echo "[+] mkfont_bdf 빌드 중..."
if ! cc -o mkfont_bdf tools/mkfont_bdf.c -std=c99 -D_XOPEN_SOURCE=700 -I/usr/include/hangul-1.0 -lhangul 2>/dev/null; then
  echo "[!] mkfont_bdf 빌드 실패. make 명령으로 재시도..."
  make mkfont_bdf || {
    echo "ERROR: mkfont_bdf 빌드에 실패했습니다."
    exit 1
  }
fi
echo "[+] mkfont_bdf 빌드 완료"

# 폰트 글리프(glyph.h) 자동 생성
echo "[+] 폰트 글리프(glyph.h) 생성 중..."
./mkfont_bdf -hH04.FNT table/alias \
  fonts/milkjf/milkjf_k16.bdf \
  fonts/milkjf/milkjf_8x16r.bdf \
  fonts/milkjf/milkjf_8x16.bdf \
  fonts/terminus/ter-u16n.bdf > glyph.h

# === yaft 최종 빌드 및 설치 ===
echo "[+] yaft 최종 빌드 및 설치 중..."
make clean

# usleep 함수가 glibc 최신 버전에서 _DEFAULT_SOURCE 매크로를 필요로 할 수 있으므로, 컴파일러 플래그에 추가합니다.
# 또한, 파일 수정이 알 수 없는 이유로 실패하여 -include unistd.h로 헤더를 강제 포함합니다.
make CFLAGS="-std=c99 -D_XOPEN_SOURCE=700 -D_DEFAULT_SOURCE -I/usr/include/hangul-1.0 -include unistd.h" LDFLAGS="-lhangul"
sudo make install

# 현재 계정에 video 그룹 권한 부여(프레임버퍼 접근)
sudo usermod -aG video "$USER"
echo "[!] video 그룹 추가 반영을 위해 반드시 로그아웃 후 재로그인 하세요."

# === TTY 자동 실행 설정 (getty 유지, 로그인 후 yaft 실행) ===
echo "[+] TTY에서 yaft 자동 실행 설정 중..."

read -p "TTY 콘솔에서 (로그인 후) yaft를 자동 실행하시겠습니까? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # .bashrc에 남아있을 수 있는 exec yaft 제거 (대화형 비로그인 셸 영향 방지)
  sed -i '/exec yaft/d' "$HOME/.bashrc" || true

  # 로그인 셸에서만 tty1일 때 yaft 실행
  if ! grep -q 'exec yaft' "$HOME/.profile" 2>/dev/null; then
    {
      echo ""
      echo "# Auto start yaft on tty1 (login shell only)"
      echo 'if [ "$(tty)" = "/dev/tty1" ] && command -v yaft >/dev/null; then exec yaft; fi'
    } >> "$HOME/.profile"
    echo "[+] ~/.profile에 TTY 자동 실행 설정 추가됨"
  fi
  echo "[+] getty 유지 + 로그인 후 yaft 자동 실행 구성이 완료되었습니다."
fi

# 키맵 덤프 및 shift+space로 한/영 전환 매핑 예시
dumpkeys > ~/kmap
echo '※ ~/kmap 파일 내 string F60 = "\200" 추가, shift keycode 57 = F60 추가, keycode 100 항목 (shift+space) 편집 필요'
echo "※ 편집 후 loadkeys ~/kmap 수행 및 /etc/default/keyboard에 KEYMAP=/home/$(whoami)/kmap 설정 가능"

# 빌드 관련 패키지 및 libhangul-dev 등 제거 (주석 처리됨)
# sudo apt purge -y build-essential imagemagick xz-utils libhangul-dev
# sudo apt autoremove -y
# sudo apt install libhangul1
# echo "[+] 설치 패키지 및 불필요한 의존성 자동 삭제 완료"

# 적용 요약 출력
echo
echo "=== 적용 요약 ==="
echo "1. yaft : 프레임버퍼 터미널 실행"
echo "2. 한영 전환: shift+space(직접 편집 기준)"
echo "3. 자판 배열: $KEYBOARD_LAYOUT (두벌식=2, 세벌식390=39)"
echo "4. CLI 편집기(vim 등)에서도 정상 한글표시/입력"
echo ""
echo "※ 적용 후 재로그인 필요, 공식문서 참조 필수."
echo "※ yaft 사용 중 문제 발생 시 'dthp.sh uninstall'로 제거 가능"
echo "================"
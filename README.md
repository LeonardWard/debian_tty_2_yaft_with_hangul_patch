# debian_tty_2_yaft_with_hangul_patch
# README.md

## 소개

데비안 기반 시스템의 TTY 콘솔을 한글을 볼 수 있는 yaft 터미널로 교체하는 자동화 스크립트입니다. 한글 입력을 위해 libhangul 기반 패치가 적용되어 있으며, 두벌식/세벌식390 자판을 지원할 예정.

## 요구 사항

- Debian 계열 리눅스
- sudo 권한
- 인터넷 연결
- 프레임버퍼 지원 그래픽 환경

## 설치 방법

```bash
git clone https://github.com/LeonardWard/debian_tty_2_yaft_with_hangul_patch.git
cd debian_tty_2_yaft_with_hangul_patch
chmod +x dt2ywhp.sh
bash dt2ywhp.sh
```

설치 후 video 그룹에 사용자 계정이 자동 추가되며, 반드시 로그아웃 후 재로그인 하여야 프레임버퍼 접근 권한이 정상적으로 반영됩니다.

### 자판 선택 (옵션)

- 기본 두벌식: `bash dt2ywhp.sh`
- 세벌식 390: `bash dt2ywhp.sh 390`
- 두벌식 명시: `bash dt2ywhp.sh 2`

## 설치 제거 방법

```bash
bash dt2ywhp.sh uninstall
```

설치 파일과 관련 리소스를 모두 삭제합니다.

## 한영 전환 및 키맵 설정

- shift+space로 한/영 전환이 됩니다.  
- kmap 파일을 덤프하여 수동 편집 및 loadkeys 명령으로 적용 가능합니다.
- `/etc/default/keyboard`에서 직접 키맵 지정 가능

## 주요 동작

- yaft (한글 패치 적용)
- 한글 입력: 두벌식 또는 세벌식390 자판 지원
- TTY에서 로그인 후 yaft 자동 실행 (선택적 적용)
- CLI 에디터(vim 등)에서도 한글 입력/출력 지원

## 참고 및 주의사항

- 로그아웃/재로그인 필요
- yaft 사용 중 문제 발생 시 스크립트의 uninstall 옵션으로 제거 가능
- 설치 및 사용 전/후 관련 안내를 반드시 확인 바랍니다.

***
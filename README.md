# dev-env setup

개인 개발 환경을 한 번에 세팅하는 스크립트. macOS / Linux / WSL 모두 지원합니다.

여러 번 실행해도 안전하게 동작하고 (idempotent), OS에 맞춰 알아서 분기합니다.

## 무엇을 설치하나

### 셸
- **zsh** + **Oh My Zsh**
- **Powerlevel10k** 테마 (예쁜 프롬프트)
- **zsh-autosuggestions** — 명령어 입력 시 히스토리 기반 회색 추천
- **zsh-syntax-highlighting** — 명령어 색 표시 (실행 가능 여부 확인)
- **zsh-completions** — 추가 자동완성

### 터미널 도구
- **tmux** 세팅
  - `Ctrl+B` → `4` 로 4분할
  - 마우스 클릭으로 패널 이동, 드래그로 크기 조절, 스크롤
  - 마우스 드래그 시 시스템 클립보드 자동 복사 (OS별 자동 분기)
  - `Ctrl+B` → `r` 로 설정 리로드
- **vim** 세팅 — 줄번호, 시스템 클립보드, 마우스, 합리적인 들여쓰기 등

### Modern CLI
- **bat** — `cat` 대체. 신택스 하이라이팅 포함
- **eza** — `ls` 대체. 컬러 + git 상태 표시
- **fzf** — 퍼지 검색 (Ctrl+R 히스토리 검색 등)
- **ripgrep** — 빠른 grep

### 개발 도구
- **fnm** — Node.js 버전 매니저 (Rust 기반, nvm보다 빠름)
- **uv** — Python 패키지/버전 매니저 (pip/pyenv 대체)
- **gh** — GitHub CLI

### 기타
- **Git** 기본 설정 + 글로벌 gitignore + 유용한 alias
- **MesloLGS Nerd Font** (p10k 아이콘용)

## 설치 방법

```bash
git clone https://github.com/<YOUR_USERNAME>/dotfiles.git
cd dotfiles
chmod +x setup.sh
./setup.sh
```

## 옵션

```bash
./setup.sh --dry-run       # 실제 설치 없이 무엇을 할지 미리 보기
./setup.sh --minimal       # zsh + tmux + vim만 (CLI 도구/dev tool 제외)
./setup.sh --skip-pkg      # 패키지 매니저 설치 건너뛰기
./setup.sh --skip-fonts    # Nerd Font 설치 건너뛰기
./setup.sh --help
```

## 설치 후

1. **새 터미널 열기** (또는 `exec zsh`)
2. 처음 실행 시 **Powerlevel10k 설정 마법사**가 자동으로 뜸
   - 나중에 다시 하려면: `p10k configure`
3. **터미널 폰트를 'MesloLGS NF'로 설정** — p10k 아이콘이 깨지지 않으려면 필수
4. tmux 사용: `Ctrl+B` → `4` 로 4분할 시도

## 멱등성 (Idempotency)

이 스크립트는 안전하게 여러 번 실행할 수 있습니다.

- 이미 설치된 패키지는 건너뜀 (`[SKIP]`)
- 설정 파일의 관리 블록은 매번 OS에 맞춰 다시 작성됨
  - 예: macOS에서 만든 dotfiles를 Linux에 가져와 실행하면 `pbcopy`가 자동으로 `xclip`으로 바뀜
- 관리 블록 **밖의** 사용자 설정은 절대 건드리지 않음

설정 블록 marker 예시:
```
# >>> dev-env tmux config BEGIN >>>
... 스크립트가 관리하는 영역
# <<< dev-env tmux config END <<<
```

## 다른 머신으로 옮길 때

```bash
# 새 머신에서
git clone https://github.com/<YOUR_USERNAME>/dotfiles.git
cd dotfiles
./setup.sh
```

OS가 달라도 자동으로 적응합니다.

## 트러블슈팅

### tmux 마우스 복사가 안 되면
```bash
tmux kill-server && tmux
tmux list-keys | grep MouseDrag   # 클립보드 명령어 확인
```

### Powerlevel10k 아이콘이 깨져 보이면
터미널 설정에서 폰트를 `MesloLGS NF`로 바꿔주세요. 스크립트가 자동 설치하지만, 터미널 자체에서 폰트를 선택해야 적용됩니다.

### Oh My Zsh "Insecure completion-dependent directories" 경고
스크립트가 자동으로 권한을 수정합니다. 그래도 뜨면:
```bash
compaudit | xargs chmod g-w,o-w
```

### 설정을 처음부터 다시 하고 싶다면
관리 블록을 지우고 스크립트를 다시 실행하세요:
```bash
# 예: tmux 설정 초기화
sed -i.bak '/# >>> dev-env tmux config BEGIN/,/# <<< dev-env tmux config END/d' ~/.tmux.conf
./setup.sh
```

## 라이선스

MIT

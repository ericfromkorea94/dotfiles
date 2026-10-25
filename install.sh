#!/usr/bin/env bash
# 패키지를 설치하고 dotfiles를 홈 디렉터리에 stow로 연결한다.

# 명령 실패, 정의되지 않은 변수 사용, 파이프 중간 실패가 발생하면 즉시 종료한다.
set -euo pipefail

# 이 스크립트가 있는 디렉터리(저장소 루트)의 절대 경로. 어느 위치에서 실행해도 같은 경로를 사용한다.
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# pyenv로 설치할 Python 버전. 3.13처럼 마이너 버전까지만 적으면 그 계열의 최신 패치 버전을 설치한다.
python_versions=(3.10 3.12 3.13)
# 기본 Python으로 지정할 버전. python_versions에 포함된 버전이어야 한다.
python_global=3.12

install_packages() {
    # packages.txt에 적힌 패키지를 설치한다. 목록이 비어 있으면 xargs -r이 apt-get을 실행하지 않는다.
    # Python 빌드에 필요한 라이브러리(libssl-dev 등)도 packages.txt에 포함한다.
    sudo apt-get update
    xargs -r sudo apt-get install -y < "$repo_dir/packages.txt"

    # Claude Code와 Codex의 설치 위치(~/.local/bin)를 PATH에 미리 추가한다.
    # PATH에 없으면 Codex 설치 스크립트가 셸 설정 파일에 PATH 설정을 추가하기 때문이다.
    export PATH="$HOME/.local/bin:$PATH"

    # Claude Code를 공식 설치 스크립트로 ~/.local/bin에 설치한다. 이미 설치되어 있으면 건너뛴다.
    if [[ ! -x ~/.local/bin/claude ]]; then
        curl -fsSL https://claude.ai/install.sh | bash
    fi

    # Codex를 공식 설치 스크립트로 ~/.local/bin에 설치한다. npm 없이 실행 파일만 내려받는다. 이미 설치되어 있으면 건너뛴다.
    if [[ ! -x ~/.local/bin/codex ]]; then
        curl -fsSL https://chatgpt.com/codex/install.sh | sh
    fi

    # pyenv는 apt 패키지가 없으므로 공식 설치 스크립트로 ~/.pyenv에 설치한다.
    # 설치 스크립트는 ~/.pyenv가 이미 있으면 실패하므로, 디렉터리가 없을 때만 실행한다.
    export PYENV_ROOT="$HOME/.pyenv"
    if [[ ! -d $PYENV_ROOT ]]; then
        curl -fsSL https://pyenv.run | bash
    fi
    # 이 스크립트 안에서 pyenv 명령을 사용할 수 있도록 PATH에 추가한다. 새 셸에서는 .bashrc가 같은 설정을 처리한다.
    export PATH="$PYENV_ROOT/bin:$PATH"

    # python_versions의 각 버전에 해당하는 최신 패치 버전을 확인해 설치한다.
    # -s는 이미 설치된 버전이면 빌드를 건너뛴다.
    local version
    for version in "${python_versions[@]}"; do
        pyenv install -s "$(pyenv latest -k "$version")"
    done

    # python_global에 해당하는 설치된 버전 중 최신 패치 버전을 기본 Python으로 지정한다.
    pyenv global "$(pyenv latest "$python_global")"
}

install_packages

# 기존 bash 설정 파일이 있으면 .bak으로 백업한다. stow는 대상 위치에 일반 파일이 있으면 충돌로 처리하기 때문이다.
# 심볼릭 링크는 이전 실행에서 stow가 만든 것이므로 옮기지 않는다. 다시 실행해도 원본 백업을 덮어쓰지 않는다.
for f in .bashrc .profile .bash_logout; do
    if [[ -f ~/$f && ! -L ~/$f ]]; then
        mv ~/"$f" ~/"$f.bak"
    fi
done

# 각 패키지 디렉터리의 파일을 $HOME에 심볼릭 링크로 연결한다. --restow는 기존 링크를 지우고 다시 만든다.
stow --dir="$repo_dir" --target="$HOME" --restow bash git nvim tmux vim

# 스크립트는 실행한 셸의 설정을 바꿀 수 없으므로, 새 설정을 적용하는 명령을 안내한다.
# -l(로그인 셸)은 .profile도 다시 읽고, .profile이 .bashrc를 읽는다.
echo "설치가 끝났습니다. 새 설정을 적용하려면 exec bash -l 을 실행하세요."

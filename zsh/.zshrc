# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

# 補完
autoload -Uz compinit
compinit

# プロンプト
PROMPT="%* %~ $ "

# シェルオプション
setopt auto_cd
setopt auto_pushd
setopt correct

# ヒストリー
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

# キーバインド
bindkey "^P" history-beginning-search-backward
bindkey "^N" history-beginning-search-forward

# Git ブランチ表示
autoload -Uz vcs_info
setopt prompt_subst
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr "%F{yellow}!"
zstyle ':vcs_info:git:*' unstagedstr "%F{red}+"
zstyle ':vcs_info:*' formats "%F{green}%c%u[%b]%f"
zstyle ':vcs_info:*' actionformats '[%b|%a]'
precmd () { vcs_info }
RPROMPT=$RPROMPT'${vcs_info_msg_0_}'

# TIMEFMT
TIMEFMT=$'\n\n========================\nProgram : %J\nCPU     : %P\nuser    : %*Us\nsystem  : %*Ss\ntotal   : %*Es\n========================\n'

# Google Cloud SDK completion
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

# エイリアス
alias c='claude'

# Kiro シェル統合
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# 秘密情報の読み込み
ZSHSECRET="${0:A:h}/.zshsecret"
[[ -f "$ZSHSECRET" ]] && source "$ZSHSECRET"

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"

# 補完
autoload -Uz compinit
compinit

# プロンプト
PROMPT='%F{245}%*%f %B%F{cyan}%~%f%b ${vcs_info_msg_0_}
%B%F{green}>%f%b '

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
zstyle ':vcs_info:git:*' stagedstr "%F{yellow}[!]"
zstyle ':vcs_info:git:*' unstagedstr "%F{red}[+]"

# 変更状態に応じてブランチ名の色を切り替える
+vi-git-color() {
  local color
  if [[ -n ${hook_com[unstaged]} ]]; then
    color='red'
  elif [[ -n ${hook_com[staged]} ]]; then
    color='yellow'
  else
    color='green'
  fi
  hook_com[branch]="%F{${color}} %B${hook_com[branch]}%b%f"
}
zstyle ':vcs_info:git*+set-message:*' hooks git-color

zstyle ':vcs_info:*' formats "%F{250}on%f %b%c%u"
zstyle ':vcs_info:*' actionformats '[%b|%a]'
precmd () { vcs_info }

# TIMEFMT
TIMEFMT=$'\n\n========================\nProgram : %J\nCPU     : %P\nuser    : %*Us\nsystem  : %*Ss\ntotal   : %*Es\n========================\n'

# Google Cloud SDK completion
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

# エイリアス
alias c='claude'
alias cl='clear'
alias n='nvim'

# inshellisense（コマンド仕様ベースのインライン補完）
[[ -f ~/.inshellisense/init/zsh/init.zsh ]] && source ~/.inshellisense/init/zsh/init.zsh

# 秘密情報の読み込み
ZSHSECRET="$(dirname "$(readlink ~/.zshrc || echo ~/.zshrc)")/.zshsecret"
[[ -f "$ZSHSECRET" ]] && source "$ZSHSECRET"

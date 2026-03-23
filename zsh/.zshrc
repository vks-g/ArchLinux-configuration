###############################
#           PATHS
###############################
export PATH=$PATH:~/.spicetify



###############################
#        LS / EZA / COLORS
###############################
alias ls="eza --icons"
alias lt='eza --tree --icons -L 2 -lah'

###############################
#      DIRECTORY SHORTCUTS
###############################
alias ~="cd ~"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

###############################
#         FZF SETTINGS
###############################
source <(fzf --zsh)

###############################
#         GIT ALIASES
###############################
alias gc="git commit -m"
alias gca="git commit -a -m"
alias gp="git push origin"
alias gpu="git pull origin"
alias gst="git status"
alias glog="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"
alias gdiff="git diff"
alias gco="git checkout"
alias gb="git branch"
alias gba="git branch -a"
alias gadd="git add"
alias ga="git add -p"
alias gcoall="git checkout -- ."
alias gr="git remote"
alias gre="git reset"

###############################
#         HISTORY SETTINGS
###############################
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
setopt appendhistory sharehistory hist_ignore_space hist_ignore_dups \
       hist_find_no_dups hist_save_no_dups hist_ignore_all_dups

###############################
#      COMPLETION ENGINE
###############################
autoload -Uz compinit
compinit
setopt auto_menu
setopt complete_in_word
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

###############################
#  SYNTAX HIGHLIGHTING & SUGGESTIONS
###############################
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
setopt prompt_subst

###############################
#       NAVIGATION HELPERS
###############################
cx() { cd "$@" && lt; }
fcdlt() { cd "$(find . -type d -not -path '*/.*' | fzf)" && lt; }
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)"; }
f() { echo "$(find . -type f -not -path '*/.*' | fzf)" | wl-copy }
fv() { nvim "$(find . -type f -not -path '*/.*' | fzf)" }

###############################
#       STARSHIP PROMPT
###############################
eval "$(starship init zsh)"

###############################
#       CUSTOM INIT
###############################
source ~/.config/zsh/zsh-init.sh

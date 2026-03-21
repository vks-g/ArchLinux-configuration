cd() {
  builtin cd $@ &&
  ls
}

pasteimg() {
    local name="${1:-clipboard.png}"
    [[ "$name" != *.png ]] && name="$name.png"
    wl-paste --type image/png | sudo tee "$name" > /dev/null
}

stsetup() {
    local proj_dir="$HOME/Projects/stewart-new"
    
    if [[ ! -d "$proj_dir" ]]; then
        echo "Directory $proj_dir does not exist."
        return 1
    fi

    cd "$proj_dir" || return 1

    kitty --directory "$proj_dir" nix develop --command zsh -ic "alias run='python main.py'; exec zsh" &
    
    sleep 0.5
    
    hyprctl dispatch splitratio -0.5

    nix develop --command zsh -ic "edit; exec zsh"
}

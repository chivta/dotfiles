function fish_prompt
    set -l last_status $status

    # xterm-256 hex equivalents of the bash/.bashrc palette
    set -l c_frame af005f # 125
    set -l c_user ffafff # 219
    set -l c_host ffd7ff # 225
    set -l c_dir ffafff # 219
    set -l c_git 87ff87 # 120
    set -l c_err ff0000 # 196

    # Match bash \W
    set -l dir (string replace -r '^.*/(?=.)' '' -- $PWD)
    test "$PWD" = "$HOME"; and set dir '~'

    set_color $c_frame
    echo -n '┌──['
    set_color $c_user
    echo -n $USER
    set_color $c_frame
    echo -n @
    set_color $c_host
    echo -n (prompt_hostname)
    set_color $c_dir
    echo -n " $dir"
    set_color $c_frame
    echo -n '] '
    set_color $c_git
    echo -n (fish_git_prompt '(%s)')
    if test $last_status -ne 0
        set_color $c_err
        echo -n " $last_status"
    end
    set_color normal
    echo
    set_color $c_frame
    echo -n '└─'
    set_color $c_user
    echo -n '$'
    set_color normal
    echo -n ' '
end

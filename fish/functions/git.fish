# git-show does not honor diff.external unless --ext-diff is passed.
function git --wraps git
    if test "$argv[1]" = show
        command git show --ext-diff $argv[2..]
    else
        command git $argv
    end
end

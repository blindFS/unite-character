let s:command = expand('<sfile>:p:h').'/../autoload/unite/sources/unum.pl c="%s"'

function! s:unicode_search(char)
    echo system(printf(s:command, a:char))
endfunction

command! SearchUnicode :call s:unicode_search(getline(".")[col(".") - 1])

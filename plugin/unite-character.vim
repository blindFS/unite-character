let s:command = expand('<sfile>:p:h').'/../autoload/unite/sources/unum.pl c="%s"'

function! s:unicode_search(char)
    echo system(printf(s:command, a:char))
endfunction

function! s:unicode_html(char)
    normal x
    let @" = split(system(printf(s:command, a:char)), '\s\+')[9]
    let g:ll = split(system(printf(s:command, a:char)), '\s\+')
    normal P
endfunction

command! SearchUnicode :call s:unicode_search(matchstr(getline('.'), '.', col('.')-1))
command! HTMLUnicode :call s:unicode_html(matchstr(getline('.'), '.', col('.')-1))

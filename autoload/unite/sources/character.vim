let s:save_cpo = &cpo
set cpo&vim

let s:unite_source = {
            \ 'name': 'character',
            \ 'required_pattern_length': 2,
            \ 'is_volatile': 1,
            \ 'hooks' : {},
            \ 'action_table': {},
            \ 'syntax' : 'uniteSource__Character'
            \ }

let s:command = expand('<sfile>:p:h').'/unum.pl n="%s"'

let s:unite_source.action_table.insert= {
            \ 'description' : 'insert the character',
            \ 'is_quit' : 1,
            \ }

function! s:unite_source.action_table.insert.func(candidate)
    let @" = matchstr(a:candidate.word, '"\zs.*\ze"')
    normal p
endfunction

function! s:unite_source.hooks.on_syntax(args, context)
    syntax match uniteSource__Character_html /&[^;]*;/ contained containedin=uniteSource__Character
    syntax match uniteSource__Character_desc /[ a-zA-Z]*$/ contained containedin=uniteSource__Character contains=uniteCandidateInputKeyword
    syntax match uniteSource__Character_char /"[^"]*"/ contained containedin=uniteSource__Character contains=uniteCandidateInputKeyword
    syntax match uniteSource__Character_hex /0x[0-9A-F]*/ contained containedin=uniteSource__Character contains=uniteCandidateInputKeyword
    highlight default link uniteSource__Character_html Constant
    highlight default link uniteSource__Character_desc Keyword
    highlight default link uniteSource__Character_char Define
    highlight default link uniteSource__Character_hex  Type
endfunction

function! s:unite_source.gather_candidates(args, context)
    return map(
                \ split(
                \   unite#util#system(printf(
                \     s:command,
                \     a:context.input)),
                \   "\n"),
                \ '{"word": v:val,
                \ "kind": "word",
                \ "source": "character",
                \ }')
endfunction

function! unite#sources#character#define()
    return s:unite_source
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo

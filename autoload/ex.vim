" ex#hint {{{1
" msg: string
function ex#hint(msg)
    silent echohl ModeMsg
    "echon slow to show ?
    " echon a:msg
    echomsg a:msg
    silent echohl None
endfunction

" ex#warning {{{1
" msg: string
function ex#warning(msg)
    silent echohl WarningMsg
    echomsg a:msg
    silent echohl None
endfunction

" ex#error {{{1
" msg: string
function ex#error(msg)
    silent echohl ErrorMsg
    echomsg 'Error(exVim): ' . a:msg
    silent echohl None
endfunction

" ex#debug {{{1
" msg: string
function ex#debug(msg)
    silent echohl Special
    echom 'Debug(exVim): ' . a:msg . ', ' . expand('<sfile>') 
    silent echohl None
endfunction

" ex#short_message {{{1
" short the msg 
function ex#short_message( msg )
   if len( a:msg ) <= &columns-13
       return a:msg
   endif

   let len = (&columns - 13 - 3) / 2
   return a:msg[:len] . "..." . a:msg[ (-len):] 
endfunction

" ex#register_plugin {{{1

" registered plugin used in exVim to make sure the current buffer is a
" plugin buffer.
" this is done by first check the filetype, and go through each item and 
" make sure the option of the buffer is same as the option you provide
" NOTE: if the filetype is empty, exVim will use '__EMPTY__' rules to check  
" your buffer
" DISABLE: we use ex#register_plugin instead
" let s:registered_plugin = {
"             \ 'explugin': [],
"             \ 'exproject': [], 
"             \ 'minibufexpl': [ { 'bufname': '-MiniBufExplorer-', 'buftype': 'nofile' } ], 
"             \ 'taglist': [ { 'bufname': '__Tag_List__', 'buftype': 'nofile' } ],
"             \ 'tagbar': [ { 'bufname': '__TagBar__', 'buftype': 'nofile' } ],
"             \ 'nerdtree': [ { 'bufname': 'NERD_tree_\d\+', 'buftype': 'nofile' } ], 
"             \ 'undotree': [ { 'bufname': 'undotree_\d\+', 'buftype': 'nowrite' } ],
"             \ 'diff': [ { 'bufname': 'diffpanel_\d\+', 'buftype': 'nowrite' } ], 
"             \ 'gitcommit': [], 
"             \ 'gundo': [],
"             \ 'vimfiler': [], 
"             \ '__EMPTY__': [ { 'bufname': '-MiniBufExplorer-' } ]
"             \ }
let s:registered_plugin = {}

" debug print of registered plugins
function ex#echo_registered_plugins ()
    silent echohl Statement
    echo 'List of registered plugins:'
    silent echohl None

    for [k,v] in items(s:registered_plugin)
        if empty(v)
            echo k . ': {}'
        else
            for i in v
                echo k . ': ' . string(i) 
            endfor
        endif
    endfor
endfunction

" filetype: the filetype you wish to register as plugin, can be ''
" options: buffer options you wish to check
" special options: bufname, winpos
function ex#register_plugin ( filetype, options )
    let filetype = a:filetype
    if filetype == ''
        let filetype = '__EMPTY__'
    endif

    " get rules by filetype, if not found add new rules
    let rules = []
    if !has_key( s:registered_plugin, filetype )
        let s:registered_plugin[filetype] = rules
    else
        let rules = s:registered_plugin[filetype]
    endif

    " check if we have options
    if !empty(a:options)
        silent call add ( rules, a:options ) 
    endif
endfunction

" ex#is_registered_plugin {{{1
function ex#is_registered_plugin ( bufnr, ... )
    " if the buf didn't exists, don't do anything else
    if !bufexists(a:bufnr)
        return 0
    endif

    let bufname = bufname(a:bufnr)
    let filetype = getbufvar( a:bufnr, '&filetype' )

    " if this is not empty filetype, use regular rules for buffer checking
    if filetype == ''
        let filetype = "__EMPTY__"
    endif

    " get rules directly from registered dict, if rules not found, 
    " simply return flase because we didn't register the filetype
    if !has_key( s:registered_plugin, filetype )
        return 0
    endif

    " if rules is empty, which means it just need to check the filetype
    let rules = s:registered_plugin[filetype]
    if empty(rules)
        return 1
    endif

    " check each rule dict to make sure this buffer meet our request
    for ruledict in rules 
        let failed = 0

        for key in keys(ruledict) 
            " NOTE: this is because the value here can be list or string, if
            " we don't unlet it, it will lead to E706 
            if exists('l:value')
                unlet value
            endif
            let value = ruledict[key] 

            " check bufname
            if key ==# 'bufname'
                if match( bufname, value ) == -1
                    let failed = 1
                    break
                endif

                continue
            endif

            " skip autoclose
            if key ==# 'actions'
                if a:0 > 0
                    silent call extend( a:1, value )
                endif
                continue
            endif

            " check other option
            let bufoption = getbufvar( a:bufnr, '&'.key )
            if bufoption !=# value 
                let failed = 1
                break
            endif
        endfor

        " congratuation, all rules passed!
        if failed == 0
            return 1
        endif
    endfor 

    return 0
endfunction

function ex#smartcasecompare( text, pattern ) " <<<
    if match(a:pattern, '\u') != -1 " if we have upper case, use case compare
        return match ( a:text, '\C'.a:pattern ) != -1
    else " ignore case compare
        return match ( a:text, a:pattern ) != -1
    endif 
endfunction " >>>

" ex#set_symbol_path {{{1
function ex#set_symbol_path( path )
    let s:symbols_file = a:path
endfunction

" ex#compl_by_symbol {{{1
function ex#compl_by_symbol( arg_lead, cmd_line, cursor_pos )
    if !exists ('s:symbols_file') || findfile(s:symbols_file) == '' 
        return
    endif

    let filter_tag = []
    let tags = readfile( s:symbols_file )

    let pattern = '^'.a:arg_lead.'.*'
    for tag in tags
        if ex#smartcasecompare ( tag, pattern)
            silent call add ( filter_tag, tag )
        endif
    endfor
    return filter_tag
endfunction

function ex#getfilename( text ) " <<<
    let line = ''
    " if it is a file
    if match(a:text,'[^^]-\C\[[^F]\]') != -1
        let line = a:text
        let line = substitute(line,'.\{-}\[.\{-}\]\(.\{-}\)','\1','')
        let idx_end_1 = stridx(line,' {')
        let idx_end_2 = stridx(line,' }')
        if idx_end_1 != -1
            let line = strpart(line,0,idx_end_1)
        elseif idx_end_2 != -1
            let line = strpart(line,0,idx_end_2)
        endif
    endif
    return line
endfunction " >>>
" ex#compl_by_prjfile {{{1
function ex#compl_by_prjfile( arg_lead, cmd_line, cursor_pos ) " <<<
    let filter_files = []
    if exists ('g:ex_project_file')
        let project_files = readfile(g:ex_project_file)
        for file_line in project_files
            let file_name = ex#getfilename (file_line)
            if ex#smartcasecompare( file_name, '^'.a:arg_lead.'.*' )
                silent call add ( filter_files, file_name )
            endif
        endfor
    endif
    return filter_files
endfunction " >>>

" ex#set_restore_info {{{1
let s:restore_info = './restore_info'
function ex#set_restore_info(path)
    let s:restore_info = a:path
endfunction

" ex#restore_lasteditbuffers {{{1
function ex#restore_lasteditbuffers()
    if findfile(s:restore_info) != '' 
        call ex#window#goto_edit_window()
        let cmdlist = readfile(s:restore_info)
        let needJump = 0

        " load all buffers
        for cmd in cmdlist 
            if stridx(cmd, 'badd') == 0
                let filename = strpart( cmd, 4 )
                if findfile(filename) != '' 
                    silent exec 'edit '.filename
                    doautocmd BufAdd,BufRead
                endif
            elseif stridx(cmd, 'edit') == 0 
                let filename = strpart( cmd, 4 )
                if findfile(filename) != '' 
                    let needJump = 1
                    silent exec cmd 
                endif
            elseif stridx(cmd, 'call') == 0 
                if needJump != 0
                    silent exec cmd 
                endif
            endif
        endfor

        " go to last edit buffer
        if &filetype != 'vimentry'
            doautocmd BufRead,BufEnter,BufWinEnter
        endif
    endif
endfunction

" ex#save_restore_info {{{1
function ex#save_restore_info()
    let nb_buffers = bufnr('$')     " Get the number of the last buffer.
    let idx = 1                     " Set the buffer index to one, NOTE: zero is represent to last edit buffer.
    let cmdlist = []

    " store listed buffers
    while idx <= nb_buffers
        if getbufvar( idx, '&buflisted') == 1
            silent call add ( cmdlist, "badd " . bufname(idx) )
        endif
        let idx += 1
    endwhile

    " save the last edit buffer detail info
    " call exUtility#GotoEditBuffer()
    call ex#window#goto_edit_window()
    let last_buf_nr = bufnr('%')
    if getbufvar( last_buf_nr, '&buflisted') == 1
        " load last edit buffer
        silent call add ( cmdlist, "edit " . bufname(last_buf_nr) )
        let save_cursor = getpos(".")
        silent call add ( cmdlist, "call cursor(" . save_cursor[1] . "," . save_cursor[2] . ")" )
    endif

    "
    call writefile( cmdlist, s:restore_info)
endfunction

function ex#InsertIFZero() range " <<<
    let lstline = a:lastline + 1 
    call append( a:lastline , "#endif")
    call append( a:firstline -1 , "#if 0")
    silent exec ":" . lstline
endfunction " >>>

" ------------------------------------------------------------------ 
" Desc: 
" ------------------------------------------------------------------ 

function ex#RemoveIFZero() range " <<<
    " FIXME: when line have **, it will failed
    let save_cursor = getpos(".")
    let save_line = getline(".")
    let cur_line = save_line

    let if_lnum = -1
    let else_lnum = -1
    let endif_lnum = -1

    " found '#if 0' first
    while match(cur_line, "#if.*0") == -1
        let cur_line_nr = line(".")
        silent normal! [#
        let cur_line = getline(".")
        let lnum = line(".")
        if lnum == cur_line_nr
            if match(cur_line, "#if.*0") == -1
                call ex#warning(" not #if 0 matched")
                silent call cursor(save_cursor[1], save_cursor[2])
                return
            endif
        endif
    endwhile

    " record the line
    let if_lnum = line(".")
    silent normal! ]#
    let cur_line = getline(".")
    if match(cur_line, "#else") != -1
        let else_lnum = line(".")
        silent normal! ]#
        let endif_lnum = line(".")
    else
        let endif_lnum = line(".")
    endif

    " delete the if/else/endif
    if endif_lnum != -1
        silent exe endif_lnum
        silent normal! dd
    endif
    if else_lnum != -1
        silent exe else_lnum
        silent call setline('.',"// XXX #else XXX")
    endif
    if if_lnum != -1
        silent exe if_lnum
        silent normal! dd
    endif

    silent call setpos('.', save_cursor)
    if match(save_line, "#if.*0") == -1 && match(save_line, "#endif.*") == -1
        silent call search('\V'.save_line, 'b')
    endif
    silent call cursor(line('.'), save_cursor[2])
    if match(save_line, "#endif.*") != -1
        silent normal! kk
    endif
endfunction " >>>

" ------------------------------------------------------------------ 
" Desc: TODO: check if the last character is space, if not, add space
"       TODO: used the longest column as the base column to insert \
" ------------------------------------------------------------------ 

function ex#InsertRemoveExtend() range " <<<
    let line = getline('.')
    if (strpart(line,strlen(line)-1,1) == "\\")
        exec ":" . a:firstline . "," . a:lastline . "s/\\\\$//"
    else
        exec ":" . a:firstline . "," . a:lastline . "s/$/ \\\\/"
    endif
endfunction " >>>
" vim:ts=4:sw=4:sts=4 et fdm=marker:

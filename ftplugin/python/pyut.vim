" File:        pyut.vim
" Description: Runs the current test Class/Method/File
" Maintainer:  Alex Meade
"============================================================================


if exists("g:loaded_pyut") || &cp
  finish
endif

if(!exists("g:pyut_shell_command"))
    let g:pyut_shell_command = "nosetests " "Nose Tests
endif

if(!exists("g:pyut_class_delimiter"))
    let g:pyut_class_delimiter = ":"
endif

if(!exists("g:pyut_method_delimiter"))
    let g:pyut_method_delimiter = "."
endif


" Global variables
let g:pyut_last_session      = ""


function! s:Echo(msg, ...)
    redraw!
    let x=&ruler | let y=&showcmd
    set noruler noshowcmd
    if (a:0 == 1)
        echo a:msg
    else
        echohl WarningMsg | echo a:msg | echohl None
    endif

    let &ruler=x | let &showcmd=y
endfun


" Always goes back to the first instance
" and returns that if found
function! s:FindPythonObject(obj)
    let orig_line   = line('.')
    let orig_col    = col('.')
    let orig_indent = indent(orig_line)

    if (a:obj == "class")
        let objregexp  = '\v^\s*(.*class)\s+(\w+)\s*'
    elseif (a:obj == "method")
        let objregexp = '\v^\s*(.*def)\s+(\w+)\s*\(\s*(self[^)]*)'
    endif

    let flag = "Wb"

    while search(objregexp, flag) > 0
        if orig_indent > 0
            if orig_indent > indent(line('.'))
                return 1
            endif
        endif
        return 1
    endwhile

endfunction


function! s:NameOfCurrentClass()
    let save_cursor = getpos(".")
    normal $<cr>
    let find_object = s:FindPythonObject('class')
    if (find_object)
        let line = getline('.')
        call setpos('.', save_cursor)
        let match_result = matchlist(line, ' *class \+\(\w\+\)')
        return match_result[1]
    endif
endfunction


function! s:NameOfCurrentMethod()
    let save_cursor = getpos(".")
    normal $<cr>
    let find_object = s:FindPythonObject('method')
    if (find_object)
        let line = getline('.')
        call setpos('.', save_cursor)
        let match_result = matchlist(line, ' *def \+\(\w\+\)')
        return match_result[1]
    endif
endfunction


function! s:CurrentPath()
    let cwd = expand("%:p")
    return cwd
endfunction


function! s:RunInSplitWindow(path)
    let cmd = g:pyut_shell_command . a:path
    if exists("g:ConqueTerm_Loaded")
        call conque_term#open(cmd, ['split', 'resize 20'], 0)
    else
        let command = join(map(split(cmd), 'expand(v:val)'))
        let winnr = bufwinnr('Pyut.Verbose')
        silent! execute  winnr < 0 ? 'botright new ' . 'Verbose.pyut' : winnr . 'wincmd w'
        setlocal buftype=nowrite bufhidden=wipe nobuflisted noswapfile nowrap number filetype=pyut

        let out = system(command)
        let g:pyut_last_session   = out
        let session = split(g:pyut_last_session, '\n')
        call append(0, session)
        silent! execute 'resize ' . line('$')
        " Do both commands so the last line of output is flush with bottom
        silent! execute 'normal gg'
        silent! execute 'normal G'
        silent! execute 'nnoremap <silent> <buffer> q :q! <CR>'
    endif
endfunction


function! s:LastSession()
    call s:ClearAll()
    if (len(g:pyut_last_session) == 0)
        call s:Echo("There is currently no saved last session to display")
        return
    endif
	let winnr = bufwinnr('LastSession.pyut')
	silent! execute  winnr < 0 ? 'botright new ' . 'LastSession.pyut' : winnr . 'wincmd w'
	setlocal buftype=nowrite bufhidden=wipe nobuflisted noswapfile nowrap number filetype=pyut
    let session = split(g:pyut_last_session, '\n')
    call append(0, session)
	silent! execute 'resize ' . line('$')
    " Do both commands so the last line of output is flush with bottom
    silent! execute 'normal gg'
    silent! execute 'normal G'
    nnoremap <silent> <buffer> q       :call <sid>ClearAll(1)<CR>
    nnoremap <silent> <buffer> <Enter> :call <sid>ClearAll(1)<CR>
    exe 'wincmd p'
endfunction


function! s:ToggleLastSession()
	let winnr = bufwinnr('LastSession.pyut')
    if (winnr == -1)
        call s:LastSession()
    else
        silent! execute winnr . 'wincmd w'
        silent! execute 'q'
        silent! execute 'wincmd p'
    endif
endfunction


function! s:ClearAll(...)
    let bufferL = [ 'LastSession.pyut', 'Verbose.pyut' ]
    for b in bufferL
        let _window = bufwinnr(b)
        if (_window != -1)
            silent! execute _window . 'wincmd w'
            silent! execute 'q'
        endif
    endfor
    " Remove any echoed messages
    if (a:0 == 1)
        " Try going back to our starting window
        " and remove any left messages
        call s:Echo('')
        silent! execute 'wincmd p'
    endif
endfunction


function! s:ResetAll()
    " Resets all global vars
    let g:pyut_last_session      = ""
endfunction!


function! s:RunPyTest(path)
    let g:pyut_last_session = ""
    let cmd = g:pyut_shell_command . a:path
    let out = system(cmd)
    let g:pyut_last_session   = out

    if v:shell_error
        call s:RedBar()
        return
    endif

    call s:GreenBar()
endfunction


function! s:RedBar()
    redraw
    hi RedBar ctermfg=white ctermbg=red guibg=red
    echohl RedBar
    echon repeat(" ",&columns - 1)
    echohl
endfunction


function! s:GreenBar()
    redraw
    hi GreenBar ctermfg=white ctermbg=green guibg=green
    echohl GreenBar
    echon repeat(" ",&columns - 1)
    echohl
endfunction


function! s:GetPath(action, ...)
    let save_cursor = getpos('.')
    call s:ClearAll()
    let abspath     = s:CurrentPath()

    if (a:action == "class")
        let c_name = s:NameOfCurrentClass()
        if (strlen(c_name) == 1)
            call setpos('.', save_cursor)
            call s:Echo("Unable to find a matching class for testing")
            return ""
        endif
        return abspath . g:pyut_class_delimiter . c_name

    elseif (a:action == "method")
        let c_name = s:NameOfCurrentClass()
        let m_name  = s:NameOfCurrentMethod()
        if (strlen(m_name) == 1)
            call setpos('.', save_cursor)
            call s:Echo("Unable to find a matching method for testing")
            return ""
        elseif (strlen(c_name) == 1)
            call setpos('.', save_cursor)
            call s:Echo("Unable to find a matching class for testing")
            return ""
        endif
        return abspath . g:pyut_class_delimiter . c_name . g:pyut_method_delimiter . m_name

    elseif (a:action == "file")
        return abspath
endfunction



function! s:RunTests(verbose, action, ...)
    call s:ClearAll()
    call s:Echo("Running tests for " . a:action, 1)
    let abspath     = s:GetPath(a:action) 
    if strlen(abspath) == 0
        return
    endif

    if (a:verbose == 1)
        call s:RunInSplitWindow(abspath)
    else
        call s:RunPyTest(abspath)
    endif
endfunction


function! s:Version()
    call s:Echo("pyut.vim version 0.3.0dev", 1)
endfunction


function! s:Completion(ArgLead, CmdLine, CursorPos)
    let test_objects = "class\nmethod\nfile\n"
    let optional     = "verbose\nclear\n"
    let reports      = "fails\nsession\nend\n"
    let pyversion    = "version\n"
    return test_objects . reports . optional . pyversion
endfunction


function! s:Proxy(action, ...)
    " Some defaults
    let verbose = 0

    if (a:0 > 0)
        if (a:1 == 'verbose')
            let verbose = 1
        endif
    endif
    if (a:action == "class")
        call s:RunTests(verbose, a:action)
    elseif (a:action == "method")
        call s:RunTests(verbose, a:action)
    elseif (a:action == "file")
        call s:RunTests(verbose, a:action)
    elseif (a:action == "fails")
        call s:ToggleFailWindow()
    elseif (a:action == "session")
        call s:ToggleLastSession()
    elseif (a:action == "clear")
        call s:ClearAll()
        call s:ResetAll()
    elseif (a:action == "version")
        call s:Version()
    else
        call s:Echo("Not a valid Pyut option ==> " . a:action)
    endif
endfunction


command! -nargs=+ -complete=custom,s:Completion Pyut call s:Proxy(<f-args>)


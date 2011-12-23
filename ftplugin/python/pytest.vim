" File:        pytest.vim
" Description: Runs the current test Class/Method/Function/File with
"              py.test
" Maintainer:  Alex Meade
"============================================================================


if exists("g:loaded_pytest") || &cp
  finish
endif


"Configuration Global variables for shell execution
  " for use with Py.Test
"let g:cmd_to_run = "py.test --tb=short " "py.tests
"let g:class_delimiter = "::"
"let g:method_delimiter = "::"
  " for use with Nose Tests
let g:cmd_to_run = "nosetests " "Nose Tests
let g:class_delimiter = ":"
let g:method_delimiter = "."

" Global variables
let g:pytest_last_session      = ""


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
    else
        let objregexp = '\v^\s*(.*def)\s+(\w+)\s*\(\s*(.*self)@!'
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


function! s:NameOfCurrentFunction()
    let save_cursor = getpos(".")
    normal $<cr>
    let find_object = s:FindPythonObject('function')
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
    let cmd = g:cmd_to_run . a:path
    if exists("g:ConqueTerm_Loaded")
        call conque_term#open(cmd, ['split', 'resize 20'], 0)
    else
        let command = join(map(split(cmd), 'expand(v:val)'))
        let winnr = bufwinnr('PytestVerbose.pytest')
        silent! execute  winnr < 0 ? 'botright new ' . 'PytestVerbose.pytest' : winnr . 'wincmd w'
        setlocal buftype=nowrite bufhidden=wipe nobuflisted noswapfile nowrap number filetype=pytest
        silent! execute 'silent %!'. command
        silent! execute 'resize ' . line('$')
        silent! execute 'nnoremap <silent> <buffer> q :q! <CR>'
    endif
endfunction


function! s:LastSession()
    call s:ClearAll()
    if (len(g:pytest_last_session) == 0)
        call s:Echo("There is currently no saved last session to display")
        return
    endif
	let winnr = bufwinnr('LastSession.pytest')
	silent! execute  winnr < 0 ? 'botright new ' . 'LastSession.pytest' : winnr . 'wincmd w'
	setlocal buftype=nowrite bufhidden=wipe nobuflisted noswapfile nowrap number filetype=pytest
    let session = split(g:pytest_last_session, '\n')
    call append(0, session)
	silent! execute 'resize ' . line('$')
    silent! execute 'normal gg'
    nnoremap <silent> <buffer> q       :call <sid>ClearAll(1)<CR>
    nnoremap <silent> <buffer> <Enter> :call <sid>ClearAll(1)<CR>
    exe 'wincmd p'
endfunction


function! s:ToggleLastSession()
	let winnr = bufwinnr('LastSession.pytest')
    if (winnr == -1)
        call s:LastSession()
    else
        silent! execute winnr . 'wincmd w'
        silent! execute 'q'
        silent! execute 'wincmd p'
    endif
endfunction


function! s:ClearAll(...)
    let bufferL = [ 'Fails.pytest', 'LastSession.pytest', 'PytestVerbose.pytest' ]
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
    let g:pytest_last_session      = ""
endfunction!


function! s:RunPyTest(path)
    let g:pytest_last_session = ""
    let cmd = g:cmd_to_run . a:path
    let out = system(cmd)
    let g:pytest_last_session   = out

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


function! s:ThisMethod(verbose, ...)
    let save_cursor = getpos('.')
    call s:ClearAll()
    let m_name  = s:NameOfCurrentMethod()
    let c_name  = s:NameOfCurrentClass()
    let abspath = s:CurrentPath()
    if (strlen(m_name) == 1)
        call setpos('.', save_cursor)
        call s:Echo("Unable to find a matching method for testing")
        return
    elseif (strlen(c_name) == 1)
        call setpos('.', save_cursor)
        call s:Echo("Unable to find a matching class for testing")
        return
    endif

    let path =  abspath . g:class_delimiter . c_name . g:method_delimiter . m_name
    let message = "py.test ==> Running test for method " . m_name
    call s:Echo(message, 1)

    if ((a:1 == '--pdb') || (a:1 == '-s'))
        call s:Pdb(path, a:1)
        return
    endif
    if (a:verbose == 1)
        call s:RunInSplitWindow(path)
    else
       call s:RunPyTest(path)
    endif
endfunction


function! s:ThisFunction(verbose, ...)
    let save_cursor = getpos('.')
    call s:ClearAll()
    let c_name      = s:NameOfCurrentFunction()
    let abspath     = s:CurrentPath()
    if (strlen(c_name) == 1)
        call setpos('.', save_cursor)
        call s:Echo("Unable to find a matching function for testing")
        return
    endif
    let message  = "py.test ==> Running tests for function " . c_name
    call s:Echo(message, 1)

    let path = abspath . g:class_delimiter . c_name

    if ((a:1 == '--pdb') || (a:1 == '-s'))
        call s:Pdb(path, a:1)
        return
    endif

    if (a:verbose == 1)
        call s:RunInSplitWindow(path)
    else
        call s:RunPyTest(path)
    endif
endfunction


function! s:ThisClass(verbose, ...)
    let save_cursor = getpos('.')
    call s:ClearAll()
    let c_name      = s:NameOfCurrentClass()
    let abspath     = s:CurrentPath()
    if (strlen(c_name) == 1)
        call setpos('.', save_cursor)
        call s:Echo("Unable to find a matching class for testing")
        return
    endif
    let message  = "py.test ==> Running tests for class " . c_name
    call s:Echo(message, 1)

    let path = abspath . g:class_delimiter . c_name

    if ((a:1 == '--pdb') || (a:1 == '-s'))
        call s:Pdb(path, a:1)
        return
    endif

    if (a:verbose == 1)
        call s:RunInSplitWindow(path)
    else
        call s:RunPyTest(path)
    endif
endfunction


function! s:ThisFile(verbose, ...)
    call s:ClearAll()
    call s:Echo("py.test ==> Running tests for entire file ", 1)
    let abspath     = s:CurrentPath()

    if ((a:1 == '--pdb') || (a:1 == '-s'))
        call s:Pdb(abspath, a:1)
        return
    endif

    if (a:verbose == 1)
        call s:RunInSplitWindow(abspath)
    else
        call s:RunPyTest(abspath)
    endif
endfunction


function! s:Pdb(path, ...)
    let pdb_command = "py.test " . a:1 . " " . a:path
    if exists("g:ConqueTerm_Loaded")
        call conque_term#open(pdb_command, ['split', 'resize 20'], 0)
    else
        exe ":!" . pdb_command
    endif
endfunction


function! s:Version()
    call s:Echo("pytest.vim version 1.1.0dev", 1)
endfunction


function! s:Completion(ArgLead, CmdLine, CursorPos)
    let test_objects = "class\nmethod\nfile\n"
    let optional     = "verbose\nclear\n"
    let reports      = "fails\nsession\nend\n"
    let pyversion    = "version\n"
    let pdb          = "--pdb\n-s\n"
    return test_objects . reports . optional . pyversion . pdb
endfunction


function! s:Proxy(action, ...)
    " Some defaults
    let verbose = 0
    let pdb     = 'False'

    if (a:0 > 0)
        if (a:1 == 'verbose')
            let verbose = 1
        elseif (a:1 == '--pdb')
            let pdb = '--pdb'
        elseif (a:1 == '-s')
            let pdb = '-s'
        endif
    endif
    if (a:action == "class")
        call s:ThisClass(verbose, pdb)
    elseif (a:action == "method")
        call s:ThisMethod(verbose, pdb)
    elseif (a:action == "function")
        call s:ThisFunction(verbose, pdb)
    elseif (a:action == "file")
        call s:ThisFile(verbose, pdb)
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
        call s:Echo("Not a valid Pytest option ==> " . a:action)
    endif
endfunction


command! -nargs=+ -complete=custom,s:Completion Pytest call s:Proxy(<f-args>)


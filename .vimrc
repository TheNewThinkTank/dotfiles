set nocompatible  "vim over vi
filetype off  "disable filetype before Vundle

" set runtime path
set rtp+=~/.vim/bundle/Vundle.vim

" call Vundle
call vundle#begin()

" add plugins
Plugin 'VundleVim/Vundle.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'scrooloose/nerdtree'
Plugin 'majutsushi/tagbar'
Plugin 'ctrlpvim/ctrlp.vim'
" Plugin 'junegunn/fzf'
Plugin 'tpope/vim-surround'
" Plugin 'valloric/youcompleteme'  " requires a vim version with Python3
" support
" support
" Plugin 'neoclide/coc.nvim'
Plugin 'tpope/vim-fugitive'  " git integration
Plugin 'tiagofumo/vim-nerdtree-syntax-highlight'
Plugin 'xuyuanp/nerdtree-git-plugin'
Plugin 'dense-analysis/ale'
" Plugin 'puremourning/vimspector'  " requires a vim version with Python3 support

" end Vundle
call vundle#end()
filetype plugin indent on
set title

" core environment
syntax on
set hlsearch
set number
set ruler
set mouse=a
set spell spelllang=en_us

" indentation / tabbing
set autoindent
set softtabstop=2
set tabstop=2
set shiftwidth=2
set expandtab

set list listchars=tab:\ \ ,trail:·
set showbreak=//

set noerrorbells
set novisualbell
set backup
set swapfile

" plugin configurations
" autocmd VimEnter * NERDTree | wincmd p  " start NERDTree automatically, and ensure platform agnostic
" autocmd VimEnter * NERDTree  " Enable if NERDTree should have the active cursor by default on start of vim
let NERDTreeQuitOnOpen=1
nmap <F8> :TagbarToggle<CR>
" nmap <F5> <Plug>VimspectorContinue<CR>
" nmap <F6> <Plug>VimspectorStop<CR>
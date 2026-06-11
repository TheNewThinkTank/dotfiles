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
Plugin 'tpope/vim-surround'
Plugin 'tpope/vim-fugitive'  " git integration
Plugin 'tiagofumo/vim-nerdtree-syntax-highlight'
Plugin 'xuyuanp/nerdtree-git-plugin'
Plugin 'dense-analysis/ale'

" end Vundle
call vundle#end()
filetype plugin indent on
set title

" core environment
syntax on
set hlsearch
set incsearch       " show matches as you type
set ignorecase      " ignore case in searches
set smartcase       " unless you use uppercase
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
set backupdir=~/.vim/backup//     " keep backups organized
set swapfile
set directory=~/.vim/swaps//      " keep swaps organized
set undofile                       " enable persistent undo
set undodir=~/.vim/undo//         " organize undo history

" UI improvements
set scrolloff=5     " keep 5 lines visible when scrolling
set sidescroll=5
set cursorline      " highlight current line

" Performance
set lazyredraw      " faster scrolling
set ttyfast

" plugin configurations
let NERDTreeQuitOnOpen=1
nmap <F8> :TagbarToggle<CR>

" Key mappings - move lines up and down with Alt+j and Alt+k
nnoremap <A-j> :m+1<CR>==
nnoremap <A-k> :m-2<CR>==

" Visual mode line movement
vnoremap <A-j> :m'>+1<CR>gv=gv
vnoremap <A-k> :m'<-2<CR>gv=gv

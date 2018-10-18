#!/bin/bash

WORKDIR=$(pwd)

# use vim, nvim, or 'gvim --nofork'
usage() {
  cat <<EOF
usage: $0 [vim] [--exit] [--plug-dir <plugdir>] [--tdd]
requires vader.vim, fzf, vim-projectionist installed in plugdir

args:
  vim         defaults to nvim
  --exit      if '--exit', exits vim after running vader,
              outputs test results otherwise stays open
  --plug-dir  defaults to parent directory of
              fuzzy-projectionist.vim/
  --tdd       restart vim in a loop
              to stop, delete the file 'tdd-run'
              (or use provided mappings ,r to restart,
               or ,q to exit permanently)


examples:
  from ~/.vim/bundle/fuzzy-projectionist.vim
    ./test/run.sh
    ./test/run.sh vim noexit
    ./test/run.sh 'gvim --nofork'
  from elsewhere
    ./test/run.sh nvim --plug-dir \$HOME/.vim/bundle
    ./test/run.sh nvim --plug-dir \$HOME/.config/nvim/plugged

EOF
exit
}

VIM=""
EXIT=""
TDD=0
TESTDIR=`cd "$(dirname "$0")"; pwd`
FZPDIR=$(cd "$TESTDIR/.."; pwd)
PLUGDIR=$(cd "$FZPDIR/.."; pwd)

while true; do
  case "$1" in
    "--help"|"-h") usage
      ;;
    "--exit") EXIT="!"; shift 1
      ;;
    "--tdd") TDD=1; shift 1
      ;;
    "--plug-dir") PLUGDIR="$(cd "$2"; pwd)"; shift 2
      ;;
    "") break ;;
    *)
      if [[ "$VIM" == "" ]]; then
        VIM="$1"
        shift 1
      else
        echo 'unrecognised: '$1;
        exit 1
      fi
      ;;
  esac
done

if [[ $TDD -eq 1 ]]; then EXIT=""; fi

VIM="${VIM:=nvim}"

vimcmd=$(echo "$VIM" | awk '{print $1}')

if [ "$VIM" != "" ] && ! hash $vimcmd 2>/dev/null; then
  echo "could not find $vimcmd in PATH, trying plain vim"
  VIM=vim
fi
if ! hash vim 2>/dev/null; then
  echo "could not find $VIM in PATH"
  exit 1
fi

run() {
  if [ "$EXIT" == "!" ]; then TEMP=$(mktemp); fi

VADER_OUTPUT_FILE=${TEMP:-} $VIM -Nu <(cat << EOF
filetype off
set rtp+=$PLUGDIR/vader.vim
set rtp+=$PLUGDIR/fzf
set rtp+=$PLUGDIR/vim-projectionist
set rtp+=$FZPDIR
filetype plugin indent on
syntax enable
colors desert256
nmap ,r :qall<cr>
nmap ,q :!rm '$WORKDIR/tdd-run'<cr>:qall<cr>
cd $TESTDIR
EOF) "+Vader${EXIT}./*"

  if [ "$EXIT" == "!" ]; then
    cat $TEMP
    rm -f $TEMP
  fi
}

if [[ $TDD -eq 1 ]]; then
touch tdd-run
  while test -f tdd-run; do
    run
  done
else
  run
fi

exit $?

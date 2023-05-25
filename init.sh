#!/usr/bin/env zsh

CONFIG_PREFIX=${CONFIG_PREFIX:-"config"}
INSTALLER_USER=${INSTALLER_USER:-"sabinmarcu"}
INSTALLER_REPO=${INSTALLER_REPO:-"${INSTALLER_USER}/${CONFIG_PREFIX}"}
GITHUB_DOMAIN=${GITHUB_DOMAIN:-"github.com"}
GITHUB_SSH=${GITHUB_SSH:-"git@${GITHUB_DOMAIN}:"}
GITHUB_HTTPS=${GITHUB_HTTPS:-"https://${GITHUB_DOMAIN}/"}
GITHUB_HOST=${GITHUB_HOST:-$GITHUB_HTTPS}
INSTALLER_URL=${INSTALLER_URL:-"${GITHUB_HTTPS}${INSTALLER_REPO}/tree/main/"}
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
INSTALLER_USER_REPOS_URL=${INSTALLER_USER_REPOS_URL:-"https://api.github.com/users/${INSTALLER_USER}/repos"}
URL_FIELD="clone_url"
PRINT_HELP=${PRINT_HELP:-0}
PRINT_LIST=${PRINT_LIST:-0}

TMP_DIR=${TMP_DIR:-$(mktemp -d)}
function cleanup_temp {
  rm -rf $WORK_DIR
}
trap cleanup_temp EXIT

args=()
while [ $OPTIND -le "$#" ]; do
  if getopts ":lhs" option; then
    case $option in
      l) PRINT_LIST=1;;
      s) 
        GITHUB_HOST=${GITHUB_SSH}; 
        URL_FIELD="ssh_url"
      ;;
      h) PRINT_HELP=1;;
    esac
  else
    args+=(${@:$OPTIND:1})
    ((OPTIND++))
  fi
done

if [ $PRINT_HELP = 1 ]; then
  echo "HELP"
  exit 0
fi;


function read_with_curl {
  curl -L $@
}

function read_with_wget {
  wget -qO- $@
}

function read_url {
  if command -v curl &> /dev/null; then
    read_with_curl $1 $2
  elif command -v wget &> /dev/null; then
    read_with_wget $1 $2
  else 
    echo "Need either wget or curl. Please install either."
    exit 1
  fi
}

repos_list=(${(@f)$(read_url $INSTALLER_USER_REPOS_URL &> /dev/null | grep "${CONFIG_PREFIX}" | grep "${URL_FIELD}" | tr -s " " | cut -d " " -f3 | sed -E "s/\"(.*)\",?/\1/")})

echo $repos_list


typeset -A tools=()
for repo in $repos_list; do
  repo_short=$(echo $repo | sed -E "s/.*(${CONFIG_PREFIX}\..*)\.git$/\1/")
  tool=$(echo $repo_short | cut -d "." -f2)
  tools+=(
    $tool $repo
  )
done

if [ $PRINT_LIST = 1 ]; then
  echo "LIST"
  exit 0
fi

function install_tool {
  local tool=$1
  local tool_repo=$tools[$tool]
  local tool_path="${XDG_CONFIG_HOME}/${tool}"
  local config_path="${tool_path}/${CONFIG_SCRIPT_NAME}.zsh"

  echo $tool_path
  if [ -d $tool_path ]; then
    local tool_path_old="$tool_path.old"
    if read -qs "?$tool_path exists. Rename to $tool_path_old? "; then
      echo $REPLY
      mv $tool_path $tool_path_old
    elif echo $REPLY && read -qs "?In that case, remove? "; then
      echo $REPLY
      rm -rf $tool_path
    else
      echo $REPLY
      exit 1
    fi
  fi

  echo "\033[34m - Installing: \033[34;1m${tool}\033[0m"
  git clone $tool_repo $tool_path --depth 1

  if [ -f $config_path ]; then
    echo "\033[34m  Running repo configure script\033[0m"
    echo source $config_path
  fi
  echo "\033[32m ✓ Done with \033[32;1m${tool}\033[0m"
}

toolsToInstall=()
for arg in $args; do
  if [ -z $CMD ]; then
    CMD=$arg
  elif [ ! -z ${tools[(Ie)$arg]} ]; then
    toolsToInstall+=($arg)
  else
    echo "\033[33;4m⚠ Unknown tool: $arg\033[0m"
  fi
done

case $CMD in
  install)
    if [ ! -n "$toolsToInstall" ]; then
      toolsToInstall=(${(k)tools})
    fi
    echo "\033[34m  Installing: \033[34;2m${toolsToInstall}\033[0m"
    for tool in $toolsToInstall; do
      install_tool $tool;
    done
  ;;
  *) echo "Unknown command ${CMD}"; exit 1;;
esac

# this is only intended be referenced by scripts in the bin/
# directory, but it could be expanded.
#
# TODO validate vars from mirror.conf, rather than just reading them in

function read_config
{
  local self=$(realpath -e "${BASH_SOURCE[0]}")
  local selfdir=$(dirname "$self")

  MIRROR_CONFIG="${selfdir}/etc/mirror.conf"
  pushd . &>/dev/null # save current location
  cd "$selfdir"

  for ((i=0; i<100; i++)) # in case of fs loops
  do
    if [[ -r "${MIRROR_CONFIG}" ]]; then
      source "${MIRROR_CONFIG}"
      popd &>/dev/null
      return
    fi
    if [[ "$PWD" == '/' ]]; then break; fi
    cd ..
    MIRROR_CONFIG="$PWD/etc/mirror.conf"
  done

  echo "ERROR: missing config" 2>&1
  exit 1
}

read_config

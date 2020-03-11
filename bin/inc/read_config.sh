# this is only intended be referenced by scripts in the bin/
# directory, but it could be expanded.
#
# TODO **maybe?** walk back up to root looking for ./etc/mirror.conf:
#   while [[ $PWD != / ]]; do
#     cd ..
#     # do stuff
#   done

# TODO validate required vars

function read_config
{
  local self=$(readlink -f "$0")
  local selfdir=$(dirname "$self")

  MIRROR_CONFIG="${selfdir}/../etc/mirror.conf"

  if [[ -r "${MIRROR_CONFIG}" ]]; then
    source "${MIRROR_CONFIG}"
  else
    echo "ERROR: could not read config (${MIRROR_CONFIG})" 2>&1
    exit 1
  fi
}

read_config
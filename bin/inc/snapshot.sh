#!/bin/bash

# tested with:
#   [root@mirror ~]# rpm -q centos-release coreutils findutils rsync
#   centos-release-7-7.1908.0.el7.centos.x86_64
#   coreutils-8.22-23.el7.x86_64
#   findutils-4.5.11-6.el7.x86_64
#   rsync-3.1.2-6.el7_6.1.x86_64
#
#  * rsync 2.6.4+ required for `--link-dest` improvements
#  * coreutils 8.15+ required for `realpath`
#
# TODO - some of these `find`s are a tiny bit sloppy, since there is a
# character termination mismatch between find, sort/head, and filenames--
# which, technically, can contain newlines.  you could muck around with
# temporarily transposing nulls/newlines with something like:
#   function DANCE { tr "\0\n" "\n\0" | "$@" | tr "\n\0" "\0\n"; }
#   find <...> -print0 | DANCE sort -r | DANCE head -n 1
# ...so that downstream programs like sort/head will work perfectly, but
# i swear to christ, if you (or your users) put newlines in file/dir names,
# you deserve some pain and suffering.  if this were to be used as a public
# mirror, you'd probably want to fix this.  on the other hand, if someone
# _did_ manage to write something janky to your filesystem to exploit this,
# you're pretty much bjorked no matter what.  regardless, all the other
# special/shell characters ARE escaped, so i'm not bothering with null
# bullshit RN.  i'm only ever using it as an internal mirror, and ain't
# nobody got time for that.



function snap_ls
{
  local file base path i sym_base=() sym_path=() info out

  # find the symlinks in www/
  while IFS='' read -r -d $'\0' file
  do
    if ! realpath -e "$file" &>/dev/null; then continue; fi
    base=$(basename "$file")
    path=$(realpath "$file")
    sym_base+=("$base")
    sym_path+=("$path")
  done < <(
    find "${MIRROR_BASE_PATH}/www" \
      -maxdepth 1 -type l -print0
  )

  # find snap dirs in www/
  while IFS='' read -r -d $'\0' file
  do

    if ! realpath -e "$file" &>/dev/null; then echo "not realpath $file" continue; fi

    info=''
    base=$(basename "$file")
    path=$(realpath "$file")

    for ((i=0; i<${#sym_path[@]}; i++))
    do
      if [[ "$path" == "${sym_path[i]}" ]]; then
        if [[ -n "$info" ]]; then info="${info}, "; fi
        info="${info}${sym_base[i]}"
      fi
    done

    if [[ -n "$info" ]]; then info="<-- $info"; fi
    printf -v info "%s %s\n" "$base" "$info"
    out="${out}${info}"

  done < <(
    find "${MIRROR_BASE_PATH}/www/" \
      -maxdepth 1 -type d -name 'snap-[0-9]*' -print0
  )

  echo "$out" | sort | sed '/^\s*$/d'
}



# IMPORTANT:  All the snap dirs **MUST** be on the same filesystem.
# Hardlinks are used to save space, and they do not cross filesystem
# boundaries, so tread carefully there.  If you want to, it's possible
# to create latest/ on a separate mount, since it's copied and not
# hardlinked, BUT **ALL** the snap dirs have to stay together.  also,
# TRAILING SLASHES VERY MUCH MATTER because of the special way rsync
# handles them.

function snap_mk
{
  local now=$(date +%Y%m%d%H%M%S)
  local src="${MIRROR_BASE_PATH}/www/latest/"
  local dst="${MIRROR_BASE_PATH}/www/snap-${now}/"
  local tmp="${MIRROR_BASE_PATH}/www/snap-tmp/"
  local opts=(
    '--archive'
    '--numeric-ids'
    '--delete'
    '--delete-excluded'
  )

  if [[ ! -d "$src" ]]; then
    echo "ERROR: source dir missing ($src)" >&2
    exit 1
  fi
  if [[ -f "$dst" ]]; then
    echo "ERROR: destination already exists ($dst)" >&2
    exit 1
  fi

  local last=$(
    find "${MIRROR_BASE_PATH}/www" \
      -maxdepth 1 -type d -name 'snap-[0-9]*' \
      -exec basename {} \; \
      | sort -r \
      | head -n 1
  )

  # the very first time a snap is created (no $last), you need to straight
  # copy the dirs (no hardlinks), so that changes to "latest" do not effect
  # your snaps.  BUT after that, you can save a lot of space by hardlinking
  # unchanged files from snap to snap, which is what `--link-dest` does.
  # IMPORTANT:  `--link-dest` is **relative** to the destination directory!
  if [[ "$last" =~ ^snap-[0-9]+$ ]]; then
    opts+=("--link-dest=../${last}/")
  fi

  # mkdir is doubling as our lock to prevent concurrent runs.  note the
  # intentional absence of the `-p` flag; we don't want a silent ignore.
  if mkdir -m 0755 "$tmp"; then
    rsync "${opts[@]}" "$src" "$tmp"
    touch "$tmp"
    mv "$tmp" "$dst" # also "clears" the lock
  else
    snap_error_locked
  fi
}



# ok, fine.  since we're removing stuff (and that's potentially dangerous),
# i'll handle some of the null/newline nastiness.  remember, in bash, you
# can work with nulls via pipes and escaped strings, but bash variables
# CANNOT store nulls.  bash will simply ignore/skip them, and you'll get
# mismatches because the null characters are missing.

function snap_rm
{
  local file base path i sym_base=() sym_path=()

  if [[ -d "${MIRROR_BASE_PATH}/www/snap-tmp/" ]]; then
    snap_error_locked
  fi

  # build some info about the symlinks in www/
  while IFS='' read -r -d $'\0' file
  do
    if realpath -e "$file" &>/dev/null; then
      base=$(basename "$file")
      path=$(realpath "$file")
      sym_base+=("$base")
      sym_path+=("$path")
    else
      echo "WARN: symlink has no target ($file)"
    fi
  done < <(
    find "${MIRROR_BASE_PATH}/www" \
      -maxdepth 1 -type l -print0
  )

  for file in "$@"
  do

    if [[ ! -e "$file" ]]; then
      echo "WARN: file not found ($file)" >&2
      continue
    fi
    if [[ -L "$file" ]]; then # symlink, short circuit
      rm -f "$file"
      continue
    fi
    if [[ ! -d "$file" ]]; then
      echo "ERROR: not a snapshot dir ($file)"
      continue
    fi
    if [[ ! "$file" =~ ^snap-[0-9]+$ ]]; then
      echo "ERROR: invalid snapshot name ($file)" >&2
      continue
    fi

    path=$(realpath "${MIRROR_BASE_PATH}/www/$file")
    for ((i=0; i<${#sym_path[@]}; i++))
    do
      if [[ "$path" == "${sym_path[i]}" ]]; then
        echo "WARN: skipping $file, symlink target (${sym_base[i]} -> $file)"
        continue 2
      fi
    done

    rm -rf "$path"

  done
}



function snap_ln
{
  local target="$1"
  local linkname="$2"

  if [[ ! "$target" =~ ^snap-[0-9]+$ ]]; then
    echo "ERROR: snapshot name invalid ($target)" >&2
    exit 1
  fi
  if [[ ! -d "${MIRROR_BASE_PATH}/www/$target" ]]; then
    echo "ERROR: snapshot not found ($target)" >&2
    exit 1
  fi
  if [[ ! "$linkname" =~ ^[A-Za-z][A-Za-z0-9\.\_\-]*$ ]]; then
    echo "ERROR: symlink name invalid ($linkname)">&2
    echo "  Rules:"
    echo "  1. must start with a letter"
    echo "  2. only letters, numbers, dashes, underscores, and periods allowed"
    exit 1
  fi
  if [[ -e "${MIRROR_BASE_PATH}/www/$linkname" ]]; then
    echo "ERROR: file exists ($linkname)" >&2
    ls -la "${MIRROR_BASE_PATH}/www/$linkname" |& sed 's/^/  /' >&2
    exit 1
  fi

  cd "${MIRROR_BASE_PATH}/www" \
    && ln -s "$target" "$linkname"
}



function snap_error_locked
{
  echo "ERROR: lock/temp dir found ($tmp)" >&2

  local out=$(pgrep -a rsync)
  local ret=$?

  if [[ $ret -eq 0 ]]; then
    echo "INFO: rsync processes found"
    sed 's/^/  /' <<< "$out"
  elif [[ $ret -eq 1 ]]; then
    echo "INFO: rsync processes not found"
    echo "  (It's probably safe to delete '$tmp'.)"
  else
    echo "ERROR: pgrep failed" >&2
  fi

  exit 1
}

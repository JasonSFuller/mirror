function valid_iso
{
  local iso="$1" # full path
  local sha256="$2"

  if [[ ! -r "$iso" ]]; then
    echo "ERROR: file not found or unreadable ($iso)" >&2
    return 1
  fi
  if [[ ! $sha256 =~ ^[a-f0-9]{64}$ ]]; then
    echo "ERROR: invalid sha256 checksum ($sha256)" >&2
    return 1
  fi

  echo "INFO: verifying iso checksum..."
  echo "  iso    = $iso"
  echo "  sha256 = $sha256"
  if ! sha256sum "$iso" | grep -q "$sha256"; then
    echo "WARN: iso validation failed; checksum mismatch" >&2
    return 1
  fi

  echo "INFO: iso validated; checksum matches"
}



function scrub_iso
{
  local iso="$1" # full path
  local sha256="$2"

  if [[ ! -r "$iso" ]]; then
    echo "ERROR: file not found or unreadable ($iso)" >&2
    return 1
  fi
  if [[ ! $sha256 =~ ^[a-f0-9]{64}$ ]]; then
    echo "ERROR: invalid sha256 checksum ($sha256)" >&2
    return 1
  fi

  if ! valid_iso "$iso" "$sha256"; then
    echo "WARN: removing iso ($iso)"
    iso-umount "$iso"
    rm -f "$iso"
    return 1
  fi

  echo "INFO: mounting iso ($iso)"
  mount_iso "$iso"
}



function download_iso
{
  local file="$1" # short file name only (no path)
  local url="$2" # download URL
  local sha256="$3"
  local isodir="${MIRROR_BASE_PATH}/www/iso"

  if [[ ! -d "$isodir" ]]; then
    echo "ERROR: iso directory not found ($isodir)" >&2
    return 1
  fi
  if [[ ! "$file" =~ \.iso$ ]]; then
    echo "ERROR: invalid filename; must end in '.iso' ($file)" >&2
    return 1
  fi
  if [[ ! "$file" =~ ^[-\.\_A-Za-z0-9]+$ ]]; then
    echo "ERROR: invalid characters in filename ($file)" >&2
    echo "  only alphanumeric, periods, dashes, and underscores allowed." >&2
    return 1
  fi
  if [[ -f "$isodir/$file" ]]; then
    echo "INFO: iso found; scrubbing..."
    if scrub_iso "$isodir/$file" "$sha256"; then
      echo "INFO: skipping download"
      return
    fi
  fi

  # If it failed checksum, it shouldn't be mounted, but Just In Case (tm)...
  umount_iso "$isodir/$file"

  echo    "INFO: beginning download"
  echo    "  url  = $url"
  echo    "  file = $isodir/$file"
  echo    "If the download fails (or is canceled), you can resume with:"
  echo    "  wget -cO '$isodir/$file' '$url'"
  echo -e "Afterwards, you can re-run this script.\n"
  wget -cO "$isodir/$file" "$url"

  echo "INFO: scrubbing iso ($file)"
  return scrub_iso "$isodir/$file" "$sha256"
}



# NOTE:  Normally, these mounting options are sufficient if you ran the
# install.sh script, but sometimes SELinux gives you trouble serving up
# ISO files via httpd if context defaults have not been set properly.
# If so (and you can't fix it the "right" way), try adding this to the
# mount options below:
#   -o ro,context="system_u:object_r:httpd_sys_content_t:s0"

function mount_iso
{
  local iso="$1"

  if [[ ! -r "$iso" ]]; then
    echo "ERROR: file missing or unreadable ($iso)" >&2
    return 1
  fi
  if [[ ! "$iso" =~ \.iso$ ]]; then
    echo "ERROR: invalid filename; must end in '.iso' ($iso)" >&2
    return 1
  fi

  local isobase=$(basename "$iso" .iso)
  local isodir=$(dirname "$iso")
  local isomount="${isodir}/${isobase}"

  if [[ ! -d "$isomount" ]]; then
    echo "INFO: creating dir '$isomount'"
    mkdir "$isomount"
  fi
  if ! mountpoint "$isomount" > /dev/null 2>&1; then
    echo "INFO: mounting '$iso' on '$isomount'"
    mount -t iso9660 -o ro "$iso" "$isomount"
  fi
}



function umount_iso
{
  local iso="$1"

  if [[ ! "$iso" =~ \.iso$ ]]; then
    echo "ERROR: invalid filename; must end in '.iso' ($iso)" >&2
    return 1
  fi

  local isobase=$(basename "$iso" .iso)
  local isodir=$(dirname "$iso")
  local isomount="${isodir}/${isobase}"

  if mountpoint "$isomount" > /dev/null 2>&1; then
    echo "INFO: unmounting '$iso' on '$isomount'"
    umount "$isomount"
  fi
  if [[ -d "$isomount" ]]; then
    echo "INFO: removing mount point dir '$isomount'"
    rmdir "$isomount"
  fi
}



function write_iso_file
{
  local file="$1"
  local type="$2"
  local data="$3"
  if [[ -z "$data" ]]; then data=$(</dev/stdin); fi

  local iso="${MIRROR_BASE_PATH}/www/iso/$file"
  local isobase=$(basename "$iso" .iso)
  local isodir=$(dirname "$iso")
  local isomount="${isodir}/${isobase}"

  if [[ ! "$iso" =~ \.iso$ ]]; then
    echo "ERROR: invalid filename; must end in '.iso' ($iso)" >&2
    return 1
  fi
  if [[ ! -r "$iso" ]]; then
    echo "ERROR: iso missing or unreadable ($iso)" >&2
    return 1
  fi

  case "$type" in
    "repo")
      echo "INFO: writing the repo file for $isobase"
      echo "$data" > "${MIRROR_BASE_PATH}/www/iso/${isobase}.repo" ;;
    "sha256")
      echo "INFO: writing the sha256 checksum for $isobase"
      echo "$data" > "${MIRROR_BASE_PATH}/www/iso/${isobase}.sha256" ;;
    "menu-vanilla")
      echo "INFO: writing the vanilla menu for $isobase"
      echo "$data" > "${MIRROR_BASE_PATH}/tftp/pxelinux.cfg/main-menu.cfg/vanilla.${isobase}.cfg" ;;
    "menu-troubleshooting")
      echo "INFO: writing the troubleshooting menu for $isobase"
      echo "$data" > "${MIRROR_BASE_PATH}/tftp/pxelinux.cfg/main-menu.cfg/troubleshooting.${isobase}.cfg" ;;
    "kickstart-vanilla")
      echo "INFO: writing the vanilla kickstart for $isobase"
      echo "$data" > "${MIRROR_BASE_PATH}/www/ks/vanilla.${isobase}.repo" ;;
    "kickstart-troubleshooting")
      echo "INFO: writing the troubleshooting kickstart for $isobase"
      echo "$data" > "${MIRROR_BASE_PATH}/www/ks/troubleshooting.${isobase}.repo" ;;
    *)
      echo "ERROR: invalid type specified" >&2
      return 1
      ;;
  esac
}

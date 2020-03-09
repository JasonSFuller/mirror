function valid_iso
{
  local iso="$1"
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
  local iso="$1"
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
    "${selfdir}/iso-umount" "$iso"
    rm -f "$iso"
    return 1
  fi

  if [[ ! -f "${iso}.sha256" ]]; then
    echo "INFO: writing checksum file"
    local file=$(dirname "$iso")
    echo "$sha256  $file" > "${iso}.sha256"
  fi

  echo "INFO: mounting iso ($iso)"
  mount_iso "$iso"
}



function download_iso
{
  local url="$1"
  local sha256="$2"
  local iso=$(basename "$url")
  local isodir="${MIRROR_BASE_PATH}/www/iso"

  if [[ ! -d "$isodir" ]]; then
    echo "ERROR: iso directory not found ($isodir)" >&2
    return 1
  fi
  if [[ -f "$isodir/$iso" ]]; then
    echo "INFO: iso found; scrubbing..."
    if scrub_iso "$isodir/$iso" "$sha256"; then
      echo "INFO: skipping download"
      return
    fi
  fi

  echo    "INFO: beginning download"
  echo    "  url  = $url"
  echo    "  file = $isodir/$iso"
  echo    "If the download fails (or is canceled), you can resume with:"
  echo    "  wget -cO '$isodir/$iso' '$url'"
  echo -e "Afterwards, you can re-run this script.\n"
  wget -cO "$isodir/$iso" "$url"

  echo "INFO: scrubbing iso ($iso)"
  scrub_iso "$isodir/$iso" "$sha256"
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

  isobase=$(basename "$iso" .iso)
  isomount="${isodir}/${isobase}"

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
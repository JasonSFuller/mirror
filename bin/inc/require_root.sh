if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: you must be root"
  exit 1
fi
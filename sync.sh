#!/usr/bin/env bash
set -eo pipefail

# Log output formatters
log_heading() {
  echo ""
  echo "==> $*"
}

log_info() {
  echo "-----> $*"
}

log_error_exit() {
  echo " !  Error:"
  echo " !     $*"
  echo " !     Aborting!"
  exit 1
}

#
# Set defaults for all variables that we depend on (if they aren't already set in env).
#

# The source for the sync. This will also be recursively monitored by inotifywatch.
: ${SYNC_SOURCE:="/source"}

# The destination for sync. When files are changed in the source, they are automatically
# synced to the destination.
: ${SYNC_DESTINATION:="/var/www"}

# If set, this script will attempt to increase the inotify limit accordingly.
# This option REQUIRES that the container be run as a privileged container.
: ${SYNC_MAX_INOTIFY_WATCHES:='40000'}

log_heading "Starting bg-sync"

# Dump the configuration to the log to aid bug reports.
log_heading "Configuration:"
log_info "SYNC_SOURCE:                  $SYNC_SOURCE"
log_info "SYNC_DESTINATION:             $SYNC_DESTINATION"
if [ -n "${SYNC_MAX_INOTIFY_WATCHES}" ]; then
  log_info "SYNC_MAX_INOTIFY_WATCHES:     $SYNC_MAX_INOTIFY_WATCHES"
fi

# Validate values as much as possible.
[ -d "$SYNC_SOURCE" ] || log_error_exit "Source directory does not exist!"
[ -d "$SYNC_DESTINATION" ] || log_error_exit "Destination directory does not exist!"
[[ "$SYNC_SOURCE" != "$SYNC_DESTINATION" ]] || log_error_exit "Source and destination must be different directories!"

if [ -z "${SYNC_MAX_INOTIFY_WATCHES}" ]; then
  # If SYNC_MAX_INOTIFY_WATCHES is not set and the number of files in the source
  # is greater than the default inotify limit, warn the user so that they can
  # take appropriate action.
  file_count="$(find $SYNC_SOURCE | wc -l)"
  if [[ "$file_count" < "8192" ]]; then
    log_heading "inotify may not be able to monitor all of your files!"
    log_info "By default, inotify can only monitor 8192 files. The configured source directory"
    log_info "contains $file_count files. It's extremely likely that you will need to increase"
    log_info "your inotify limit in order to be able to sync your files properly."
    log_info "See the documentation for the SYNC_MAX_INOTIFY_WATCHES environment variable"
    log_info "to handle increasing that limit inside of this container."
  fi
else
  # If bg-sync runs with this environment variable set, we'll try to set the config
  # appropriately, but there's not much we can do if we're not allowed to do that.
  log_heading "Attempting to set maximum inotify watches to $SYNC_MAX_INOTIFY_WATCHES"
  log_info "If the container exits with 'Operation not allowed', make sure that"
  log_info "the container is running in privileged mode."
  if [ -z "$(sysctl -p)" ]; then
    echo fs.inotify.max_user_watches=$SYNC_MAX_INOTIFY_WATCHES | tee -a /etc/sysctl.conf && sysctl -p
  else
    log_info "Looks like /etc/sysctl.conf already has fs.inotify.max_user_watches defined."
    log_info "Skipping this step."
  fi
fi

# unison profile added in the Dockerfile.

# Start syncing files.
log_heading "Starting continuous sync."
unison drupal


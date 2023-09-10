#!/bin/bash

########################################
####                                ####
####   Written by Noxyro (C) 2019   ####
####      https://elodrias.de/      ####
####                                ####
####         Version 1.0.0          ####
####                                ####
########################################


#### VARIABLES START ####

CURRENT_DATE=$(date +'%Y_%m_%d')
LATEST_EXTENSION=".latest"

BACKUP_MODE=0x0000
BACKUP_MODE_FULL_NEW=0x0001
BACKUP_MODE_INCREMENTAL=0x0002
BACKUP_MODE_LATEST=0x0004
BACKUP_MODE_LATEST_FULL=0x0008
BACKUP_MODE_REMOTE_SOURCE=0x0010
BACKUP_MODE_REMOTE_SOURCE_DAEMON=0x0020
BACKUP_MODE_REMOTE_DESTINATION=0x0040
BACKUP_MODE_REMOTE_DESTINATION_DAEMON=0x0080

RELATIVE_LINK_DESTINATION=""
FORCE_MODE=0
AUTO_CORRECT=0
VERBOSE=0

#### VARIABLES END ####


#### FUNCTIONS START ####

function get_remote_pattern_type() {
  case $1 in
    rsync://*@*:*/*) echo 6; return;;
    rsync://*:*/*) echo 5; return;;
    *@*::*) echo 4; return;;
    *::*) echo 3; return;;
    *@*:*) echo 2; return;;
    *:*) echo 1; return;;
    *) echo 0; return;;
  esac
}

function run_remote_shell_command() {
    case $# in
    2)
      ssh -i "***REMOVED***" "${2}" "${1}";;
    3)
      ssh -i "***REMOVED***" -l "${3}" "${2}" "${1}";;
    4)
      ssh -i "***REMOVED***" -p "${4}" -l "${3}" "${2}" "${1}";;
    *)
      return 1
  esac
}

function find_directories_with_name() {
  find "${1}" -maxdepth 1 -type d -name "${2}"
}

function find_directories_by_name_with_time_prefix() {
  find "${1}" -maxdepth 1 -type d -name "${2}*" -printf "%T@ %p\n"
}

function find_lines_by_name() {
  echo "${1}" | grep -e "${2}"
}

function get_last_sorted_by_time() {
   echo "${1}" | sort -n | cut -d' ' -f 2- | tail -n 1
}

function find_remote_directories_by_name_with_time_prefix() {
  case $# in
    3)
      ssh -i "***REMOVED***" "${3}" "find ${1} -maxdepth 1 -type d -name ${2} -printf \"%T@ %p\n\"";;
    4)
      ssh -i "***REMOVED***" -l "${4}" "${3}" "find ${1} -maxdepth 1 -type d -name ${2} -printf \"%T@ %p\n\"";;
    5)
      ssh -i "***REMOVED***" -p "${5}" -l "${4}" "${3}" "find ${1} -maxdepth 1 -type d -name ${2} -printf \"%T@ %p\n\"";;
    *)
      echo "-1"
  esac
}

function find_latest_directory_with_name() {
  find "${DESTINATION}" -maxdepth 1 -type d -name "${NAME}*" -printf "%T@ %p\n" | sort -n | cut -d' ' -f 2- | tail -n 1
}

function confirm_backup_location() {
  echo "Contents of \"${1}\" will now be backed up to \"${2}\" using \"${3}\" as link destination"
	read -r -p "Continue? (Y/N): " CONFIRM_BACKUP && [[ $CONFIRM_BACKUP == [yY] || $CONFIRM_BACKUP == [yY][eE][sS] ]] || exit 1
}

function rename_old() {
  if [[ ! -d ${1} ]]; then
    return 1
  fi

	if [[ -d ${2} ]]; then
		if [[ VERBOSE -eq 1 ]]; then echo "Existing old backup(s) found."; fi

		local OLD="${2}.old"
		local OLD_COUNT=1

		while [[ -d "${OLD}" ]]; do
			OLD_COUNT=$((OLD_COUNT + 1))
			OLD="${2}.old.${OLD_COUNT}"
		done

		if [[ VERBOSE -eq 1 ]]; then echo "Renaming to \"${OLD}\" ..."; fi
		mv "${1}" "${OLD}"
	else
	  mv "${1}" "${2}"
	fi

	return 0
}

function rsync_backup() {
  echo "=== Backup process started at $(date +%Y-%m-%d\ %H:%M:%S.%3N) ==="

  if [[ $# -gt 2 ]]; then
    rsync -avh --delete --progress --link-dest="${3}" "${1}" "${2}"
  else
    rsync -avh --delete --progress "${1}" "${2}"
  fi

  echo "=== Backup process finished at $(date +%Y-%m-%d\ %H:%M:%S.%3N) ==="
}

function run_backup() {
  if [[ ${FORCE_MODE} -eq 0 ]]; then
    confirm_backup_location "${1}" "${2}/${3}_${CURRENT_DATE}${LATEST_EXTENSION}" "$(basename "${4}" ${LATEST_EXTENSION})"
  fi

  if [[ $# -gt 3 && ${4} != "" ]]; then
      rename_old "${4}" "${2}/$(basename "${4}" ${LATEST_EXTENSION})"
      sleep 1
      rsync_backup "${SOURCE}" "${2}/${3}_${CURRENT_DATE}${LATEST_EXTENSION}" "${5}${2}/$(basename "${4}" ${LATEST_EXTENSION})"
  else
    rename_old "${2}/${3}_${CURRENT_DATE}${LATEST_EXTENSION}" "${2}/$(basename "${3}_${CURRENT_DATE}${LATEST_EXTENSION}" ${LATEST_EXTENSION})"
    sleep 1
    rsync_backup "${SOURCE}" "${2}/${3}_${CURRENT_DATE}${LATEST_EXTENSION}"
  fi
}

function extract_substring_at_index() {
  cut -d "${2}" -f "${3}" <<< "${1}"
}

function extract_substrings_to_lines() {
  cut -d "${2}" -f 1- --output-delimiter=$'\n' <<< "${1}"
}

function extract_line() {
  echo "${1}" | sed "${2}q;d"
}

function extract_remote_info() {
  local REMOTE_INFO
  REMOTE_INFO=$(extract_substring_at_index "${1}" ':' 1)
  extract_substrings_to_lines "$(extract_substring_at_index "${1}" ':' 2):$(extract_substring_at_index "${REMOTE_INFO}" '@' 2):$(extract_substring_at_index "${REMOTE_INFO}" '@' 1)" ':'
}

function extract_remote_daemon_info() {
  if [[ "${1}" == *@*::* || "${1}" == rsync://*@*:*/* ]]; then
    if [[ "${1}" == rsync://*@*:*/* ]]; then
      EXTRACTED_INFO=$(extract_substring_at_index "${1}" '/' 3)
      EXTRACTED_PATH="/$(extract_substring_at_index "${1}" '/' "4-")"
      EXTRACTED_USER=$(extract_substring_at_index "${EXTRACTED_INFO}" '@' 1)
      EXTRACTED_HOST_AND_PORT=$(extract_substring_at_index "${EXTRACTED_INFO}" '@' 2)
      EXTRACTED_HOST=$(extract_substring_at_index "${EXTRACTED_HOST_AND_PORT}" ':' 1)
      EXTRACTED_PORT=$(extract_substring_at_index "${EXTRACTED_HOST_AND_PORT}" ':' 2)
    else
      EXTRACTED_INFO=$(extract_substring_at_index "${1}" ':' 1)
      EXTRACTED_PATH=$(extract_substring_at_index "${1}" ':' 3)
      EXTRACTED_USER=$(extract_substring_at_index "${EXTRACTED_INFO}" '@' 1)
      EXTRACTED_HOST=$(extract_substring_at_index "${EXTRACTED_INFO}" '@' 2)
      EXTRACTED_PORT=""
    fi

    extract_substrings_to_lines "${EXTRACTED_PATH}:${EXTRACTED_HOST}:${EXTRACTED_USER}:${EXTRACTED_PORT}" ':'
  else
    extract_remote_info "${SOURCE}"
  fi
}

function extract_value_from_line() {
  extract_line "${1}" "${2}"
}

#### FUNCTIONS END ####


#### ARGUMENT PARSING START ####

while test $# -gt 0; do
  PARAMS_COUNT=$#
  case "$1" in
    -h|--help)
      echo "command [options] [name@host:]source [name@host:]destination name"
      echo " "
      echo "options:"
      echo "-a, --auto-correct        enables rsync specific path auto-correction"
      echo "-h, --help                show brief help"
      echo "-e EXTENSION              specify an extension used by the last full backup"
      echo "-f, --force               enables force mode, which auto-accepts all dialogs"
      echo "-i FILE                   specify an identification file for remote connections"
      echo "--rsync-params=\"PARAMS\" specify additional rsync parameters passed to all internal calls"
      echo "--ssh-params=\"PARAMS\"   specify additional ssh parameters passed to all internal calls"
      echo "-v, --verbose             shows more verbose command output"
      exit 0
      ;;
    -a|--auto-correct)
      shift; AUTO_CORRECT=1;;
    -e|--extension)
      shift; if test $# -gt 0; then LATEST_EXTENSION=${1}; else echo "no extension specified"; exit 1; fi; shift;;
    -f|--force)
      shift; FORCE_MODE=1;;
    -i)
      shift; if test $# -gt 0; then IDENTIFICATION_FILE=${1}; else echo "no identification file specified"; exit 1; fi; shift;;
    --rsync-params=*)
      shift; RSYNC_PARAMETERS=$(echo "${1}" | cut -d '=' -f 2-); shift;;
    --ssh-params=*)
      shift; SSH_PARAMETERS=$(echo "${1}" | cut -d '=' -f 2-); shift;;
    -v|--verbose)
      shift; VERBOSE=1;;
    *)
      if [[ -z ${SOURCE} ]]; then SOURCE=${1}; fi; shift
      if [[ -z ${DESTINATION} ]]; then DESTINATION=${1}; fi; shift
      if [[ -z ${NAME} ]]; then NAME=${1}; fi; shift
  esac
done

#### ARGUMENT PARSING END ####


#### SCRIPT START ####

if [[ ${PARAMS_COUNT} -eq 0 ]]; then
  read -r -e -p "Enter source for backup: " SOURCE
  read -r -e -p "Enter destination for backup: " DESTINATION
  read -r -e -p "Enter backup name: " NAME
fi

if [[ -z ${SOURCE} ]]; then echo "Error: no source specified"; exit 1; fi
if [[ -z ${DESTINATION} ]]; then echo "Error: no destination specified"; exit 1; fi
if [[ -z ${NAME} ]]; then echo "Error: no NAME specified"; exit 1; fi

# Auto-correcting paths
if [[ $AUTO_CORRECT -eq 1 ]]; then
  if [[ "${SOURCE: -1}" != "/" ]]; then
    SOURCE="${SOURCE}/"
  fi

  if [[ "${DESTINATION: -1}" == "/" ]]; then
    DESTINATION="${DESTINATION: : -1}"
  fi
fi

# Extracting remote source informations
case $(get_remote_pattern_type "${SOURCE}") in
  [1-2]) REMOTE_SOURCE_INFO=$(extract_remote_info "${SOURCE}");;
  [3-6]) REMOTE_SOURCE_INFO=$(extract_remote_daemon_info "${SOURCE}");;
  *) ;;
esac

if [[ -n ${REMOTE_SOURCE_INFO} ]]; then
  BACKUP_MODE=$((BACKUP_MODE | BACKUP_MODE_REMOTE_SOURCE))

  REMOTE_SOURCE_PATH=$(extract_value_from_line "${REMOTE_SOURCE_INFO}" 1)
  REMOTE_SOURCE_HOST=$(extract_value_from_line "${REMOTE_SOURCE_INFO}" 2)
  REMOTE_SOURCE_USER=$(extract_value_from_line "${REMOTE_SOURCE_INFO}" 3)
  REMOTE_SOURCE_PORT=$(extract_value_from_line "${REMOTE_SOURCE_INFO}" 4)
fi

# Extracting remote destination informations
case $(get_remote_pattern_type "${DESTINATION}") in
  [1-2]) REMOTE_DESTINATION_INFO=$(extract_remote_info "${DESTINATION}");;
  [3-6]) REMOTE_DESTINATION_INFO=$(extract_remote_daemon_info "${DESTINATION}");;
  *) ;;
esac

if [[ -n ${REMOTE_DESTINATION_INFO} ]]; then
  BACKUP_MODE=$((BACKUP_MODE | BACKUP_MODE_REMOTE_DESTINATION))

  REMOTE_DESTINATION_PATH=$(extract_value_from_line "${REMOTE_DESTINATION_INFO}" 1)
  REMOTE_DESTINATION_HOST=$(extract_value_from_line "${REMOTE_DESTINATION_INFO}" 2)
  REMOTE_DESTINATION_USER=$(extract_value_from_line "${REMOTE_DESTINATION_INFO}" 3)
  REMOTE_DESTINATION_PORT=$(extract_value_from_line "${REMOTE_DESTINATION_INFO}" 4)
fi

# Check if relative destination is used
if [[ ! "${DESTINATION:0:1}" == "/" || "${DESTINATION:0:2}" == "./" ]]; then
	if [[ VERBOSE -eq 1 ]]; then echo "Using relative destination ..."; fi
	RELATIVE_LINK_DESTINATION="../../"
fi

if [[ VERBOSE -eq 1 ]]; then echo "Checking for previous backups ..."; fi

# Remote destination directory checks
if [[ $((BACKUP_MODE & BACKUP_MODE_REMOTE_SOURCE)) != 0 ]]; then
  if ! run_remote_shell_command "[ -d ${REMOTE_SOURCE_PATH} ]" "${REMOTE_SOURCE_HOST}" "${REMOTE_SOURCE_USER}"; then
    echo "Error: remote source directory \"${REMOTE_SOURCE_PATH}\" does not exist"
    exit 1
  fi
fi

# Remote destination directory checks
if [[ $((BACKUP_MODE & BACKUP_MODE_REMOTE_DESTINATION)) != 0 ]]; then
  PREVIOUS=$(run_remote_shell_command "if [ -d ${REMOTE_DESTINATION_PATH} ]; then find ${REMOTE_DESTINATION_PATH} -maxdepth 1 -type d -name ${NAME}* -printf \"%T@ %p\n\"; else exit 1; fi" "${REMOTE_DESTINATION_HOST}" "${REMOTE_DESTINATION_USER}")
  REMOTE_DESTINATION_FIND_EXIT_CODE=$?
else
  if [[ ! -d ${DESTINATION} ]]; then
    DESTINATION_MISSING=1
  else
    PREVIOUS=$(find_directories_by_name_with_time_prefix "${DESTINATION}" "${NAME}*")
  fi
fi

# Create directories
if [[ ${REMOTE_DESTINATION_FIND_EXIT_CODE} -eq 1 || ${DESTINATION_MISSING} -eq 1 ]]; then
  while true; do
    if [[ ${FORCE_MODE} == 1 ]]; then
      CONFIRM_DIRECTORY="Y"
    else
      read -r -p "Create destination directory and parent directories? (Y/N) " CONFIRM_DIRECTORY
    fi

    case $CONFIRM_DIRECTORY in
      [Yy]* )
        if [[ $((BACKUP_MODE & BACKUP_MODE_REMOTE_DESTINATION)) != 0 ]]; then
          if ! run_remote_shell_command "mkdir -p ${REMOTE_DESTINATION_PATH}" "${REMOTE_DESTINATION_HOST}" "${REMOTE_DESTINATION_USER}"; then
            echo "Error: failed at creating remote destination directory \"${REMOTE_DESTINATION_PATH}\""
            exit 1;
          fi
        else
          mkdir -p "${DESTINATION}"
        fi; break;;
      [Nn]* ) exit 1;;
      * ) echo "Please answer yes or no.";;
    esac
  done
fi


# TODO: Remote shell works now, how about actually backing up there now?
# TODO: Don't forget about remote to remote backups - this one will be awesome!
# TODO: Oh and key verification ... we need this
# TODO: Link destinations seems to be broken now ... needs a fix?
# TODO: Check for more parameters to give command line control without dialogs
# TODO: Include given parameters in functionality of backups


# Count previous backups
if [[ -z ${PREVIOUS} ]]; then
  PREVIOUS_COUNT=0
else
  PREVIOUS_COUNT=$(echo "${PREVIOUS}" | wc -l)
fi

# Check for existing backups
if [[ ${PREVIOUS_COUNT} == 0 ]]; then
  if [[ VERBOSE -eq 1 ]]; then echo "No previous backups for \"${NAME}\" found."; fi
  BACKUP_MODE=$((BACKUP_MODE | BACKUP_MODE_FULL_NEW))
fi


if [[ ${PREVIOUS_COUNT} -gt 0 ]]; then
	if [[ VERBOSE -eq 1 ]]; then
	  echo "Previous backups for \"${NAME}\" found."
	  echo "Checking for previous full backup ..."
	fi

	PREVIOUS_FULL=$(find_lines_by_name "${PREVIOUS}" "${NAME}*${LATEST_EXTENSION}")
	PREVIOUS_COUNT_FULL=$(echo "${PREVIOUS_FULL}" | wc -l)

  if [[ ${PREVIOUS_COUNT_FULL} -eq 0 ]]; then
    echo "Warning: no previous full backup for \"${NAME}\" found."
    BACKUP_MODE=$((BACKUP_MODE | BACKUP_MODE_LATEST))
	fi

	if [[ ${PREVIOUS_COUNT_FULL} -gt 1 ]]; then
		echo "Warning: more than one previous full backup for \"${NAME}\" found."
		BACKUP_MODE=$((BACKUP_MODE | BACKUP_MODE_LATEST_FULL))
	fi

	if [[ ${PREVIOUS_COUNT_FULL} -eq 1 ]]; then
		if [[ VERBOSE -eq 1 ]]; then echo "Previous full backup found."; fi
		BACKUP_MODE=$((BACKUP_MODE | BACKUP_MODE_INCREMENTAL))
		LINK_DESTINATION=$(echo "${PREVIOUS_FULL}" | cut -d' ' -f 2-)
	else
    LINK_DESTINATION=$(get_last_sorted_by_time "$(find_lines_by_name "${PREVIOUS_FULL}" "${NAME}*${LATEST_EXTENSION}")")

    if [[ -n $LINK_DESTINATION ]]; then
      LINK_DESTINATION=$(get_last_sorted_by_time "${PREVIOUS_FULL}")
    fi

    echo "Latest backup found is \"${LINK_DESTINATION}\" created on $(date -r "${LINK_DESTINATION}" +"%Y-%m-%d %H:%M:%S")"

    if [[ $((BACKUP_MODE & BACKUP_MODE_LATEST)) != 0 || $((BACKUP_MODE & BACKUP_MODE_LATEST_FULL)) != 0 ]]; then
      while true; do
        if [[ ${FORCE_MODE} == 1 ]]; then
          CONFIRM_DIRECTORY="Y"
        else
          read -r -p "Continue with latest backup found (Y) or create new full backup (N)? - (Y/N): " CONFIRM_LATEST
        fi

        case $CONFIRM_LATEST in
          [Yy]* ) break;;
          [Nn]* ) BACKUP_MODE=$BACKUP_MODE_FULL_NEW; break;;
          * ) echo "Please answer yes or no.";;
        esac
      done
    fi
  fi
fi

# Select backup method by previous input
if [[ $((BACKUP_MODE & BACKUP_MODE_REMOTE_SOURCE)) != 0 && $((BACKUP_MODE & BACKUP_MODE_REMOTE_DESTINATION)) != 0 ]]; then
  run_remote_to_remote_backup "${REMOTE_SOURCE_INFO}" "${REMOTE_DESTINATION_INFO}" "${NAME}" "${LINK_DESTINATION}" "${RELATIVE_LINK_DESTINATION}"
elif [[ $((BACKUP_MODE & BACKUP_MODE_REMOTE_SOURCE)) != 0 ]]; then
  run_remote_source_backup "${REMOTE_SOURCE_INFO}" "${DESTINATION}" "${NAME}" "${LINK_DESTINATION}" "${RELATIVE_LINK_DESTINATION}"
elif [[ $((BACKUP_MODE & BACKUP_MODE_REMOTE_DESTINATION)) != 0 ]]; then
  run_remote_destination_backup "${REMOTE_DESTINATION_INFO}" "${SOURCE}" "${NAME}" "${LINK_DESTINATION}" "${RELATIVE_LINK_DESTINATION}"
else
  run_backup "${SOURCE}" "${DESTINATION}" "${NAME}" "${LINK_DESTINATION}" "${RELATIVE_LINK_DESTINATION}"
fi

#### SCRIPT END ####

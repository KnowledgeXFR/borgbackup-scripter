#!/bin/bash


# Copyright (c) 2025 Michael J. Bartholomew
# License: MIT
# https://github.com/KnowledgeXFR/borgbackup-scripter


# Version
readonly VERSION="1.2.0"


# ----------------------------------------
# Function: Parse arguments
# ----------------------------------------
parseArguments() {
  
  ARG_TEST=0
  
  for var in "$@"; do
    case "$var" in
      --setup)
        ARG_SETUP=1
        ;;
      --repo=*)
        ARG_REPO=$(echo $var | cut -d'=' -f 2)
        ;;
      --test)
        ARG_TEST=1
        ;;
      --help)
        echo ""
        echo "Version: $VERSION"
        echo ""
        echo "usage: borgbackup_scripter.sh --repo=X [--setup] [--test]"
        echo ""
        echo "BorgBackup Scripter"
        echo ""
        echo "optional arguments:"
        echo "  --setup              Setup the configuration and shell scripts for a new"
        echo "                       repository. This will not overwrite the existing"
        echo "                       directory and files"
        echo ""
        echo "  --test               Display the generated BorgBackup command line syntax" 
        echo "                       instead of running it"
        echo ""
        echo "required argument:"
        echo "  --repo=[name]        Repository name"
        echo ""
        exit
        ;;
      *)
        echo -e "--------------------------------------------------------------------------------"
        echo -e "ERROR: Unknown argument ${var}"
        echo -e "Usage: \"$(basename "$0") --help\" for accepted arguments"
        echo -e "--------------------------------------------------------------------------------"
        exit 1
        ;;
    esac
  done
  
  # Validate if repo has been passed
  if ! test $ARG_REPO; then
    echo ""
    echo "No repo was passed. Please run borgbackup_scripter.sh --help for more information"
    echo ""
    exit 1
  fi
  
}


# ----------------------------------------
# Function: Parse repo configuration file
# ----------------------------------------
parseConfig() {
  
  # Validate if the configuration file exists
  REPO_CONF="$SCRIPT_PATH/repos/$ARG_REPO/repo.conf"
  if [ ! -f "$REPO_CONF" ]; then
    echo "--------------------------------------------------------------------------------"
    echo "ERROR: The following repository has not been setup:"
    echo " - $ARG_REPO"
    echo "Please run \"borgbackup_scripter.sh --help\" for more information on how to setup the"
    echo "repository configuration files."
    echo "--------------------------------------------------------------------------------"
    exit 1
  fi
  
  while IFS= read -r line || [ -n "$line" ]; do
  
    
    # Email Address
    if [[ $line == "EMAIL_ADDR="* ]]; then
      EMAIL_ADDR=${line:11}
    fi
    
    # Email Body
    if [[ $line == "EMAIL_BODY="* ]]; then
      EMAIL_BODY=${line:11}
    fi
    
    # BorgBackup Binary Location
    if [[ $line == "BORG_BIN="* ]]; then
      BORG_BIN=${line:9}
    fi
    
    # Caffeinate
    if [[ $line == "ENABLE_CAFFEINATE="* ]]; then
      TEMP_CAFF=${line:18}
      if [[ $TEMP_CAFF == "Y" ]]; then
        ENABLE_CAFFEINATE=1
      else
        ENABLE_CAFFEINATE=0
      fi
    fi
    
    # Repository Path
    if [[ $line == "REPOSITORY_PATH="* ]]; then
      REPOSITORY_PATH=${line:16}
    fi
    
    # Archive Date Format
    if [[ $line == "ARCHIVE_DATE_FORMAT="* ]]; then
      ARCHIVE_DATE_FORMAT=$(eval echo ${line:20})
    fi
    
    # Repo Passphrase
    if [[ $line == "REPO_PASSPHRASE="* ]]; then
      export BORG_PASSPHRASE=${line:16}
    fi
    
    # Remote Host Information
    if [[ $line == "REMOTE_USER="* ]]; then
      REMOTE_USER=${line:12}
    fi
    if [[ $line == "REMOTE_DOMAIN="* ]]; then
      REMOTE_DOMAIN=${line:14}
    fi
    if [[ $line == "REMOTE_PORT="* ]]; then
      REMOTE_PORT=${line:12}
    fi
    
    # Compression
    if [[ $line == "COMPRESSION="* ]]; then
      COMPRESSION=${line:12}
    fi
        
    # Prune
    if [[ $line == "PRUNE_LAST="* ]]; then
      PRUNE_LAST=${line:11}
    fi
    if [[ $line == "PRUNE_DAILY="* ]]; then
      PRUNE_DAILY=${line:12}
    fi
    if [[ $line == "PRUNE_WEEKLY="* ]]; then
      PRUNE_WEEKLY=${line:13}
    fi
    if [[ $line == "PRUNE_MONTHLY="* ]]; then
      PRUNE_MONTHLY=${line:14}
    fi
    if [[ $line == "PRUNE_YEARLY="* ]]; then
      PRUNE_YEARLY=${line:13}
    fi
    
    # Paths
    if [[ $line == "# Paths"* ]]; then
      PATHS_FOUND=1
    fi
    if [[ $PATHS_FOUND == 1 ]] && [[ $line == "- "* ]]; then
      PATHS+=("${line:2}")
    fi
    
  done < "$REPO_CONF"
  
}


# ----------------------------------------
# Function: Setup repository
# ----------------------------------------
setupRepository() {
  
  if [[ $ARG_SETUP == 1 ]]; then
    CONFIG_PATH="$SCRIPT_PATH/repos/$ARG_REPO"
    if [ ! -d "$CONFIG_PATH" ]; then
      mkdir -p "$CONFIG_PATH"
    fi
    if [ ! -f "$CONFIG_PATH/exclude.txt" ]; then
      touch "$CONFIG_PATH/exclude.txt"
    fi
    if [ ! -f "$CONFIG_PATH/repo.conf" ]; then
      cp files/repo.conf "$CONFIG_PATH"
    fi
    if [ ! -f "$CONFIG_PATH/post.sh" ]; then
      cp files/post.sh "$CONFIG_PATH"
    fi
    if [ ! -f "$CONFIG_PATH/pre.sh" ]; then
      cp files/pre.sh "$CONFIG_PATH"
    fi
    echo "--------------------------------------------------------------------------------"
    echo "Configuration files and scripts for the following repository have been setup:"
    echo " - $ARG_REPO"
    echo "--------------------------------------------------------------------------------"
    exit 0
  fi
  
}


# ----------------------------------------
# Function: Validate configuration values
# ----------------------------------------
validateVariables() {
  
  # Validate email information
  EMAIL=1
  if [ ! $EMAIL_ADDR ] || [[ ${#EMAIL_ADDR} == 0 ]]; then
    EMAIL=0
  fi
  if [ ! $EMAIL_BODY ] || [[ ${#EMAIL_BODY} == 0 ]]; then
    EMAIL=0
  fi
  if [[ $EMAIL == 1 ]]; then
    if [ "$EMAIL_BODY" != "T" ] && [ "$EMAIL_BODY" != "H" ] && [ "$EMAIL_BODY" != "B" ]; then
      echo "--------------------------------------------------------------------------------"
      echo "ERROR: The EMAIL_BODY value must be T, H or B"
      echo "--------------------------------------------------------------------------------"
      exit 1
    fi
  fi
  
  # Validate if BORG_BIN file path exists
  if [ ! -f $BORG_BIN ]; then
    echo "--------------------------------------------------------------------------------"
    echo "ERROR: The BorgBackup binary was not found at the provided location:"
    echo " - $BORG_BIN"
    echo "--------------------------------------------------------------------------------"
    exit 1
  fi
  
  # Validate if caffeinate file path exists
  if [[ $ENABLE_CAFFEINATE == 1 ]] && [ ! -f "/usr/bin/caffeinate" ]; then
    echo "--------------------------------------------------------------------------------"
    echo "ERROR: Unable to find the caffeinate binary at \"/usr/bin/caffeinate\"."
    echo "If you are not on macOS, please update repo.conf and change the"
    echo "ENABLE_CAFFEINATE value to \"N\"."
    echo "--------------------------------------------------------------------------------"
    exit 1
  fi
  
  # Validate repository path information
  if [ ! $REPOSITORY_PATH ] || [[ ${#REPOSITORY_PATH} == 0 ]]; then
    echo "--------------------------------------------------------------------------------"
    echo "ERROR: The REPOSITORY_PATH value in repo.conf must be populated"
    echo "--------------------------------------------------------------------------------"
    exit 1
  fi
  
  # Validate repository passphrase
  if [ ! $BORG_PASSPHRASE ] || [[ ${#BORG_PASSPHRASE} == 0 ]]; then
    echo "--------------------------------------------------------------------------------"
    echo "ERROR: The REPO_PASSPHRASE value in repo.conf must be populated"
    echo "--------------------------------------------------------------------------------"
    exit 1
  fi
  
  # Validate archive date format
  if [ ! $ARCHIVE_DATE_FORMAT ] || [[ ${#ARCHIVE_DATE_FORMAT} == 0 ]]; then
    echo "--------------------------------------------------------------------------------"
    echo "ERROR: The ARCHIVE_DATE_FORMAT value in repo.conf must be populated"
    echo "--------------------------------------------------------------------------------"
    exit 1
  fi
  
  # Validate remote host information
  REMOTE=1
  if [ ! $REMOTE_USER ] || [[ ${#REMOTE_USER} == 0 ]]; then
    REMOTE=0
  fi
  if [ ! $REMOTE_DOMAIN ] || [[ ${#REMOTE_DOMAIN} == 0 ]]; then
    REMOTE=0
  fi
  if [ ! $REMOTE_PORT ] || [[ ${#REMOTE_PORT} == 0 ]]; then
    REMOTE=0
  fi
  
  # Compression
  if [ ! $COMPRESSION ] || [[ ${#COMPRESSION} == 0 ]]; then
    echo "--------------------------------------------------------------------------------"
    echo "ERROR: The COMPRESSION value in repo.conf must be populated"
    echo "--------------------------------------------------------------------------------"
    exit 1
  fi
  
  # Prune
  PRUNE=1
  if [ ! $PRUNE_LAST ] || [[ ${#PRUNE_LAST} == 0 ]]; then
    PRUNE=0
  fi
  if [ ! $PRUNE_DAILY ] || [[ ${#PRUNE_DAILY} == 0 ]]; then
    PRUNE=0
  fi
  if [ ! $PRUNE_WEEKLY ] || [[ ${#PRUNE_WEEKLY} == 0 ]]; then
    PRUNE=0
  fi
  if [ ! $PRUNE_MONTHLY ] || [[ ${#PRUNE_MONTHLY} == 0 ]]; then
    PRUNE=0
  fi
  if [ ! $PRUNE_YEARLY ] || [[ ${#PRUNE_YEARLY} == 0 ]]; then
    PRUNE=0
  fi
  
  # Path(s)
  if [ ! $PATHS ] || [[ ${#PATHS[@]} == 0 ]]; then
    echo "--------------------------------------------------------------------------------"
    echo "ERROR: At least one path must be populated in repo.conf"
    echo "--------------------------------------------------------------------------------"
    exit 1
  fi
  
}


# ----------------------------------------
# Function: Run script
# ----------------------------------------
runScript() {
  
  local SCRIPT_FILE="$SCRIPT_PATH/repos/$ARG_REPO/$1"
  if test -s "$SCRIPT_FILE"; then
    # Plaintext
    echo -e "\n================================================================================" >> /tmp/BorgBackupTEXT_$$.log 2>&1
    echo -e "Running $2" >> /tmp/BorgBackupTEXT_$$.log 2>&1
    echo -e "================================================================================\n" >> /tmp/BorgBackupTEXT_$$.log 2>&1
    # HTML
    echo "<h3>Running $2</h3>" >> /tmp/BorgBackupHTML_$$.log 2>&1
    echo "<div class=\"content\">" >> /tmp/BorgBackupHTML_$$.log 2>&1
    if [[ $ARG_TEST == 0 ]]; then
      local SCRIPT_OUTPUT=$(source "$SCRIPT_FILE" 2>&1)
      if [[ ${#SCRIPT_OUTPUT} == 0 ]]; then
        # Plaintext
        echo "No output from script to display" >> /tmp/BorgBackupTEXT_$$.log 2>&1
        # HTML
        echo "<p>No output from script to display</p>" >> /tmp/BorgBackupHTML_$$.log 2>&1
      else
        # Plaintext
        echo $SCRIPT_OUTPUT >> /tmp/BorgBackupTEXT_$$.log 2>&1
        # HTML
        echo "<pre><code>$SCRIPT_OUTPUT</code></pre>" >> /tmp/BorgBackupHTML_$$.log 2>&1
      fi
      # Plaintext
      echo "" >> /tmp/BorgBackupTEXT_$$.log 2>&1
    else
      # Plaintext
      echo -e "Test mode enabled; $1 not ran\n" >> /tmp/BorgBackupTEXT_$$.log 2>&1
      # HTML
      echo -e "<p>Test mode enabled; $1 not ran</p>" >> /tmp/BorgBackupHTML_$$.log 2>&1
    fi
    echo "</div>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  fi
  
}


# ----------------------------------------
# Function: Create BorgBackup archive
# ----------------------------------------
createBorgArchive() {
  
  ARCHIVE=`date +$ARCHIVE_DATE_FORMAT`
  
  # Determine if exclude-from param should be applied
  CONFIG_PATH="$SCRIPT_PATH/repos/$ARG_REPO"
  if [ -f "$CONFIG_PATH/exclude.txt" ]; then
    FILESIZE=$(wc -c "$CONFIG_PATH/exclude.txt" | awk '{print $1}')
    if [[ $FILESIZE > 0 ]]; then
      EXCLUDE_YN=1
      EXCLUDE_TEXT="Yes"
    else
      EXCLUDE_YN=0
      EXCLUDE_TEXT="No"
    fi
  fi
  
  # Determine REPO_PATH value
  if [[ $REMOTE == 1 ]]; then
    REPO_PATH="ssh://$REMOTE_USER@$REMOTE_DOMAIN:$REMOTE_PORT$REPOSITORY_PATH"
  else
    REPO_PATH="$REPOSITORY_PATH"
  fi
  
  # Plaintext
  echo -e "\n================================================================================" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  echo -e "Creating Archive" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  echo -e "================================================================================\n" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  echo -e "Repo:        ${ARG_REPO}" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  echo -e "Archive:     ${ARCHIVE}" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  echo -e "Compression: ${COMPRESSION}" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  echo -e "Exclusions:  ${EXCLUDE_TEXT}" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  echo "" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  # HTML
  echo "<h3>Creating Archive</h3>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  echo "<div class=\"content\">" >> /tmp/BorgBackupHTML_$$.log 2>&1
  echo "<table>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  echo "<tr><td>Repo:</td><td>${ARG_REPO}</td></tr>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  echo "<tr><td>Archive:</td><td>${ARCHIVE}</td></tr>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  echo "<tr><td>Compression:</td><td>${COMPRESSION}</td></tr>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  echo "<tr><td>Exclusions:</td><td>${EXCLUDE_TEXT}</td></tr>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  echo "</table>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  
  # Validate paths and create string
  # Plaintext
  echo -e "Source Path(s):" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  # HTML
  echo "<p><strong>Source Path(s):</strong></p>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  SOURCE_PATHS=""
  PATH_COUNT=0
  if [[ ${#PATHS[@]} > 0 ]]; then
    # HTML
    echo "<ul>" >> /tmp/BorgBackupHTML_$$.log 2>&1
    for i in "${PATHS[@]}"; do
      if test -e "$i"
      then
        # Plaintext
        echo -e " - \"$i\"" >> /tmp/BorgBackupTEXT_$$.log 2>&1
        # HTML
        echo -e "<li>$i</li>" >> /tmp/BorgBackupHTML_$$.log 2>&1
        SOURCE_PATHS="$SOURCE_PATHS\"$i\" "
        PATH_COUNT=$(($PATH_COUNT+1))
      else
        # Plaintext
        echo -e " - \"$i\" - [not found]" >> /tmp/BorgBackupTEXT_$$.log 2>&1
        # HTML
        echo -e "<li>$i <span class=\"error\">[not found]</span></li>" >> /tmp/BorgBackupHTML_$$.log 2>&1
      fi
    done
    # HTML
    echo "</ul>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  fi
  # Plaintext
  echo "" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  if [[ $PATH_COUNT == 0 ]]; then
    # Plaintext
    echo -e "No valid source paths were provided" >> /tmp/BorgBackupTEXT_$$.log 2>&1
    # HTML
    echo -e "<p>No valid source paths were provided</p>" >> /tmp/BorgBackupHTML_$$.log 2>&1
    return
  fi
  
  # Display repository path
  # Plaintext
  echo -e "Repository Path:\n$REPO_PATH\n" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  # HTML
  echo "<p><strong>Repository Path:</strong></p>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  echo "<p>$REPO_PATH</p>" >> /tmp/BorgBackupHTML_$$.log 2>&1

  # Create command
  if [[ $ENABLE_CAFFEINATE == 1 ]]; then
    CMD_CREATE="/usr/bin/caffeinate -i $BORG_BIN create -v --stats --compression $COMPRESSION"
  else
    CMD_CREATE="$BORG_BIN create -v --stats --compression $COMPRESSION"
  fi
  
  # Include exclude-from param when exclude.txt is populated
  if [[ $EXCLUDE_YN == 1 ]]; then
    CMD_CREATE="$CMD_CREATE --exclude-from \"$CONFIG_PATH/exclude.txt\""
  fi
  
  CMD_CREATE="$CMD_CREATE $REPO_PATH::$ARCHIVE $SOURCE_PATHS"
  
  # Display command
  if [[ $ARG_TEST == 1 ]]; then
    # Plaintext
    echo -e "Command:\n$CMD_CREATE" >> /tmp/BorgBackupTEXT_$$.log 2>&1
    echo "" >> /tmp/BorgBackupTEXT_$$.log 2>&1
    # HTML
    echo -e "<p><strong>Command:</strong></p>" >> /tmp/BorgBackupHTML_$$.log 2>&1
    echo -e "<pre><code>$CMD_CREATE</code></pre>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  fi
  
  # Run command 
  if [[ $ARG_TEST == 0 ]]; then
    CMD_OUTPUT=$(bash -c "$CMD_CREATE" 2>&1)
    # HTML
    echo "<p><strong>Response:</strong></p>" >> /tmp/BorgBackupHTML_$$.log 2>&1
    if [[ $? == 0 ]]; then
      CMD_ERR=0
    else
      CMD_ERR=1
    fi
    # Plaintext
    echo $CMD_OUTPUT >> /tmp/BorgBackupTEXT_$$.log 2>&1
    # HTML
    echo "<pre><code>$CMD_OUTPUT</code></pre>" >> /tmp/BorgBackupHTML_$$.log 2>&1
    
  fi
  # Plaintext
  echo "" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  # HTML
  echo "</div>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  
}


# ----------------------------------------
# Function: Prune repository
# ----------------------------------------
pruneRepository() {
  
  # Plaintext
  echo -e "\n================================================================================" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  echo -e "Pruning Repository" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  echo -e "================================================================================\n" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  # HTML
  echo -e "<h3>Pruning Repository</h3>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  echo "<div class=\"content\">" >> /tmp/BorgBackupHTML_$$.log 2>&1
  
  if [[ $CMD_ERR == 0 ]]; then
  
    if [[ $REMOTE == 1 ]]; then
      REPO_PATH="ssh://$REMOTE_USER@$REMOTE_DOMAIN:$REMOTE_PORT$REPOSITORY_PATH"
    else
      REPO_PATH="$REPOSITORY_PATH"
    fi
    CMD_PRUNE="$BORG_BIN prune --keep-last=$PRUNE_LAST --keep-daily=$PRUNE_DAILY --keep-weekly=$PRUNE_WEEKLY --keep-monthly=$PRUNE_MONTHLY --keep-yearly=$PRUNE_YEARLY $REPO_PATH"
    
    PRUNE_OUTPUT=$(bash -c "$CMD_PRUNE" 2>&1)
    if [[ ${#PRUNE_OUTPUT} == 0 ]]; then
      # Plaintext
      echo "No output to display" >> /tmp/BorgBackupTEXT_$$.log 2>&1
      # HTML
      echo "<p>No output to display</p>" >> /tmp/BorgBackupHTML_$$.log 2>&1
    else
      # Plaintext
      echo $PRUNE_OUTPUT >> /tmp/BorgBackupTEXT_$$.log 2>&1
      # HTML
      echo "<pre><code>$PRUNE_OUTPUT</code></pre>" >> /tmp/BorgBackupHTML_$$.log 2>&1
    fi
  else
    # Plaintext
    echo "Did not run due to \"borg create\" error" >> /tmp/BorgBackupTEXT_$$.log 2>&1
    # HTML
    echo "<p>Did not run due to \"borg create\" error</p>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  fi
  
  # Plaintext
  echo "" >> /tmp/BorgBackupTEXT_$$.log 2>&1
  # HTML
  echo "</div>" >> /tmp/BorgBackupHTML_$$.log 2>&1
  
}


# ----------------------------------------
# Function: Report out results
# ----------------------------------------
reportOut() {
  
  MAIL_FOUND=0
  if hash sendmail 2>/dev/null; then
    MAIL_FOUND=1
  fi
  
  if [[ $MAIL_FOUND == 0 ]] || [[ $EMAIL == 0 ]]; then
    cat /tmp/BorgBackupTEXT_$$.log
  else
    
    local DATE=`date +"%a, %d %b %Y %H:%M:%S"`
    local BOUNDARY="gc0p4Jq0M2Yt08jU534c0p"
    
    local HEADER="To: $EMAIL_ADDR\r\nSubject: BorgBackup Scripter - $ARG_REPO\r\nContent-Type: multipart/alternative; boundary=\"$BOUNDARY\"\r\nDate: $DATE"
    
    local HTML_CONTENT="<html><head><style>body {margin:0;padding:15px;font-family:Helvetica, Arial, sans-serif;font-size:13px;line-height:15px;color:hsl(0, 0%, 15%)}li {padding:1px 0;}h2 {font-size:1.5em;line-height:1em;}h3 {margin-top:2em;padding-bottom:0.25em;font-size:1.17em;line-height:1em;border-bottom:1px solid hsl(0, 0%, 75%);}.content {padding-left:1em;}table {font-size:13px;line-height:15px;border-collapse:collapse;}table tr td:nth-child(1) {font-weight:bold;}table tr td:nth-child(2) {padding-left:1em;}pre {font-size:12px;line-height:14px;}.error {color:hsl(0, 100%, 35%);}</style></head><body><h2>BorgBackup Scripter Report</h2>$(cat /tmp/BorgBackupHTML_$$.log)</body></html>"
    
    local CONTENT="$HEADER\r\n\r\n\r\n"
    if [[ $EMAIL_BODY == "T" ]]; then
      CONTENT="$CONTENT--$BOUNDARY\nContent-Type: text/text; charset=\"UTF-8\"\n\n$(cat /tmp/BorgBackupTEXT_$$.log)"
    fi
    if [[ $EMAIL_BODY == "H" ]]; then
      CONTENT="$CONTENT--$BOUNDARY\nContent-Type: text/html; charset=\"UTF-8\"\n\n$HTML_CONTENT"
    fi
    if [[ $EMAIL_BODY == "B" ]]; then
      CONTENT="$CONTENT--$BOUNDARY\nContent-Type: text/text; charset=\"UTF-8\"\n\n$(cat /tmp/BorgBackupTEXT_$$.log)\n\r\n--$BOUNDARY\nContent-Type: text/html; charset=\"UTF-8\"\n\n$HTML_CONTENT"
    fi
    
    echo -e "$CONTENT" | sendmail -t
  fi
  
  rm -f /tmp/BorgBackupHTML_$$.log
  rm -f /tmp/BorgBackupTEXT_$$.log
  
}

  
# Parse CLI arguments
SCRIPT_PATH=$(dirname "$0")
parseArguments $@


# Setup repository
setupRepository


# Parse repo.conf
parseConfig


# Validate config variables
validateVariables


# Run pre.sh
runScript "pre.sh" "Pre Shell Script"


# Create BorgBackup archive
createBorgArchive


# Run post.sh
runScript "post.sh" "Post Shell Script"


# Prune repository
pruneRepository


# Report out
reportOut

#/bin/bash
TEMP_DIR=/tmp
PURPLE='\033[0;35m'; NC='\033[0m'
if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "--usage" ]; then
  echo -e "   \n"													>&2; 
  echo -e "   usage: $(basename $0) <metadata file from fdroiddata> <folder for all data to be saved> <download mode>"	>&2; 
  echo -e "   \n"													>&2; 
  echo -e "   METADATA FILE from fdroiddata: See https://gitlab.com/fdroid/fdroiddata/tree/master/metadata"		>&2; 
  echo -e "   \n"													>&2; 
  echo -e "   FOLDER FOR ALL DATA:           All the ${PURPLE}app icons; activity names & activity icons${NC} go here."	>&2; 
  echo -e "   \n"													>&2; 
  echo -e "   DOWNLOAD MODE:                 Some online providers offer a WEB API to download single files directly. "	>&2; 
  echo -e "                                  All however offer the possibility to download the source code completely."	>&2; 
  echo -e "                                  The WEB API URL can sometimes only be guessed, so we need multiple tries."	>&2; 
  echo -e "                                  Downloading only the necessary files via WEB APIs can be faster than"	>&2; 
  echo -e "                                  checking out / downloading the complete source code; but don't always work">&2; 
  echo -e "                                  "										>&2; 
  echo -e "                                  ${PURPLE}DOWNLOAD${NC}: download the complete source code every time."	>&2; 
  echo -e "                                  ${PURPLE}WEBAPI${NC}: try to use the WEB API as often as possible."	>&2; 
elif [ ! -f "$1" ] || [ ! -d "$2" ]; then
  FILE_NAME=$(basename "$1")
  FILE_PATH=$(realpath -e "$1")
  DATA_PATH=$(realpath -e "$2")
  echo "FILE_PATH                         $FILE_PATH"									>&2		
  echo "FILE_NAME:                        $FILE_NAME"									>&2
  echo "DATA_PATH:                        $DATA_PATH"									>&2
  echo "$FILE_NAME - ERROR:"												>&2
  echo "                                  1st argument has to be the F-Droid metadata file; 2nd one a data folder."	>&2; exit
else
  FILE_NAME=$(basename "$1")
  FILE_PATH=$(realpath -e "$1")
  DATA_PATH=$(realpath -e "$2")
  REPO_TYPE=$(      grep "^Repo Type:"   "$FILE_PATH" | sed 's/Repo Type\://');
  SOURCE_URL_REPO=$(grep "^Repo:"        "$FILE_PATH" | sed 's/Repo\://'       );
  SOURCE_URL_CODE=$(grep "^Source Code:" "$FILE_PATH" | sed 's/Source Code\://');
  if [ "$REPO_TYPE" != "git" ]     && \
     [ "$REPO_TYPE" != "svn" ]     && \
     [ "$REPO_TYPE" != "git-svn" ] && \
     [ "$REPO_TYPE" != "hg" ]      && \
     [ "$REPO_TYPE" != "bzr" ];    then
  echo "$FILE_NAME - ERROR:"												>&2;
  echo "                                  unrecognized or unsupported REPO_TYPE $REPO_TYPE"				>&2;exit;fi
  if [   -z "$SOURCE_URL_REPO" ] && [   -z "$SOURCE_URL_CODE" ]; then 
  echo "$FILE_NAME - ERROR:   no source URL specified!" 								>&2;exit;fi
  APP_NAME1=$(      grep "^Auto Name:"   "$FILE_PATH" | sed 's/^Auto Name\://' );
  APP_NAME2=$(      grep "^Name:"        "$FILE_PATH" | sed 's/^Name\://');
  SUBDIR=$(tac "$FILE_PATH" | grep -m 1 "subdir="     | sed -E "s|^[ ]{1,10}subdir=||g" | sed -E "s|[ ]{1,10}$||g" )
  COMMIT=$(tac "$FILE_PATH" | grep -m 1 "commit="     | sed -E "s|^[ ]{1,10}commit=||g" | sed -E "s|[ ]{1,10}$||g" )
  BUILD=$( tac "$FILE_PATH" | grep -m 1 "Build:"      | sed -E "s|Build:||g"  | tr -d '[:blank:]' \
  | sed -E "s|,[0-9]{1,10}||g" | sed -E "s|\.|_|g" )
  VBUILD="v$BUILD"
  if [ ! -z "$APP_NAME1" ] && [ ! -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME1"; fi
  if [ ! -z "$APP_NAME1" ] && [   -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME1"; fi
  if [   -z "$APP_NAME1" ] && [ ! -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME2"; fi
  if [   -z "$APP_NAME1" ] && [   -z "$APP_NAME2" ]; then 
  echo "$FILE_NAME - ERROR:"												>&2;
  echo "                                  no app name specified! Specify one after 'Name:' or 'Auto Name:'"		>&2;exit;fi
  APP_NAME_SIMPLE=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]'              | sed -E "s|^[ ]{1,10}||g" | \
    sed -E "s|[\;:,. /+\(\)\!\?\*=\`\´}{'$ -]|_|g"   | sed -E "s|[_]{1,4}|_|g" | sed -E "s|[_]{1,10}$||g" )
  # create the directory where we save all our metadata. 
  METADATA_FILE="$DATA_PATH/$APP_NAME_SIMPLE/metadata.txt"
  mkdir -p "$DATA_PATH/$APP_NAME_SIMPLE"
  mkdir -p "$TEMP_DIR/$APP_NAME_SIMPLE"
  touch "$METADATA_FILE"
  touch "$DATA_PATH/$APP_NAME_SIMPLE/AndroidManifest.xml"
  # create the directory where we save all our temporary data: 
  echo "APP_NAME_SIMPLE=\"$APP_NAME_SIMPLE\""										>>$METADATA_FILE
  echo "APP_NAME1=\"$APP_NAME1\""											>>$METADATA_FILE
  echo "APP_NAME2=\"$APP_NAME2\""											>>$METADATA_FILE
  echo "SUBDIR=\"$SUBDIR\""												>>$METADATA_FILE
  echo "COMMIT=\"$COMMIT\""												>>$METADATA_FILE
  echo "BUILD=\"$BUILD\""												>>$METADATA_FILE
  echo "VBUILD=\"$VBUILD\""												>>$METADATA_FILE
  echo "FILE_NAME=\"$FILE_NAME\""											>>$METADATA_FILE
  echo "REPO_TYPE=\"$REPO_TYPE\""											>>$METADATA_FILE
  echo "FILE_PATH=\"$FILE_PATH\""											>>$METADATA_FILE
  echo "DATA_PATH=\"$DATA_PATH\""											>>$METADATA_FILE
  echo "SOURCE_URL_REPO=\"$SOURCE_URL_REPO\""										>>$METADATA_FILE
  echo "SOURCE_URL_CODE=\"$SOURCE_URL_CODE\""										>>$METADATA_FILE
  # Find out which provider is used: 
  SEARCH_GITLAB=$(  echo "$SOURCE_URL_REPO" | grep "gitlab"; 	 echo "$SOURCE_URL_CODE" | grep "gitlab")
  SEARCH_GITHUB=$(  echo "$SOURCE_URL_REPO" | grep "github";     echo "$SOURCE_URL_CODE" | grep "github")
  SEARCH_BTBCKT=$(  echo "$SOURCE_URL_REPO" | grep "bitbucket";  echo "$SOURCE_URL_CODE" | grep "bitbucket")
  SEARCH_LNCHPD=$(  echo "$SOURCE_URL_REPO" | grep "lp:";        echo "$SOURCE_URL_CODE" | grep "launchpad")
  SEARCH_SRCFRG=$(  echo "$SOURCE_URL_REPO" | grep "sf.net";     echo "$SOURCE_URL_CODE" | grep "sourceforge")
  SEARCH_GOOGLE=$(  echo "$SOURCE_URL_REPO" | grep "googlecode"; echo "$SOURCE_URL_CODE" | grep "code.google")
  if   [ ! -z "$SEARCH_GITLAB" ]; then ONLINE_SOURCE_PROVIDER="GITLAB"; 
  elif [ ! -z "$SEARCH_GITHUB" ]; then ONLINE_SOURCE_PROVIDER="GITHUB"; 
  elif [ ! -z "$SEARCH_BTBCKT" ]; then ONLINE_SOURCE_PROVIDER="BTBCKT"; 
  elif [ ! -z "$SEARCH_LNCHPD" ]; then ONLINE_SOURCE_PROVIDER="LNCHPD"; 
  elif [ ! -z "$SEARCH_SRCFRG" ]; then ONLINE_SOURCE_PROVIDER="SRCFRG"; 
  elif [ ! -z "$SEARCH_GOOGLE" ]; then ONLINE_SOURCE_PROVIDER="GOOGLE"; 
  elif [   -z "$SEARCH_GITLAB" ] && \
       [   -z "$SEARCH_GITHUB" ] && \
       [   -z "$SEARCH_BTBCKT" ] && \
       [   -z "$SEARCH_LNCHPD" ] && \
       [   -z "$SEARCH_SRCFRG" ] && \
       [   -z "$SEARCH_GOOGLE" ]; then ONLINE_SOURCE_PROVIDER="CUSTOM"
  else
  echo "$FILE_NAME - WARNING:"												>&2;
  echo "                                  src seems to be accessible in multiple different online src providers:"	>&2; 
  echo "                                  SOURCE_URL_CODE: $SOURCE_URL_CODE";						>&2;
  echo "                                  SOURCE_URL_REPO: $SOURCE_URL_REPO";						>&2;exit;fi
  case "$ONLINE_SOURCE_PROVIDER" in
  GITHUB)
          REPO_NAME=$(basename           $SOURCE_URL_CODE); 
          DEVELOPER=$(basename $(dirname $SOURCE_URL_CODE))
          ;;
  GITLAB)
          REPO_NAME=$(basename           $SOURCE_URL_CODE);
          DEVELOPER=$(basename $(dirname $SOURCE_URL_CODE))
          ;;
  BTBCKT)
          REPO_NAME=$(basename           $SOURCE_URL_CODE);
          DEVELOPER=$(basename $(dirname $SOURCE_URL_CODE))
          ;;
  LNCHPD)
          SEARCH_DEVELOPER_REPOURL=$(echo $SOURCE_URL_REPO | grep "~");
          SEARCH_DEVELOPER_CODEURL=$(echo $SOURCE_URL_CODE | grep "~");
          if   [   -z "$SEARCH_DEVELOPER_REPOURL" ] && [ ! -z "$SEARCH_DEVELOPER_CODEURL" ]; then
          DEVELOPER=$(echo "$SOURCE_URL_CODE" | sed 's/.*\~//' | sed 's/\/.*//')
          REPO_NAME=$(dirname $(echo "$SOURCE_URL_CODE" | sed "s|.*~$DEVELOPER/||"))
          elif [ ! -z "$SEARCH_DEVELOPER_REPOURL" ] && [   -z "$SEARCH_DEVELOPER_CODEURL" ]; then
          DEVELOPER=$(echo "$SOURCE_URL_REPO" | sed 's/.*\~//' | sed 's/\/.*//')
          REPO_NAME=$(dirname $(echo "$SOURCE_URL_CODE" | sed "s|.*~$DEVELOPER/||"))
          elif [ ! -z "$SEARCH_DEVELOPER_REPOURL" ] && [ ! -z "$SEARCH_DEVELOPER_CODEURL" ]; then
          DEVELOPER=$(echo "$SOURCE_URL_REPO" | sed 's/.*\~//' | sed 's/\/.*//')
          REPO_NAME=$(dirname $(echo "$SOURCE_URL_REPO" | sed "s|.*~$DEVELOPER/||"))
          else
          echo "$FILE_NAME - WARNING:"											>&2;
          echo "                                  no developer name given (e.g. after the tilde ~)" 			>&2; 
          echo "                                  Falling back to manual download via GetFileViaRepoCheckout!"		>&2;
          FALLBACK_TO_DOWNLOAD_ALL="yes"
          REPO_NAME_CODE=$(dirname $(echo $SOURCE_URL_CODE | sed 's/.*launchpad.net\///'))
          REPO_NAME_REPO=$(dirname $(echo $SOURCE_URL_REPO | sed 's/lp\://'))
          echo "REPO_NAME_CODE=\"$REPO_NAME_CODE\""
          echo "REPO_NAME_REPO=\"$REPO_NAME_REPO\""
          fi
          echo "DEVELOPER=\"$DEVELOPER\""
          echo "REPO_NAME=\"$REPO_NAME\""
          ;;
  SRCFRG)
          ;;
  GOOGLE)
          echo "$FILE_NAME - WARNING:"											>&2;
          echo "                                  google code has been shut down, only full src downloads are possible"	>&2;
          echo "                                  Falling back to manual download via GetFileViaRepoCheckout!"		>&2; 
          FALLBACK_TO_DOWNLOAD_ALL="yes"
          ;;
  esac
  echo "REPO_NAME=\"$REPO_NAME\""											>>$METADATA_FILE
  echo "DEVELOPER=\"$DEVELOPER\""											>>$METADATA_FILE
  echo "$METADATA_FILE"
fi

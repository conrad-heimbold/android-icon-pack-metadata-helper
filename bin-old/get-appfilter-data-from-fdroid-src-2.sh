#/bin/bash
TEMP_DIR=/tmp
PURPLE='\033[0;35m'; NC='\033[0m'
if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "--usage" ]; then
  echo -e "\n"
  echo -e "usage: $(basename $0) <metadata file from fdroiddata> <folder for all data to be saved> <download mode>"
  echo -e "\n"
  echo -e "METADATA FILE from fdroiddata: See ${PURPLE}https://gitlab.com/fdroid/fdroiddata/tree/master/metadata${NC}"
  echo -e "\n"
  echo -e "FOLDER FOR ALL DATA:           All the ${PURPLE}app icons; activity names and activity icons${NC} go here."
  echo -e "\n"
  echo -e "DOWNLOAD MODE:                 Some online providers offer a WEB API to download single files directly. "
  echo -e "                               All however offer the possibility to download the source code completely."
  echo -e "                               The WEB API URL can sometimes only be guessed, so we need multiple tries."
  echo -e "                               Downloading only the necessary files via WEB APIs can be faster than"
  echo -e "                               checking out / downloading the complete source code; but don't always work."
  echo -e "                               "
  echo -e "                               ${PURPLE}DOWNLOAD${NC}: download the complete source code every time."
  echo -e "                               ${PURPLE}WEBAPI${NC}: try to use the WEB API as often as possible."
elif [ ! -f "$1" ] || [ ! -d "$2" ]; then
  FILE_NAME=$(basename "$1")
  echo "FILE_NAME:                        $FILE_NAME"
  FILE_PATH=$(realpath -e "$1")
  echo "FILE_PATH                         $FILE_PATH"
  echo "$FILE_NAME - ERROR:"                                                                                                >&2
  echo "                                  1st argument has to be the F-Droid metadata file; 2nd one a data folder."         >&2; exit
else
  FILE_NAME=$(basename "$1")
  echo "FILE_NAME:                        $FILE_NAME"
  FILE_PATH=$(realpath -e "$1")
  echo "FILE_PATH:                        $FILE_PATH"
  DATA_PATH=$(realpath -e "$2")
  echo "DATA_PATH:                        $DATA_PATH"
  REPO_TYPE=$(      grep "^Repo Type:"   "$FILE_PATH" | sed 's/Repo Type\://');
  echo "REPO_TYPE:                        $REPO_TYPE"
  SOURCE_URL_REPO=$(grep "^Repo:"        "$FILE_PATH" | sed 's/Repo\://'       );
  echo "SOURCE_URL_REPO:                  $SOURCE_URL_REPO"
  SOURCE_URL_CODE=$(grep "^Source Code:" "$FILE_PATH" | sed 's/Source Code\://');
  echo "SOURCE_URL_CODE:                  $SOURCE_URL_CODE"
  if [ "$REPO_TYPE" != "git" ]     && \
     [ "$REPO_TYPE" != "svn" ]     && \
     [ "$REPO_TYPE" != "git-svn" ] && \
     [ "$REPO_TYPE" != "hg" ]      && \
     [ "$REPO_TYPE" != "bzr" ];    then
  echo "$FILE_NAME - ERROR:"                                                                                                 >&2;
  echo "                                  unrecognized or unsupported REPO_TYPE $REPO_TYPE"                                  >&2;exit;fi
  if [   -z "$SOURCE_URL_REPO" ] && [   -z "$SOURCE_URL_CODE" ]; then 
  echo "$FILE_NAME - ERROR:   no source URL specified!" >&2; exit; fi
  APP_NAME1=$(      grep "^Auto Name:"   "$FILE_PATH" | sed 's/^Auto Name\://' );
  echo "APP_NAME1:                        $APP_NAME1"
  APP_NAME2=$(      grep "^Name:"        "$FILE_PATH" | sed 's/^Name\://');
  echo "APP_NAME2:                        $APP_NAME2"
  SUBDIR=$(tac "$FILE_PATH" | grep -m 1 "subdir="     | sed -E "s|^[ ]{1,10}subdir=||g" | sed -E "s|[ ]{1,10}$||g" )
  echo "SUBDIR:                           $SUBDIR"
  COMMIT=$(tac "$FILE_PATH" | grep -m 1 "commit="     | sed -E "s|^[ ]{1,10}commit=||g" | sed -E "s|[ ]{1,10}$||g" )
  echo "COMMIT:                           $COMMIT"
  BUILD=$( tac "$FILE_PATH" | grep -m 1 "Build:"      | sed -E "s|Build:||g"  | tr -d '[:blank:]' \
  | sed -E "s|,[0-9]{1,10}||g" | sed -E "s|\.|_|g" )
  echo "BUILD:                            $BUILD"
  VBUILD="v$BUILD"
  echo "VBUILD:                           $VBUILD"
  if [ ! -z "$APP_NAME1" ] && [ ! -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME1"; fi
  if [ ! -z "$APP_NAME1" ] && [   -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME1"; fi
  if [   -z "$APP_NAME1" ] && [ ! -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME2"; fi
  if [   -z "$APP_NAME1" ] && [   -z "$APP_NAME2" ]; then 
  echo "$FILE_NAME - ERROR:"                                                                                                 >&2;
  echo "                                  no app name specified! Specify one after 'Name:' or 'Auto Name:'"                  >&2;exit;fi
  APP_NAME_SIMPLE=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]'              | sed -E "s|^[ ]{1,10}||g" | \
    sed -E "s|[\;:,. /+\(\)\!\?\*=\`\´}{'$ -]|_|g"   | sed -E "s|[_]{1,4}|_|g" | sed -E "s|[_]{1,10}$||g" )
  echo "APP_NAME_SIMPLE:                  $APP_NAME_SIMPLE"
  # create the directory where we save all our metadata. 
  mkdir -p "$DATA_PATH/$APP_NAME_SIMPLE"
  touch "$DATA_PATH/$APP_NAME_SIMPLE/AndroidManifest.xml"
  # create the directory where we save all our temporary data: 
  mkdir -p "$TEMP_DIR/$APP_NAME_SIMPLE"
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
  echo "$FILE_NAME - WARNING:"
  echo "                                  src seems to be accessible in multiple different online src providers:"            >&2; 
  echo "                                  SOURCE_URL_CODE: $SOURCE_URL_CODE";                                                >&2
  echo "                                  SOURCE_URL_REPO: $SOURCE_URL_REPO";                                                >&2;exit;fi
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
          echo "$FILE_NAME - WARNING:"                                                                                       >&2;
          echo "                                  no developer name given (with a tilde ~) after 'Source Code:' or 'Repo:'!" >&2; 
          echo "                                  Falling back to manual download via GetFileViaRepoCheckout!"               >&2;
          FALLBACK_TO_DOWNLOAD_ALL="yes"
          REPO_NAME_CODE=$(dirname $(echo $SOURCE_URL_CODE | sed 's/.*launchpad.net\///'))
          REPO_NAME_REPO=$(dirname $(echo $SOURCE_URL_REPO | sed 's/lp\://'))
          echo "REPO_NAME_CODE:                   $REPO_NAME_CODE"
          echo "REPO_NAME_REPO:                   $REPO_NAME_REPO"
          fi
          echo "DEVELOPER:                        $DEVELOPER"
          echo "REPO_NAME:                        $REPO_NAME"
          ;;
  SRCFRG)
          ;;
  GOOGLE)
          echo "$FILE_NAME - WARNING:"                                                                                       >&2;
          echo "google code has been shut down, only complete src downloads are possible"                                    >&2;
          echo "                                  Falling back to manual download via GetFileViaRepoCheckout!"               >&2; 
          FALLBACK_TO_DOWNLOAD_ALL="yes"
          ;;
  esac
  echo "REPO_NAME:                        $REPO_NAME"
  echo "DEVELOPER:                        $DEVELOPER"

  # If GITLAB, GITHUB, BITBUCKET or SOURCEFORGE is used; direct download of single files is possible. 
  #    However, often we don't know the exact path to specific FILES (e.g. if a drawable is available as xxxhdpi, xxhdpi, mdpi, ...; 
  #    paths to the AndroidManifest.xml file can be /app/src/main or  /src/main or nothing at all! 
  #    so we have to guess (=> $PATH_TO_FILE) 
  #  GIT     ON GITHUB: 
  #    https://github.com/$DEVELOPER/$REPO_NAME/raw/{$COMMIT / HEAD / $TAG / $BRANCH / master}/$PATH_TO_FILE/$FILENAME
  #  GIT     ON GITLAB: 
  #    https://gitlab.com/$DEVELOPER/$REPO_NAME/raw/{$COMMIT / HEAD / $TAG / $BRANCH / master}/$PATH_TO_FILE/$FILENAME
  #  GIT     ON BTBCKT: 
  #    https://bitbucket.org/$DEVELOPER/$REPO_NAME/raw/{$COMMIT / HEAD / $TAG / $BRANCH / master}/$PATH_TO_FILE/$FILENAME
  #  GIT     ON LNCHPD: 
  #    https://git.launchpad.net/$REPO_NAME/$PATH_TO_FILE/$FILENAME?$IDENT
  #  HG      ON BTBCKT: 
  #    https://bitbucket.org/$DEVELOPER/$REPO_NAME/raw/{$COMMIT / HEAD / $TAG / $BRANCH / tip}/$PATH_TO_FILE/$FILENAME
  #  GIT     ON SRCFRG: 
  #    https://sourceforge.net/p/$REPO_NAME/code/ci/{$COMMIT / HEAD / $TAG / $BRANCH / master}/tree/$PATH_TO_FILE/$FILENAME?format=raw
  #  GIT-SVN ON SRCFRG: 
  #    https://sourceforge.net/p/$REPO_NAME/svn/{$COMMIT / HEAD / $TAG / $BRANCH / master}/tree/$PATH_TO_FILE/$FILENAME?format=raw
  #  SVN     ON SRCFRG: 
  #    http://svn.code.sf.net/p/$REPO_NAME/code/trunk/$PATH_TO_FILE/$FILENAME
  #  HG      ON SRCFRG: 
  #    http://hg.code.sf.net/p/$REPO_NAME/code/raw-file/{$COMMIT / tip / $TAG / $MASTER_BRANCH}/$PATH_TO_FILE/$FILENAME
  # If LAUNCHPAD is used, we can directly download single files; but unfortunately the download link for the file can't be 
  #    directly generated only with the information from F-Droid. So we have two possibilities: 
  #    - Download only the HTML VIEW file and extract the download link for the single file from the download website. 
  #    WEBSITE ON LNCHPD: 
  #    https://bazaar.launchpad.net/~$DEVELOPER/$REPO_NAME/{$BRANCH / trunk}/view/head:$PATH_TO_FILE/$FILENAME
  #    - clone the complete repo. 
  # GOOGLECODE has been shut down and doesn't offer any download possibility for single files. 
  #    Instead; we are forced to download the complete repo. 
  #    

  # FOR GITLAB, GITHUB, BITBUCKET, SOURCEFORGE (doesn't work for LAUNCHPAD or GOOGLECODE): 
  function GetFileViaWebAPI()
  {
    ONLINE_PROVIDER="$1" # can be "GITHUB", "GITLAB", "BTBCKT" or "SRCFRG"
    DEVELOPER="$2"; 
    REPO_NAME="$3"; 
    REPO_TYPE="$4"
    IDENT="$5"           # can be $BRANCH , $COMMIT, tip, master, trunk, $TAG, ... 
    # if REPO_TYPE=git:       IDENT= { $BRANCH | $COMMIT | $TAG | master }
    # if REPO_TYPE=(git-)svn: IDENT= { branches/$BRANCH | tags/$TAG | trunk }
    # if REPO_TYPE=hg: 	      IDENT= { $BRANCH | default | $COMMIT | $TAG | tip }
    PATH_TO_FILE="$6"; 
    FILENAME="$7"; 
    if   [ "$ONLINE_PROVIDER"="GITHUB" ]; then
      ONLINE_PROVIDER_URL="https://github.com"
      FILE_URL="$ONLINE_PROVIDER_URL/$DEVELOPER/$REPO_NAME/raw/$IDENT/$PATH_TO_FILE/$FILENAME"
    elif [ "$ONLINE_PROVIDER"="GITLAB" ]; then
      ONLINE_PROVIDER_URL="https://gitlab.com"
      FILE_URL="$ONLINE_PROVIDER_URL/$DEVELOPER/$REPO_NAME/raw/$IDENT/$PATH_TO_FILE/$FILENAME"
    elif [ "$ONLINE_PROVIDER"="BTBCKT" ]; then
      ONLINE_PROVIDER_URL="https://bitbucket.org"
      FILE_URL="$ONLINE_PROVIDER_URL/$DEVELOPER/$REPO_NAME/raw/$IDENT/$PATH_TO_FILE/$FILENAME"
    elif [ "$ONLINE_PROVIDER"="SRCFRG" ] && [ "$REPO_TYPE"="git" ] ; then 
      ONLINE_PROVIDER_URL="https://sourceforge.net"
      FILE_URL="$ONLINE_PROVIDER_URL/p/$REPO_NAME/code/ci/$IDENT/tree/$PATH_TO_FILE/$FILENAME?format=raw"
    elif [ "$ONLINE_PROVIDER"="SRCFRG" ] && [ "$REPO_TYPE"="git-svn" ]; then
      ONLINE_PROVIDER_URL="https://sourceforge.net"
      FILE_URL="$ONLINE_PROVIDER_URL/p/$REPO_NAME/svn/$IDENT/tree/$PATH_TO_FILE/$FILENAME?format=raw"
    elif [ "$ONLINE_PROVIDER"="SRCFRG" ] && [ "$REPO_TYPE"="svn" ]; then
      ONLINE_PROVIDER_URL="https://svn.code.sf.net"
      FILE_URL="$ONLINE_PROVIDER_URL/p/$REPO_NAME/code/trunk/$PATH_TO_FILE/$FILENAME"
    elif [ "$ONLINE_PROVIDER"="SRCFRG" ] && [ "$REPO_TYPE"="hg" ]; then
      ONLINE_PROVIDER_URL="https://hg.code.sf.net"
      FILE_URL="$ONLINE_PROVIDER_URL/p/$REPO_NAME/code/raw-file/$IDENT/$PATH_TO_FILE/$FILENAME"
    elif [ "$ONLINE_PROVIDER"="LNCHPD" ] && [ "$REPO_TYPE"="git" ]; then
      ONLINE_PROVIDER_URL="https://git.launchpad.net"
      FILE_URL="$ONLINE_PROVIDER_URL/$REPO_NAME/plain/$PATH_TO_FILE/$FILENAME?id=$IDENT"
    fi
    echo "$FILE_URL"
  }

    if   [ "$REPO_TYPE"="git"     ]; then POSSIBLE_IDENT[0]="master"; 
    elif [ "$REPO_TYPE"="git-svn" ]; then POSSIBLE_IDENT[0]="trunk"; 
    elif [ "$REPO_TYPE"="svn"     ]; then POSSIBLE_IDENT[0]="trunk"; 
    elif [ "$REPO_TYPE"="hg"      ]; then POSSIBLE_IDENT[0]="tip"; 
    fi
    POSSIBLE_IDENT[1]="$COMMIT"
    POSSIBLE_IDENT[2]="$TAG"
    POSSIBLE_IDENT[3]="$BRANCH"
    POSSIBLE_IDENT[4]="trunk"
    POSSIBLE_IDENT[5]="tip"
    POSSIBLE_IDENT[6]="$BUILD"
    POSSIBLE_IDENT[7]="$VBUILD"
    
    POSSIBLE_SUBDIR[0]="$SUBDIR"; 
    POSSIBLE_SUBDIR[1]="$SUBDIR/src/main"
    POSSIBLE_SUBDIR[2]="$SUBDIR/app/src/main"
    POSSIBLE_SUBDIR[3]="$APP_NAME_SIMPLE"
    POSSIBLE_SUBDIR[4]="$APP_NAME_SIMPLE/src/main"
    POSSIBLE_SUBDIR[5]="$APP_NAME_SIMPLE/app/src/main"
    POSSIBLE_SUBDIR[6]=""
    POSSIBLE_SUBDIR[7]="src/main"
    POSSIBLE_SUBDIR[8]="app/src/main"
    POSSIBLE_SUBDIR[9]="$APP_NAME_SIMPLE/android"
    POSSIBLE_SUBDIR[10]="$APP_NAME_SIMPLE/android/src/main"

  #if [ ! "$FALLBACK_TO_DOWNLOAD_ALL"="yes" ]; then
  cd $DATA_PATH/$APP_NAME_SIMPLE/
  echo "DATA_PATH/APP_NAME_SIMPLE/...:    $DATA_PATH/$APP_NAME_SIMPLE/AndroidManifest.xml"
  FINISHED="no"
  I=0; while [ ! "$FINISHED"="no" ]; do
  K=0; while [ ! "$FINISHED"="no" ]; do
  WEB_URL=$(GetFileViaWebAPI $ONLINE_SOURCE_PROVIDER $DEVELOPER \
                             $REPO_NAME $REPO_TYPE ${POSSIBLE_IDENT[$I]} ${POSSIBLE_SUBDIR[$K]} AndroidManifest.xml \
                             | sed "s|\.xml/|\.xml|")
  echo "WEB_URL:                          $WEB_URL"
  curl -f -L -o $DATA_PATH/$APP_NAME_SIMPLE/AndroidManifest.xml $WEB_URL && FINISHED="yes";
  if [ "$FINISHED"="yes" ]; then 
  SUCCESSFUL_IDENT="${POSSIBLE_IDENT[$I]}";
  SUCCESSFUL_SUBDR="${POSSIBLE_SUBDIR[$K]}"; 
  SUCCESSFUL_IDENT_NMBR="$I"; 
  SUCCESSFUL_SUBDR_NMBR="$K"; 
  break 3; fi 
  FINISHED="no"
  K=$(( $K + 1 ))
  done
  I=$(( $I + 1 ))
  done
  FINISHED="no"
  echo "SUCCESSFUL_IDENT:                 $SUCCESSFUL_IDENT"
  echo "SUCCESSFUL_SUBDIR:                $SUCCESSFUL_SUBDIR"
  echo "SUCCESSFUL_IDENT_NMBR:            $SUCCESSFUL_IDENT_NMBR"
  echo "SUCCESSFUL_SUBDR_NMBR:            $SUCCESSFUL_SUBDR_NMBR"
  #fi
  # FOR LAUNCHPAD (would work for GITLAB, GITHUB, BITBUCKET as well; but would not be very efficient)
  function GetFileViaWebView()
  {
    ONLINE_PROVIDER="$1" # can so far only be "LNCHPD"
    DEVELOPER="$2"
    REPO_NAME="$3"
    REPO_TYPE="$4"
    IDENT="$5" # can be $COMMIT or HEAD, $TAG, $BRANCH, master, tip, trunk, $REVISION, etc.; depending on CVS
    PATH_TO_FILE="$6"
    FILENAME="$7"
    if   [ "$ONLINE_PROVIDER"="LNCHPD" ]; then
      HTML_VIEW_URL="https://bazaar.launchpad.net/~$DEVELOPER/$REPO_NAME/$IDENT/view/head:$PATH_TO_FILE/$FILENAME"
      LINE_SEARCH_STRING="download file"
      OPEN_SEARCH_STRING="<a href=\""
      CLOSE_SEARCH_STRING="\"> download file</a>"
    fi
    RELATIVE_FILE_URL=$(wget -q --output-document=/dev/stdout "$HTML_VIEW_URL" | grep "$LINE_SEARCH_STRING" \
    | sed 's|$OPEN_SEARCH_STRING||g' | sed 's|$CLOSE_SEARCH_STRING||g' | tr -d '[:blank:]' )
    ABSOLUTE_FILE_URL="$ONLINE_PROVIDER_URL/$RELATIVE_FILE_URL"; 
    echo "$ABSOLUTE_FILE_URL"
  }

  function GetFileViaRepoCheckout()
  {
  # for Google Code: 
    if [ "$ONLINE_SOURCE_PROVIDER"="GOOGLE" ]; then
    	SOURCE_URL="https://storage.googleapis.com/google-code-archive-source/v2/code.google.com/$REPO_NAME/source-archive.zip"
    fi
    wget -q "$SOURCE_URL" --output-document="$TEMP_DIR/$APP_NAME_SIMPLE/source-archive.zip"
    unzip "$TEMP_DIR/$APP_NAME_SIMPLE/source-archive.zip"
    FILE_PATHS=$(find "$TEMP_DIR/$APP_NAME_SIMPLE/" -type f -name AndroidManifest.xml) 
  }

  function ParseAndroidManifestFile()
  {
    APP_NAME_SIMPLE=$1
    ANDROID_MANIFEST_FILE=$2
    DESTINATION_DIR=$3

  sed 's/android://g' "$ANDROID_MANIFEST_FILE" > "$DESTINATION_DIR"/AndroidManifestWithoutAndroidNS.xml; 
  PACKAGE_NAME=$(		xmllint --xpath 2>/dev/null \
	"/manifest/@package" \
	"$DESTINATION_DIR"/AndroidManifestWithoutAndroidNS.xml \
        | sed 's/package=\"//g' | sed 's/\"//g' | tr -d '[:space:]')
  LIST_OF_ACTIVITY_NAMES_RAW=$(	xmllint --xpath 2>/dev/null \
	"//category[@name='android.intent.category.LAUNCHER']/../action[@name='android.intent.action.MAIN']/../../@name" \
	"$DESTINATION_DIR"/AndroidManifestWithoutAndroidNS.xml \
        | sed 's/name=\"/ /g'   | sed 's/\"/ /g' | tr -s '[:space:]'; printf "\n")
  APP_ICON=$(			xmllint --xpath  2>/dev/null \
        "//application/@icon" \
        "$DESTINATION_DIR"/AndroidManifestWithoutAndroidNS.xml \
        | sed 's/icon=\"@//g' | sed 's/\"//g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g");
  APP_NAME3=$(			xmllint --xpath  2>/dev/null \
	"//application/@name" \
	"$DESTINATION_DIR"/AndroidManifestWithoutAndroidNS.xml \
	| sed 's/name=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g"; printf "\n")
  K=0; for ACTIVITY_NAME in "$LIST_OF_ACTIVITY_NAMES_RAW"; do
  	ACTIVITY_NAME_COMPLETE=$(echo "$ACTIVITY_NAME" \
       		| sed "s|^\.|$PACKAGE_NAME\.|g")
  	ACTIVITY_NAME_SIMPLE=$(echo "$ACTIVITY_NAME" \
        	| tr '[:upper:]' '[:lower:]' \
  		| sed -E "s|activity||g" | sed -E "s|\.ui||g" \
        	| sed -E "s|main||g" | sed -E "s|[.-]{1,3}||g" )
  	LIST_OF_ACTIVITY_NAMES_COMPLETE="$LIST_OF_ACTIVITY_NAMES_COMPLETE $ACTIVITY_NAME_COMPLETE";
  	LIST_OF_ACTIVITY_NAMES_SIMPLE="$LIST_OF_ACTIVITY_NAMES_SIMPLE $ACTIVITY_NAME_SIMPLE"
  	ARRAY_OF_ACTIVITY_NAMES_COMPLETE[$K]="$ACTIVITY_NAME_COMPLETE"
  	ARRAY_OF_ACTIVITY_NAMES_SIMPLE[$K]="$ACTIVITY_NAME_SIMPLE"
  	ARRAY_OF_ACTIVITY_NAMES[$K]="$ACTIVITY_NAME"
     	     ACTIVITY_ICON_SOURCE=$(         xmllint --xpath  2>/dev/null \
        	"//application/@icon" \
        	"$DESTINATION_DIR"/AndroidManifestWithoutAndroidNS.xml \
        	| sed 's/icon=\"@//g' | sed 's/\"//g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g");
  	ACTIVITY_ICON_NAME=$(basename "$ACTIVITY_ICON_SOURCE" )
  	ACTIVITY_ICON_PATH=$(dirname  "$ACTIVITY_ICON_SOURCE" )
  	LIST_OF_ACTIVITY_ICONS="$LIST_OF_ACTIVITY_ICONS $ACTIVITY_ICON_SOURCE";
  	LIST_OF_ACTIVITY_ICON_NAMES="$LIST_OF_ACTIVITY_ICON_NAMES $ACTIVITY_ICON_NAME"
  	LIST_OF_ACTIVITY_ICON_PATHS="$LIST_OF_ACTIVITY_ICON_PATHS $ACTIVITY_ICON_PATH"
  	ARRAY_OF_ACTIVITY_ICONS[$K]="$ACTIVITY_ICON"
  	ARRAY_OF_ACTIVITY_ICON_NAMES[$K]="ACTIVITY_ICON_NAME"
  	ARRAY_OF_ACTIVITY_ICON_PATHS[$K]="ACTIVITY_ICON_PATH"
        echo "ACTIVITIES:  $LIST_OF_ACTIVITY_NAMES_COMPLETE"
        echo "ACTIV_ICONS: $LIST_OF_ACTIVITY_ICONS"
  	K=$(( $K + 1 ))
  done
  }
#  function ReturnAllMetaData()
#  {
#  echo "blabla"
#  }
#  function ReturnAppfilterMetadata()
#  {
#  echo "blabla"
#  }
fi

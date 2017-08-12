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
  FILE_PATH=$(realpath -e "$1")
  # ERROR: The first argument has to be the F-Droid metadata file from https://gitlab.com/fdroid/fdroiddata/metadata; 
  #        the second argument has to be a folder where all the metadata (package name, main activity names, icons) get saved
  echo "ERROR: $FILE_NAME - ERROR: First argument has to be the F-Droid metadata file; the second one a folder for all the data."
else
  FILE_NAME=$(basename "$1")
  FILE_PATH=$(realpath -e "$1")
  DATA_PATH=$(realpath -e "$2")
  REPO_TYPE=$(      grep "^Repo Type:"   "$FILE_PATH" | sed 's/Repo Type\://');
  SOURCE_URL_REPO=$(grep "^Repo:"        "$FILE_PATH" | sed 's/Repo\://'       );
  SOURCE_URL_CODE=$(grep "^Source Code:" "$FILE_PATH" | sed 's/Source Code\://');
  if [ "$REPO_TYPE" != "git" ] && [ "$REPO_TYPE" != "svn" ] && [ "$REPO_TYPE" != "git-svn" ] && [ "$REPO_TYPE" != "hg" ] && [ "$REPO_TYPE" != "bzr" ]; then
  echo "$FILE_NAME - ERROR: unrecognized or unsupported REPO_TYPE $REPO_TYPE" >&2; exit; fi
  if [   -z "$SOURCE_URL_REPO" ] && [   -z "$SOURCE_URL_CODE" ]; then 
  echo "$FILE_NAME - ERROR: no source URL specified!" >&2; exit; fi
  APP_NAME1=$(      grep "^Auto Name:"   "$FILE_PATH" | sed 's/^Auto Name\://' );
  APP_NAME2=$(      grep "^Name:"        "$FILE_PATH" | sed 's/^Name\://');
  SUBDIR=$(tac "$FILE_PATH" | grep -m 1 "subdir="     | sed -E "s|^[ ]{1,10}subdir=||g" | sed -E "s|[ ]{1,10}$||g" )
  COMMIT=$(tac "$FILE_PATH" | grep -m 1 "commit="     | sed -E "s|^[ ]{1,10}commit=||g" | sed -E "s|[ ]{1,10}$||g" )
  BUILD=$( tac "$FILE_PATH" | grep -m 1 "Build:"      | sed -E "s|^[ ]{1,10}Build:||g"  | sed -E "s|[ ]{1,10}$||g" | sed -E "s|,[0-9]{1,10}||g" | sed -E "s|\.|_|g" )
  BUILDV="v$BUILD"
  # only take the APP_NAME* that is not empty. Spit out ERROR if no app name is specified. 
  if [ ! -z "$APP_NAME1" ] && [ ! -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME1"; fi
  if [ ! -z "$APP_NAME1" ] && [   -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME1"; fi
  if [   -z "$APP_NAME1" ] && [ ! -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME2"; fi
  if [   -z "$APP_NAME1" ] && [   -z "$APP_NAME2" ]; then echo "$FILE_NAME - ERROR: no app name specified!" >&2; exit; fi
  APP_NAME_SIMPLE=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]'              | sed -E "s|^[ ]{1,10}||g" | \
    sed -E "s|[\;:,. /+\(\)\!\?\*=\`\´}{'$ -]|_|g"   | sed -E "s|[_]{1,4}|_|g" | sed -E "s|[_]{1,10}$||g" )
  # create the directory where we save all our metadata. 
  mkdir -p "$DEST_DIR/$APP_NAME_SIMPLE"
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
  echo "$FILE_NAME - WARNING: the source seems to be accessible in multiple different online source providers; which could lead to problems!" >&2; 
  echo "   SOURCE_URL_CODE: 	$SOURCE_URL_CODE"
  echo "   SOURCE_URL_REPO: 	$SOURCE_URL_REPO"
  fi
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

  # Everything before $DEVELOPER / $REPO_NAME (https://github.com , https:/sourceforge.net, ...) will be called ONLINE Provider Service
  ONLINE_SOURCE_PROVIDER=; 
  # Everything before $PATH_TO_FILE will be called WEB_ROOT_PATH_URL
  WEB_ROOT_PATH_URL=; 
  # FOR GITLAB, GITHUB, BITBUCKET, SOURCEFORGE (doesn't work for LAUNCHPAD or GOOGLECODE): 
  function GetFileViaWebAPI()
  {
  ONLINE_PROVIDER=$1 # can be "GITHUB", "GITLAB", "BTBCKT" or "SRCFRG"
  IDENT=$2 # can be $COMMIT or HEAD, $TAG, $BRANCH, master, tip, trunk, $REVISION, etc.; depending on CVS. 
  }
  # FOR LAUNCHPAD (would work for GITLAB, GITHUB, BITBUCKET as well; but would not be very efficient. )
  function GetFileViaWebView()
  {
  ONLINE_PROVIDER=$1 # can so far only be "LNCHPD"
  IDENT=$2 # can be $COMMIT or HEAD, $TAG, $BRANCH, master, tip, trunk, $REVISION, etc.; depending on CVS
  }
  # FOR GOOGLECODE (would work for all other providers as well; but is very slow.)
  function GetFileViaRepoCheckout()
  {
  echo "bla"
  # if $1 == repo from google code; then ONLINE_PROVIDER == "GOOGLE"
  # else REPO_URL=$1
  }

  function ParseAndroidApp()
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
  if   [ "$SOURCE_OR_BINARY" == "source" ]; then
     APP_ICON_SOURCE=$(		xmllint --xpath  2>/dev/null \
        "//application/@icon" \
        "$DESTINATION_DIR"/AndroidManifestWithoutAndroidNS.xml \
        | sed 's/icon=\"@//g' | sed 's/\"//g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g");
  elif [ "$SOURCE_OR_BINARY" == "binary" ]; then
     APP_ICON_BINARY=$(         xmllint --xpath  2>/dev/null \
        "//application/@icon" \
        "$DESTINATION_DIR"/AndroidManifestWithoutAndroidNS.xml \
        | sed 's/icon=\"@//g' | sed 's/\"//g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g" | tr '[:upper:]' '[:lower:]');
     APP_ICON_SOURCE=$(aapt d resources $APK_FILE | grep -m 1 "$APP_ICON_BINARY" \
	| sed "s/.*$PACKAGE_NAME://g" | sed 's/: .*//g')
  fi
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
  function ReturnAllMetaData()
  {
  echo "blabla"
  }
  function ReturnAppfilterMetadata()
  {
  echo "blabla"
  }
fi

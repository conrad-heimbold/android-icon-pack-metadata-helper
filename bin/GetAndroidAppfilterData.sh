#!/bin/bash
if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ "$1" == "--usage" ]; then
  echo "usage: $0 <app-metadata from fdroiddata repo> <folder to save all metadata (max. 1GB of space needed!)>"
else
  if [ ! -f $1 ] || [ ! -d $2 ]; then
# ERROR: FIRST ARGUMENT HAS TO BE A FILE; SECOND ONE A FOLDER
        echo "$FILENAME - ERROR: FIRST argument has to be a FILE, the SECOND one a FOLDER" >&2; exit 1;
  else
        # APP_NAME1 comes from the F-Droid Metadata FILE, after "Auto Name:"
        # APP_NAME2 comes from the F-Droid Metadata FILE, after "Name:"
        # APP_NAME3 comes from the AndroidManifest.xml FILE, from manifest/application/@android:name="..."
        # SOURCE_URL1 comes from the F-Droid Metadata FILE, after "Repo:"
        # SOURCE_URL2 comes from the F-Droid Metadata FILE, after "Source Code:"
        FILE="$1"; DEST_DIR=$2; FILENAME=$(basename $FILE); 
        # PART 1: PARSE ALL THE NECESSARY INFORMATION FROM THE METADATA FILES IN F-DROID
        # =============================================================================================================================
        SOURCE_URL1=$(grep "^Repo:" $FILE | sed 's/Repo\://' | sed 's/\.git$//'); 
        SOURCE_URL2=$(grep "^Source Code:" $FILE | sed 's/Source Code\://'); 
        # only take the SOURCE_URL* that is not empty.
        # test if both SOURCE_URLS are empty => ERROR 
        if [ ! -z "$SOURCE_URL1" ] && [ ! -z "$SOURCE_URL2" ]; then SOURCE_URL="$SOURCE_URL1"; fi
        if [ ! -z "$SOURCE_URL1" ] && [   -z "$SOURCE_URL2" ]; then SOURCE_URL="$SOURCE_URL1"; fi
        if [   -z "$SOURCE_URL1" ] && [ ! -z "$SOURCE_URL2" ]; then SOURCE_URL="$SOURCE_URL2"; fi
# ERROR: NO SOURCE URL!    
        if [   -z "$SOURCE_URL1" ] && [   -z "$SOURCE_URL2" ]; then echo "$FILENAME - ERROR: no source URL specified!" >&2; fi
        # Create the URL to checkout the REPO via git/svn/hg
        REPO_TYPE=$(grep "^Repo Type:" $FILE | sed 's/Repo Type\://')
        if [ "$REPO_TYPE" == "git" ]; then GIT_URL=$(echo $SOURCE_URL | sed 's/$/.git/'); fi
        if [ "$REPO_TYPE" == "svn" ]; then SVN_URL="$SOURCE_URL";                         fi
        if [ "$REPO_TYPE" == "hg"  ]; then  HG_URL="$SOURCE_URL";                         fi
# ERROR: UNSUPPORTED OR UNRECOGNIZED REPO TYPE
        if [ "$REPO_TYPE" != "git" ] && [ "$REPO_TYPE" != "hg" ] && [ "$REPO_TYPE" !=  "svn" ]; then
        echo "$FILENAME - ERROR: unrecognized or unsupported REPO_TYPE called $REPO_TYPE" >&2; fi
        SEARCH_GITHUB=$(echo $SOURCE_URL | grep "github"   )
        SEARCH_GITLAB=$(echo $SOURCE_URL | grep "gitlab"   )
        SEARCH_BTBCKT=$(echo $SOURCE_URL | grep "bitbucket")
        SEARCH_SRCFRG=$(echo $SOURCE_URL | grep "sf.net"   )
        SEARCH_GOOGLE=$(echo $SOURCE_URL | grep "google"   )
        if [ ! -z "$SEARCH_GITHUB" ] || [ ! -z "$SEARCH_GITLAB" ] || [ ! -z "$SEARCH_BTBCKT" ]; then
        DEVELOPER=$(basename $(dirname                   $SOURCE_URL))
        REPO_NAME=$(basename                             $SOURCE_URL);
        ONLINE_SERVICE_URL=$(dirname $(dirname           $SOURCE_URL));   fi
        if [ ! -z "$SEARCH_SRCFRG" ] || [ ! -z "$SEARCH_GOOGLE" ]; then
        REPO_NAME=$(basename $(dirname                   $SOURCE_URL2)); 
        ONLINE_SERVICE_URL=$(dirname $(dirname $(dirname $SOURCE_URL2))); fi
        # Get the app name
        APP_NAME1=$(grep "^Auto Name:" $FILE | sed 's/^Auto Name\://' )
        APP_NAME2=$(grep "^Name:"      $FILE | sed 's/^Name\://')
        # only take the APP_NAME* that is not empty.
        if [ ! -z "$APP_NAME1" ] && [ ! -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME1"; fi
        if [ ! -z "$APP_NAME1" ] && [   -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME1"; fi
        if [   -z "$APP_NAME1" ] && [ ! -z "$APP_NAME2" ]; then APP_NAME="$APP_NAME2"; fi
        if [   -z "$APP_NAME1" ] && [   -z "$APP_NAME2" ]; then 
# ERROR: NO APP NAME SPECIFIED! 
        echo "$FILENAME - ERROR: no app name specified!" >&2; fi
        # Give the $APP_NAME a canonical form (without whitespace, without special chars, etc.)
        APP_NAME_SIMPLE=$(echo $APP_NAME | tr '[:upper:]' '[:lower:]'              | sed -E "s|^[ ]{1,10}||g" | \
        sed -E "s|[\;:,. /+\(\)\!\?\*=\`\´}{'$ -]|_|g"   | sed -E "s|[_]{1,4}|_|g" | sed -E "s|[_]{1,10}$||g" )
        SUBDIR=$(tac "$FILE" | grep -m 1 subdir= | sed -E "s|^[ ]{1,10}subdir=||g" | sed -E "s|[ ]{1,10}$||g" )
        COMMIT=$(tac "$FILE" | grep -m 1 commit= | sed -E "s|^[ ]{1,10}commit=||g" | sed -E "s|[ ]{1,10}$||g" )
        TAG_TMP=$(tac "$FILE" | grep -m 1 Build: | sed -E "s|Build:||g" | sed -E "s|,[0-9]{1,10}||g" | sed -E "s|\.|_|g")
        TAG="v$TAG_TMP"
        if [ -d $DEST_DIR/"$APP_NAME_SIMPLE" ]; then echo "Metadata already downloaded"; exit; fi
        mkdir -p $DEST_DIR/"$APP_NAME_SIMPLE"; cd $DEST_DIR/"$APP_NAME_SIMPLE"
        POSSIBLE_URL_PART[0]="$COMMIT/$SUBDIR"
        POSSIBLE_URL_PART[1]="$COMMIT/$SUBDIR/src/main"
        POSSIBLE_URL_PART[2]="$COMMIT/app"
        POSSIBLE_URL_PART[3]="$COMMIT/app/src/main"
        POSSIBLE_URL_PART[4]="$COMMIT/$SUBDIR/app/src/main"
        POSSIBLE_URL_PART[5]="$TAG/$SUBDIR"
        POSSIBLE_URL_PART[6]="$TAG/$SUBDIR/src/main"
        POSSIBLE_URL_PART[7]="$TAG/app"
        POSSIBLE_URL_PART[8]="$TAG/app/src/main"
        POSSIBLE_URL_PART[9]="$TAG/$SUBDIR/app/src/main"
        POSSIBLE_URL_PART[10]="$COMMIT/tree/$SUBDIR" # needed for sourceforge
        POSSIBLE_URL_PART[11]="$COMMIT/tree/$SUBDIR/src/main" # needed for sourceforge
        POSSIBLE_URL_PART[12]="$COMMIT/tree/app" # needed for sourceforge
        POSSIBLE_URL_PART[13]="$COMMIT/tree/app/src/main" # needed for sourceforge
        POSSIBLE_URL_PART[14]="$COMMIT/tree/$SUBDIR/app/src/main" # needed for sourceforge
        POSSIBLE_URL_PART[15]="$TAG/tree/$SUBDIR"
        POSSIBLE_URL_PART[16]="$TAG/tree/$SUBDIR/src/main"
        POSSIBLE_URL_PART[17]="$TAG/tree/app"
        POSSIBLE_URL_PART[18]="$TAG/tree/app/src/main"
        POSSIBLE_URL_PART[19]="master/$SUBDIR"
        POSSIBLE_URL_PART[20]="master/$SUBDIR/src/main"
        POSSIBLE_URL_PART[21]="master/app"
        POSSIBLE_URL_PART[22]="master/app/src/main"
        POSSIBLE_URL_PART[23]="master/$SUBDIR/app/src/main"
        POSSIBLE_URL_PART[24]="tip/$SUBDIR"
        POSSIBLE_URL_PART[25]="tip/$SUBDIR/src/main"
        POSSIBLE_URL_PART[26]="tip/app"
        POSSIBLE_URL_PART[27]="tip/app/src/main"
        POSSIBLE_URL_PART[28]="tip/$SUBDIR/app/src/main"
        # PART 2: CHECKOUT THE SOURCE (IF POSSIBLE, ONLY THE NEEDED FILES) FROM THE $SOURCE_URL
        # ===================================================================================================================================
        # test, if SOURCE_URL contains github
        SEARCH_GITHUB=$(echo $SOURCE_URL | grep "github"   )
        SEARCH_GITLAB=$(echo $SOURCE_URL | grep "gitlab"   )
        SEARCH_BTBCKT=$(echo $SOURCE_URL | grep "bitbucket")
        SEARCH_SRCFRG=$(echo $SOURCE_URL | grep "sf.net"   )
        SEARCH_GOOGLE=$(echo $SOURCE_URL | grep "google"   )
        GITHUB_BASE_URL="https://github.com"
        GITLAB_BASE_URL="https://gitlab.com"
        BTBCKT_BASE_URL="https://bitbucket.com"
        SRCFRG_BASE_URL="https://sourceforge.net";
        I=0; NUMBER_OF_POSSIBLE_URL_PARTS=30; FINISHED="false"; 
        while [ $I -lt $NUMBER_OF_POSSIBLE_URL_PARTS ]; do
        if [ ! -z "$SEARCH_GITHUB" ]; then
        ANDROID_MANIFEST_URL[$I]="$GITHUB_BASE_URL/$DEVELOPER/$REPO_NAME/raw/${POSSIBLE_URL_PART[$I]}/AndroidManifest.xml";                   fi
        if [ ! -z "$SEARCH_GITLAB" ]; then
        ANDROID_MANIFEST_URL[$I]="$GITLAB_BASE_URL/$DEVELOPER/$REPO_NAME/raw/${POSSIBLE_URL_PART[$I]}/AndroidManifest.xml";                   fi
        if [ ! -z "$SEARCH_BTBCKT" ]; then
        ANDROID_MANIFEST_URL[$I]="$BTBCKT_BASE_URL/$DEVELOPER/$REPO_NAME/raw/${POSSIBLE_URL_PART[$I]}/AndroidManifest.xml";                   fi
        if [ ! -z "$SEARCH_SRCFRG" ] && [ "$REPO_TYPE" == "svn" ]; then
        ANDROID_MANIFEST_URL[$I]="$SRCFRG_BASE_URL/p/$REPO_NAME/code/HEAD/tree/tags/${POSSIBLE_URL_PART[$I]}/AndroidManifest.xml?format=raw"; fi
        if [ ! -z "$SEARCH_SRCFRG" ] && [ "$REPO_TYPE" == "git" ]; then
        ANDROID_MANIFEST_URL[$I]="$SRCFRG_BASE_URL/p/$REPO_NAME/code/ci/${POSSIBLE_URL_PART[$I]}/AndroidManifest.xml?format=raw";         fi
        if [ ! -z "$SEARCH_GOOGLE" ]; then
# ERROR: GOOGLE CODE DOES NOT OFFER A WEB API. 
         echo "$FILENAME - ERROR: GOOGLE CODE does not have a WEB API anymore. Please download manually.." >&2;                          fi
         wget -q "${ANDROID_MANIFEST_URL[$I]}" && FINISHED="FINISHED" && SUCCESSFUL_SUB_PATH="${POSSIBLE_URL_PART[$I]}" \
        && WEB_ROOT_URL=$(dirname "${ANDROID_MANIFEST_URL[$I]}")
        if [ "$FINISHED" == "FINISHED" ]; then
        break; 
        fi
        mv "AndroidManifest.xml?format=raw" "AndroidManifest.xml" 2>/dev/null; 
        I=$(( $I + 1 ))
        done
# ERROR: COULD NOT DOWNLOAD ANDROID MANIFEST (WRONG URL)
         if [ "$FINISHED" == "false" ]; then
         echo "$FILENAME - ERROR: could not download AndroidManifest.xml" >&2;
         echo "SUBDIR: $SUBDIR" >&2 
         echo "TAG:    $TAG" >&2
         echo "ANDROID_MANIFEST_URLS:" >&2

         printf '%s         '"${ANDROID_MANIFEST_URL[@]} \n"; echo " "; printf "\n"; fi
         # What I am searching for inside the AndroidManifest: 
         # $PACKAGE_NAME
         # $LAUNCHER_ICON_PATHS 
         # $LAUNCHER_ACTIVITIES
         PACKAGE_NAME=$(xmllint --xpath 2>/dev/null \
           "/manifest/@package" AndroidManifest.xml | sed 's/package=\"//g' | sed 's/\"//g' | tr -d '[:space:]')
         # Parsing the AndroidManifest.xml FILE: 
         cat AndroidManifest.xml | sed 's/android://g' > AndroidManifestWithoutAndroidNS.xml 
         RAW_LIST_OF_ACTIVITIES=$(xmllint --xpath 2>/dev/null \
           "//category[@name='android.intent.category.LAUNCHER']/../action[@name='android.intent.action.MAIN']/../../@name" \
           AndroidManifestWithoutAndroidNS.xml 2>/dev/null | sed 's/name=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]'; printf "\n")
         LIST_OF_ACTIVITY_ICONS=$(xmllint --xpath 2>/dev/null \
           "//category[@name='android.intent.category.LAUNCHER']/../action[@name='android.intent.action.MAIN']/../../@icon" \
           AndroidManifestWithoutAndroidNS.xml 2>/dev/null | sed 's/icon=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]'; printf "\n")
         APPLICATION_ICON=$(xmllint --xpath  "//application/@icon" \
           AndroidManifestWithoutAndroidNS.xml 2>/dev/null | sed 's/icon=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g"; printf "\n")
         APPLICATION_ICON_NAME=$(basename $APPLICATION_ICON ); 
         APPLICATION_ICON_PATH=$(dirname $APPLICATION_ICON | sed -E "s|@||g" ); 
         APP_NAME3=$(xmllint --xpath "//application/@name" \
           AndroidManifestWithoutAndroidNS.xml 2>/dev/null | sed 's/name=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g"; printf "\n") 
       K=0; for ACTIVITY in $RAW_LIST_OF_ACTIVITIES ; do
         COMPLETE_ACTIVITY_NAME=$(echo $ACTIVITY | sed "s|^\.|$PACKAGE_NAME\.|g"); 
         SIMPLE_ACTIVITY_NAME=$(echo "$ACTIVITY" | tr '[:upper:]' '[:lower:]' | sed -E "s|activity||g" | sed -E "s|\.ui||g" | sed -E "s|main||g" | sed -E "s|^\.\-||g" )
         # echo $SIMPLE_ACTIVITY_NAME
         ARRAY_OF_ACTIVITY_NAMES[$K]=$COMPLETE_ACTIVITY_NAME; 
         ARRAY_OF_SIMPLE_ACTIVITY_NAMES[$K]=$SIMPLE_ACTIVITY_NAME;
         K=$(( $K + 1 )); done
       K=0; for ICON in $LIST_OF_ACTIVITY_ICONS ; do
         ARRAY_OF_ACTIVITY_ICONS[$K]=$ICON; 
         ARRAY_OF_ACTIVITY_ICON_PATHS[$K]=$(dirname  $(echo $ICON)); 
         ARRAY_OF_ACTIVITY_ICON_NAMES[$K]=$(basename $(echo $ICON)); 
         K=$(( $K + 1 )); done
#       K=0; while [ "$K" -le ${#ARRAY_OF_ACTIVITY_NAMES[*]} ]; do
#         echo "<!-- $APP_NAME - ${ARRAY_OF_ACTIVITY_NAMES[$K]} -->" >> $DEST_DIR/appfilter.xml
#         echo "<item component=\"ComponentInfo{$PACKAGE_NAME/${ARRAY_OF_ACTIVITY_NAMES[$K]}}\" drawable=\"$APP_NAME_SIMPLE\" />" >> $DEST_DIR/appfilter.xml ; 
#         K=$(( $K + 1 )); done
       rm $DEST_DIR/$APP_NAME_SIMPLE/AndroidManifestWithoutAndroidNS.xml
     # DOWNLOAD THE APPLICATION ICON
     POSSIBLE_ICON_URL_PARTS[0]="-xxxhdpi"
     POSSIBLE_ICON_URL_PARTS[1]="-xxhdpi"
     POSSIBLE_ICON_URL_PARTS[2]="-xhdpi"
     POSSIBLE_ICON_URL_PARTS[3]="-hdpi"
     POSSIBLE_ICON_URL_PARTS[4]="-mdpi"
     POSSIBLE_ICON_URL_PARTS[5]="-ldpi"
     POSSIBLE_ICON_URL_PARTS[7]=""
     L=0; K=0; M=0;  
     # DOWNLOAD THE APPLICATION ICON
     while [ "$K" -le ${#POSSIBLE_ICON_URL_PARTS[*]} ]
     do
     wget -q "$WEB_ROOT_URL/res/${APPLICATION_ICON_PATH}${POSSIBLE_ICON_URL_PARTS[$K]}/$APPLICATION_ICON_NAME.png" && break; 
     K=$(( $K + 1 ))
     done
     while [ "$L" -le ${#ARRAY_OF_ACTIVITY_ICONS[*]} ]; do
     while [ "$M" -le ${#POSSIBLE_ICON_URL_PARTS[*]} ]; do
     if [ ! -z "${ARRAY_OF_ACTIVITY_ICONS[$L]}" ]; then
     wget -q "$WEB_ROOT_URL/res/${ARRAY_OF_ACTIVITY_ICON_PATHS[$L]}${POSSIBLE_ICON_URL_PARTS[$M]}/${ARRAY_OF_ACTIVITY_ICON_NAMES[$L]}.png" && break 2; 
     fi
     M=$(( $M + 1 )) 
     done
     L=$(( $L + 1 ))
     done
     N=0; P=0; Q=0; R=0;  
     echo "APP_NAME_SIMPLE:  $APP_NAME_SIMPLE"							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "============================================================================="	>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   APP_NAME:         $APP_NAME" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   APP_NAME1:        $APP_NAME1" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   APP_NAME2:        $APP_NAME2"  							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   APP_NAME3:        $APP_NAME3" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   PACKAGE_NAME:     $PACKAGE_NAME" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   SOURCE_URL:       $SOURCE_URL" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   SOURCE_URL1:      $SOURCE_URL1" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   SOURCE_URL2:      $SOURCE_URL2" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
   # echo "   DEVELOPER:        $DEVELOPER" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
   # echo "   REPO_NAME:        $REPO_NAME" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
   # echo "   SUBDIR:           $SUBDIR" 							>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   REAL_SUB_PATH:    $SUCCESSFUL_SUB_PATH" 						>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   ACTIV_NAMES:"       								>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     while [ "$N" -le           ${#ARRAY_OF_ACTIVITY_NAMES[@]} ]; do
     echo "                     ${ARRAY_OF_ACTIVITY_NAMES[$N]}"      				>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "                     ${ARRAY_OF_SIMPLE_ACTIVITY_NAMES[$N]}"				>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     N=$(( $N + 1 )); done
     echo "   ACTIV_ICONS:"									>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     while [ "$P" -le           ${#ARRAY_OF_ACTIVITY_ICONS[@]} ]; do
     echo "                     ${ARRAY_OF_ACTIVITY_ICONS[$P]}"      				>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     P=$(( $P + 1 )); done
     echo "   ACTIV_ICON_PATHS:"  								>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     while [ "$Q" -le           ${#ARRAY_OF_ACTIVITY_NAMES[@]} ]; do
     echo "                     ${ARRAY_OF_ACTIVITY_ICON_PATHS[$Q]}" 				>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     Q=$(( $Q + 1 )); done
     echo "   ACTIV_ICON_NAMES:"  								>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     while [ "$R" -le           ${#ARRAY_OF_ACTIVITY_NAMES[@]} ]; do
     echo "                     ${ARRAY_OF_ACTIVITY_ICON_NAMES[$R]}" 				>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     R=$(( $R + 1 )); done
     echo "   APP_ICON:         $APPLICATION_ICON" 						>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   APP_ICON_PATH:    $APPLICATION_ICON_PATH"						>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "   APP_ICON_NAME:    $APPLICATION_ICON_NAME"						>> $DEST_DIR/$APP_NAME_SIMPLE/METADATA.txt
     echo "FINISHED!"
     if [ ${#ARRAY_OF_ACTIVITY_NAMES[@]} -eq 1 ]; then
        mv ${APPLICATION_ICON_NAME}.png ${APP_NAME_SIMPLE}.png
        mv ${APP_NAME_SIMPLE}.png $DEST_DIR/; 
     fi
     # if [ ${#ARRAY_OF_ACTIVITY_NAMES[@]} -gt 1 ]; then
     #    S=0; while [ "$S" -le ${#ARRAY_OF_ACTIVITY_ICON_NAMES[@]} ]; do
     #    mv ${ARRAY_OF_ACTIVITY_ICON_NAMES[$S]}.png $DEST_DIR/${SIMPLE_APP_NAME}__${ARRAY_OF_SIMPLE_ACTIVITY_NAMES[$S]}.png
     #    S=$(( $S + 1 ))
     #    done
     # fi
fi
fi







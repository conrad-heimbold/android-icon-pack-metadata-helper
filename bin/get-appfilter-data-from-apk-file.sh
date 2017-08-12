#!/bin/bash
TEMP_DIR="/tmp"
APP_NAME_SIMPLE=$1
APK_FILE=$2
APK_FILENAME=$(basename "$APK_FILE")
DATA_DIR=$3
mkdir -p "$TEMP_DIR/$APP_NAME_SIMPLE/"
mkdir -p "$DATA_DIR/$APP_NAME_SIMPLE/"
unzip -q -d "$TEMP_DIR/$APP_NAME_SIMPLE/" "$APK_FILE"
mv "$TEMP_DIR/$APP_NAME_SIMPLE/AndroidManifest.xml" "$DATA_DIR"/"$APP_NAME_SIMPLE"/
ANDROID_MANIFEST_FILE="$DATA_DIR"/"$APP_NAME_SIMPLE"/AndroidManifest.xml
java -jar /usr/local/src/conrad_heimbold/AXMLPrinter2.jar "$ANDROID_MANIFEST_FILE" > "$DATA_DIR/$APP_NAME_SIMPLE/AndroidManifest.real.xml"
trash "$ANDROID_MANIFEST_FILE"; mv "$DATA_DIR/$APP_NAME_SIMPLE/AndroidManifest.real.xml" "$ANDROID_MANIFEST_FILE"
sed 's/android://g' "$ANDROID_MANIFEST_FILE" > "$DATA_DIR"/"$APP_NAME_SIMPLE"/AndroidManifestWithoutAndroidNS.xml;

PACKAGE_NAME=$(			xmllint --xpath 2>/dev/null \
        "/manifest/@package" \
        "$DATA_DIR"/"$APP_NAME_SIMPLE"/AndroidManifestWithoutAndroidNS.xml \
        | sed 's/package=\"//g' | sed 's/\"//g' | tr -d '[:space:]')
LIST_OF_ACTIVITY_NAMES_RAW=$( 	xmllint --xpath 2>/dev/null \
        "//category[@name='android.intent.category.LAUNCHER']/../action[@name='android.intent.action.MAIN']/../../@name" \
        "$DATA_DIR"/"$APP_NAME_SIMPLE"/AndroidManifestWithoutAndroidNS.xml \
        | sed 's/name=\"/ /g'   | sed 's/\"/ /g' | tr -s '[:space:]'; printf "\n")
APP_ICON_BINARY=$(         	xmllint --xpath  2>/dev/null \
        "//application/@icon" \
        "$DATA_DIR"/"$APP_NAME_SIMPLE"/AndroidManifestWithoutAndroidNS.xml \
        | sed 's/icon=\"@//g' | sed 's/\"//g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g" | tr '[:upper:]' '[:lower:]');
APP_ICON_SOURCE=$(aapt d resources "$APK_FILE" 2>/dev/null | grep -m 1 "$APP_ICON_BINARY" \
        | sed "s/.*$PACKAGE_NAME://g" | sed 's/: .*//g')
APP_NAME3=$(                  xmllint --xpath  2>/dev/null \
        "//application/@name" \
        "$DATA_DIR"/"$APP_NAME_SIMPLE"/AndroidManifestWithoutAndroidNS.xml \
        | sed 's/name=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g"; printf "\n")
  K=0; for ACTIVITY_NAME in "$LIST_OF_ACTIVITY_NAMES_RAW"; do
        echo "ACTIVITIY NAMES: $ACTIVITY_NAME"
        ACTIVITY_NAMES_COMPLETE=$(echo "$ACTIVITY_NAME" \
                | sed "s|^\.|$PACKAGE_NAME\.|g")
	echo "ACTIVITY_NAME_COMPLETE: $ACTIVITY_NAME_COMPLETE"
        ACTIVITY_NAMES_SIMPLE=$(echo "$ACTIVITY_NAME"  \
		| sed -E "s|$PACKAGE_NAME||g" \
                | tr '[:upper:]' '[:lower:]' \
		| perl -pe 's/\.[a-zA-Z0-9]{1,20}\.([a-zA-Z0-9]{1,20})/\1/')
#                | sed -E "s|activity||g" | sed -E "s|\.ui||g" \
#                | sed -E "s|main||g" | sed -E "s|[.-]{1,3}||g" )
	echo "ACTIVITY NAME SIMPLE: $ACTIVITY_NAME_SIMPLE"
        LIST_OF_ACTIVITY_NAMES_COMPLETE="$LIST_OF_ACTIVITY_NAMES_COMPLETE $ACTIVITY_NAME_COMPLETE";
	echo "COMPLETE ACTIVITY NAMES: $LIST_OF_ACTIVITY_NAMES_COMPLETE"
        LIST_OF_ACTIVITY_NAMES_SIMPLE="$LIST_OF_ACTIVITY_NAMES_SIMPLE $ACTIVITY_NAME_SIMPLE"
	echo "SIMPL ACTIVITY NAMES: $LIST_OF_ACTIVITY_NAMES_COMPLETE"
        ARRAY_OF_ACTIVITY_NAMES_COMPLETE[$K]="$ACTIVITY_NAME_COMPLETE"
        ARRAY_OF_ACTIVITY_NAMES_SIMPLE[$K]="$ACTIVITY_NAME_SIMPLE"
        ARRAY_OF_ACTIVITY_NAMES[$K]="$ACTIVITY_NAME"
        ACTIVITY_ICON_BINARY=$(         xmllint --xpath  2>/dev/null \
        	"//activity[@name='$ACTIVITY_NAME']/@icon" \
        	"$DATA_DIR"/"$APP_NAME_SIMPLE"/AndroidManifestWithoutAndroidNS.xml   \
        	| sed 's/icon=\"@//g' | sed 's/\"//g' | tr -s '[:space:]' | sed -E 's|^[ ]\{1,10\}||g');
        echo "$ACTIVITY_ICON_BINARY"
        ACTIVITY_ICON_SOURCE=$(aapt d resources "$APK_FILE" 2>/dev/null | grep -m 1 "$ACTIVITY_ICON_BINARY" )
#        	| sed "s/$PACKAGE_NAME://g" | sed 's/: .*//g')
	ACTIVITY_ICON_NAME=$(basename "$ACTIVITY_ICON_SOURCE" )
        ACTIVITY_ICON_PATH=$(dirname  "$ACTIVITY_ICON_SOURCE" )
        LIST_OF_ACTIVITY_ICONS="$LIST_OF_ACTIVITY_ICONS $ACTIVITY_ICON_SOURCE";
        LIST_OF_ACTIVITY_ICON_NAMES="$LIST_OF_ACTIVITY_ICON_NAMES $ACTIVITY_ICON_NAME"
        LIST_OF_ACTIVITY_ICON_PATHS="$LIST_OF_ACTIVITY_ICON_PATHS $ACTIVITY_ICON_PATH"
        ARRAY_OF_ACTIVITY_ICONS[$K]="$ACTIVITY_ICON_SOURCE"
#        ARRAY_OF_ACTIVITY_ICON_NAMES[$K]="ACTIVITY_ICON_NAME"
#        ARRAY_OF_ACTIVITY_ICON_PATHS[$K]="ACTIVITY_ICON_PATH"
        echo "ACTIVITIES:  $LIST_OF_ACTIVITY_NAMES_COMPLETE"
        echo "ACTIV_ICONS: $LIST_OF_ACTIVITY_ICONS"
        K=$(( $K + 1 ))
  done

echo "APP_NAME_SIMPLE: $APP_NAME_SIMPLE"
echo "APP_NAME: $APP_NAME3"
echo "PACKAGE_NAME: $PACKAGE_NAME"
echo "APP_ICON_SOURCE: $APP_ICON_SOURCE"
echo "ACTIVITY_ICONS:"
K=0; for ICON in ${#ARRAY_OF_ACTIVITY_ICONS[*]}; 
do
echo "     $ARRAY_OF_ACTIVITY_ICONS[$K]"
K=$(( $K + 1 ))
done
echo "ACTIVITY_NAMES:"
K=0; for ACTIVITY in ${#ARRAY_OF_ACTIVITY_NAMES[*]}; 
do
echo "     $ARRAY_OF_ACTIVITY_NAMES[$K]"
K=$(( $K + 1 ))
done
echo "ACTIVITY_NAMES_COMPLETE: "
K=0; for ACTIVITY in ${#ARRAY_OF_ACTIVITY_NAMES_COMPLETE[*]}; 
do
echo "     $ARRAY_OF_ACTIVITY_NAMES_COMPLETE[$K]"
K=$(( $K + 1 ))
done
echo "ACTIVITY_NAMES_SIMPLE: "
K=0; for ACTIVITY in ${#ARRAY_OF_ACTIVITY_NAMES_SIMPLE[*]}; 
do
echo "     $ARRAY_OF_ACTIVITY_NAMES_SIMPLE[$K]"
K=$(( $K + 1 ))
done
echo "LIST_OF_ACTIV_ICONS: $LIST_OF_ACTIVITY_ICONS"

TEMP_DIR=
APP_NAME_SIMPLE=
APK_FILE=
PACKAGE_NAME=
APK_FILENAME=
LIST_OF_ACTIVITY_NAMES=
LIST_OF_ACTIVITY_ICONS=
LIST_OF_ACTIVITY_ICON_NAMES=
LIST_OF_ACTIVITY_ICON_PATHS=
ACTIVITY_ICON_SOURCE=
ACTIVITY_ICON_BINARY=
APP_ICON_SOURCE=
APP_ICON_BINARY=
ARRAY_OF_ACTIVITY_NAMES[0]=
ARRAY_OF_ACTIVITY_NAMES[1]=
ARRAY_OF_ACTIVITY_NAMES[2]=
ARRAY_OF_ACTIVITY_NAMES_COMPLETE[0]=
ARRAY_OF_ACTIVITY_NAMES_COMPLETE[1]=
ARRAY_OF_ACTIVITY_NAMES_COMPLETE[2]=
ARRAY_OF_ACTIVITY_NAMES_SIMPLE[0]=
ARRAY_OF_ACTIVITY_NAMES_SIMPLE[1]=
ARRAY_OF_ACTIVITY_NAMES_SIMPLE[2]=
ARRAY_OF_ACTIVITY_ICONS[0]=
ARRAY_OF_ACTIVITY_ICONS[1]=
ARRAY_OF_ACTIVITY_ICONS[2]=
DATA_DIR=
ANDROID_MANIFEST_FILE=

#!/bin/bash
# AndroidManifestWithoutAndroidNS.xml is just AndroidManifest.xml , where all occurences of "android:" have been deleted


PACKAGE_NAME=$(xmllint --xpath 2>/dev/null \
	"/manifest/@package" \
	AndroidManifestWithoutAndroidNS.xml 
	| sed 's/package=\"//g' | sed 's/\"//g' | tr -d '[:space:]')
LIST_OF_ACTIVITY_NAMES_RAW=$( xmllint --xpath 2>/dev/null \
        "//category[@name='android.intent.category.LAUNCHER']/../action[@name='android.intent.action.MAIN']/../../@name" \
        AndroidManifestWithoutAndroidNS.xml \
        | sed 's/name=\"/ /g'   | sed 's/\"/ /g' | tr -s '[:space:]'; printf "\n")
APP_ICON=$(                   xmllint --xpath  2>/dev/null \
        "//application/@icon" \
        AndroidManifestWithoutAndroidNS.xml \
        | sed 's/icon=\"@//g' | sed 's/\"//g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g");
APP_NAME3=$(                  xmllint --xpath  2>/dev/null \
        "//application/@name" \
        AndroidManifestWithoutAndroidNS.xml \
        | sed 's/name=\"/ /g' | sed 's/\"/ /g' | tr -s '[:space:]' | sed -E "s|^[ ]{1,10}||g"; printf "\n")

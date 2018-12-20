#!/bin/bash
#
###############################################################################
# Photo sorting program by Mike Beach
# For usage and instructions, and to leave feedback, see
# http://mikebeach.org/?p=4729
#
# Last update: 20-January-2016 by tastensolo
###############################################################################
#
# The following are the only settings you should need to change:
# USE_LMDATE: If this is TRUE, images without EXIF data will have their Last Modified file
# timestamp used as a fallback. If FALSE, images without EXIF data are put in noexif/ for
# manual sorting.
# WARNING: Filename collisions are NOT handled when this is off. Files are automatically
# overwritten.
# FIXME: Handle collisions when this is off.
# Valid options are "TRUE" or anything else (assumes FALSE). FIXME: Restrict to TRUE/FALSE
#
USE_LMDATE=TRUE
#
# The following is an array of filetypes that we intend to locate using find.
# Any imagemagick-supported filetype can be used, but EXIF data is only present in
# jpeg and tiff. Script will optionally use the last-modified time for sorting (see above)
# Extensions are matched case-insensitive. *.jpg is treated the same as *.JPG, etc.
# Can handle any file type; not just EXIF-enabled file types. See USE_LMDATE above.
#
FILETYPES=("*.jpg" "*.jpeg" "*.png" "*.bmp" "*.tif" "*.tiff" "*.gif" "*.xcf" "*.mp4" "*.mov" "*.avi" "*.3gp" "*.m4v")
#
# Optional: Prefix of new top-level directory to move sorted photos to.
# if you use MOVETO, it MUST have a trailing slash! Can be a relative pathspec, but an
# absolute pathspec is recommended.
# FIXME: Gracefully handle unavailable destinations, non-trailing slash, etc.
#
MOVETO="/media/medienschubse/SAMSUNG/Medien/Archiv/"
FINDIN="/media/medienschubse/SAMSUNG/Medien/Bilder/"
#
###############################################################################
# End of settings. If you feel the need to modify anything below here, please share
# your edits at the URL above so that improvements can be made to the script. Thanks!
#
#
# Assume find, grep, stat, awk, sed, tr, etc.. are already here, valid, and working.
# This may be an issue for environments which use gawk instead of awk, etc.
# Please report your environment and adjustments at the URL above.
#
###############################################################################
# Nested execution (action) call
# This is invoked when the programs calls itself with
# $1 = "doAction"
# $2 = <file to handle>
# This is NOT expected to be run by the user in this matter, but can be for single image
# sorting. Minor output issue when run in this manner. Related to find -print0 below.
#
# Are we supposed to run an action? If not, skip this entire section.
if [[ "$1" == "doAction" && "$2" != "" ]]; then
 # Check for EXIF and process it
 # Get the FILE type and lowercase it for use as the extension

 # check spaces and rename to underscore
 find $2 -name '* *' -exec rename -n 's/ /_/g' {} \;

 VIDEO=`file -i $2 | grep "video"`
 OCTET=`file -i $2 | grep "octet"`
 echo -n "video $VIDEO"
 echo -n "octet $OCTET"

 if [[ "$VIDEO" == "" && "$OCTET" == "" ]]; then
  echo -n ": Checking EXIF... "
  DATETIME=`identify -verbose "$2" | grep "exif:DateTime:" | awk -F' ' '{print $2" "$3}'`
 fi;
 if [[ "$DATETIME" == "" ]]; then
  echo "not found."
  if [[ $USE_LMDATE == "TRUE" ]]; then
   # I am deliberately not using %Y here because of the desire to display the date/time
   # to the user, though I could avoid a lot of post-processing by using it.
   DATETIME=`stat --printf='%y' "$2" | awk -F. '{print $1}' | sed y/-/:/`
   echo " Using LMDATE: $DATETIME"
  else
   echo " Moving to ./noexif/"
   mkdir -p "${MOVETO}noexif" && mv -f "$2" "${MOVETO}noexif"
   exit
  fi;
 else
 echo "found: $DATETIME"
 fi;
 # The previous iteration of this script had a major bug which involved handling the
 # renaming of the file when using TS_AS_FILENAME. The following sections have been
 # rewritten to handle the action correctly as well as fix previously mangled filenames.
 # FIXME: Collisions are not handled.
 #
 EDATE=`echo $DATETIME | awk -F' ' '{print $1}'`
 # DIRectory NAME for the file move
 # sed issue for y command fix provided by thomas
 EYEAR=`echo $EDATE | cut -f1 -d':'`
 EMONTH=`echo $EDATE | cut -f2 -d':'`
 EDAY=`echo $EDATE | cut -f3 -d':'`

 DIRNAME=`echo "$EYEAR/$EYEAR-$EMONTH/" `
 MVFILETYPE=`echo $2 | awk -F . '{print $NF}'`
 MVFILENAME=`echo $DATETIME.$MVFILETYPE | sed 's/://g' | sed 's/ /_/g'`
 echo -n " Moving to ${MOVETO}${DIRNAME}${MVFILENAME} ... "
 mkdir -p "${MOVETO}${DIRNAME}" && mv -f "$2" "${MOVETO}${DIRNAME}${MVFILENAME}"
 echo "done."
 echo ""
 exit
fi;
#
###############################################################################
# Scanning (find) loop
# This is the normal loop that is run when the program is executed by the user.
# This runs find for the recursive searching, then find invokes this program with the two
# parameters required to trigger the above loop to do the heavy lifting of the sorting.
# Could probably be optimized into a function instead, but I don't think there's an
# advantage performance-wise. Suggestions are welcome at the URL at the top.
for x in "${FILETYPES[@]}"; do
 # Check for the presence of imagemagick and the identify command.
 # Assuming its valid and working if found.
 I=`which identify`
 if [ "$I" == "" ]; then
 echo "The 'identify' command is missing or not available."
 echo "Is imagemagick installed?"
 exit 1
 fi;
 echo "Scanning for $x..."
 # FIXME: Eliminate problems with unusual characters in filenames.
 # Currently the exec call will fail and they will be skipped.
 find ${FINDIN} -iname "$x" -print0 -exec sh -c "$0 doAction '{}'" \;
 echo "... end of $x"
done;
# clean up empty directories. Find can do this easily.
# Remove Thumbs.db first because of thumbnail caching
echo -n "Removing Thumbs.db files ... "
find ${FINDIN} -name Thumbs.db -delete
echo "done."
echo -n "Cleaning up empty directories ... "
find ${FINDIN} -empty -delete -mindepth 1
echo "done."

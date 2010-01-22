#!/bin/bash
ROWSINDEX="/tmp/$( basename $0 ).$( date +%s)"
ROWTAG="row"
RESULTSETTAG="resultset"
FILE="$1"
if ! [ -r "$FILE" ]; then
  echo "usage: $0 filename"
  exit 1
fi

grep -no "</${ROWTAG}>" "$FILE" > "$ROWSINDEX"

TOTALROWS="`wc -l $ROWSINDEX | awk '{ print $1 }'`"
echo "Righe totali trovate: $TOTALROWS"
AVGROW=$(( $TOTALROWS / 2 ))
ROWNUM=$( head -n $AVGROW $ROWSINDEX | tail -n 1 | awk -F: '{ print $1 }')
echo "Riga centrale: $ROWNUM"

head -n $ROWNUM $FILE > $FILE.1
tail -n +$(( $ROWNUM + 1 )) $FILE > $FILE.2.tmp

echo "</$RESULTSETTAG>" >> $FILE.1
head -c $( grep "<$RESULTSETTAG>" -b "$FILE.1"  -o | awk -F: '{ print $1 }' ) $FILE.1 > $FILE.2
echo "<$RESULTSETTAG>" >> $FILE.2
cat $FILE.2.tmp >> $FILE.2

rm $FILE.2.tmp
rm $ROWSINDEX

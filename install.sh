#!/bin/bash
function installFile() {
	FILE="$1"
	DIR="$2"
	DESTFILE="$DIR/$(basename $FILE)"
	echo -e "Copying $FILE to $DIR... "
	cp "$FILE" "$DIR" -av
	echo -e " Setting executable bit... "
	chmod +x "$DESTFILE"
	echo "done"
}
BINDIR="/usr/local/bin"
SBINDIR="/usr/local/sbin"

for file in user/*; do
	installFile $file $BINDIR
done

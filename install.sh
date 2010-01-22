#!/bin/bash
PROFILE="$HOME/.bashrc"
function installFile() {
	FILE="$1"
	DIR="$2"
	DESTFILE="$DIR/$(basename $FILE)"
	echo -e "Copying $FILE to $DIR... "
	cp "$FILE" "$DIR" -a
	echo -e " Setting executable bit... "
	chmod +x "$DESTFILE"
	echo "done"
}

function fixPathFor() {
	if test "x$( echo "$PATH" | grep $1)" == "x"; then
		echo "export PATH=\"$1:\$PATH\"" >> $PROFILE
	fi
}
BINDIR="/usr/local/bin"
SBINDIR="/usr/local/sbin"
mkdir $BINDIR
mkdir $SBINDIR

fixPathFor $BINDIR
fixPathFor $SBINDIR
for file in user/*; do
	installFile $file $BINDIR
done

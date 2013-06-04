#!/usr/bin/bash
USER="$1"
GMAILRC="/home/$USER/.gmailrc"
shift

if ! [ -r "$GMAILRC" ]; then
	echo "Il file $GMAILRC è mancante. Crearlo, e dare i permessi appropriati"
	echo "La sintassi del file è email:password"
	exit 1
fi

if test "x$( stat -c "%a" "$GMAILRC" )" != "x600"; then
	echo "Il file $GMAILRC deve avere maschera di permessi 600 (-rw-------)"
	exit 1
fi

EMAIL="$( cat $GMAILRC | cut -d : -f 1 )"
PASSWD="$( cat $GMAILRC | cut -d : -f 2 )"

if test "x$EMAIL" == "x" || test "x$PASSWD" == "x"; then
	echo "Il file $GMAILRC non ha il formato corretto (email:password)"
	exit 1
fi

if test "x$1" == "x"; then
	echo "Utilizzo: $0 username_locale lista_interfacce"
	exit 1
fi

if ! which sendemail 2>&1 >/dev/null; then
	echo "SendEmail non trovato, procedo all'installazione del pacchetto e delle dipendenze"
	sudo apt-get install sendemail libio-socket-ssl-perl libnet-ssleay-perl
fi

TEMPFILE="/tmp/$( basename $0 )"
echo $TEMPFILE
echo "$(hostname)" > $TEMPFILE
for interface in $@; do
	if ! ifconfig $interface >> $TEMPFILE; then
		rm $TEMPFILE
		echo "Errore su fetch informazioni interfaccia $interface"
		exit 1
	fi
	echo "" >> $TEMPFILE
done

sendemail -f $EMAIL -t $EMAIL -u "[ip-update] $( hostname ) new ip address" -m "$( cat $TEMPFILE )" -s smtp.gmail.com -xu $EMAIL -xp $PASSWD -o tls=yes || exit 1

rm $TEMPFILE


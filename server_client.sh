#! /bin/bash

# Ce script implémente un serveur.  
# Le script doit être invoqué avec l'argument :                   
# PORT   le port sur lequel le serveur attend ses clients 

if [ $# -ne 1 ]; then
    echo "usage: $(basename $0) PORT"
    exit -1
fi

PORT="$1"

# Déclaration du tube

FIFO="/tmp/$USER-fifo-$$"

# Il faut détruire le tube quand le serveur termine pour éviter de
# polluer /tmp.  On utilise pour cela une instruction trap pour être sur de
# nettoyer même si le serveur est interrompu par un signal.

function nettoyage() { rm -f "$FIFO"; }
trap nettoyage EXIT

# on crée le tube nommé

[ -e "FIFO" ] || mkfifo "$FIFO"


function accept-loop() {
	next=true
   while $next; do
		interaction < "$FIFO" | netcat -l -p "$PORT" > "$FIFO"
		if [[ $(head last | grep exit) != "" ]]
		then
			next=false
			#Retirer le serveur de la liste des serveurs en cours d'exéuction
			sed "/$PORT/d" etc/livehosts -i
		else
			next=true
		fi
   done
}

# La fonction interaction lit les commandes du client sur entrée standard 
# et envoie les réponses sur sa sortie standard. 
#
# 	CMD arg1 arg2 ... argn                   
#                     
# alors elle invoque la fonction :
#                                                                            
#         commande-CMD arg1 arg2 ... argn                                      
#                                                                              
# si elle existe; sinon elle envoie une réponse d'erreur.                    

function interaction() {
   local cmd args
 	while true; do
		echo -n "user@machine\> "
		read cmd args || exit -1
		echo $cmd > last
		fun="commande-$cmd"
		if [ "$(type -t $fun)" = "function" ]; then
		    $fun $args
		else
		    commande-non-comprise $fun $args
		fi
    done
}

# Les fonctions implémentant les différentes commandes du serveur


function commande-non-comprise () {
   echo "Commande inconnue"
}

function commande-convert() {
	echo $@ | tr '[a-z]' '[A-Z]' # tr '[:lower:upper]'
}

function commande-who() {

}

function commande-rusers() {

}

function commande-rhost() {

}

function commande-rconnect() {

}

function commande-su() {

}


function commande-passwd() {

}

function commande-finger() {

}

function commande-write() {

}

function commande-exit() {
	echo "Déconnexion du serveur..."
	echo "Appuyez sur RETURN pour valider."
	echo "exit" > last
	exit -1
}

# On accepte et traite les connexions

accept-loop
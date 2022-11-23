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
   while true; do
	interaction < "$FIFO" | netcat -l -p "$PORT" > "$FIFO"
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
	echo -n user@machine\>
	read cmd args || exit -1
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

function commande-host() {
	
}

function commande-user() {

}

function commande-wall() {

}

function commande-exit() {
	echo "Déconnexion du serveur..."
	echo "Appuyez sur RETURN pour valider."
	exit -1
}

# On accepte et traite les connexions

accept-loop
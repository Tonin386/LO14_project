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

FIFO="tmp/$USER-fifo-$$"

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
	echo "En construction"
	#TODO : recuperer le nom de la machine sur laquelle est co l'utilisateur et le passer par la variable
	awk -v var="hostroot" -f fichawk/who etc/liveusers
}

function commande-rusers() {
	awk -f fichawk/rusers etc/liveusers
}

function commande-rhost() {
	awk -f fichawk/rhost etc/hosts
}

function commande-rconnect() {
	echo "En construction"
}

function commande-su() {
	echo "En construction"
	#TODO : Checker si 2 args (nom utilisateur + mdp) > checker si nom utilisateur peut se connecter sur la machine et existe > checker si mdp correct > connecter sur le profil (changer infos dans liveusers + dans la console)
	#Changer dans liveusers :
	#awk -v var=nom_actuel -v var1=nom_modifie -f fichawk/su etc/liveusers > etc/temp
	#echo etc/temp > etc/liveusers
}


function commande-passwd() {
	echo "En construction"
}

function commande-finger() {
	awk -v var=$1 -f fichawk/finger etc/passwd
}

function commande-write() {
	echo "En construction"
}

function commande-receive() {
	echo " "
	echo "$@"
}

function commande-exit() {
	echo "Déconnexion du serveur..."
	echo "Appuyez sur RETURN pour valider."
	echo "exit" > last
	exit -1
}

# On accepte et traite les connexions

accept-loop

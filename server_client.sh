#! /bin/bash

# Ce script implémente un serveur.  
# Le script doit être invoqué avec l'argument :                   
# PORT   le port sur lequel le serveur attend ses clients 

if [ $# -lt 1 ]; then
    echo "usage: $(basename $0) PORT"
    exit -1
fi

PORT="$1"
machine="$(cat etc/livehosts|grep $PORT|cut -d':' -f1)"

if [ $# -eq 1 ]; then
	user="utilisateur"
else
	user=$2
fi



# Déclaration du tube

FIFO="tmp/$machine-$user-fifo-$PORT"

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
		if [[ $(head tmp/last | grep exit) != "" ]]
		then
			next=false
			#Retirer le serveur de la liste des serveurs en cours d'exécution
			sed "/$PORT/d" etc/livehosts -i
			rm tmp/last
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
		echo -n "$user@$machine\> "
		read cmd args || exit -1
		echo $cmd > tmp/last
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
	awk -v var="$machine" -f fichawk/who etc/liveusers
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
	if test $# -eq 2
	then
		echo "Vérification du droit de l'utilisateur de se connecter sur cette  machine"
		if [[ $(cat etc/hosts|grep :$PORT:|grep :$1:) != "" ]]
		then
			echo "L'utilisateur $1 peut se connecter sur la machine !"
			echo "Vérification du mot de passe de $1 !" 
			mdp=$(echo $(cat etc/shadow | grep ^$1: | cut -d':' -f2) | openssl enc -base64 -d -aes-256-cbc -salt -pass pass:LO14 -pbkdf2)
			if [[ $mdp == $2 ]]
			then
				echo "Le mot de passe entré est correct, reconnexion en cours..."

				#TODO : Changer dans liveusers :
				awk -v var=$user -v var1=$1 -f fichawk/su etc/liveusers > etc/temp
				cat etc/temp > etc/liveusers
				
				#TODO : Changer l'utilisateur dans le prompt
				user=$1

			else
				echo "Mot de passe incorrect !"
			fi
		else
			echo "L'utilisateur n'est pas autorisé à se connecter sur la machine."
		fi
	else
		echo "Usage : su nom_utilisateur mot_de_passe"
	fi
}


function commande-passwd() {
	echo "En construction"
	if test $# -eq 2
	then
		echo "Vérification de la correspondance des mots de passe"
		ancien=$(echo $(head etc/shadow | grep $user | sed "s/$user://") | openssl enc -base64 -d -aes-256-cbc -salt -pass pass:LO14 -pbkdf2)
		if [[ $ancien == $1 ]]
		then
			echo "Les mots de passe correspondent."
			echo "Remplacement de l'ancien mot de passe..."
			nouveau=$(echo $2 | openssl enc -base64 -e -aes-256-cbc -salt -pass pass:LO14 -pbkdf2)
			sed "s/$user:.*$/$user:$nouveau/" etc/shadow -i
			echo "Le mot de passe a été changé."
		else
			echo "Le mot de passe entré ne correspond pas au mot de passe actuel !"
		fi
	else
		echo "Usage : passwd mot_de_passe_actuel nouveau_mot_de_passe"
	fi
}

function commande-finger() {
	awk -v var=$1 -f fichawk/finger etc/passwd
}

function commande-write() {
	if test $# -ge 2
	then
		destinataireNom=$(echo $1 | sed "s/\@.*$//")
		destinataireMachine=$(echo $1 | sed "s/.*\@//")
		echo "Vérification de la connexion du destinataire ..."
		if [[ $(echo $(cat etc/livehosts | grep $destinataireNom)) != "" ]]
		then
			destinataireMachinePort=$(cat etc/livehosts | grep $destinataireMachine:$destinataireNom | sed "s/$destinataireMachine:$destinataireNom://")
			echo "Le destinataire est connecté. Envoi du message..."
			shift
			echo "receive $@" >> "tmp/$destinataireMachine-$destinataireNom-fifo-$destinataireMachinePort"
		else
			echo "L'utilisateur n'est pas connecté !"
		fi
	else
		echo "Usage : write nom_destinataire message"
	fi
}

function commande-receive() {
	echo " "
	echo "$@"
}

function commande-exit() {
	echo "Déconnexion du serveur..."
	echo "Appuyez sur RETURN pour valider."
	echo "exit" > tmp/last
	exit -1
}

# On accepte et traite les connexions

accept-loop

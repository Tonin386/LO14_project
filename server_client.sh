#! /bin/bash

# Ce script implémente un serveur.  
# Le script doit être invoqué avec l'argument :                   
# port   le port sur lequel le serveur attend ses clients 

if [ $# -lt 1 ]; then
	echo "usage: $(basename $0) port"
	exit -1
fi

port="$1"
machine="$(cat etc/livehosts|grep $port|cut -d':' -f1)"

if [ $# -eq 1 ]; then
	user="utilisateur"
else
	user=$2
fi

saved_message=$(cat etc/passwd | grep $user | cut -d '|' -f6)
if [[ $saved_message != "" ]]
then
	echo "Vous avez reçu un message pendant que vous étiez déconnecté : $saved_message"
	awk -v name=$user -v message="" -vOFS='|' -f fichawk/wall etc/passwd > tmp/temp
	cat tmp/temp > etc/passwd
	rm tmp/temp
else
	echo "Pas de nouveau message."
fi



# Déclaration du tube

FIFO="tmp/$machine-$user-fifo-$port"

# Il faut détruire le tube quand le serveur termine pour éviter de
# polluer /tmp.  On utilise pour cela une instruction trap pour être sur de
# nettoyer même si le serveur est interrompu par un signal.

function nettoyage() { rm -f "$FIFO"; }
trap nettoyage EXIT

# on crée le tube nommé

[ -e "$FIFO" ] || mkfifo "$FIFO"


function accept-loop() {
	next=true
	while $next; do
		interaction < "$FIFO" | netcat -l -p "$port" > "$FIFO"
		if [[ $(head tmp/last | grep exit) != "" ]]
		then
			next=false
			
			#Retirer le serveur de la liste des serveurs en cours d'exécution
			sed "/$port/d" etc/livehosts -i				

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
	echo "Commande inconnue."
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
	if [[ $# -eq 2 ]]
	then
		if [[ $(cat etc/hosts | grep $1 | grep $user) != "" ]]
		then
			mdp=$(echo $(cat etc/shadow | grep $user | sed "s/$user://") | openssl enc -base64 -d -aes-256-cbc -salt -pass pass:LO14 -pbkdf2)
			if [[ $mdp == $2 ]]
			then
				echo "Le mot de passe entré est correct, reconnexion en cours..."

				sed "s/$machine:$user:$port/$1:$user:$port/" etc/livehosts -i
				
				dates=$(date | egrep '.*[0-9]{4}' -o)
				heure=$(date | cut -d' ' -f5)
				sed "s/$user|$machine.*/$user|$1|$dates|$heure/" etc/liveusers -i
				
				echo "$machine" >> "tmp/$user-route"
				rm $FIFO
				machine=$1
				FIFO="tmp/$machine-$user-fifo-$port"
				[ -e "FIFO" ] || mkfifo "$FIFO"
			else
				echo "Mot de passe incorrect !"
			fi
		else
			echo "L'utilisateur n'existe pas sur la machine $1."
		fi
	else
		echo "Usage : rconnect nom_machine mot_de_passe"
	fi

}

function commande-su() {
	if test $# -eq 2
	then
		echo "Vérification du droit de l'utilisateur de se connecter sur cette  machine"
		if [[ $(cat etc/hosts | grep $machine | grep $1) != "" ]]
		then
			echo "L'utilisateur $1 peut se connecter sur la machine."
			echo "Vérification du mot de passe de $1." 
			mdp=$(echo $(cat etc/shadow | grep $1 | sed "s/$1://") | openssl enc -base64 -d -aes-256-cbc -salt -pass pass:LO14 -pbkdf2)
			if [[ $mdp == $2 ]]
			then
				echo "Le mot de passe entré est correct, reconnexion en cours..."

				sed "s/$machine:$user:$port/$machine:$1:$port/" etc/livehosts -i
				
				dates=$(date | egrep '.*[0-9]{4}' -o)
				heure=$(date | cut -d' ' -f5)
				sed "s/$user|$machine.*/$1|$machine|$dates|$heure/" etc/liveusers -i

				inf=$(cat etc/passwd|grep $1|cut -d'|' -f1-4)
				message=$(cat etc/passwd|grep $1|cut -d'|' -f6)
				sed "s/$1|.*$/$inf|$dates $heure|$message/" etc/passwd -i

				user=$1
				rm $FIFO
				FIFO="tmp/$machine-$user-fifo-$port"
				[ -e "FIFO" ] || mkfifo "$FIFO"
				
				saved_message=$(cat etc/passwd | grep $user | cut -d '|' -f6)
				if [[ $saved_message != "" ]]
				then
					echo "Vous avez reçu un message pendant que vous étiez déconnecté : $saved_message"
					awk -v name=$user -v message="" -vOFS='|' -f fichawk/wall etc/passwd > tmp/temp
					cat tmp/temp > etc/passwd
					rm tmp/temp
				else
					echo "Pas de nouveau message."
				fi

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
	echo "Changement de mot de passe"
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
	if test $# -eq 0
	then
		lignes=$(cat etc/passwd | grep $user)
		echo "Login : $user"
		nom=$(echo $lignes|cut -d'|' -f3)
		echo "Nom : $nom"
		email=$(echo $lignes|cut -d'|' -f4)
		echo "Email : $email"
		jour=$(echo $lignes|cut -d'|' -f5)
		echo "Connecté depuis : $jour"
		echo ""
	else
		for i in $*
		do
			login=$i
			if [[ $(cat etc/passwd | grep $login) != "" ]]
			then
				ligne=$(cat etc/passwd | grep $login)
				echo "Login : $login"
				nom=$(echo $ligne|cut -d'|' -f3)
				echo "Nom : $nom"
				email=$(echo $ligne|cut -d'|' -f4)
				echo "Email : $email"
				jour=$(echo $ligne|cut -d'|' -f5)
				if [[ $(cat etc/livehosts|grep :$login) != "" ]]
				then
					echo "Connecté depuis : $jour"
				else
					echo "Dernière connexion : $jour"
				fi
			else
				echo "L'utilisateur $login n'apparait pas parmi les utilisateurs du réseau."
			fi
			echo ""
		done
	fi
}

function commande-write() {
	if test $# -ge 2
	then
		destinataireNom=$(echo $1 | sed "s/\@.*$//")
		destinataireMachine=$(echo $1 | sed "s/.*\@//")
		echo "Vérification de la connexion du destinataire ..."
		if [[ $(echo $(cat etc/livehosts | grep $destinataireNom | grep $destinataireMachine)) != "" ]]
		then
			destinataireMachinePort=$(cat etc/livehosts | grep $destinataireMachine:$destinataireNom | sed "s/$destinataireMachine:$destinataireNom://")
			echo "Le destinataire est connecté. Envoi du message..."
			shift
			echo "receive $user@$machine: $@" >> "tmp/$destinataireMachine-$destinataireNom-fifo-$destinataireMachinePort"
		else
			echo "L'utilisateur n'est pas connecté sur cette machine !"
		fi
	else
		echo "Usage : write nom_destinataire@machine message"
	fi
}

function commande-receive() {
	echo " "
	echo "$@"
}

function commande-exit() {
	echo "exit" > tmp/last

	if [[ -f "tmp/$user-route" ]]
	then
		echo "Retour sur la machine précédente."

		rm $FIFO

		new_machine=$(tail tmp/$user-route -n 1)
		sed "s/$machine:$user:$port/$new_machine:$user:$port/" etc/livehosts -i
		

		dates=$(date | egrep '.*[0-9]{4}' -o)
		heure=$(date | cut -d' ' -f5)
		sed "s/$user|$machine.*/$user|$new_machine|$dates|$heure/" etc/liveusers -i
		machine=$new_machine

		echo $(head -n -1 "tmp/$user-route") > "tmp/$user-route"

		FIFO="tmp/$machine-$user-fifo-$port"
		[ -e "FIFO" ] || mkfifo "$FIFO"

		if [[ $(head "tmp/$user-route") == "" ]]
		then
			rm "tmp/$user-route"
		fi
	else
		sed "/$user|$machine.*/d" etc/liveusers -i
		echo "Déconnexion du serveur..."
		echo "Appuyez sur RETURN pour valider."
		exit -1
	fi
}

function commande-help() {
	echo "Les commandes disponibles sur le mode connect sont les suivantes :"
	echo "who : Afficher les utilisateurs connectés sur la même machine."
	echo "rusers : Afficher les utilisateurs connectés sur le réseau."	
	echo "rhost : Afficher les machines rattachées au réseau."
	echo "rconnect nom_machine mot_de_passe : Se connecter sur une autre machine."
	echo "su nom_utilisateur mot_de_passe : Changer d'utilisateur."
	echo "passwd mot_de_passe_actuel nouveau_mot_de_passe : Changer son mot de passe."
	echo "finger [utilisateurs] : Afficher les infos des utilisateurs indiqués ou de tous les utilisateurs rattachés au réseau."
	echo "write utilisateur@machine message : Envoyer un message à un autre utilisateur."
}	
# On accepte et traite les connexions

accept-loop

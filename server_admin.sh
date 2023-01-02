#! /bin/bash

# Ce script implémente un serveur.  
# Le script doit être invoqué avec l'argument :                   
# port   le port sur lequel le serveur attend ses clients 

if [ $# -ne 1 ]; then
    echo "usage: $(basename $0) port"
    exit -1
fi

port="$1"

# Déclaration du tube

FIFO="tmp/hostroot-root-fifo-$port"

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
		echo -n "root@hostroot\> "
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

function commande-host() { #Ajoute une machine sur le réseau
	#TODO: Ajouter la vérification que la machine n'existe pas déjà
	if [[ $# -eq 1 ]]
	then
		echo "$1:" >> etc/hosts
		echo "La machine $1 a été ajoutée au réseau."
	else
		echo "Utilisez : host nom_machine"
	fi
}

function commande-hosts() {
	# while read line
	# do
	# 	sed "s/://" line
	# done < etc/hosts
	#TODO: Améliorer la fonctionnalité
	sed "s/://" etc/hosts
}

function commande-user() { #Ajoute un utilisateur sur le réseau
	if [[ $# -ge 3 ]]
	then
		user=$1
		shift
		pwd=$1
		cryptedPwd=$(echo $pwd | openssl enc -base64 -e -aes-256-cbc -salt -pass pass:LO14 -pbkdf2)
		echo $user:$cryptedPwd >> etc/shadow
		echo "$user|x|||$(date)" >> etc/passwd
		shift
		for arg in $@
		do
			if [[ $(echo $(cat etc/hosts | grep $arg | grep $user)) != "" ]]
			then
				echo "L'utilisateur $user est déjà enregistré sur la machine $arg."
			elif [[ $(echo $(cat etc/hosts | grep $arg)) != "" ]]
			then
				sed "s/^$arg:.*$/&$user:/" etc/hosts -i
				echo "L'utilisateur $user a été ajouté à la machine $arg."
			else
				echo "La machine $arg n'existe pas."
			fi
		done
	else
		echo "Utilisez : user nouvel_utils pass machine1 machine2 ..."
	fi
}

function commande-deluser() { 
	if [[ $# -ge 1 ]]
	then
		for arg in $@
		do
			rm "users/$arg"
			sed "s/$user://" etc/hosts -i
			sed "s/$user:.*$//" etc/shadow -i
			sed "s/$user|.*$//" etc/passwd -i
		done
	else
		echo "Usage : deluser util1 util2 ..."
	fi
}

function commande-wall() { #Envoie un message à tous les utilisateurs connectés
	if [ $# -ge 1 ]
	then
		online=$(echo $(ls tmp | grep fifo))
		for u in $online
		do
			echo "receive $@" >> tmp/$u
		done
	else
		echo "Utilisez : wall message"
	fi
}

function commande-afinger() {
	echo "To do"
	echo "Voilà la commande fonctionne"
}

function commande-exit() {
	echo "Déconnexion du serveur..."
	echo "Appuyez sur RETURN pour valider."
	echo "exit" > tmp/last
	exit -1
}

function commande-receive() {
	echo " "
	echo "$@"
}

# On accepte et traite les connexions

accept-loop	
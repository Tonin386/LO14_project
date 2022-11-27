#!/bin/bash

if [ $# -gt 0 ]
then
	if [ $1 = -connect ]
	then
		shift
		if [ $# -ge 2 ]
		then
			echo "Entrée dans le mode connect"
			if [[ $(cat etc/hosts | grep $1 | grep :$2:) != "" ]]
			then
				echo "L'utilisateur peut se connecter à la machine !"
				port=$(cat etc/hosts | grep $1 | egrep -o '[0-9]{4}')
				echo "La connexion virtuelle se fait sur le port : $port"
				#TOUT CE QUI SUIT EST OBSOLETE
				# if [ $(ps a | grep -c server_client) -ge 0 ] #Si le serveur n'est pas lancé
				# then
				# 	./server_client.sh 8080& #Lancement du réseau de machines virtuelles
				# 	sleep 1
				# else
				# 	echo "Client server already running!"
				# fi
				# nc localhost 8080 #Connexion au serveur de machines virtuelles
			else
				echo "Connexion impossible."
				exit -1
			fi
		else
			echo "Utilisez : rvsh -connect nom_machine nom_utilisateur"
		fi
	elif [ $1 = -admin ]
	then
		#TODO: ajouter le système de login
		shift
		echo "Veuillez entrer le mot de passe administrateur : "
		read pwd
		adminPwd=$(echo $(head etc/shadow | sed 's/root://') | openssl enc -base64 -d -aes-256-cbc -salt -pass pass:LO14 -pbkdf2)
		if [[ $adminPwd == $pwd ]]
		then
			echo "Les mots de passe correspondent. Connexion à la machine hostroot."
			port=$(tail -n 1 etc/livehosts | egrep -o '[0-9]{4}')

			if [[ $port = "" ]]
			then
				port=8000
			else
				port=$(($port+1))
			fi

			signature="hostroot:$port"
			echo $signature >> etc/livehosts

			echo "Lancement du serveur de la machine hostroot"
			./server_admin.sh $port&
			sleep 1
			
			nc localhost $port

		else
			echo "Mot de passe incorrect."
			exit -1
		fi
	else
		echo "Mode inconnu."
	fi
else
	echo "Utilisez : rvsh -mode [...]"
fi


#Problemes : 
# - impossible de connecter deux utilisateurs simultanément sur la même machine avec le script actuel
# - chaque machine utilise un seul port... Impossible de lancer deux serveurs sur le même port
#Solutions envisagées : 
# - créer un serveur par connexion, gérer les utilisateurs connectés simultanément en écrivant dans des fichiers que l'on nettoie au fur et à mesure des déconnexions.
# - ???
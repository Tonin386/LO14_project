#!/bin/bash

if [ $# -gt 0 ]
then
	if [ $1 = -connect ]
	then
		shift
		if [ $# -ge 2 ]
		then
			echo "Entrée dans le mode connect"
			if [[ $(more etc/hosts | grep $1 | grep :$2:) != "" ]]
			then
				echo "L'utilisateur peut se connecter à la machine !"
				port=$(more etc/hosts | grep $1 | egrep -o '[0-9]{4}')
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
				# pkill -f server_client.sh #On tue le serveur une fois l'exécution terminée
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
		#TOUT CE QUI SUIT EST OBSOLETE
		# echo "Entrée dans le mode admin..."
		# if [ $(ps a | grep -c server_admin) -ge 0 ] #Si le serveur n'est pas lancé
		# then
		# 	./server_admin.sh 8081& #Lancement du réseau de machines virtuelles
		# 	sleep 1
		# else
		# 	echo "Admin server already running!"
		# fi
	else
		echo "Mode inconnu."
	fi
else
	echo "Utilisez : rvsh -mode [...]"
fi

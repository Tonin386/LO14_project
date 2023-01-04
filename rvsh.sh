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
				echo "L'utilisateur existe sur la machine."
				echo "Veuillez entrer votre mot de passe : "
				read pwd
				userPwd=$(echo $(cat etc/shadow | grep $2 | sed "s/$2://") | openssl enc -base64 -d -aes-256-cbc -salt -pass pass:LO14 -pbkdf2)
				if [[ $userPwd == $pwd ]]
				then
					echo "Mot de passe correct."
					port=$(tail -n 1 etc/livehosts | egrep -o '[0-9]{4}$')
					if [[ $port = "" ]]
					then
						port=8000
					else
						port=$(($port+1))
					fi
					echo "La connexion virtuelle se fait sur le port : $port"

					signature="$1:$2:$port"
					echo $signature >> etc/livehosts
					dates=$(date | egrep '.*[0-9]{4}' -o)
					heure=$(date | cut -d' ' -f5)
					infos="$2|$1|$dates|$heure"
					echo $infos >> etc/liveusers
	
					inf=$(cat etc/passwd|grep $2|cut -d'|' -f1-4)
					message=$(cat etc/passwd|grep $2|cut -d'|' -f6)
					sed "s/$2|.*$/$inf|$dates $heure|$message/" etc/passwd -i

					./server_client.sh $port $2&
					sleep 1
					nc localhost $port
				else
					echo "Mot de passe incorrect."
					exit -1
				fi
			else
				echo "Connexion impossible. L'utilisateur n'existe pas sur la machine."
				exit -1
			fi
		else
			echo "Utilisez : rvsh -connect nom_machine nom_utilisateur"
		fi
	elif [ $1 = -admin ]
	then
		shift
		echo "Veuillez entrer le mot de passe administrateur : "
		read pwd
		adminPwd=$(echo $(head etc/shadow -n 1 | sed 's/root://') | openssl enc -base64 -d -aes-256-cbc -salt -pass pass:LO14 -pbkdf2)
		if [[ $adminPwd == $pwd ]]
		then
			echo "Les mots de passe correspondent. Connexion à la machine hostroot."
			port=$(tail -n 1 etc/livehosts | egrep -o '[0-9]{4}$')

			if [[ $port = "" ]]
			then
				port=8000
			else
				port=$(($port+1))
			fi

			signature="hostroot:root:$port"
			echo $signature >> etc/livehosts
			

			signature="$1:$2:$port"
			echo $signature >> etc/livehosts
			dates=$(date | egrep '.*[0-9]{4}' -o)
			heure=$(date | cut -d' ' -f5)
			infos="root|hostroot|$dates|$heure"
			echo $infos >> etc/liveusers

			inf=$(cat etc/passwd|grep root|cut -d'|' -f1-4)
			message=$(cat etc/passwd|grep root|cut -d'|' -f6)
			sed "s/root|.*$/$inf|$dates $heure|$message/" etc/passwd -i

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

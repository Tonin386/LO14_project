# LO14_project
Julien &amp; Antonin's LO14 project for A22. Creating a virtual network of machines on Linux with basic functionalities.

## File syntax

	etc/hosts: machine_name:port:user1:user2:
	etc/passwd: username:password:id: #Yet to be defined more precisely

## Global idea

Virtual machines are hosted on local netcat servers with a different port for each machine.
Once a machine is live, the user can connect using his credentials if he's registered on the machine.
The root machine server script will be a bit different, because it proposes different functionnalities.
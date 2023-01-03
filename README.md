# LO14_project
Julien &amp; Antonin's LO14 project for A22. Creating a virtual network of machines on Linux with basic functionalities.

## File syntax

	etc/hosts: machine_name:user1:user2:
	etc/passwd: username|x|email|full name|last connection date|[pending message]

## Global idea

Virtual machines are hosted on local netcat servers with a different port for each machine.
Once a machine is live, the user can connect using his credentials if he's registered on the machine.
The root machine server script will be a bit different, because it proposes different functionnalities.

## Installation

Create a `hosts` file in `etc` directory.
Add this line:
	- `hostroot:root:`

Create a `shadow` file in `etc` directory.
Add this line:
	- `root:U2FsdGVkX1+Xhe5h7UcWGXJD2pZcTiaC1tGVJNTv4UQ=`

Then you can use the admin mode. The password is: `root`.

Connect to admin mode with : `bash rvsh.sh -admin`.

You should first setup some users and machines while in admin mode. Then, you can connect as a user using: `bash rvsh.sh -connect machine user`.

Once connected as a user, type `help` for a list command.

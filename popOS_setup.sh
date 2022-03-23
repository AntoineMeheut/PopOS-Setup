#!/bin/bash

#----------------------------------------------------------------------------------------------------------------------#
# Script de configuration de Pop!_OS et d'installation des logiciels de mon Setup
#----------------------------------------------------------------------------------------------------------------------#
# MIT License - Copyright (c) 2021 Nicolás Castellán <cnicolas.developer@gmail.com>
# MIT License - Copyright (c) 2022 Antoine Meheut <antoine.meheut@watay.fr>
# Identifiant de licence SPDX : MIT
# LE LOGICIEL EST FOURNI "TEL QUEL"
# Lisez le fichier de LICENCE inclus pour plus d'informations
#----------------------------------------------------------------------------------------------------------------------#
# Variables d'exécution de ce script
# - load_tmp_file : utilisée pour indiquer que l'on souhaite charger un fichier pour le script, défaut = no
# - run_as_root : utilisée pour indiquer que le script doit s'exécuter en tant que root, défaut =no
load_tmp_file=no
run_as_root=no

#----------------------------------------------------------------------------------------------------------------------#
# Partie du script pour la lecture des variables de lancement du script
# Lit les variables et vérifie si load_tmp_file ou run_as_root sont utilisés
#----------------------------------------------------------------------------------------------------------------------#
USAGE_MSG () {
	printf "Paramètres du script shell: \e[01m./%s (-f)\e[00m
	-f) Charger les choix précédents
	-s) Exécuter en tant que root (non recommandé)\n" "$(basename "$0")"
}

# Lecture des variables du script
while [ -n "$1" ]; do
	case "$1" in
		-f) load_tmp_file=yes ;; # Charger depuis un fichier temporaire
		-s) run_as_root=yes   ;; # Ne pas s'arrêter si exécuté en tant que root
		-h | --help)
		USAGE_MSG >&2
		exit 0
		;;
		*)
		printf "Option \"%s\" non reconnue.\n" "$1" >&2
		USAGE_MSG >&2
		exit 1
		;;
esac; shift; done

#----------------------------------------------------------------------------------------------------------------------#
# Partie du script pour rechercher les différents fichiers .txt avec les choix de l'utilisateur
#----------------------------------------------------------------------------------------------------------------------#
# Récupère le path du répertoire du script et le sauvegarde pour l'utiliser plus tard
cd "$(dirname "$0")"
script_location="$(pwd)"

# Rechercher les dossiers et fichiers pertinents pour l'installation
MISSING() {
	printf "\e[31mMissing directory or file:\e[00m\n%s\n" "$1"
	exit 1
}

# Prépare et teste les chemins de fichiers dans les variables
autoresume_file="$HOME/.config/autostart/autoresume_popOS_setup.desktop"
choices_file="$script_location/.tmp_choices.txt"

packages_file="$script_location/packages.txt"
flatpaks_file="$script_location/flatpaks.txt"
remove_file="$script_location/remove.txt"

scripts_folder="$script_location/scripts"
postinstall_folder="$script_location/post-install.d"
sources_folder="$script_location/sources.d"

[ -f "$packages_file"      ] || MISSING "$packages_file"
[ -f "$flatpaks_file"      ] || MISSING "$flatpaks_file"
[ -f "$remove_file"        ] || MISSING "$remove_file"
[ -d "$scripts_folder"     ] || MISSING "$scripts_folder"
[ -d "$postinstall_folder" ] || MISSING "$postinstall_folder"
[ -d "$sources_folder"     ] || MISSING "$sources_folder"

unset USAGE_MSG MISSING

# Fonction pour tracer une ligne sur toute la largeur de la console
Separate () {
	printf "\n\n\e[34m%`tput cols`s\e[00m\n" | tr ' ' '='
}

#----------------------------------------------------------------------------------------------------------------------#
# Préviens l'utilisateur sur les droits root, demande le privilège root et affiche des informations
# avant que le script ne débute sont action sur le système
#----------------------------------------------------------------------------------------------------------------------#
# Préviens que le script ne doit pas être exécuté en tant que root
if [ $(id -u) == 0 -a "$run_as_root" = "no" ]; then
	printf "\e[31mLe script ne doit pas fonctionner en tant que root, car certaines choses pourraient se casser\e[00m
Au lieu de cela, lancez-le en tant que utilisateur et laissez le script demander les droits root
Pour forcer le script en tant que root, utilisez le flag -s\n" >&2
	exit 1
fi

# Demande les privilèges root maintenant
sudo echo >/dev/null || exit 1

# Affiche le message de bienvenue et l'avis de non-responsabilité
commit="$(git log -1 --format='%h' 2>/dev/null)"
version="$(git describe --tags --abbrev=0 2>/dev/null)"
[ -n "$version" ] && \
	version=" version $version"
[ -z "$version" -a -n "$commit" ] && \
	version=" at commit $commit"

printf "Bienvenue dans \e[36;01mPop!_OS Setup\e[00m%s!
Suivez les instructions et vous devriez être opérationnel bientôt
LE LOGICIEL EST FOURNI \"TEL QUEL\", lisez la licence pour plus d'informations\n\n" "$version"
unset version commit

#----------------------------------------------------------------------------------------------------------------------#
# Charge le fichier temporaire ou bien commence à préparer le fichier qui va contenir toutes les actions
# qui vont être réalisées sur le système Pop!_OS. Partie du script où les fichiers .txt de choix de
# l'utilisateur sont lus, ainsi que la liste des scripts shell qui vont être exécutés
#----------------------------------------------------------------------------------------------------------------------#
#Invite l'utilisateur a faire ses choix de région
if [ "$load_tmp_file" = "no" ]; then
	# Nous sommes sur le point de créer un nouveau fichier de choix
	[ -f "$choices_file" ] && rm "$choices_file"

	# Configure IFS et umask
	IFSB="$IFS"
	IFS="$(echo -en "\n\b")"
	MASK=$(umask)
	umask 077

	# Utiliser le fichier suivant en mémoire
	MEMFILE=/tmp/$$-line

	# Parcoure la liste remove.txt en demandant à l'utilisateur de choisir ceux à supprimer
	printf "Confirmer les packages à supprimer :\n"
	for i in $(cat "$remove_file"); do
		echo "$i" > $MEMFILE && chmod u-w $MEMFILE

		read -rp "$(printf "Confirmer : \e[31m%s\e[00m (y/N) " "$(cut -d' ' -f1 $MEMFILE | tr '_' ' ')" )"
		[ "${REPLY,,}" == "y" ] && \
			TO_REMOVE+=($(cut -d' ' -f2- $MEMFILE))

		chmod u+w $MEMFILE
	done
	TO_REMOVE=($(echo ${TO_REMOVE[@]} | tr ' ' '\n' | sort -u))
	echo "Logiciels à supprimer - ${TO_REMOVE[@]}" >> "$choices_file"

	# Parcoure la liste packages.txt en demandant à l'utilisateur de choisir ceux à installer
	printf "Confirmer les packages à installer :\n"
	for i in $(cat "$packages_file"); do
		echo "$i" > $MEMFILE && chmod u-w $MEMFILE

		# Détecte la catégorie et le choix de l'utilisateur d'ignorer ou de ne pas ignorer
		if [ -n "$(awk '$0 ~ /^\#/' $MEMFILE)" ]; then
			read -rp "$(printf "Voulez-vous installer \e[01;33m%s\e[00m ? (%s) (Y/n) > " "$(awk '{print $1}' $MEMFILE | tr '_' ' ')" "$(cut -d' ' -f2- $MEMFILE)")"
			[ "${REPLY,,}" == 'y' -o -z "$REPLY" ] && SKIP_CATEGORY=no || SKIP_CATEGORY=yes
			# Traite les applications en catégories
			if [ -n "$(awk '$0 ~ /\t/' $MEMFILE)" -a "$SKIP_CATEGORY" = 'non' ]; then
				read -rp "$(printf "Logiciels à installer : \e[33m%s\e[00m (Y/n) " "$(awk '{print $1}' $MEMFILE | tr '_' ' ')")"
				[ "${REPLY,,}" == 'y' -o -z "$REPLY" ] && \
				TO_DNF+=($(cut -d' ' -f2- $MEMFILE))
			fi
		fi

		chmod u+w $MEMFILE
	done

	# Ajouter les packages essentiels, les trier et les enregistrer
	TO_APT+=(ufw xclip pixz)
	TO_APT=($(echo ${TO_APT[@]} | tr ' ' '\n' | sort -u))
	echo "Packages essentiels à intaller - ${TO_APT[@]}" >> "$choices_file"

	# Parcoure la liste de flatpaks.txt en demandant à l'utilisateur de choisir ceux à installer
	printf "Confirmez les flatpaks à installer :\n"
	for i in $(cat "$flatpaks_file"); do
		echo "$i" > $MEMFILE && chmod u-w $MEMFILE

		read -rp "$(printf "Flatpaks à installer : \e[36m%s\e[00m (Y/n) " "$(cut -d' ' -f1 $MEMFILE | tr '_' ' ')")"
		[ "${REPLY,,}" == "y" -o -z "$REPLY" ] && \
			TO_FLATPAK+=($(cut -d' ' -f2- $MEMFILE))

		chmod u+w $MEMFILE
	done
	TO_FLATPAK=($(echo ${TO_FLATPAK[@]} | tr ' ' '\n' | sort -u))
	echo "Logiciels flatpaks à installer - ${TO_FLATPAK[@]}" >> "$choices_file"

	# Supprime MEMFILE et remet IFS et umask à la normale
	rm $MEMFILE
	IFS="$IFSB"
	umask $MASK
	unset IFSB MASK MEMFILE

	# Choix du pilote NVIDIA
	CHOSEN_DRIVER=none
	if lspci | grep "NVIDIA" &>/dev/null; then
		DRIVERS+=("system76-driver-nvidia")
		DRIVERS+=("nvidia-driver-470")
		DRIVERS+=("nvidia-driver-440")
		DRIVERS+=("nvidia-driver-390")
		DRIVERS+=("nvidia-driver-360")
		DRIVERS+=("none")
		select i in ${DRIVERS[@]}; do
		case $i in
			none) break ;;
			*)
			if [ $REPLY -lt 0 ] || [ $REPLY -gt ${#DRIVERS[@]} ]; then
				printf "Je ne comprends pas ce choix\n" >&2
				continue
			else CHOSEN_DRIVER="$i"; fi
			;;
		esac
		break
		done
		Separate
	fi

	# Stocker le pilote choisi
	echo "Driver NVIDIA choisi - $CHOSEN_DRIVER" >> "$choices_file"
	unset DRIVERS

	# Laisser l'utilisateur choisir des scripts supplémentaires à exécuter
	printf "Choisissez des scripts supplémentaires à exécuter :\n"
	for i in $(ls "$scripts_folder" | grep \.sh$); do
		read -rp "$(printf "Voulez-vous exécuter le script \e[01m%s\e[00m ? (Y/n) " "${i/".sh"/""}")"
		[ "${REPLY,,}" = "y" -o -z "$REPLY" ] && \
			SCRIPTS+=("$i")
	done

	# Stocke les scripts sélectionnés
	echo "Les scripts sélectionnés - ${SCRIPTS[@]}" >> "$choices_file"
	unset prompt_user
	Separate
fi
# Fin de la partie initialisation et choix d'installation

#----------------------------------------------------------------------------------------------------------------------#
# Copie des les différentes variables qui vont être utilisées les informations issues de la lecture des
# fichier .txt et de la liste des scripts schell
#----------------------------------------------------------------------------------------------------------------------#
# Chargement des choix à partir du fichier
if [ "$load_tmp_file" = "yes" ]; then
	# Erreur s'il n'y a pas de choix précédents
	if [ -f "$choices_file" ]; then
		printf "\e[01mChargement des choix précédents\e[00m\n"
	else
		printf "\e[31mERREUR : aucun fichier de choix trouvé.\e[00m\n" >&2
		exit 1
	fi

	# Charge les packages à supprimer
	TO_REMOVE=$(cat "$choices_file" | grep "TO_REMOVE")
	TO_REMOVE=${TO_REMOVE/"TO_REMOVE - "/""}

	# Charge les packages à installer
	TO_APT=$(cat "$choices_file" | grep "TO_APT")
	TO_APT=${TO_APT/"TO_APT - "/""}

	# Charge les flatpaks à installer
	TO_FLATPAK=$(cat "$choices_file" | grep "TO_FLATPAK")
	TO_FLATPAK=${TO_FLATPAK/"TO_FLATPAK - "/""}

	# Charge le pilote NVIDIA choisi
	CHOSEN_DRIVER=$(cat "$choices_file" | grep "CHOSEN_DRIVER")
	CHOSEN_DRIVER=${CHOSEN_DRIVER/"CHOSEN_DRIVER - "/""}

	# Charge les scripts shell à exécuter
	SCRIPTS=$(cat "$choices_file" | grep "SCRIPTS")
	SCRIPTS=${SCRIPTS/"SCRIPTS - "/""}

	Separate
fi
# Fin du chargement des choix

#----------------------------------------------------------------------------------------------------------------------#
# Partie du script qui va exécuter toutes les actions dans le système d'exploitation Pop!_OS
#----------------------------------------------------------------------------------------------------------------------#
# Réglez l'heure du BIOS sur UTC
sudo timedatectl set-local-rtc 0

# Créer des dossiers de thèmes et d'icônes
mkdir -p ~/.local/share/{themes,icons}

# Dossiers secrets
mkdir -p ~/.{ssh,safe} -m 700

# Sauvegardez les fichiers suivants s'ils sont présents
for i in .bashrc .clang-format .zshrc .vimrc .config/{nvim/init.vim,htop/htoprc}; do
	[ ! -f ~/$i-og -a -f ~/$i ] && cp ~/{$i,$i-og}
	# "-og" stands for original
done

# Créer un modèle de "fichier vide"
[ -f ~/Templates/Empty ] || touch ~/Templates/Empty

# Testez la connexion Internet et quittez si aucune n'est trouvée
ping -c 1 google.com &>/dev/null
if [ ! $? -eq 0 ]; then
	printf "\e[31mERREUR : Pas d'Internet\e[00m\n" >&2
	exit 1
fi

# Arrête le packagekit de GNOME pour éviter les problèmes pendant l'utilisation du gestionnaire de packages
sudo systemctl stop packagekit

# Installe ce paquet pour qu'apt supporte https
sudo apt-get install apt-transport-https -y &>/dev/null

# Source tous les fichiers contenant des sources supplémentaires
for i in $(ls "$sources_folder" | grep \.sh$); do
	[[ "${TO_APT[@]}" == *"${i/".sh"/""}"* ]] && \
		source "$sources_folder/$i"
done

[[ "${REPOS_CONFIGURED[@]}" ]] && Separate
unset REPOS_CONFIGURED URL KEY

# Mettez à jour tous les référentiels
printf "Updating repositories...\n"
sudo apt update

# Supprime les packages sélectionnés par l'utilisateur
if [ -n "$TO_REMOVE" ]; then
	Separate
	printf "Suppression du packages sélectionné par l'utilisateur ...\n"
	sudo apt --purge remove ${TO_REMOVE[@]}
	Separate
fi

# Installe le pilote NVIDIA
if [ "$CHOSEN_DRIVER" != "none" ]; then
	Separate
	printf "Installation du pilote NVIDIA : \e[01m%s\e[00m\n" $CHOSEN_DRIVER
	sudo apt install $CHOSEN_DRIVER
	Separate
fi

# Fait la mise à niveau des packages
let UPGRADABLE=$(apt list --upgradable 2>/dev/null | wc -l)
let UPGRADABLE--
if [ $UPGRADABLE -gt 0 ]; then
	printf "%i ces packets peuvent être mis à niveau\n" $UPGRADABLE
	read -rp "Voulez-vous les mettre à niveau maintenant ? (Y/n) "
	if [ "${REPLY,,}" = "y" ] || [ -z $REPLY ]; then
		sudo apt upgrade -y
	fi
fi
unset UPGRADABLE

Separate

# Installe les packages sélectionnés par l'utilisateur
printf "Installation de packages sélectionnés par l'utilisateur ...\n"
sudo apt install ${TO_APT[@]}

# Installe les flatpaks sélectionnés par l'utilisateur
if [ -n "$TO_FLATPAK" ]; then
	Separate
	flatpak --system remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
	printf "Installation des flatpaks sélectionnés par l'utilisateur ...\n"
	printf "Quel type d'installation souhaitez-vous faire ?\n"
	select i in "system" "user"; do
	case $i in
		system) flatpak --system install ${TO_FLATPAK[@]}    ;;
		user)   flatpak --user   install ${TO_FLATPAK[@]}    ;;
		*) printf "Vous devez choisir une option valide"; continue ;;
	esac; break; done
	Separate
fi

# Source les scripts de post-installation pour les packages que nous avons installés
if [ $? -eq 0 ]; then
	for i in $(ls "$postinstall_folder" | grep \.sh$); do
		[[ "${TO_APT[@]}" == *"${i/".sh"/""}"* ]] && \
			source "$postinstall_folder/$i"
	done
fi

# Exécuter les scripts supplémentaires
for i in ${SCRIPTS[@]}; do
	Separate
	printf "Exécution du script \e[01m%s\e[00m ...\n" "${i/".sh"/""}"
	"$scripts_folder/$i"
done

Separate

#----------------------------------------------------------------------------------------------------------------------#
# Nettoyage une fois que le script a terminé ses actions
#----------------------------------------------------------------------------------------------------------------------#
printf "Nettoyage ...\n"
[ -f "$autoresume_file" ] && rm "$autoresume_file"
[ -f "$choices_file"    ] && rm "$choices_file"
sudo apt-get autoremove -y &>/dev/null
sudo apt-get autoclean -y &>/dev/null
wait

# Redémarre le packagekit de GNOME une fois que nous en avons terminé avec le gestionnaire de packages
sudo systemctl restart packagekit

printf "\e[01;32mTerminé!\e[00m votre système a été configuré.\n"
exit 0

# Merci pour le téléchargement, et profitez-en !

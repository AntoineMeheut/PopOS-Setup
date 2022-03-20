# MIT License

# Copyright (c) 2020-2022 Antoine Meheut

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#--Changer le nom de votre hostname il faut remplacer aloha par le nom que vous voulez
hostnamectl set-hostname aloha

#--Choisir votre langue et le site miroir
sudo sed -i 's|http://us.|http://fr.|' /etc/apt/sources.list.d/system.sources
sudo locale-gen fr_FR.UTF.8
sudo locale-gen en_US.UTF.8
sudo update-locale LANG=en_US.UTF-8

#--Créer une nouvelle clef SSH
ssh-keygen -t ed25519 -C "popos-on-precision"

#--Installer les softs pour une clef Yubikey
sudo apt install -y yubikey-manager yubikey-personalization
sudo apt install -y libpam-u2f # authentification second facteur pour les commandes sudo
sudo apt install -y yubikey-luks  # authentification second facteur pour luks
sudo apt install -y gpg scdaemon gnupg-agent pcscd gnupg2 # librairies pour GPG

#--Installer Nextcloud, par défaut Nextcloud est proposé par pop, mais pas le desktop
sudo apt install -y nextcloud-desktop

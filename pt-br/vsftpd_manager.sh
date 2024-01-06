#!/bin/bash

if [[ "$(whoami)" != "root" ]]; then
    clear
    echo -e "${RED}Execute o script como root (${YELLOW}sudo -i${RED}).${NC}"
    exit 1
fi

# Define cores usando códigos de escape ANSI
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Arquivo temporário para armazenar usuários criados durante a execução do script
temp_users_file="/tmp/script_temp_users.txt"
userlist_file="/etc/vsftpd.userlist"

# Função para instalar o vsftpd
install_vsftpd() {
    # Atualiza a lista de pacotes
    apt update

    # Instala o vsftpd e o OpenSSL
    apt install -y vsftpd openssl

    touch "$userlist_file"

    # Gera um certificado SSL autoassinado
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/certs/vsftpd.pem -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com"

    # Ajusta as permissões do certificado
    chmod 600 /etc/ssl/private/vsftpd.pem

    # Copia o arquivo de configuração original como backup
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

    # Configuração do vsftpd.conf
    cat <<EOF > /etc/vsftpd.conf
# Configurações básicas
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem

# Limita o acesso a usuários locais
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO

# Limita o número de conexões
max_clients=50
max_per_ip=5

# Ativa o modo passivo e define as portas
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100

# Ativa a proteção contra ataques
async_abor_enable=YES

EOF

    # Reinicia o serviço vsftpd
    systemctl restart vsftpd

    echo -e "${GREEN}vsftpd instalado e configurado com segurança.${NC}"
}


# Função para adicionar um novo usuário
add_user() {
    read -p "Digite o nome do novo usuário: " username
    read -s -r -p "Digite a senha para o novo usuário: " password

    # Verifica se o usuário já existe
    if id "$username" >/dev/null 2>&1; then
        echo "Usuário $username já existe. Removendo..."
        remove_user "$username"
    fi

    # Adiciona o novo usuário
    useradd -m -s /bin/bash "$username"
    echo "$username:$password" | chpasswd

    # Adiciona o usuário ao arquivo de lista de usuários
    echo "$username" >> "$userlist_file"

    # Cria o diretório do usuário FTP e define as permissões
    user_home="/home/$username"
    mkdir -p "$user_home/ftp"
    chmod 755 "$user_home/ftp"
    
    # Ajusta as permissões do diretório raiz do usuário para torná-lo não gravável
    chmod a-w "$user_home"

    # Adiciona o usuário ao arquivo temporário
    echo "$username" >> "$temp_users_file"

    echo -e "${GREEN}Novo usuário criado: $username${NC}"
}

# Função para abrir as portas necessárias no firewall
open_firewall_ports() {
        # ufw está instalado
    if command -v ufw >/dev/null 2>&1; then

    # Abre as portas necessárias para o vsftpd
    ufw allow 21/tcp
    ufw allow 22/tcp
    ufw allow 990/tcp
    ufw allow 40000:40100/tcp  # Portas usadas no modo passivo (ajuste conforme necessário)
    ufw --force enable  # Ativa o firewall
    echo -e "${GREEN}Portas no firewall abertas com sucesso.${NC}"
else
    echo -e "${RED}UFW não instalado. As portas não podem ser abertas.${NC}"
fi
}

# Função para remover um usuário existente
remove_user() {
    local username="$1"

    # Verifica se o usuário existe antes de removê-lo
    if id "$username" >/dev/null 2>&1; then
        # Remove o usuário e seu diretório home
        userdel -r "$username"

        # Remove o usuário do arquivo de lista de usuários
        sed -i "/$username/d" "$userlist_file"

        echo -e "${RED}Usuário removido: $username${NC}"
    else
        echo "Usuário $username não existe."
    fi

    # Remove o usuário do arquivo temporário, se estiver presente
    [ -e "$temp_users_file" ] && sed -i "/$username/d" "$temp_users_file"
}


# Função para remover tudo (usuários e o programa por completo)
remove_all() {
    # Lê o arquivo temporário e remove os usuários listados
    while IFS= read -r username; do
        remove_user "$username"
    done < "$temp_users_file"

    # Remove o vsftpd, OpenSSL e o arquivo temporário
    apt purge -y vsftpd openssl
    apt autoremove -y
    rm -rf /etc/vsftpd.conf /etc/vsftpd.conf.bak /etc/ssl/private/vsftpd.pem /etc/ssl/certs/vsftpd.pem /etc/vsftpd.userlist "$temp_users_file"

    # Remove o arquivo de lista de usuários
    rm -f "$userlist_file"

    # Remove o arquivo temporário, se existir
    [ -e "$temp_users_file" ] && rm -f "$temp_users_file"
    
    systemctl restart vsftpd

    echo -e "${RED}Tudo removido.${NC}"
}

# Função para alterar permissões do usuário
change_user_permissions() {
    echo "Escolha uma opção:"
    echo "1. Alterar permissão de escrita"
    echo "2. Alterar permissão de leitura"

    read -p "Digite o número da opção desejada: " subchoice

    case $subchoice in
        1)
            change_write_permission
            ;;
        2)
            change_read_permission
            ;;
        *)
            echo "Opção inválida. Saindo."
            ;;
    esac
}

# Função para alterar permissão de escrita do usuário
change_write_permission() {
    read -p "Digite o nome do usuário: " username

    if id "$username" >/dev/null 2>&1; then
        read -p "Deseja permitir escrita para o usuário $username? (1 para sim, 2 para não): " choice
        if [ "$choice" -eq 1 ]; then
            chmod +w "/home/$username/ftp"
            sudo chmod 1777 "/home/$username/ftp"
            echo "Permissão de escrita concedida para o usuário $username."
        elif [ "$choice" -eq 2 ]; then
            chmod -w "/home/$username/ftp"
            sudo chmod 555 "/home/$username/ftp"
            echo "Permissão de escrita removida para o usuário $username."
        else
            echo "Permissão de escrita não alterada para o usuário $username."
        fi
    else
        echo "Usuário $username não existe."
    fi
}

# Função para alterar permissão de leitura do usuário
change_read_permission() {
    read -p "Digite o nome do usuário: " username

    if id "$username" >/dev/null 2>&1; then
        read -p "Deseja permitir leitura para o usuário $username? (1 para sim, 2 para não): " choice
        if [ "$choice" -eq 1 ]; then
            chmod +r "/home/$username/ftp"
            echo "Permissão de leitura concedida para o usuário $username."
        elif [ "$choice" -eq 2 ]; then
            chmod -r "/home/$username/ftp"
            echo "Permissão de leitura removida para o usuário $username."
        else
            echo "Opção inválida. Permissão de leitura não alterada para o usuário $username."
        fi
    else
        echo "Usuário $username não existe."
    fi
}


# Menu de opções
while true; do
    echo -e "${YELLOW}Escolha uma opção:${NC}"
    echo -e "${YELLOW}1. Instalar vsftpd${NC}"
    echo -e "${YELLOW}2. Adicionar um novo usuário${NC}"
    echo -e "${YELLOW}3. Remover um usuário existente${NC}"
    echo -e "${YELLOW}4. Alterar permissões do usuário${NC}"
    echo -e "${YELLOW}5. Remover tudo (usuários e o programa por completo)${NC}"
    echo -e "${YELLOW}6. Abrir portas no firewall${NC}"
    echo -e "${YELLOW}7. Sair${NC}"

    read -p "Digite o número da opção desejada: " choice

    case $choice in
        1)
            install_vsftpd
            ;;
        2)
            add_user
            ;;
        3)
            read -p "Digite o nome do usuário a ser removido: " username
            remove_user "$username"
            ;;
        4)
            change_user_permissions
            ;;
        5)
            remove_all
            ;;
        6)
            open_firewall_ports
            ;;
        7)
            echo -e "${YELLOW}Saindo. Até mais!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida. Tente novamente.${NC}"
            ;;
    esac
done
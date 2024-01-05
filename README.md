# Gerenciador VSFTPD

Este é um script em shell desenvolvido para facilitar a instalação, configuração e gerenciamento do servidor FTP VSFTPD no ambiente Ubuntu 20.04. Abaixo estão os principais recursos e funcionalidades abordados pelo script:

## Instalação e Configuração do VSFTPD
- **Instalação do VSFTPD:** Inclui a configuração básica e segura do servidor FTP, gerando um certificado SSL autoassinado para aumentar a segurança nas transferências.

## Gerenciamento de Usuários
- **Adição de Novo Usuário:** Permite a criação de novos usuários FTP, solicitando nome de usuário e senha. Os usuários são armazenados em um arquivo temporário durante a execução do script.
- **Remoção de Usuário Existente:** Remove um usuário existente, incluindo sua pasta home e removendo-o do arquivo de lista de usuários.
- **Alteração de Permissões do Usuário:** Fornece opções para alterar as permissões de leitura e escrita para um usuário específico.

## Firewall
- **Abrir Portas no Firewall:** Abre as portas necessárias no firewall para permitir conexões FTP seguras.

# Remoção Completa
- Opção para remover completamente o VSFTPD, OpenSSL, usuários criados pelo script e arquivos de configuração, restaurando o sistema para o estado inicial.

## Menu de Opções Interativo
- Apresenta um menu interativo que permite ao usuário escolher entre diferentes opções, como instalação do VSFTPD, adição de usuários, remoção de usuários, alteração de permissões, abertura de portas no firewall e remoção completa do servidor FTP.

## Como Usar
Certifique-se de ter permissões de administrador para executar o script. Utilize o seguinte comando para iniciar a instalação:
```bash
sudo bash vsftpd_manager_pt_br
```
**ou**

```bash
bash <(wget -qO- https://raw.githubusercontent.com/DX-BR/gerenciador-de-vsftpd/main/pt-br/vsftpd_manager_pt_br.sh)
```
Este script visa simplificar a administração do VSFTPD, proporcionando uma experiência intuitiva e eficiente para usuários do Ubuntu 20.04. Sinta-se à vontade para contribuir, relatar problemas ou personalizar conforme suas necessidades.

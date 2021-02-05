# infra-wordpress

Infra criada para exemplificar o uso do terraform para a criação de um ambiente de Wordpress

#### Dependências 
* Terraform
* Azure CLI

Link instalação do Terraform
https://www.terraform.io/downloads.html

Link do tutorial de instalação do Azure CLI
https://docs.microsoft.com/pt-br/cli/azure/install-azure-cli

#### Executar os seguintes comandos para criar a chave rsa id_rsa.pub id_rsa e id_rsa.insecure

### Criando as chaves rsa
ssh-keygen -m PEM -t rsa -b 4096

### Descriptografando a chave para usar no remote-exec
cd ~/.ssh/
rsa -in id_rsa -out id_rsa.insecure

#### Nota

Caso algum dos pacotes acima não estiverem disponíveis recomendo o uso do Chocalatey para sua instação no Windows ou apt-get no Linux com base em Debian. 


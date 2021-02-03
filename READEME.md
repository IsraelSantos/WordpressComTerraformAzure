Executar os seguintes comandos para criar a chave rsa id_rsa.pub id_rsa e id_rsa.insecure no Windows

Criando as chaves rsa
ssh-keygen -m PEM -t rsa -b 4096

Descriptografando a chave para usar no remote-exec
cd ~/.ssh/
rsa -in id_rsa -out id_rsa.insecure

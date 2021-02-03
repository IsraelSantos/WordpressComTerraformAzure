Executar os seguintes comandos para criar a chave rsa id_rsa.pub id_rsa e id_rsa.insecure no Windows

ssh-keygen -m PEM -t rsa -b 4096
cd ~/.ssh/
rsa -in id_rsa -out id_rsa.insecure

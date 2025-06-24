# Projeto-asg-aws-cloudwatch
Repositório do projeto de Auto Scaling, CLB e  Endpoint de Teste.

O projeto se consiste nos seguintes tópicos:

* [Visão-Geral-do-Projeto](#visão-geral-do-projeto)
* [Componentes-da-Arquitetura](#componentes-da-arquitetura)
* [Configuração-e-Implementação](#configuração-e-implementação)
    * [0. Criação de Chave de Par (Key Pair) para SSH](#0-criação-de-chave-de-par-key-pair-para-ssh)
    * [1. Criação da VPC e Subredes](#1-criação-da-vpc-e-subredes)
    * [2. Security Groups](#2-security-groups)
    * [3. Aplicação Web Simples (Hello World)](#3-aplicação-web-simples-hello-world)
    * [4. Classic Load Balancer (CLB)](#4-classic-load-balancer-clb)
    * [5. Auto Scaling Group (ASG)](#5-auto-scaling-group-asg)
    * [6. Alarmes do CloudWatch](#6-alarmes-do-cloudwatch)
    * [7. Políticas de Escala Dinâmica](#7-políticas-de-escala-dinâmica)
* [Teste-e-Validação](#teste-e-validação)
    * [Teste de Diminuição de Capacidade (Scale In)](#teste-de-diminuição-de-capacidade-scale-in)
    * [Teste de Aumento de Capacidade (Scale Out)](#teste-de-aumento-de-capacidade-scale-out)
* [Conclusão](#conclusão)

# Projeto de Auto Scaling na AWS com Classic Load Balancer (CLB)

## Visão Geral do Projeto

Este projeto demonstra a implementação de um sistema de Auto Scaling na Amazon Web Services (AWS) utilizando um Classic Load Balancer (CLB), um Auto Scaling Group (ASG) e políticas de escalabilidade baseadas em métricas do Amazon CloudWatch. O objetivo é garantir que a aplicação web mantenha a alta disponibilidade e a elasticidade, ajustando automaticamente o número de instâncias EC2 em resposta à demanda de tráfego.

## Componentes da Arquitetura

A arquitetura implementada consiste nos seguintes serviços AWS:

1. **Virtual Private Cloud:** Rede virtual que comunica os recursos da AWS e da rede externa.
2. **Security Groups:** Regras de firewall que controlam o tráfego de entrada e saída das instâncias EC2.
3.  **Amazon EC2:** Máquinas virtuais que hospedam a aplicação web ("hello world").
4.  **Classic Load Balancer (CLB):** Distribui o tráfego de entrada para as instâncias EC2 saudáveis.
5.  **Auto Scaling Group (ASG):** Gerencia a coleção de instâncias EC2, garantindo que o número desejado de instâncias esteja sempre em execução.
6.  **Amazon CloudWatch:** Monitora métricas de performance (como RequestCount do CLB) e dispara alarmes.
7.  **Políticas de Escala Dinâmica (Dynamic Scaling Policies):** Definem as ações do ASG em resposta aos alarmes do CloudWatch.

## Configuração e Implementação
Para acessar o projeto pode ser utilizado uma chave de par (key pair) para SSH. Como este item não é necessario, pois podemos usar a conexão via EC2 Instance Connect neste caso, chamaremos este item como o de numero 0.Para criar a chave de par siga os seguintes passos:
### 0. Criação de Chave de Par (Key Pair) para SSH

Acesse o menu de EC2 e navegue na aba lateral esquerda até a opção Rede e segurança > pares de chaves. Clique em criar par de chaves. Escreva o nome do par de chaves, selecione o formato de chave como `pem` e clique em criar. O arquivo será baixado automaticamente para o seu computador. Guarde-o em um local seguro, pois ele será necessário para acessar as instâncias EC2 via SSH. Após isto, use o comando no powershell no arquivo baixado para conectar na instância EC2:
```powershell
icacls.exe "C:\caminho\nome-da-chave.pem" /reset
 icacls.exe "C:\caminho\nome-da-chave.pem" /inheritance:r
```
```powershell
ssh -i "nome-da-chave.pem" ec2-user@ip-da-instancia
``` 

![key-pair](images/key-pair.jpeg)

### 1. Criação da VPC e Subredes

Criação de uma VPC (Virtual Private Cloud) e algumas sub-redes públicas, eliminando a necessidade de NAT Gateway. Para criar a VPC, pesquise pela mesma, clique para acessar seu menu e clique em "criar VPC". Clique em VPC e mais, escreva o nome da VPC, slecione 2 sub-redes públicas e nenhuma rede privada. Clique em criar VPC.

![vpc-detalhes](https://github.com/user-attachments/assets/7bca8846-9a64-46a6-8f34-d3c2468d3ecc)

O mapa de recursos resultante toma forma de:

![vpc-mapa-recursos](images/vpc-mapa-recursos.jpeg)
### 2. Security Groups
Para este projeto, foram criados os seguintes security groups:
* **`sg-ec2-teste-clb`:** Permite tráfego HTTP (porta 80) de do grupo de segurança do CLB e tráfego de saída para a porta 22 (SSH) para o IP do usuário. Não foi restringido nenhuma conexão de saída. Este grupo é associado às instâncias EC2.
![grupo de seguranca ec2](images/sg-ec2-inbound.jpeg)
* **`sg-clb-teste`:** Permite tráfego HTTP (porta 80) de qualquer origem. Não foi restringido nenhuma conexão de saída. Este grupo é associado ao Classic Load Balancer (CLB).
![grupo de seguranca clb](images/sg-lb-inbound.jpeg)

### 3. Aplicação Web Simples (Hello World)

As instâncias EC2 foram configuradas para servir uma página web simples com a mensagem "hello world". Isso foi verificado acessando o DNS do Load Balancer.
Para criar a instância EC2, pesquise por instâncias EC2, clique em "criar instância", selecione a imagem Amazon Linux 2, escolha o tipo de instância t2.micro, selecione o par de chaves criado anteriormente e associe os grupos de segurança criados. Após isto, selecione a opção configurações avançadas e adicione o seguinte [script](user_data.sh) de inicialização (user data) para instalar o servidor web e servir a página "hello world":

```bash
#!/bin/bash

yum update -y
yum install -y httpd
echo "Hello World" > /var/www/html/index.html
# Servidor básico com endpoint /teste
cat <<EOL > /var/www/html/teste
#!/bin/bash
echo "Content-type: text/plain"
echo ""
echo "Requisição recebida em $(hostname)"
sleep 5 # simula carga
EOL

chmod +x /var/www/html/teste
systemctl start httpd
systemctl enable httpd
```

Houve uma modificação no script dado no user_data, realizando a modificação pois ocorreu erro na inicialização do processo Apache, Para Iniciar o serviço apache httpd e o habilitar para iniciar o boot:

```bash
#httpd -k start 

systemctl start httpd
systemctl enable httpd

```

![hello-world](https://github.com/user-attachments/assets/b36cd3fa-43b6-436e-8d39-f549326bcd1a)



### 4. Classic Load Balancer (CLB)

Um CLB foi criado para distribuir o tráfego. Ele foi associado às sub-redes públicas e configurado para direcionar o tráfego para as instâncias do Auto Scaling Group. 

![Configuração do CLB](images/lb-detalhes.jpeg)
![Atividades do CLB](images/lb-healthy.jpeg)
### 5. Auto Scaling Group (ASG)

O ASG (`meu-asg-teste-clb`) foi configurado para gerenciar as instâncias EC2. Ele utiliza um Modelo de Lançamento para definir as características das instâncias (AMI) e está associado a múltiplas zonas de disponibilidade para alta resiliência.Para este projeto, foi solicitado que houvesse no mínimo uma instancia ativa e no máximo três, gerenciadas pelas [políticas](#7-políticas-de-escala-dinâmica) de escala da ASG que serão apresentadas no futuro.
![Detalhes ASG](images/asg-detalhes.jpeg)
![Politicas do ASG](images/asg-politicas.jpeg)
![Atividades do ASG](images/asg-atividades.jpeg)

### 6. Alarmes do CloudWatch

Dois alarmes principais foram configurados no CloudWatch para monitorar a métrica `RequestCount` do CLB:

* **`alarme-diminuir-requestcount-clb` (Scale In):** Dispara quando o número de requisições cai abaixo de um limiar.
    * **Condição:** `RequestCount < 5` (para 1 ponto de dados em 1 minuto)
    * **Métrica:** `AWS/ELB RequestCount`, Estatística `Average` (Média).

    ![Alarme de Diminuir em Alarme](images/alarme-diminuir-detalhes.jpeg)
    
    ![Email de Diminuir em Alarme](images/diminuir-email.jpeg)

* **`alarme-aumentar-requestcount-clb` (Scale Out):** Dispara quando o número total de requisições excede um limiar.
    * **Condição:** `RequestCount > 100` (para 1 ponto de dados em 1 minuto)
    * **Métrica:** `AWS/ELB RequestCount`, Estatística `Sum` (Soma). (Importante: a estatística foi ajustada de Média para Soma para capturar o volume total de tráfego do LB).

    ![Alarme de Aumentar em Alarme](images/alarme-aumentar-detalhes.jpeg)
    
    ![Email de Aumentar em Alarme](images/aumentar-email.jpeg)
    
        

### 7. Políticas de Escala Dinâmica

Duas políticas de escalabilidade foram associadas ao ASG:

* **`diminuir-instancias-requestcount`:** Vinculada ao `alarme-diminuir-requestcount-clb`. Quando acionada, remove 1 unidade de capacidade.

    ![Política de Diminuir Instâncias](images/asg-politicas.jpeg)

* **`aumentar-instancias-requestcount`:** Vinculada ao `alarme-aumentar-requestcount-clb`. Quando acionada, adiciona 1 unidade de capacidade.

    ![Configuração da Política de Escalabilidade Simples](images/asg-politicas.jpeg)

## Teste e Validação

Para validar o funcionamento do Auto Scaling, foram realizados testes de carga utilizando a ferramenta `hey` e o monitoramento em tempo real dos alarmes do CloudWatch e do histórico de atividades do Auto Scaling Group.

### Teste de Diminuição de Capacidade (Scale In)

Quando o tráfego foi baixo ou inexistente, o alarme `alarme-diminuir-requestcount-clb` entrou no estado `ALARM`, indicando que a capacidade poderia ser reduzida.

![Estado dos Alarmes (Diminuir em Alarme)](images/alarmes-iniciados.jpeg)

### Teste de Aumento de Capacidade (Scale Out)

Para simular o aumento de tráfego, o comando `hey` foi utilizado para gerar um volume significativo de requisições por um período sustentado (por exemplo, `hey -z 3m -c 50 http://seu-dns-do-clb.amazonaws.com/`).
![Histórico de Atividades do (Teste de Carga)](images/teste-hey.jpeg)

O alarme `alarme-aumentar-requestcount-clb` entrou no estado `ALARM` (conforme visto nos detalhes da métrica e no estado do alarme durante o teste).

O histórico de atividades do Auto Scaling Group confirmou que uma nova instância foi lançada em resposta ao alarme de aumento de requisições:

![Histórico de Atividades do ASG (Lançamento de Instância)](images/asg-atividade-ec2.jpeg)
*Observar a linha "Launching a new EC2 instance ... in response to EC2 alarm ... changing the desired capacity from 1 to 2".*

A verificação no painel de instâncias EC2 confirmou a presença de duas instâncias em execução após o disparo do alarme de aumento:

![Painel de Instâncias EC2 (Duas Instâncias)](images/escalabilidade-instancia.jpeg)
*Presença da instância original (`i-0d98ac084a80100ca`) e da nova instância (`i-0360c353c42b45db2`).*

## Conclusão

Este projeto demonstra a configuração bem-sucedida de um ambiente com Auto Scaling na AWS, que é capaz de reagir dinamicamente a alterações na demanda de tráfego. As políticas de escalabilidade baseadas em `RequestCount` do Classic Load Balancer garantem que os recursos sejam provisionados de forma eficiente, mantendo a disponibilidade da aplicação e otimizando os custos.

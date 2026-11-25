# Terraform — Google Cloud

Esta configuração cria a base de infraestrutura para a arquitetura definida em `docs/escopo.md`:

- região padrão `us-central1` (Iowa), zona `us-central1-a`;

- VPC e subnet próprias;
- VM Ubuntu para a aplicação e VM Ubuntu exclusiva para o PostgreSQL;
- IPs privados fixos e regra que libera TCP/5432 somente da VM da aplicação;
- SSH permitido somente pelo Identity-Aware Proxy (IAP);
- IP externo estático para o DNS e portas públicas 80/443 terminadas pelo Nginx com certificado Let's Encrypt;
- um disco persistente adicional para cada VM, protegido contra destruição acidental pelo Terraform;
- Artifact Registry Docker e permissão de leitura para a VM da aplicação.

O Terraform **não instala Docker nem configura o sistema operacional**: essa parte fica com o Ansible. O HTTPS termina no Nginx do host da aplicação, sem um balanceador gerenciado adicional. As portas públicas abertas são 80/443; SSH entra pelo IAP, e PostgreSQL só aceita a origem da VM de aplicação. A VM do banco também recebe IP externo para baixar pacotes/imagens, mas não há regra pública de ingresso para o banco.

## Pré-requisitos

1. Projeto Google Cloud com faturamento habilitado e permissões para Compute, Artifact Registry, IAM e rede.
2. Terraform CLI 1.8 ou superior e Google Cloud CLI (`gcloud`).
3. Login local para desenvolvimento: `gcloud auth application-default login`.
4. Chave SSH pública, por exemplo `~/.ssh/id_ed25519.pub`. Nunca use a chave privada.
5. E-mail da conta Google que usará IAP para abrir o SSH nas VMs.

## Estado remoto (GCS)

O estado contém detalhes da infraestrutura e deve ficar fora do Git. O backend configurado é um bucket GCS, com versionamento recomendado. Crie **uma vez** um bucket globalmente único na mesma conta, com acesso restrito e versionamento ativado. O bucket precisa existir antes de inicializar o Terraform. A localização do bucket é independente da região das VMs; para este projeto, `us-central1` também é uma opção. Não use o bucket de dados/imagens da aplicação para guardar o state.

Copie `backend.hcl.example` para `backend.hcl` e substitua o nome do bucket. `backend.hcl` não deve ser versionado. Depois:

```sh
terraform init -backend-config=backend.hcl
```

Na pipeline, configure a autenticação de uma service account/Workload Identity com acesso ao bucket e use o mesmo backend e prefix. Não gere um state novo em cada execução.

## Preparar e revisar

Dentro desta pasta:

```sh
cp terraform.tfvars.example terraform.tfvars
```

No PowerShell, use `Copy-Item terraform.tfvars.example terraform.tfvars`. Edite `terraform.tfvars` com o ID do projeto e o conteúdo da chave pública (uma única linha). Em seguida:

```sh
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

Leia o plano e confirme recursos, região, tipos de máquina e custos antes de qualquer criação. Só aplique quando estiver pronto:

```sh
terraform apply tfplan
```

Os outputs mostram os IPs e a URL do registry. Aponte o DNS A do domínio para `app_public_ip`. O inventário Ansible usa os nomes das VMs com `gcloud compute start-iap-tunnel` como `ProxyCommand`; não é preciso copiar IPs para o inventário. Use o IP privado do banco em `DB_PRIVATE_IP` na configuração da aplicação.

## Persistência e encerramento

Os discos de dados são separados dos discos de boot e possuem `prevent_destroy`; isso evita apagar dados acidentalmente, mas também impede um `terraform destroy` completo enquanto essa proteção estiver no código. Para encerrar o laboratório, faça e valide backup, remova a proteção de cada disco conscientemente, revise `terraform plan -destroy` e só então destrua. Discos mantidos após apagar as VMs continuam gerando cobrança.

Os discos estão apenas anexados nesta etapa. O próximo passo do Ansible deve formatá-los somente se estiverem vazios, montá-los em caminhos estáveis e configurar PostgreSQL/Docker para usar esses caminhos sem apagar dados existentes.

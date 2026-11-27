# Ansible — implantação nas VMs GCP

`site.yml` prepara as duas VMs Ubuntu. A VM da aplicação recebe Docker, os serviços web/API/SeaweedFS e as credenciais geradas pelo setup existente. A VM do banco recebe somente as duas senhas necessárias ao PostgreSQL. O banco sobe antes da aplicação. Atualização de Ubuntu e atualização forçada de imagens são parâmetros separados.

O disco persistente é inspecionado antes de qualquer formatação: o playbook só cria ext4 quando não encontra assinatura. Se encontrar um formato diferente, para sem apagar o disco. Depois monta o disco no boot e configura o `data-root` do Docker ali, para manter os volumes Compose em reinícios e atualizações.

## Antes da primeira implantação

1. Aplique o Terraform (ou execute a pipeline `.github/workflows/deploy.yml` com `action=deploy`) e aguarde a criação das VMs e a concessão de IAP.
2. Na máquina de controle Linux/WSL (quando rodar manualmente), autentique o `gcloud` (`gcloud auth login`) e confirme `gcloud config set project projeto-mensal-515620`.
3. Instale as collections: `ansible-galaxy collection install -r ansible/requirements.yml`.
4. Configure `app_domain` e o modo TLS (`tls_mode`):
   - **`cloudflare_origin` (recomendado com Cloudflare proxy):** informe `tls_cert_pem` e `tls_key_pem` (via GitHub Secrets `CLOUDFLARE_ORIGIN_CERT` e `CLOUDFLARE_ORIGIN_KEY`).
   - **`letsencrypt`:** informe `letsencrypt_email` e aponte o registro DNS A (sem proxy bloqueando o desafio HTTP) para o `app_public_ip`.
   - **`self_signed`:** gera certificado local temporário apenas para testes pré-DNS.
5. Publique as imagens `web` e `api` no Artifact Registry antes do Ansible (a pipeline `deploy.yml` já faz isso automaticamente quando `build_and_push_images=true`).

## Backup e restauração isolada

- Gerar backup consistente (`pg_dump` + volumes SeaweedFS + `.secrets`): `ansible-playbook -i ansible/inventory/hosts.yml ansible/backup.yml`
- Validar restauração em contêiner/diretório isolado sem sobrescrever a produção: `ansible-playbook -i ansible/inventory/hosts.yml ansible/restore-test.yml`

## Publicar imagens para uma implantação manual

No WSL, a partir da raiz do repositório, use a mesma tag para as duas imagens:

```bash
IMAGE_TAG="$(git rev-parse --short HEAD)"
REGISTRY="us-central1-docker.pkg.dev/projeto-mensal-515620/smart-construction"
gcloud auth configure-docker us-central1-docker.pkg.dev

docker build \
  --build-arg NEXT_PUBLIC_ASSETS_BASE_URL=/assets \
  --build-arg ASSETS_PROXY_URL=http://storage:8333/smart-assets \
  --build-arg API_PROXY_URL=http://api:8000 \
  -t "$REGISTRY/web:$IMAGE_TAG" .
docker build -f backend/Dockerfile -t "$REGISTRY/api:$IMAGE_TAG" backend
docker push "$REGISTRY/web:$IMAGE_TAG"
docker push "$REGISTRY/api:$IMAGE_TAG"
```

Passe a tag publicada ao Ansible com `-e app_image_tag="$IMAGE_TAG"` ou atualize `app_image_tag` em `group_vars/app_servers.yml`. Guarde a mesma tag nas evidências da entrega.

## Executar

Na raiz do repositório, depois de confirmar que o Terraform foi aplicado, o domínio aponta para a infraestrutura e as imagens já existem:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible -i ansible/inventory/hosts.yml all -m ping
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml
```

O inventário usa IAP como `ProxyCommand`, portanto não é necessário colocar IPs que mudam nem abrir SSH para a internet. A chave privada permanece no WSL em `~/.ssh/id_ed25519`; ela não vai para o repositório nem para as VMs.

## Atualizações controladas

Por padrão, `update_operating_system`, `update_application_images` e `update_database_image` são `false`. Depois de publicar uma nova tag, execute:

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml \
  -e app_image_tag=TAG_PUBLICADA \
  -e update_application_images=true
```

Para incluir atualizações de pacotes do Ubuntu, acrescente `-e update_operating_system=true`. Para atualizar a imagem PostgreSQL, acrescente `-e update_database_image=true`. Rode primeiro sem esses parâmetros para manter as versões atuais; registre a tag escolhida e o resultado no relatório.

As senhas são criadas pelo setup existente na VM da aplicação; os valores não aparecem no log do Ansible. Somente a senha de migração e a senha da API são transferidas à VM do banco, também com saída oculta. Não copie `.env` ou `.secrets` para o Git.

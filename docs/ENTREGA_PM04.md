# Roteiro de Entrega Final (PM-04 · Smart Construction)

> Use este documento como base para gerar o PDF único a ser anexado na Blackboard após executar a pipeline na nuvem e capturar os prints/logs reais.

## 1. Identificação
- **Disciplina:** PM-04 | DevOps e Infraestrutura
- **Integrantes:** *(preencher até 3 nomes/RAs)*
- **Repositório Git:** `https://github.com/puko02/smart-construction-DedSec`

## 2. Análise da demanda e decisões de arquitetura
- Demanda de referência: [escopo.md](escopo.md) / `escopo.pdf` (Bubikas Holdings — Smart Construction).
- Arquitetura de nuvem, justificativa da GCP, isolamento do PostgreSQL, segurança e estimativa mensal de custos (~US\$ 93,15/mês 24×7 ou ~US\$ 37,50/mês em uso acadêmico): [ARQUITETURA_NUVEM.md](ARQUITETURA_NUVEM.md).
- Infraestrutura declarada em [terraform/](../terraform), automação em [ansible/](../ansible) e pipeline em [.github/workflows/deploy.yml](../.github/workflows/deploy.yml).

## 3. Evidências obrigatórias a anexar após execução da pipeline

### Cenário 1 — Criação inicial pela pipeline
- [ ] Print/log da execução manual (`workflow_dispatch`, `action=deploy`) no GitHub Actions com os parâmetros iniciais.
- [ ] Trecho do log mostrando `terraform apply` criando VPC, subnet, firewalls, 2 VMs, discos e Artifact Registry.
- [ ] Trecho do log mostrando `build-images` publicando `web` e `api` e `ansible` instalando Docker, configurando Nginx HTTPS e iniciando todos os containers.

### Cenário 2 — Atualização parametrizada pela pipeline
- [ ] Print/log de nova execução alterando ao menos 1 parâmetro Terraform (ex.: `app_machine_type` ou `data_disk_size_gb`) e 1 parâmetro Ansible (ex.: `docker_tag`, `update_os=true` ou `extra_packages=curl,git,unzip`).
- [ ] Comprovação de atualização in-place sem recriação indevida dos discos de dados.

### Cenário 3 — Reexecução sem alterações (Idempotência)
- [ ] Print/log de execução repetida com os mesmos parâmetros mostrando `No changes` no Terraform e ausência de alterações desnecessárias no Ansible.

### Validação da demanda e critérios de aceite
- [ ] Captura da página inicial, busca e catálogo acessíveis via `https://<seu-dominio>` (cadeado TLS válido, sem assets remotos obrigatórios).
- [ ] Captura de cadastro sintético (profissional com imagem + empresa), criação do admin (`app.auth.cli`), carga das 25 profissões (`app.profissoes.cli --apply`), aprovação no `/admin` e exibição pública somente do profissional aprovado.
- [ ] Evidência de acesso negado (`401`) sem autenticação para rotas administrativas/dados privados e teste externo comprovando porta `5432` fechada na internet.
- [ ] Evidência de persistência dos dados e imagens após reinício da VM ou atualização.
- [ ] Log da pipeline executando `action=backup_and_restore_test` (`backup.yml` + `restore-test.yml`) comprovando restauração em contêiner isolado.
- [ ] Log da pipeline executando `action=destroy` (`confirm_destroy=DESTROY`) e relatório dos recursos remanescentes (apenas bucket GCS de state).

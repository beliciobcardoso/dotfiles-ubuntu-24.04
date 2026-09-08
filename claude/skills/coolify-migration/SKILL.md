---
name: coolify-migration
description: Guia completo e seguro para migrar aplicações legadas rodando direto no servidor/Docker Compose para o Coolify 100% via Terraform, com zero perda de dados, persistência em volumes, healthchecks saudáveis, backups automáticos e estrito respeito ao controle do dev sobre a infraestrutura.
---

# Migração de Aplicações para o Coolify via Terraform

Este guia padroniza o processo de migração de aplicações que rodam direto no host/Docker Compose para stacks gerenciadas pelo Coolify via Terraform (IaC).

## 🛡️ Regras de Ouro e Segurança

1. **O Dev manda na Infra**: O agente nunca para, apaga ou sobe contêineres e servidores diretamente. Toda ação no host/Docker deve ser solicitada em formato de comando pronto para o dev executar.
2. **100% Terraform**: Toda a modelagem da aplicação, compose, volumes, portas e variáveis deve ser declarada em arquivos `.tf` (`services.tf`, `variables.tf`, `servers.tf`).
3. **Zero Perda de Dados**: Nunca remova um container ou volume antigo antes de concluir o dump do banco e cópia dos arquivos persistentes.
4. **Segredos Protegidos**: Senhas e chaves privadas nunca ficam expostas no Git. Devem usar `sensitive = true` em `variables.tf` e valores salvos em `terraform.tfvars` (ignorado no `.gitignore`).

---

## 📋 Fluxo de Migração Passo a Passo

### Fase 1: Levantamento e Planejamento
1. Inspecione o `docker-compose.yml` e o `.env` antigos da aplicação:
   - Identifique imagens, portas, volumes de persistência e variáveis de banco/app.
   - Identifique em qual servidor (`servers.tf`) e projeto (`projects.tf`) a nova stack deve rodar.

### Fase 2: Modelagem no Terraform (`services.tf`)
1. Adicione o recurso `coolify_service.<nome>` em `services.tf`:
   - `project_uuid`: Apontando para o projeto correto (ex: `coolify_project.aplicativos_internos.uuid`).
   - `server_uuid`: Apontando para o servidor correto (ex: `coolify_server.srv_dev_ip_10_0_3_6.uuid`).
   - `environment_name`: `"production"`.
2. Estruture o `docker_compose_raw`:
   - **Volumes**: Use volumes nomeados do Docker (`app_data`, `db_data`) para que o Docker crie as permissões automaticamente.
   - **Porta**: Se o container antigo ainda estiver ativo, use temporariamente uma porta livre (ex: `8089`) para evitar conflito de bind.
   - **Banco de Dados**: Sempre defina `MYSQL_ROOT_PASSWORD: ${var.<app>_db_password}` (evite senhas aleatórias para permitir que os backups automáticos do Coolify funcionem).
   - **Healthcheck**: Configure `healthcheck` tanto no banco quanto na aplicação web (ex: `curl -f http://127.0.0.1:80/ || exit 1`) para garantir status `Healthy` (verde) no Coolify.
3. Declare as variáveis sensíveis em `variables.tf` com `sensitive = true` e salve os valores em `terraform.tfvars`.

### Fase 3: Criação no Coolify via Terraform
1. Execute `terraform plan` para validar a sintaxe e o plano.
2. Execute `terraform apply` para provisionar o serviço no Coolify.
3. Se necessário, solicite ao dev para iniciar/reiniciar o serviço no painel do Coolify.

### Fase 4: Migração de Dados (Dump + Restauração + Arquivos)
Solicite ao dev a execução dos comandos de migração:
1. **Dump do banco antigo** (usando `--no-tablespaces` se for MySQL 8):
   ```bash
   docker exec -i <container_db_antigo> mysqldump --no-tablespaces -u <user> -p'<senha>' <db_name> > dump.sql
   ```
2. **Restauração no novo banco do Coolify**:
   ```bash
   docker exec -i <container_db_novo> mysql -u <user> -p'<senha>' <db_name> < dump.sql
   ```
3. **Cópia dos arquivos persistentes**:
   ```bash
   sudo docker cp ./storage/. <container_app_novo>:/caminho/destino/
   sudo docker exec -it <container_app_novo> chown -R www-data:www-data /caminho/destino/
   ```

### Fase 5: Virada de Chave e Ajuste de Portas
1. Teste a aplicação na porta nova pelo navegador.
2. Quando tudo estiver 100% validado:
   - Solicite ao dev para parar e remover o container antigo (`docker rm -f <container_antigo>`).
   - Se desejar retornar à porta padrão original, ajuste a porta em `services.tf`.
   - Rode `terraform apply` para aplicar a porta final.

### Fase 6: Validação de Backups e Encerramento
1. Acesse o Coolify e teste o botão **"Backup Now"** para certificar que os backups automáticos no S3 estão operacionais.
2. Execute `terraform plan` para certificar que o estado do Terraform está 100% sincronizado (**"No changes"**).
3. Registre as alterações no `docs/TASKS.md`.

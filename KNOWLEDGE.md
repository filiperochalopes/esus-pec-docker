# e-SUS-PEC — Base de Conhecimento Operacional

## Configurações do Sistema

### Tabela principal de configuração

As configurações globais do e-SUS-PEC ficam na tabela `tb_config_sistema` do banco `esus`:

```sql
SELECT co_config_sistema, ds_config_sistema, ds_texto, ds_inteiro
FROM tb_config_sistema;
```

### Campos críticos

| chave | descrição | nota |
|-------|-----------|------|
| `LINKINSTALACAO` | Endereço URI base da instalação | Define as rotas internas; deve apontar para a URL de acesso local (ex: `http://localhost:8082`) |
| `VERSAOBANCODADOS` | Versão do banco de dados | Deve ser compatível com a versão do JAR do app |
| `TIPOINSTALACAO` | Tipo: `PRONTUARIO` ou `CENTRALIZADORA` | Define o modo de operação |
| `NOMEINSTALACAO` | Nome da instalação | Identificador textual |
| `HORUSHABILITADO` / `CADSUSHABILITADO` | Integrações com Hórus / CADSUS | Desabilitar se não usar |

### Arquivos de configuração dentro do container

- `/etc/pec.config` — JSON com metadata da instalação (criado na primeira inicialização). Usado pelo `entrypoint.sh` para verificar se o sistema já foi instalado.
- `/opt/e-SUS/webserver/config/application.properties` — Configuração Spring Boot (apenas datasource: usuário, senha, URL do banco).

## Versão do App vs Versão do Banco

O e-SUS-PEC verifica compatibilidade na inicialização (`StartupListener` → `SystemVersionService.ensureCompatibleVersions`). Se as versões não coincidirem, a aplicação falha com:

```
O PEC e o seu banco de dados não estão na mesma versão.
```

Verificar:

```sql
-- Versão do banco
SELECT ds_texto FROM tb_config_sistema WHERE co_config_sistema = 'VERSAOBANCODADOS';
```

A versão do app está embutida no JAR (ex: `pec-bundle.jar:5.4.21`).

## Como acessar o banco via docker compose

```bash
# Listar bancos
docker compose exec db psql -U postgres -c "\l"

# Listar tabelas do banco esus
docker compose exec db psql -U postgres -d esus -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;"

# Consultar configurações do sistema
docker compose exec db psql -U postgres -d esus -c "SELECT * FROM tb_config_sistema;"

# Atualizar URL base
docker compose exec db psql -U postgres -d esus -c \
  "UPDATE tb_config_sistema SET ds_texto = 'http://localhost:8082' WHERE co_config_sistema = 'LINKINSTALACAO';"

# Verificar versão do banco
docker compose exec db psql -U postgres -d esus -c \
  "SELECT ds_texto FROM tb_config_sistema WHERE co_config_sistema = 'VERSAOBANCODADOS';"

# Verificar configurações específicas
docker compose exec db psql -U postgres -d esus -c \
  "SELECT co_config_sistema, ds_texto FROM tb_config_sistema WHERE co_config_sistema IN ('LINKINSTALACAO','VERSAOBANCODADOS','TIPOINSTALACAO','NOMEINSTALACAO');"
```

## Como verificar logs do app

```bash
# Logs da aplicação
docker compose exec pec cat /opt/e-SUS/webserver/logs/pec.log

# Logs recentes
docker compose logs -f pec

# Reiniciar app após alterações de config
docker compose restart pec
```

## Fluxo de restauração de backup

1. Executar `build.sh -C -p -r <backup>` para reconstruir a imagem e restaurar o banco
2. Verificar se a versão do JAR bate com a versão no banco (`VERSAOBANCODADOS`)
3. Atualizar `LINKINSTALACAO` para a URL local
4. Reiniciar o container: `docker compose restart pec`
5. Verificar logs: `docker compose logs pec`

## Problemas comuns

- **Rotas não funcionam**: geralmente `LINKINSTALACAO` ainda aponta para a URL de produção
- **App não inicia**: version mismatch entre JAR e banco de dados
- **Erro de EntityManager**: consequência do version mismatch — o app falha na inicialização e fecha o EntityManagerFactory
- **Instalador não conecta no PostgreSQL** com `authentication type 10 is not supported`: o driver do instalador PEC pode não suportar autenticação SCRAM. Para banco local em Docker, inicializar PostgreSQL com autenticação host MD5 e `password_encryption=md5`.

## Compatibilidade com PostgreSQL

O instalador PEC pode usar driver PostgreSQL sem suporte a SCRAM-SHA-256. Em PostgreSQL moderno, isso aparece como:

```
The authentication type 10 is not supported.
```

Para bancos locais criados pelo Docker Compose, usar:

```yaml
command: ["postgres", "-c", "password_encryption=md5"]
environment:
  - POSTGRES_INITDB_ARGS=--auth-host=md5
```

Essa configuração só afeta a inicialização de um volume novo. Se o volume do PostgreSQL já foi criado com SCRAM, recriar o volume ou redefinir a senha do usuário com `password_encryption=md5`.

## JAR, latest release e instalação persistida

`build.sh` só busca o latest release quando `filename` está vazio. A origem do JAR pode ser:

- `-f <arquivo-ou-url>`
- `FILENAME` no `.env` ou `cloud/.env`
- `scripts/get-latest-pec-release.sh --url-only`, quando nenhum JAR foi informado

No modo cloud, `/opt/e-SUS` é persistido por bind mount:

```yaml
./esus-data/opt:/opt/e-SUS
```

Rebuild da imagem pode copiar um JAR novo para `/var/www/html`, mas isso não garante substituição do webserver já instalado em `/opt/e-SUS/webserver`. Quando houver mismatch, verificar:

```bash
docker compose exec db psql -U postgres -d esus -c \
  "SELECT ds_texto FROM tb_config_sistema WHERE co_config_sistema = 'VERSAOBANCODADOS';"

unzip -l cloud/esus-data/opt/webserver/pec-bundle.jar | grep 'backend-'
```

Se o webserver persistido estiver em versão antiga, preservar chaves/configurações necessárias e recriar ou limpar a instalação persistida antes de reinstalar.
"⚠️ Atenção ao atualizar para produção: o valor antigo (https://esus.dominio.com.br) pode ser restaurado quando necessário."

## Resolução de profissional CDS (CdsProfissionalServiceImpl)

O PEC resolve `tb_cds_prof` por **hash SHA1** gerado a partir de `CNS + CBO + CNES + INE` (`CdsEncrypt.generateSHA1CdsProf`). Não é lookup por INE/CNES soltos.

### Fluxo de criação
- `saveProfissional()` gera hash do CNS da lotação → tenta `loadProfissional(hash)` → se não encontra, cria novo registro em `tb_cds_prof`
- O hash é único por combinação CNS+CBO+CNES+INE

### Fluxo de exibição
- `loadUnicaLotacaoHeaderForm(co_seq_cds_prof)` carrega o header do CDS e faz join com `tb_prof_historico_cns` para recuperar CPF/CNS
- A listagem de fichas (`FichaAtendimentoIndividualRowItemPagingQuery`) usa `cdsProfissionalPrincipal` da ficha e exibe CNS, CBO, CNES e INE

### Known Issue: CNS duplicado em `tb_prof_historico_cns`
Se o mesmo CNS aparece no `tb_prof_historico_cns` de **dois profissionais diferentes**, a query de exibição retorna o primeiro encontrado (não necessariamente o correto). Sintomas:
- Atendimentos de um profissional aparecem com nome de outro na interface
- Módulo CDS Individual fica inacessível ("Funcionalidade não acessivel")

**Diagnóstico:**
```sql
-- Buscar CNS duplicados entre profissionais diferentes
SELECT ph.nu_cns, COUNT(DISTINCT ph.co_prof) AS num_perfis
FROM tb_prof_historico_cns ph
GROUP BY ph.nu_cns
HAVING COUNT(DISTINCT ph.co_prof) > 1;
```

**Correção:** Remover o registro errôneo de `tb_prof_historico_cns` (scripts em `scripts/fix-alynne-cds-prof.sql`).

## INE como identificador de equipe

O campo `nu_ine` em `tb_equipe` é o **número da equipe ESF**, não um identificador único de profissional. Múltiplos profissionais compartilham o mesmo INE quando pertencem à mesma equipe. O campo `nu_ine` em `tb_cds_prof` reflete o INE da equipe de lotação do profissional.

## Tabela `tb_prof_historico_cns`

Armazena o histórico de CNS vinculados a cada profissional (`co_prof`). Usada pela aplicação para:
- Recuperar CPF/CNS do profissional CDS na exibição de fichas
- Validar CNS durante cadastro

**Regra:** Cada CNS deve aparecer em apenas UM `co_prof`. Duplicação entre profissionais diferentes causa confusão na resolução de nome.

## Known Issues

### Conflito de Identificação por CNS em `tb_prof_historico_cns`

**Problema:**
Ocorrem inconsistências na exibição do nome do profissional e no acesso a módulos (como Ficha de Atendimento Individual) quando um mesmo número de CNS está associado a mais de um profissional na tabela `tb_prof_historico_cns`.

**Causa:**
A aplicação utiliza o CNS para resolver a identidade do profissional no banco de dados. Se um registro de identificação (como o histórico de um médico) contiver um CNS que também pertence a outro profissional, a consulta pode retornar o registro incorreto (ex: exibir o nome do médico A no prontuário da médica B).

**Solução:**
Garantir que cada CNS seja único dentro da tabela `tb_prof_historico_cns`. Caso existam registros duplicados, devem ser removidos para que a associação entre o identificador e o profissional seja única e consistente.


## Identidade do Profissional e Fluxo de Acessos

A identidade do profissional não é determinada pelo campo `TB_USUARIO.CO_ACTOR` (campo legado). A resolução de identidade e de papéis ativos segue o fluxo abaixo:

### Cadeia de Identidade
`TB_USUARIO.DS_LOGIN` $\rightarrow$ `TB_USUARIO.CO_SEQ_USUARIO` $\rightarrow$ `TB_PROF.CO_USUARIO` $\rightarrow$ `TB_PROF.CO_SEQ_PROF` $\rightarrow$ `TB_ATOR_PAPEL.CO_PROF`.

### Tipos de Acessos
O sistema distingue dois tipos principais de papéis que aparecem na interface:
1.  **LOTACAO (Acessos de Unidade/CBO):** O CBO e a Unidade de Saúde não vêm do perfil, mas sim da tabela `TB_LOTACAO`. O vínculo ocorre via `TB_LOTACAO.CO_ATOR_PAPEL = TB_ATOR_PAPEL.CO_SEQ_ATOR_PAPEL`.
2.  **PERFIL (Acessos de Permissão):** Define as permissões do profissional via `RL_ATOR_PAPEL_PERFIL`.

### Consulta de Diagnóstico de Papéis Ativos
Para listar exatamente os acessos que o usuário visualiza na interface (Unidade, CBO e Perfil):

```sql
SELECT 
    u.ds_login,
    l.co_unidade_saude,
    c.no_cbo,
    c.co_cbo_2002,
    tap.no_tipo_ator_papel,
    p.no_perfil
FROM tb_usuario u
JOIN tb_prof pr ON u.co_seq_usuario = pr.co_usuario
JOIN tb_ator_papel tap ON pr.co_seq_prof = tap.co_prof
LEFT JOIN tb_lotacao l ON tap.co_seq_ator_papel = l.co_ator_papel
LEFT JOIN rl_ator_papel_perfil rpp ON tap.co_seq_ator_papel = rpp.co_actor_papel
LEFT JOIN tb_perfil p ON rpp.co_perfil = p.co_seq_perfil
LEFT JOIN tb_cbo c ON l.co_cbo = c.co_cbo
WHERE u.ds_login = 'login_do_usuario'
  AND tap.st_ativo = 1;
Nota: Se o papel for do tipo 'LOTACAO', o CBO/Unidade não vêm do perfil, mas sim da tabela TB_LOTACAO.


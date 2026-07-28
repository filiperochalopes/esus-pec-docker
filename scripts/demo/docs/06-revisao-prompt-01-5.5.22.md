# Revisão do relatório do Prompt 01 — PEC 5.5.22

## Evidências aceitas

- PEC e `VERSAOBANCODADOS`: 5.5.22.
- Binário: `eSUS-AB-PEC-5.5.22-Linux64.jar`.
- PostgreSQL: 17.10.
- Tipo de instalação: `PRONTUARIO`, em modo de produção/atendimento.
- Foram identificados catálogos/dimensões para município, UF, tipo de unidade,
  complexidade, tipo de equipe, CBO, tipo de atendimento, conduta, serviço e
  local de atendimento.
- Não foram identificados jobs cron explícitos nos metadados apresentados.

O nome da instituição analisada não foi registrado porque é específico da
instância e irrelevante para o gerador reutilizável.

## Lacunas bloqueantes

O relatório não trouxe os valores da tabela “Códigos para Cenário Mínimo”.
Continuam faltando os códigos naturais para:

- UBS;
- complexidade de atenção básica;
- equipe de Saúde da Família;
- médico de família/comunidade;
- enfermeiro;
- atendimento finalizado;
- consulta/atendimento básico.

Também não foram entregues:

- defaults;
- constraints únicas;
- checks;
- sequences/identities;
- definição e tabela-alvo dos triggers relevantes;
- dependências exatas dos catálogos;
- evidência de quais tabelas são operacionais e quais são somente dimensões
  analíticas.

## Divergência a resolver

O relatório citou `tb_dim_municipio`, `tb_dim_uf`,
`tb_dim_tipo_atendimento` e `tb_dim_local_atendimento`. O inventário de FKs do
grafo operacional mostrou, entre outras:

```text
tb_cnes.co_localidade -> tb_localidade.co_localidade
tb_atend.st_atend -> tb_status_atend.co_status_atend
tb_atend.tp_local_atend -> tb_local_atend.co_local_atend
tb_atend_prof.st_atend_prof -> tb_status_atend_prof.co_status_atend_prof
tb_atend_prof.tp_atend -> tb_tipo_atend.co_tipo_atend
tb_atend_prof.tp_atend_prof -> tb_tipo_atend_prof.co_tipo_atend_prof
```

As dimensões podem ser necessárias para relatórios, mas não devem substituir
automaticamente os catálogos apontados pelas FKs de escrita.

## Decisão

Ainda não iniciar INSERTs nem o provisionamento SQL. Executar o Prompt 01b para
obter somente as lacunas acima. Após isso, seguir para o Prompt 02 sobre CNES,
autenticação, perfis, lotações e credenciais.

A instância analisada é apenas fonte de leitura. Nenhuma etapa do gerador,
importação CNES, provisionamento ou restauração será executada nela; essas
operações usarão uma instalação 5.5.22 nova e isolada.

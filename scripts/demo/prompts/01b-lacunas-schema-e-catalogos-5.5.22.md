# Prompt 01b — lacunas de schema e catálogos do PEC 5.5.22

Você está complementando um relatório anterior sobre uma instância PEC
5.5.22/PostgreSQL 17.10. Faça somente leitura. Não retorne dados pessoais,
clínicos, credenciais, instituição, host ou URL.

Não repita o resumo de versão. Entregue somente as duas partes abaixo. Se algo
não existir ou não puder ser confirmado, escreva `NÃO CONFIRMADO`; não deixe
células vazias.

## Parte A — constraints do grafo operacional

Para cada tabela abaixo, informe PK, sequence/identity/default da PK, demais
defaults, uniques, checks, FKs e triggers anexados:

```text
tb_localidade
tb_uf
tb_tipo_unidade_saude
tb_subtipo_unidade_saude
tb_complexidade
tb_tipo_equipe
tb_cbo
tb_status_atend
tb_status_atend_prof
tb_tipo_atend
tb_tipo_atend_prof
tb_local_atend
tb_tipo_servico
tb_cds_tipo_conduta
tb_atend
tb_atend_prof
```

Para triggers, informe: tabela, nome do trigger, evento, função chamada e se
altera outra tabela. Não basta dizer que existem triggers `audit_*`.

## Parte B — códigos técnicos preenchidos

Retorne uma tabela Markdown preenchida, usando códigos naturais, nunca apenas
IDs internos:

| Uso no demo | Tabela operacional | Coluna do código natural | Código | Descrição técnica |
| --- | --- | --- | --- | --- |
| Unidade Básica de Saúde |  |  |  |  |
| Complexidade de atenção básica |  |  |  |  |
| Equipe de Saúde da Família |  |  |  |  |
| Médico de Família e Comunidade |  |  |  |  |
| Enfermeiro |  |  |  |  |
| Atendimento finalizado |  |  |  |  |
| Consulta/atendimento básico |  |  |  |  |
| Local UBS |  |  |  |  |
| Serviço/consulta básica |  |  |  |  |
| Conduta de retorno programado |  |  |  |  |

Confirme explicitamente:

1. quais tabelas `tb_dim_*` citadas no relatório anterior são somente
   dimensões analíticas;
2. quais catálogos são realmente alvos das FKs de `tb_atend`,
   `tb_atend_prof`, `rl_atend_tipo_servico` e
   `rl_atend_prof_conduta`;
3. qual código IBGE natural resolve `tb_localidade` para a importação CNES;
4. se os códigos acima são estáveis entre instalações 5.5.22.

Encerre com no máximo cinco lacunas ainda não confirmadas. Não proponha
INSERTs.

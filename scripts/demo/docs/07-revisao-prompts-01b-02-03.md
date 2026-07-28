# Revisão dos Prompts 01b, 02 e 03

Data: 2026-07-26.

## Validação independente

As inconsistências foram conferidas somente por metadados com
`db-healthcheck.sh`, `db-schema.sh`, `db-columns.sh` e `db-fks.sh`. Nenhum
conteúdo pessoal, profissional ou clínico foi consultado.

## Prompt 01b

### Aproveitável

- `tb_atend` possui defaults `qt_referencia=0`, `st_atend=1` e
  `st_registro_tardio=0`, conforme o relatório externo.
- Foram identificados triggers de auditoria em `tb_atend`,
  `tb_atend_prof` e `tb_tipo_servico`.
- `tb_localidade.co_ibge` é o candidato a código IBGE do município.
- As dimensões `tb_dim_*` não substituem automaticamente os catálogos
  operacionais apontados pelas FKs.

### Incorreto ou insuficiente

- A coluna correta é `co_situacao_localidade`, não
  `co_situacao_location`; sua FK aponta para `tb_situacao_localidade`.
- `tp_localidade` aponta para `tb_tipo_localidade`, não para
  `tp_local_atend`.
- A tabela correta é `tb_tipo_atend_prof`. Ela possui somente
  `co_tipo_atend_prof` e `no_tipo_atend_prof`; a lista extensa de FKs
  apresentada pertence a `tb_atend_prof`.
- As listas chamadas de “checks” reproduzem principalmente nulabilidade; não
  provam constraints `CHECK`.
- Os números 1, 2, 455 e 397 foram associados a colunas de nome/descrição.
  Eles aparentam ser PKs internas, não códigos naturais.
- Os códigos naturais candidatos são `co_tipo_unidade_cnes`,
  `sg_complexidade`, `nu_ms`, `co_cbo_2002` e `no_identificador`, conforme a
  tabela. Eles ainda precisam ser preenchidos com valores confirmados.

## Prompt 02

### Confirmado pelo schema

```text
tb_usuario.co_seq_usuario
  <- tb_prof.co_usuario
       <- tb_ator_papel.co_prof
            <- tb_lotacao.co_ator_papel
```

- `tb_usuario.co_ator -> tb_ator.co_seq_ator` existe, mas é o ramo legado.
- `tb_ator_papel.co_prof -> tb_prof.co_seq_prof`.
- `tb_lotacao` não tem `co_seq_talotacao`; sua identidade é
  `co_ator_papel`.
- `tb_lotacao` referencia profissional, unidade, equipe e CBO.
- `tb_usuario` possui `st_bloqueado`, `st_termo_uso`,
  `st_forcar_troca_senha`, `nr_tentativas_acesso` e
  `st_termo_teleinterconsulta`.

### Não aceito ainda

- O diagrama via `tb_ator` não representa a identidade profissional ativa.
- Médico e enfermeiro não são apenas perfis `LOTACAO`: CBO/unidade/equipe vêm
  de `tb_lotacao`; perfis concedem permissões.
- Não foi provado que a importação CNES atribui automaticamente todos os
  perfis citados.
- Não foi provado que atualizar três flags e o hash é suficiente no 5.5.22.
- As queries globais de `IS NULL` não validam o seed e podem acusar registros
  legítimos preexistentes. A validação deve ser limitada aos identificadores
  sintéticos gerados.
- A recomendação de SQL direto permanece sem suporte até mapear subentidades
  administrativas, auditoria e pós-condições.

## Prompt 03

### Confirmado pelo schema

- `tb_cidadao` possui 85 colunas.
- São não nulos: `co_seq_cidadao`, `st_desconhece_nome_mae`,
  `co_unico_cidadao`, `co_nacionalidade` e `st_unificado`.
- `no_cidadao`, `no_cidadao_filtro`, `dt_nascimento`, `no_sexo`, CPF e CNS
  existem e são anuláveis.
- `tb_prontuario.co_cidadao -> tb_cidadao.co_seq_cidadao`; a coluna é
  anulável no banco.

### Não aceito ainda

- Nulabilidade não prova o contrato mínimo da busca.
- `tb_prontuario.co_cidadao` anulável não prova criação “sob demanda”.
- A cardinalidade 1:1 não foi provada sem uma unique constraint ou contrato
  de serviço.
- O formato UUID de `co_unico_cidadao` não foi provado pelo tipo `varchar`.
- “API REST/GraphQL” sem rota, mutation ou método concreto não é um contrato
  utilizável.
- A presença de tabelas `ta_*` não prova, sozinha, trigger ou background job.

## Decisão

Não seguir ainda para SOAP. Executar os três prompts corretivos curtos na ordem
01c, 02b e 03b. Depois disso, iniciar o scaffold Python e o gerador CNES antes
de investigar o Prompt 04.

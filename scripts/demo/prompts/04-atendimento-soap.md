# Prompt 04 — complemento de schema do atendimento SOAP 5.5.22

Este prompt substitui a versão ampla anterior. O comportamento, mutations e
comandos internos já foram investigados no codebase local e não devem ser
delegados ao agente que acessa dados sensíveis.

Faça somente inspeção dos metadados do PostgreSQL. Não leia nem amostre linhas
das tabelas. Não retorne dados pessoais, clínicos, credenciais, instituição ou
infraestrutura.

Para as tabelas abaixo, informe apenas PK, sequence/default, nulabilidade,
unique/check constraints, FKs com ações `ON UPDATE/ON DELETE` e triggers:

- `tb_atend`;
- `tb_atend_prof`;
- `tb_evolucao_subjetivo`;
- `tb_evolucao_objetivo`;
- `tb_evolucao_avaliacao`;
- `tb_evolucao_plano`;
- `tb_problema`;
- `tb_problema_evolucao`;
- `rl_evolucao_avaliacao_ciap_cid`;
- relações de conduta e serviço que referenciem `tb_atend_prof` ou
  `tb_atend`.

Confirme especificamente:

1. as duas FKs do ciclo `tb_atend <-> tb_atend_prof`;
2. se as quatro tabelas SOAP usam `co_atend_prof` como PK/FK compartilhada;
3. quais colunas NOT NULL tornam uma linha SOAP válida quando ela existe;
4. a FK de `tb_problema.co_ultimo_problema_evolucao`;
5. a FK de `tb_problema_evolucao.co_atend_prof`;
6. os nomes exatos das sequences das PKs geradas;
7. se triggers de auditoria apenas registram auditoria ou alteram outras
   tabelas — responda somente pela definição da função/trigger, sem conteúdo.

Não investigue endpoints, GraphQL, código Java, telas, fatos/dimensões por
amostra nem “um atendimento real simples”. Marque cada conclusão como
`CONFIRMADO POR METADADOS` ou `NÃO CONFIRMADO`.

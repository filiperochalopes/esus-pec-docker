# Prompt 03b — constraints físicas de cidadão e prontuário no PEC 5.5.22

O contrato de aplicação já foi investigado diretamente no codebase 5.5.22 e
está documentado em
`scripts/demo/docs/08-contrato-cidadao-prontuario-codebase-5.5.22.md`.

Investigue **somente metadados do PostgreSQL**, sem executar `SELECT` de
conteúdo. Não retorne nomes, documentos, endereços ou textos clínicos.

Para `tb_cidadao` e `tb_prontuario`, entregue:

1. PKs, sequências/identities, defaults, nulabilidade e checks.
2. Todas as unique constraints e índices únicos envolvendo:
   `nu_cpf`, `nu_cns`, `co_unico_cidadao` e
   `tb_prontuario.co_cidadao`.
3. FKs de `tb_prontuario.co_cidadao` e `co_prontuario_grupo`, incluindo ações
   `ON UPDATE`/`ON DELETE`.
4. Se a relação cidadão-prontuário é fisicamente 1:1. Considere confirmado
   apenas se houver unique constraint/índice único aplicável; o `@OneToOne`
   JPA sozinho não basta.
5. Triggers dessas duas tabelas, informando apenas nome, evento, timing e
   função executada.
6. Constraints/defaults que determinam se um cidadão fica ativo e visível em
   busca (`st_ativo`, `st_ativo_para_exibicao` e campos relacionados).

Marque cada item como `CONFIRMADO` ou `NÃO CONFIRMADO`. Não investigue regras
de serviço, FCI, SOAP nem conteúdo das tabelas.

# Prompt 02b — constraints físicas de identidade e acesso no PEC 5.5.22

O comportamento da aplicação já foi investigado diretamente no codebase
5.5.22 e está em
`scripts/demo/docs/09-identidade-acessos-credenciais-codebase-5.5.22.md`.

Investigue **somente metadados do PostgreSQL**, sem consultar conteúdo das
tabelas e sem retornar credenciais reais.

Para `tb_usuario`, `tb_prof`, `tb_ator`, `tb_ator_papel`, `tb_lotacao`,
`tb_adm_geral`, `tb_adm_municipal`, `rl_ator_papel_perfil`, `tb_perfil` e
`rl_perfil_cbo_padrao`, entregue:

1. PKs, sequências/identities, defaults, nulabilidade, checks e uniques.
2. Todas as FKs relevantes, incluindo ações `ON UPDATE`/`ON DELETE`.
3. A FK e o destino exato de `tb_usuario.co_ator`; marque se a coluna não
   possuir FK e não infira finalidade a partir do nome.
4. Confirmação física de que `tb_lotacao.co_ator_papel`,
   `tb_adm_geral.co_ator_papel` e `tb_adm_municipal.co_ator_papel` são
   simultaneamente PK e FK para `tb_ator_papel`.
5. Unique constraints que asseguram:
   - login único;
   - CPF profissional único, se existir;
   - no máximo um profissional por usuário, se existir;
   - ausência de duplicação em `(co_ator_papel, co_perfil)`.
6. Triggers dessas tabelas, retornando somente nome, timing, evento e função.
7. Colunas que funcionam como códigos naturais em `tb_perfil` e
   `rl_perfil_cbo_padrao`, sem consultar seus valores.

Marque cada afirmação como `CONFIRMADO` ou `NÃO CONFIRMADO`. Não investigue
serviços Java, importação CNES, hashes, tokens ou conteúdo das tabelas.

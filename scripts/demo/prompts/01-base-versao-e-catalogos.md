# Prompt 01 — base, versão e catálogos

Você está investigando uma instância e-SUS PEC para apoiar um gerador de base
100% sintética. Você está autorizado a consultar a instância, mas seu relatório
NÃO PODE conter qualquer dado pessoal ou clínico real.

Objetivo: entregar o contrato técnico da instalação limpa e dos catálogos
necessários para um CNES mínimo e um atendimento SOAP finalizado. O alvo é a
versão 5.5.22; o codebase 5.4.38 pode ser usado somente como referência
comportamental, nunca como substituto do schema da instância.

Regras:

- faça somente leitura;
- prefira `pg_dump --schema-only --no-owner --no-privileges` ou consultas em
  `information_schema`/`pg_catalog`;
- não copie linhas de pacientes ou profissionais;
- não inclua host, usuário, senha ou URLs privadas;
- sempre informe a versão exata do PEC e do banco;
- diferencie fatos confirmados de inferências.

Entregue:

1. Versões:
   - versão do JAR;
   - `VERSAOBANCODADOS`;
   - versão PostgreSQL;
   - modo treinamento/produção e tipo da instalação.
2. DDL relevante, incluindo colunas, tipos, nullability, defaults, PKs, uniques,
   FKs, checks, sequences e triggers, para:
   - `tb_config_sistema`;
   - catálogos de município/localidade e UF;
   - tipo/subtipo de unidade, complexidade e tipo de equipe;
   - CBO;
   - status/tipos usados por atendimento e atendimento profissional;
   - tipos de local, serviço e conduta necessários ao atendimento básico.
3. Para cada catálogo, liste apenas:
   - nome da tabela;
   - PK;
   - código natural estável;
   - descrição semântica;
   - uma ou duas opções adequadas ao cenário mínimo.
4. Confirme quais códigos, não IDs, devem ser usados para:
   - unidade básica de saúde;
   - complexidade de atenção básica;
   - equipe de Saúde da Família;
   - médico de família/comunidade;
   - enfermeiro;
   - atendimento finalizado;
   - consulta/atendimento básico.
5. Liste migrations/triggers/jobs que criam ou atualizam tabelas derivadas após
   CNES ou atendimento.

Formato do relatório:

- resumo executivo curto;
- tabela “objeto -> chave natural -> dependências”;
- DDL ou trechos de schema por tabela;
- riscos por versão;
- dúvidas restantes.

Não proponha INSERTs ainda.

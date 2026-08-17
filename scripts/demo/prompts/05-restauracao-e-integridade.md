# Prompt 05 — complemento de metadados para backup 5.5.22

O protocolo de dump/restauração e os smoke tests são responsabilidade do
projeto local e já foram auditados contra o `scripts/build.sh`. Este prompt serve
somente para fechar metadados que o codebase não prova.

Faça somente leitura de catálogos PostgreSQL e `information_schema`. Não leia
conteúdo das tabelas de negócio e não execute dump, restore, DDL ou funções.
Não reporte credenciais, hosts, URLs, instituição ou qualquer dado pessoal ou
clínico.

Entregue:

1. `SELECT extname, extversion FROM pg_extension ORDER BY extname`;
2. versão do servidor por `current_setting('server_version')`;
3. lista de tabelas `UNLOGGED` do schema da aplicação, apenas nomes;
4. para as sequences ligadas às PKs do grafo CNES, identidade, cidadão,
   prontuário, atendimento, SOAP e problema:
   - schema e nome da sequence;
   - tabela/coluna proprietária por dependência de catálogo;
   - tipo e incremento;
   - sem consultar `last_value` nem linhas das tabelas;
5. owner do banco e schemas e ACLs estruturais, sem nomes de pessoas;
6. nomes das chaves disponíveis em `tb_config_sistema` que tratem de versão,
   treinamento e integrações, apenas se esses nomes puderem ser obtidos de
   constraints/comentários/metadados. Não leia valores ou linhas.

Se o item 6 não puder ser respondido estritamente por metadados, escreva
`NÃO CONFIRMADO POR SCHEMA`; não consulte a tabela para compensar.

Não proponha endpoint, tabela ou sequence por analogia. Não use nomes
genéricos como `atendimento_soap` ou `cidadão`. Marque cada conclusão como
`CONFIRMADO POR METADADOS` ou `NÃO CONFIRMADO`.

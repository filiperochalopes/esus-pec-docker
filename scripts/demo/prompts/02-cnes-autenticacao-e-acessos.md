# Prompt 02 — CNES, autenticação e acessos

Você está investigando uma instância e-SUS PEC para apoiar um gerador de base
100% sintética. Pode consultar dados reais, mas o relatório NÃO PODE conter
qualquer valor pessoal ou credencial real.

Objetivo: mapear o grafo exato produzido por uma importação CNES mínima e como
transformar o profissional importado em um usuário demo com acessos
administrativos e assistenciais na versão 5.5.22.

Faça somente leitura e use uma importação já existente apenas como referência
estrutural. Redija valores pessoais como `<REDACTED>` e forneça somente IDs
técnicos quando forem indispensáveis para mostrar relações; prefira códigos e
nomes de perfis padrão.

Confirme DDL, constraints, sequences e relações de:

- `tb_usuario`;
- `tb_prof`;
- `tb_prof_historico_cns`;
- `tb_ator_papel` e suas subentidades;
- `tb_lotacao`;
- `tb_unidade_saude`;
- `tb_equipe`;
- `rl_ator_papel_perfil`;
- `tb_perfil`;
- tabelas de recursos/permissões vinculadas ao perfil;
- tabelas de importação/versão CNES.

Responda:

1. Quais linhas são criadas para unidade, equipe, profissional, usuário e
   lotação ao importar o CNES?
2. Quais defaults/flags ficam no usuário sem senha?
3. Como conceder, na versão investigada:
   - instalador;
   - administrador geral;
   - administrador municipal;
   - lotação assistencial;
   - perfis padrão de médico e enfermeiro?
4. “Médico” e “enfermeiro” são perfis, CBOs, recursos ou combinações?
5. Um mesmo profissional pode ter duas lotações/CBOs na mesma unidade/equipe?
   Quais constraints impedem combinações incoerentes?
6. Quais perfis são adicionados automaticamente na importação e com base em
   qual regra?
7. Quais flags precisam ser definidas para login automatizado sem bloqueio,
   redefinição obrigatória ou termo pendente?
8. A senha PBKDF2 gerada externamente é suficiente ou existe auditoria/token/
   timestamp obrigatório?
9. Quais caches, dimensões ou históricos precisam ser atualizados?
10. Confirme como provisionar todas as senhas na mesma execução e quais
    pós-condições devem passar antes de publicar `demo_credentials.txt`.

Entregue:

- diagrama textual do grafo;
- tabela com operação lógica, tabela, chave e dependências;
- valores técnicos de enum/status/perfil apenas quando não forem dados
  pessoais;
- conjunto de invariantes e queries de validação, somente SELECT;
- recomendação entre API oficial, serviço interno ou SQL direto.

Não devolva uma linha real completa de nenhuma dessas tabelas.

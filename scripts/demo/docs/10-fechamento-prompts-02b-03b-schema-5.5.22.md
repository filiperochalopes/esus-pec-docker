# Fechamento dos Prompts 02b e 03b — schema 5.5.22

Revisão dos relatórios externos de metadados, confrontados com as inspeções
anteriores de schema e com o codebase 5.5.22. Nenhum conteúdo de tabela foi
consultado nesta revisão.

## Cidadão e prontuário

### Confirmado

- `tb_cidadao.co_seq_cidadao` é PK.
- `co_unico_cidadao`, `co_nacionalidade`, `st_desconhece_nome_mae` e
  `st_unificado` são não nulos.
- Defaults relevantes:
  `st_desconhece_nome_mae=0`, `st_unificado=0`, `st_ativo=1` e
  `st_ativo_para_exibicao=1`.
- `tb_prontuario.co_seq_prontuario` é PK e `qt_referencia` tem default zero.
- `tb_prontuario.co_cidadao` referencia
  `tb_cidadao.co_seq_cidadao`, com `NO ACTION` em update/delete.
- Existe índice único sobre `tb_prontuario.co_cidadao`; a cardinalidade física
  cidadão-prontuário é 1:0..1.
- CPF, CNS e `co_unico_cidadao` não possuem unicidade física confirmada. A
  prevenção de duplicidade de CPF/CNS permanece como regra de serviço.
- `audit_tb_cidadao` e `audit_tb_prontuario` executam após
  insert/update/delete.
- Não foi encontrada FK física para `tb_prontuario.co_prontuario_grupo`.

### Implicação para o seed

O seed deve usar o fluxo oficial para obter normalização, agrupamento e
auditoria. Mesmo em eventual fallback SQL, deve validar unicidade lógica de
CPF, CNS e identificador antes de escrever. O prontuário pode ser criado sob
demanda, mas nunca mais de um por cidadão.

## Identidade, papéis e acessos

### Confirmado

- PKs:
  `tb_usuario.co_seq_usuario`, `tb_prof.co_seq_prof`,
  `tb_ator.co_seq_ator`, `tb_ator_papel.co_seq_ator_papel`,
  `tb_lotacao.co_ator_papel`, `tb_adm_geral.co_ator_papel`,
  `tb_adm_municipal.co_ator_papel`, `tb_perfil.co_seq_perfil`,
  além das PKs compostas de `rl_ator_papel_perfil` e
  `rl_perfil_cbo_padrao`.
- `tb_usuario.co_ator -> tb_ator.co_seq_ator` é o ramo legado confirmado.
- `tb_ator_papel.co_prof -> tb_prof.co_seq_prof`.
- `tb_adm_geral.co_ator_papel` e
  `tb_adm_municipal.co_ator_papel` são PK/FK compartilhadas.
- `rl_ator_papel_perfil` impede duplicação do par pela PK composta.
- Não foram confirmadas uniques físicas para login, CPF profissional ou
  `tb_prof.co_usuario`.
- Foram reportados triggers de auditoria em `tb_lotacao`,
  `tb_adm_municipal`, `rl_ator_papel_perfil` e `tb_ator_papel`.
- `tb_perfil.no_perfil_padrao` e
  `rl_perfil_cbo_padrao.no_perfil_padrao` são candidatos confirmados a código
  natural.

### Divergências reconciliadas

- O relatório recente marcou `tb_lotacao.co_ator_papel` apenas como PK. Isso
  conflita com a inspeção de FK anterior e com o mapeamento JPA
  `@PrimaryKeyJoinColumn`. Para o estudo, permanece **confirmada como PK/FK**
  para `tb_ator_papel.co_seq_ator_papel`.
- `st_termous_uso` foi reportado como nome de coluna. O nome confirmado no
  schema anterior e no modelo é `st_termo_uso`.
- O relatório recente omitiu algumas FKs da cadeia, como
  `tb_prof.co_usuario` e as referências de unidade/equipe da lotação. As
  inspeções anteriores continuam sendo a evidência adotada.

Essas divergências não justificam nova investigação ampla. Qualquer validação
automatizada futura deve conferir os nomes diretamente no schema-alvo e
abortar diante de incompatibilidade.

## Gate

Os complementos 02b e 03b estão encerrados. A próxima dependência externa é o
Prompt 01c, restrito aos valores técnicos dos códigos naturais operacionais.

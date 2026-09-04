# KNOWLEDGE.md

Base cumulativa de conhecimento reutilizável sobre o e-SUS-PEC deste repositório.

## Tipo CNES de unidade basica

- No PEC 5.5.24, UBS deve ser identificada pelo codigo natural
  `TB_TIPO_UNIDADE_SAUDE.CO_TIPO_UNIDADE_CNES = 2`.
- O XML CNES 3.1 sintetico usa a descricao canonica
  `CENTRO DE SAUDE/UNIDADE BASICA` para `TP_UNID_ID="2"`.
- Nao use `NO_TIPO_UNIDADE_SAUDE` como chave em consultas: a descricao pode
  variar entre bases e versoes, enquanto o codigo CNES 02 e o identificador
  operacional estavel.

## CDS profissional

- `CdsProfissionalServiceImpl` resolve `tb_cds_prof` por `hash`, não por busca parcial em `INE`/`CNES`.
- O hash é gerado com `CNS + CBO + CNES + INE` em `CdsEncrypt.generateSHA1CdsProf(...)`.
- `saveProfissional(...)` primeiro tenta `loadProfissional(...)`; se não houver match, persiste um novo `CdsProfissional`.
- `loadUnicaLotacaoHeaderForm(...)` carrega o header do CDS a partir do `co_seq_cds_prof` e faz join com `QProfissionalHistoricoCns` para recuperar `CPF` a partir do `CNS`.

## Ficha de atendimento individual

- A persistência da ficha individual ocorre em `FichaAtendimentoIndividualMasterFormSaveCommand`, que delega a conversão para `AtendIndividualForm2EntityConverter`.
- O conversor salva o profissional principal com `profService.saveProfissional(lotacaoFormPrincipal)` e grava o retorno em `CdsMapaAtendIndividual.cdsProfissionalPrincipal`.
- O atendimento compartilhado só é salvo quando o segundo header tem `CNS` preenchido.
- A leitura da ficha individual usa `profService.loadUnicaLotacaoHeaderForm(cdsProfissionalPrincipal.getId())`, então a exibição do cabeçalho da ficha vem do `co_seq_cds_prof` persistido na própria ficha.
- A listagem de fichas individuais faz join direto com `cdsProfissionalPrincipal` e exibe `CNS`, `CBO`, `CNES` e `INE` desse profissional.
- A transmissão CDS da ficha individual também usa `cdsProfissionalPrincipal` como fonte de `CNES` e `INE`.

## Fluxo de seleção no cabeçalho

- `BaseHeaderFichaCdsPresenterImpl` monta o cabeçalho em cascata: profissional -> CBO -> CNES -> INE.
- O combo de profissional pesquisa por `CPF/CNS` ou por nome, e restringe por município e listas de `CNS` permitidos/excluídos.
- O combo de INE usa `EquipeSelectDtoTypedComboPresenter.hasIneEqualNullInLotacao()`, que consulta `LotacaoService.hasIneEqualNullInLotacao(cbo, profissionalCNS, cnesUnidadeSaude)`.
- `LotacaoServiceImpl.loadLotacoesByProfissionalIne(...)` e `loadUnidadeSaudeIdByProfissionalIdAndIne(...)` filtram por `lotacao.profissional.id + equipe.ine`; não fazem lookup de `tb_cds_prof`.
- `LotacaoServiceImpl.hasIneEqualNullInLotacao(...)` aceita filtros opcionais de `CBO`, `CNS` e `CNES` e só verifica se a lotação tem `equipe.id is null`.

## Listagem e consulta

- A listagem de atendimentos individuais (`FichaAtendimentoIndividualRowItemPagingQuery`) usa o `cdsProfissionalPrincipal` da ficha e filtra por `CNS`, `CBO`, `CNES` e `INE` desse profissional.
- O `ORDER BY` da listagem é por `status`, `data`, `CNES` e `INE`; não há ordenação descendente por `co_seq_cds_prof`.

## Lista de atendimentos do PEC

- A rota de lista de atendimentos usa `AtendimentoPagingQuery` e sempre restringe os resultados à unidade de saúde do acesso selecionado na sessão.
- O período (`dataInicio`/`dataFim`) filtra `Atendimento.dataHorarioEncaminhamento`, isto é, a entrada/encaminhamento na lista, e não a data de finalização do atendimento profissional.
- O filtro `responsaveisIds` recebe IDs de `AtorPapel`/`Lotacao`, não IDs de `Profissional` nem CNS. Ele encontra tanto o responsável direto de `Atendimento` quanto lotações responsáveis em atendimento em observação.
- Fora do fluxo de observação, o filtro de responsável compara `Atendimento.responsavel`; ele não procura genericamente a lotação de todo `AtendimentoProfissional` finalizado. Portanto, quem executou/finalizou o atendimento pode ser diferente do responsável pelo encaminhamento usado na Lista de atendimentos.
- O seletor de responsáveis usa `LotacoesAndEstagiosQuery`: pesquisa diretamente o CNS/nome atual de `Profissional`, retorna cada lotação como um item distinto e, quando `ativo=true`, exclui acessos inativos. Ele não consulta o histórico de CNS.
- Ao criar atendimento sem agendamento, `AtendimentoSave` grava a lotação informada em `Atendimento.responsavel`; com agendamento, grava `Agendado.lotacaoAgendada`. Assim, duas lotações do mesmo profissional são identidades distintas para o filtro de responsável.
- A listagem é paginada e a ordenação pode ser crescente ou decrescente por `dataHorarioEncaminhamento`; um corte aparente em uma data intermediária pode ser apenas o limite da página quando a ordem é crescente.
- `AtendimentoPagingQuery` não consulta `ProfissionalHistoricoCns`. Alterações isoladas em `tb_prof_historico_cns` não reatribuem nem removem atendimentos da lista do PEC.

## Autenticação de usuários

- O login é processado pelo Spring Security no endpoint `/api/login` e também pela mutation GraphQL `login`, que delega a autenticação para `HttpServletRequest.login(usuario, senha)`.
- O usuário é localizado pelo campo `login`; antes da comparação da senha, são validados bloqueio da conta e, quando habilitado, bloqueio por unificação de bases.
- As senhas são armazenadas como hash PBKDF2-HMAC-SHA-256, com salt aleatório de 24 bytes, 64.000 iterações e saída de 32 bytes. O formato persistido é `sha256:iteracoes:tamanho:saltBase64:hashBase64`.
- O hash é persistido na coluna `DS_SENHA` da tabela `TB_USUARIO` (usuário em `DS_LOGIN`). Não há chave secreta global: o salt aleatório usado pelo PBKDF2 é armazenado no próprio valor de `DS_SENHA`.
- A verificação recalcula o PBKDF2 com o salt e as iterações gravados e compara o resultado em tempo constante; hashes legados identificados como `sha1` continuam verificáveis por compatibilidade.
- Falhas de autenticação incrementam o contador de tentativas e bloqueiam a conta ao atingir o limite configurado; um login bem-sucedido zera o contador.

## Seleção de acesso após o login

- O seletor pós-login é alimentado pelo campo GraphQL `sessao.profissional.acessos`, sem paginação nem `LIMIT`.
- A identidade profissional do login não é resolvida por `TB_USUARIO.CO_ATOR`. O modelo `Usuario` desta versão não mapeia essa coluna; `ProfissionalByLoginQuery` faz `TB_USUARIO.DS_LOGIN -> TB_USUARIO.CO_SEQ_USUARIO -> TB_PROF.CO_USUARIO`, e o `CO_SEQ_PROF` encontrado é gravado no principal da sessão.
- `ProfissionalResolver.acessos(...)` delega a `AcessosByProfissionalQuery`, que busca `AtorPapel` por `owner/profissional` e, por padrão, exige `TB_ATOR_PAPEL.ST_ATIVO = 1` (`mostrarInativos` inicia como `false`).
- A relação principal é `TB_ATOR_PAPEL.CO_PROF -> TB_PROFISSIONAL`. `TL_ATOR_PAPEL` não participa desse fluxo no código da versão analisada.
- Para um acesso do tipo `LOTACAO`, o texto do cartão vem da subentidade `TB_LOTACAO`, ligada a `TB_ATOR_PAPEL` pelo mesmo identificador (`TB_LOTACAO.CO_ATOR_PAPEL = TB_ATOR_PAPEL.CO_SEQ_ATOR_PAPEL`). A unidade vem de `TB_LOTACAO.CO_UNIDADE_SAUDE` e o CBO vem de `TB_LOTACAO.CO_CBO -> TB_CBO`.
- A tela mostra `unidadeSaude.nome` e `cbo.nome - cbo.cbo2002`; ela não deriva o CBO de `RL_PERFIL_CBO_PADRAO` nem do nome de um perfil.
- `RL_ATOR_PAPEL_PERFIL` associa perfis ao acesso. Ao selecionar um acesso, os recursos/autorizações são calculados apenas a partir de perfis ativos, mas o CBO exibido continua sendo o CBO da lotação.
- A mutation `selecionarAcesso` valida que o identificador pertence ao profissional e está ativo, carrega seus recursos e grava o acesso escolhido no principal da sessão. Se existir somente um acesso ativo, o backend pode selecioná-lo automaticamente.
- O `profissionalId` fica armazenado no principal da sessão. Mudanças posteriores em `TB_PROF.CO_USUARIO` não alteram uma sessão já autenticada; é necessário encerrá-la e autenticar novamente.
- A mutation GraphQL `login` não autentica novamente quando a requisição já possui uma autenticação não anônima; nesse caso, retorna sucesso e preserva o principal anterior. Isso pode fazer credenciais digitadas parecerem associadas ao usuário de uma sessão preexistente.
- O login Gov.br também usa `ProfissionalByLoginQuery`, passando o CPF (`subject`) como login; ele não possui uma rota alternativa de herança de acessos por unificação, CNS histórico ou perfil.

## Território: validação do responsável pelo imóvel

- O imóvel (`TB_CDS_DOMICILIO`) guarda no próprio registro o cabeçalho da responsabilidade da última ficha: `NU_CNES`, `NU_INE`, `NU_CNS` e `NU_CBO_2002`. Não há FK direta do imóvel para uma lotação.
- Ao editar/salvar um imóvel, o PEC reconstrói a lotação pelo conjunto exato CNS + CNES + CBO 2002 + INE. O CNS é comparado com `TB_PROF_HISTORICO_CNS`, e não diretamente com o CNS atual de `TB_PROF`.
- Quando `NU_INE` está preenchido, a lotação precisa apontar para uma equipe com o mesmo INE; quando está nulo, a lotação precisa estar sem equipe.
- A validação de lotação ativa exige simultaneamente acesso/lotação ativo em `TB_ATOR_PAPEL`, unidade ativa em `TB_UNIDADE_SAUDE` e, quando houver INE, equipe ativa em `TB_EQUIPE`.
- O município do endereço da unidade encontrada também precisa ser igual à localidade do usuário informada ao validador.
- Na query GraphQL `isLotacaoActive`, `userLocalidadeId` chega como campo do input enviado pelo cliente; o resolver apenas verifica o acesso ao recurso e não substitui esse valor pela localidade do principal autenticado. Para diagnosticar divergência de município nessa consulta, é necessário conferir a variável efetivamente enviada na requisição, não apenas `TB_CDS_DOMICILIO.CO_MUNICIPIO`.
- A mensagem "O responsável informado possui uma lotação inativa" é genérica: ela também ocorre quando não existe correspondência exata para algum item do cabeçalho, quando falta o CNS em `TB_PROF_HISTORICO_CNS` ou quando o município não coincide. Portanto, a mensagem isolada não prova que apenas `ST_ATIVO` esteja falso.

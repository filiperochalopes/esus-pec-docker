# Contrato de cidadão e prontuário no codebase 5.5.22

Investigação estática do JAR 5.5.22 decompilado. Nenhum conteúdo do banco foi
lido. Como o CFR não preserva perfeitamente nomes de propriedades Kotlin, as
constraints físicas continuam sendo autoridade para unicidade e cardinalidade.

## Fluxo oficial de criação

1. A mutation GraphQL `CidadaoMutationResolver.salvarCidadao(CidadaoInput, ...)`
   verifica o recurso de cadastro, executa `CidadaoInputValidator.validate(...)`
   e chama `CidadaoFciService.salvarCidadao(...)`.
2. `CidadaoFciService` usa
   `CidadaoConverter.convertToCadastroIndividualThriftDto(...)`, persiste uma
   FCI por `CadastroIndividualIntegrationEsusService.saveCadastroIndividual`
   e recupera o cidadão processado pelo UUID da última ficha.
3. Depois do processamento, o serviço salva informações não processadas,
   atualiza o grupo do cidadão, executa efeitos de óbito/agenda quando
   aplicáveis e grava auditoria por `CidadaoFciAuditor`.

Portanto, o fluxo oficial não equivale a inserir somente `tb_cidadao`.

## Validações confirmadas

- CPF e CNS, quando informados, passam por validadores próprios.
- CPF é obrigatório, salvo quando `stNaoPossuiCpf` é verdadeiro; nessa
  alternativa, CPF deve ficar vazio e a justificativa é obrigatória e
  pertencente ao catálogo aceito.
- CPF e CNS são rejeitados como já cadastrados por consultas do
  `CidadaoGrupoService`. Isso prova regra de negócio, mas não prova unique
  constraint física.
- Nome é obrigatório, tem regra de nome com mínimo de três caracteres e máximo
  de 70.
- Data de nascimento é obrigatória, deve ser válida e não futura.
- Sexo é obrigatório e deve pertencer ao grupo de valores aceitos.
- Raça/cor e nacionalidade também são obrigatórias.
- Nome da mãe é obrigatório, válido e entre 5 e 70 caracteres, exceto quando
  `desconheceNomeMae=true`; nesse caso deve ficar vazio.
- O mesmo padrão condicional existe para o nome do pai.
- Brasileira exige Brasil como país de nascimento e, salvo exceções indígenas,
  município de nascimento. Naturalizada exige portaria e data de
  naturalização. Estrangeira exige país e data de entrada, com datas coerentes
  com o nascimento e não futuras.
- Na edição, CPF/CNS recebidos do CADSUS possuem restrições adicionais e não é
  permitido alterar ambos simultaneamente quando ambos já existiam.

## Identificadores e normalização

- O UUID da FCI é gerado por
  `CidadaoConverter.generateUuidCadastroIndividual(cnes)` no formato
  `<CNES>-<UUID.randomUUID()>`. Sem vínculo territorial, o prefixo CNES pode
  ser vazio, produzindo `-<uuid>`.
- O código inspecionado associa esse identificador ao ciclo
  `uuid/uuidFichaOriginadora/uuidUltimaFicha`. A atribuição final de
  `tb_cidadao.co_unico_cidadao` ocorre no processador da FCI e não ficou
  diretamente demonstrada no método de mutation.
- `Cidadao.setNome`, `setNomeSocial` e `setNomeTradicional` recalculam
  `nomeFiltro`: removem acentos, convertem para minúsculas e concatenam nome
  social, tradicional e civil disponíveis.
- `Cidadao.setNomeMae` aplica `trim`, minúsculas e remoção de acentos em
  `nomeMaeFiltro`.
- O e-mail é convertido para minúsculas no `CidadaoConverter`.

## Prontuário

`ProntuarioService.loadOrCreateProntuarioByIdCidadao` consulta primeiro e chama
`ProntuarioCreate.execute` somente se não encontrar prontuário. A criação é,
portanto, sob demanda, não parte da mutation de cidadão.

`ProntuarioCreate`:

1. bloqueia o cidadão para escrita;
2. persiste `Prontuario` ligado ao cidadão e marcado como processado;
3. aponta `prontuarioGrupo` para o próprio prontuário;
4. persiste `ProntuarioGrupoHistorico` com o grupo inicial e data de
   unificação.

O mapeamento JPA declara `Prontuario.cidadao` como `@OneToOne`, mas não declara
`unique=true` no `@JoinColumn`. A prova física da cardinalidade precisa vir de
índice/constraint do PostgreSQL.

## Busca mínima

`CidadaosQuery` sempre exige `ativoParaExibicao=true`. O campo livre aceita,
individualmente:

- nome por `nomeFiltro`;
- data exata no formato `dd/MM/yyyy`;
- CPF;
- CNS.

Logo, não é necessário combinar nome e nascimento para aparecer na busca. Para
um seed previsível, basta um cidadão processado e ativo para exibição com nome
válido; CPF válido e único é a chave de teste mais determinística.

## Ordem e recomendação

Ordem funcional confirmada:

1. validar `CidadaoInput`;
2. gerar e persistir a FCI;
3. deixar o processador materializar cidadão, vínculos e derivados;
4. salvar dados complementares e auditoria;
5. criar prontuário e seu histórico sob demanda;
6. criar atendimentos somente depois.

Para o gerador demo, prefira o serviço/mutation oficial ou uma chamada interna
equivalente. SQL direto só deve ser considerado após mapear todas as tabelas
materializadas pelo processamento e validar as constraints físicas; hoje ele
tem risco concreto de omitir FCI, agrupamento, auditoria e histórico.

## Lacunas exclusivamente de schema

- uniques/checks/índices reais de CPF, CNS e `co_unico_cidadao`;
- unique constraint que sustenta `tb_prontuario.co_cidadao`;
- nulabilidade e defaults finais dos campos necessários ao estado
  `ativoParaExibicao`.

Essas lacunas foram isoladas no Prompt 03b revisado.

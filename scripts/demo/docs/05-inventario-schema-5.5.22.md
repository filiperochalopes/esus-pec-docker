# Inventário de schema do PEC 5.5.22

Data da inspeção: 2026-07-25.

Este inventário foi obtido da instância 5.5.22 em execução. O codebase 5.4.38
permanece apenas como referência comportamental temporária para importação,
senha e serviços; não é a origem deste inventário de schema.

## Escopo e método

Este inventário foi produzido exclusivamente com os scripts autorizados:

```text
./scripts/db-healthcheck.sh
./scripts/db-schema.sh
./scripts/db-columns.sh
./scripts/db-fks.sh
```

Foram lidos apenas metadados: nomes de tabelas e colunas, tipos, nulabilidade e
chaves estrangeiras. Nenhum `SELECT` de conteúdo foi executado e nenhum valor
de paciente, profissional, usuário ou atendimento foi acessado.

Os scripts atuais não mostram todos os defaults, checks, índices e constraints
únicas. Portanto, este documento delimita o grafo relacional confirmado, mas
não é ainda uma especificação suficiente para escrever um overlay SQL.

## 1. CNES, unidade, equipe e lotação

### Cadeia confirmada

```text
tb_cnes -> tb_localidade <- tb_importacao_cnes

tb_tipo_unidade_saude
  +<- tb_subtipo_unidade_saude
  +<- tb_unidade_saude <- tb_equipe <- tb_lotacao

tb_subtipo_unidade_saude
  <- tb_unidade_saude

tb_usuario
  <- tb_prof
       <- tb_ator_papel
            <- tb_lotacao
```

### Tabelas e campos estruturais

| Tabela | Identidade e campos centrais |
| --- | --- |
| `tb_cnes` | `co_seq_cnes`, `nu_versao`, `co_localidade` são não nulos |
| `tb_importacao_cnes` | `co_seq_importacao_cnes`; referências a processo, profissional e localidade; estatísticas e detalhes da importação |
| `tb_tipo_unidade_saude` | `co_seq_tipo_unidade_saude`, `co_tipo_unidade_cnes`, nome |
| `tb_subtipo_unidade_saude` | `co_seq_subtp_unidade_saude`, `co_tp_unidade_saude`, descrição |
| `tb_unidade_saude` | `co_seq_unidade_saude`; CNES, CNPJ, nome, situação, tipo/subtipo, localidade e endereço |
| `tb_tipo_equipe` | `co_seq_tipo_equipe`, código MS `nu_ms`, nome e sigla |
| `tb_equipe` | `co_seq_equipe`, `co_unidade_saude`, tipo, INE, área, nome e situação |
| `tb_prof` | `co_seq_prof`; CPF, CNS, nome, nascimento, sexo e `co_usuario` |
| `tb_prof_historico_cns` | `co_seq_prof_historico_cns`, `co_prof`, `nu_cns` |
| `tb_ator_papel` | `co_seq_ator_papel`, tipo de papel, `co_prof`, situação |
| `tb_lotacao` | `co_ator_papel`, `co_prof`, `co_unidade_saude`, `co_cbo`, equipe opcional, flags de importação/perfil e código único |

### Relações que afetam o gerador

- `tb_cnes.co_localidade -> tb_localidade.co_localidade`.
- `tb_subtipo_unidade_saude.co_tp_unidade_saude ->
  tb_tipo_unidade_saude.co_seq_tipo_unidade_saude`.
- `tb_equipe.co_unidade_saude ->
  tb_unidade_saude.co_seq_unidade_saude`.
- `tb_equipe.tp_equipe -> tb_tipo_equipe.co_seq_tipo_equipe`.
- `tb_prof.co_usuario -> tb_usuario.co_seq_usuario`.
- `tb_prof_historico_cns.co_prof -> tb_prof.co_seq_prof`.
- `tb_ator_papel.co_prof -> tb_prof.co_seq_prof`.
- `tb_lotacao.co_ator_papel ->
  tb_ator_papel.co_seq_ator_papel`.
- `tb_lotacao.co_prof -> tb_prof.co_seq_prof`.
- `tb_lotacao.co_unidade_saude ->
  tb_unidade_saude.co_seq_unidade_saude`.
- `tb_lotacao.co_equipe -> tb_equipe.co_seq_equipe`.
- `tb_lotacao.co_cbo -> tb_cbo.co_cbo`.

`tb_lotacao` não possui uma sequência própria: o campo
`co_ator_papel` é a identidade compartilhada com `tb_ator_papel`. Além disso,
`rl_unidade_saude_complexidade.co_ator_papel` referencia
`tb_unidade_saude.co_seq_unidade_saude`; o nome da coluna não revela sozinho
essa semântica e não deve ser usado para inferir o alvo.

## 2. Usuário, perfis e recursos

```text
tb_usuario -> tb_prof -> tb_ator_papel
                            |
                            +-> tb_lotacao
                            |
                            +-> rl_ator_papel_perfil -> tb_perfil
                                                         |
                                                         +-> tb_perfil_recurso
```

- `tb_usuario` contém login, hash de senha, bloqueio, tentativas de acesso,
  troca obrigatória de senha e flags de termos.
- `rl_ator_papel_perfil` liga `co_ator_papel` a `co_perfil`.
- `tb_perfil` contém nome, nome de perfil padrão, tipo, localidade e situação.
- `tb_perfil_recurso` liga o perfil aos nomes de recursos.
- `rl_perfil_cbo_padrao` referencia `tb_cbo`, mas armazena nomes de perfis
  padrão em colunas textuais; ela não é uma ligação direta a `tb_perfil`.

Conclusão: CBO/unidade pertencem à lotação; permissões pertencem ao vínculo de
papel com perfil. Um “usuário com todos os acessos” exige os dois e não pode ser
modelado apenas adicionando perfis.

## 3. Cidadão e prontuário

### Relação principal

```text
tb_cidadao
  <- tb_prontuario
       <- tb_atend
```

- `tb_cidadao` possui 85 colunas. No schema, somente
  `co_seq_cidadao`, `st_desconhece_nome_mae`, `co_unico_cidadao`,
  `co_nacionalidade` e `st_unificado` são não nulos.
- CPF, CNS, nome, sexo, nascimento, filiação, situação e endereço aparecem
  como campos de negócio, ainda que muitos sejam anuláveis no banco.
- `tb_prontuario.co_cidadao -> tb_cidadao.co_seq_cidadao`.
- `tb_atend.co_prontuario -> tb_prontuario.co_seq_prontuario`.
- `tb_cidadao_vinculacao_equipe.co_cidadao ->
  tb_cidadao.co_seq_cidadao`.

A baixa quantidade de colunas `NOT NULL` em `tb_cidadao` não prova que um
registro mínimo será aceito ou exibido corretamente. As validações da camada de
serviço e as regras de busca precisam ser respeitadas.

Catálogos referenciados por `tb_cidadao` incluem localidade, UF, país,
nacionalidade, raça/cor, escolaridade, etnia, estado civil, CBO e tipos de
endereço/logradouro. IDs internos desses catálogos não foram lidos.

## 4. Atendimento e SOAP

### Grafo mínimo confirmado

```text
tb_cidadao
  -> tb_prontuario
      -> tb_atend
          <-> tb_atend_prof
                +-> tb_evolucao_subjetivo
                +-> tb_evolucao_objetivo
                +-> tb_evolucao_avaliacao
                +-> tb_evolucao_plano
                +-> tb_medicao
                +-> tb_problema_evolucao
```

`tb_atend` tem como campos não nulos:

- `co_seq_atend`;
- `dt_inicio`;
- `st_atend`;
- `co_prontuario`;
- `co_unidade_saude`;
- `st_registro_tardio`;
- `dt_ultima_alteracao_status`.

Suas FKs centrais ligam prontuário, unidade, equipe, responsável,
classificação de risco, status, local e, opcionalmente,
`co_atend_prof -> tb_atend_prof.co_seq_atend_prof`.

`tb_atend_prof` tem como campos não nulos:

- `co_seq_atend_prof`;
- `co_atend`;
- `tp_atend_prof`;
- `st_atend_prof`.

Suas FKs centrais ligam atendimento, lotação, status e tipos de atendimento.
O schema permite lotação nula, mas isso não demonstra que um atendimento
assistencial válido possa dispensá-la.

### Chaves compartilhadas do SOAP

Cada uma das quatro tabelas abaixo usa `co_atend_prof` como identidade e FK
para `tb_atend_prof.co_seq_atend_prof`:

- `tb_evolucao_subjetivo`;
- `tb_evolucao_objetivo`;
- `tb_evolucao_avaliacao`;
- `tb_evolucao_plano`.

Isso forma extensões 1:1 do atendimento profissional, e não registros com
sequências independentes.

### Ciclo de persistência

Há duas FKs em sentidos opostos:

```text
tb_atend.co_atend_prof -> tb_atend_prof.co_seq_atend_prof
tb_atend_prof.co_atend -> tb_atend.co_seq_atend
```

Como `tb_atend.co_atend_prof` é anulável, um fallback SQL pode criar
`tb_atend`, criar `tb_atend_prof` e atualizar a referência reversa. Essa ordem
ainda precisa ser validada contra defaults, checks e comportamento da
aplicação.

### Problemas, medições e relações

- `tb_problema.co_prontuario -> tb_prontuario.co_seq_prontuario`.
- `tb_problema` pode referenciar CIAP, CID-10 e CID-11.
- `tb_problema.co_ultimo_problema_evolucao ->
  tb_problema_evolucao.co_seq_problema_evolucao`.
- `tb_problema_evolucao.co_atend_prof ->
  tb_atend_prof.co_seq_atend_prof`.
- `tb_problema_evolucao.co_situacao_problema ->
  tb_situacao_problema.co_situacao_problema`.
- `tb_medicao.co_atend_prof ->
  tb_atend_prof.co_seq_atend_prof`.
- `rl_atend_prof_conduta` liga o atendimento profissional a
  `tb_cds_tipo_conduta`.
- `rl_atend_tipo_servico` liga o atendimento a `tb_tipo_servico`.

## 5. Implicações para a implementação

1. A instalação limpa da mesma versão continua sendo a base obrigatória; o
   gerador não deve tentar recriar catálogos.
2. IDs internos precisam ser resolvidos por códigos naturais/identificadores
   estáveis no ambiente-alvo.
3. Importar o CNES pelo PEC é preferível a inserir diretamente unidade,
   equipe, profissional e lotação.
4. A criação de cidadão e atendimento deve preferir serviços da aplicação,
   porque nulabilidade do banco não representa o contrato de negócio.
5. Se SQL direto for inevitável, ele deve ser transacional, versionado e
   restaurado/testado em banco descartável.
6. A primeira implementação deve falhar fechada quando a versão, os catálogos
   ou o grafo esperado divergirem.

## 6. Lacunas para o agente autorizado

Sem retornar conteúdo sensível, ainda é necessário informar:

- constraints únicas, checks e defaults das tabelas do grafo mínimo;
- identificadores naturais usados para resolver status, tipos e catálogos;
- tabelas derivadas que a camada de serviço atualiza;
- fluxo mínimo observado para um cidadão e um atendimento SOAP finalizado;
- efeito do fluxo nos módulos de histórico, problema ativo e relatórios.

Essas respostas devem ser agregadas por estrutura/comportamento. CPF, CNS,
nomes, endereços e textos clínicos reais não devem aparecer no relatório.

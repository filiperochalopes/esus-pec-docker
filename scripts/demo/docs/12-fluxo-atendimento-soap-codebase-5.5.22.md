# Fluxo de atendimento SOAP no codebase 5.5.22

Data da revisão: 2026-07-26.

Este relatório substitui as inferências de comportamento do Prompt 04 por
evidência do codebase local 5.5.22. Constraints físicas ainda devem ser
validadas por metadados do PostgreSQL quando o gerador chegar à etapa de
persistência.

## Fluxo oficial confirmado

O fluxo assistencial não é um único `INSERT`:

1. a mutation `salvarAtendimento` cria a entrada na lista;
2. `AtendimentoSave.execute` associa cidadão/prontuário, unidade, equipe e
   serviços, usa local UBS, inicia com status aguardando e gera UUID;
3. `realizarAtendimentoIndividual` chama o fluxo de atendimento;
4. `AtendimentoProfissionalSave` cria `tb_atend_prof`, associa a lotação e
   altera o atendimento para em atendimento;
5. `salvarAtendimentoIndividual` valida o input e executa
   `AtendimentoIndividualSave`;
6. o comando salva os componentes presentes, finaliza o profissional,
   finaliza o atendimento, persiste condutas e publica os eventos do fluxo.

O ciclo relacional é real:

```text
tb_atend.co_atend_prof -> tb_atend_prof.co_seq_atend_prof
tb_atend_prof.co_atend -> tb_atend.co_seq_atend
```

Por isso um overlay SQL exigiria inserção em etapas e atualização posterior
da referência reversa. O serviço oficial já realiza essa coordenação.

## Valores técnicos confirmados

| Estado | Valor 5.5.22 |
| --- | --- |
| aguardando atendimento | `tb_atend.st_atend = 1` |
| em atendimento | `tb_atend.st_atend = 3` |
| atendimento realizado | `tb_atend.st_atend = 4` |
| profissional em atendimento | `tb_atend_prof.st_atend_prof = 1` |
| profissional finalizado | `tb_atend_prof.st_atend_prof = 2` |
| consulta profissional | `tb_atend_prof.tp_atend_prof = 1` |
| problema ativo | `co_situacao_problema = 0` |
| problema latente | `co_situacao_problema = 1` |
| problema resolvido | `co_situacao_problema = 2` |

O profissional finalizado recebe também data/hora de fim. O atendimento
realizado recebe a data da última alteração de status.

## SOAP: chave compartilhada e opcionalidade

As entidades mapeiam as seguintes tabelas com `CO_ATEND_PROF` como PK/FK
compartilhada (`@MapsId`):

- `TB_EVOLUCAO_SUBJETIVO`;
- `TB_EVOLUCAO_OBJETIVO`;
- `TB_EVOLUCAO_AVALIACAO`;
- `TB_EVOLUCAO_PLANO`.

O relatório externo errou ao classificar as quatro linhas como
obrigatórias. No comando 5.5.22:

- subjetivo, avaliação e plano são salvos apenas quando o bloco existe;
- objetivo é encaminhado ao serviço mesmo quando seu input é nulo, para que o
  serviço decida o que materializar;
- a finalização é necessária e depois é acessada para condutas e desfecho.

Para o demo, a decisão continua sendo gerar S/O/A/P completos. Isso serve à
riqueza do cenário e aos testes de interface, não a uma constraint inexistente.

## Problemas e condições

`TB_PROBLEMA` pertence ao prontuário e mantém referência à última evolução.
`TB_PROBLEMA_EVOLUCAO` liga a evolução ao atendimento profissional, guarda a
situação e usa identificador único de evolução. Criar somente
`TB_PROBLEMA` não reproduz o ciclo de vida exibido pela aplicação.

Os vínculos de CIAP/CID da avaliação ficam em
`RL_EVOLUCAO_AVALIACAO_CIAP_CID`. Problemas/condições e avaliação são
coordenados pelo `ProblemasCondicoesService` e pelo `AvaliacaoService`.

## Decisão de persistência

O caminho principal será a API GraphQL autenticada do próprio PEC:

```text
salvarAtendimento
  -> realizarAtendimentoIndividual
  -> salvarAtendimentoIndividual
```

Os nomes acima são mutations confirmadas no resolver 5.5.22. O payload e o
fluxo de autenticação ainda serão capturados em uma instalação sintética.
Não se assume a existência de `/api/v1/auth/login`.

SQL direto fica restrito a:

- provisionamento técnico previamente provado;
- correções determinísticas em uma base exclusivamente sintética;
- eventual fallback com validação completa de constraints, auditoria,
  sequences e pós-condições.

## O que permanece em aberto

- constraints e triggers exatos das tabelas SOAP/problema no PostgreSQL;
- quais fatos/dimensões são materializados após um atendimento criado pelo
  fluxo oficial e em qual momento;
- payload GraphQL mínimo aceito pela versão 5.5.22;
- smoke test de histórico e lista de problemas após restauração.

Essas lacunas serão fechadas primeiro em uma instalação sintética. Nenhum
texto clínico real é necessário para isso.

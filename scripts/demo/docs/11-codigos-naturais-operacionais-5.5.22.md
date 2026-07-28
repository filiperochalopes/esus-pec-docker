# Códigos naturais operacionais — PEC 5.5.22

Data da revisão: 2026-07-26.

Este documento reconcilia o resultado do Prompt 01c com o codebase local
extraído do JAR 5.5.22. Nenhuma linha de conteúdo clínico ou pessoal foi
consultada.

## Resultado aceito

| Uso | Resolução na versão 5.5.22 |
| --- | --- |
| UBS | `tb_tipo_unidade_saude.co_tipo_unidade_cnes = 2` |
| Atenção Básica | `tb_complexidade.sg_complexidade = 'AB'` |
| Equipe Saúde da Família | `tb_tipo_equipe.nu_ms = '01'` |
| Médico de Família e Comunidade | `tb_cbo.co_cbo_2002 = '225130'` |
| Enfermeiro | `tb_cbo.co_cbo_2002 = '223505'` |
| Atendimento realizado | `tb_status_atend.no_identificador = 'ATENDIMENTO_REALIZADO'` |
| Consulta programada | `tb_tipo_atend.no_identificador = 'CONSULTA_AGENDADA_PROGRAMADA_CUIDADO_CONTINUADO'` |
| Retorno programado | `tb_cds_tipo_conduta.no_identificador = 'RETORNO_PARA_CONSULTA_AGENDADA'` |

Os CBOs `225130` e `223505` e o identificador
`ATENDIMENTO_REALIZADO` também aparecem no codebase local 5.5.22.

## Registros sem código natural

O relatório não encontrou código natural para:

- atendimento profissional finalizado em `tb_status_atend_prof`;
- atendimento individual em `tb_tipo_atend_prof`;
- local UBS em `tb_local_atend`;
- serviço de consulta em `tb_tipo_servico`.

Esses registros não devem ser localizados por nome livre nem ter sua PK
presumida por um gerador SQL genérico. A ordem de preferência é:

1. usar o serviço/mutation oficial, que resolve os catálogos;
2. quando a aplicação 5.5.22 fixa o valor em enum, validar o par enum/PK no
   preflight da mesma versão;
3. para serviço configurável, resolver por uma combinação única confirmada no
   ambiente sintético;
4. abortar se a consulta retornar zero ou mais de uma linha.

No fluxo oficial 5.5.22, o codebase usa:

- `StatusAtendimentoProfissionalDbEnum.ATENDIMENTO_FINALIZADO = 2`;
- `TipoAtendimentoProfissionalEnum.CONSULTA = 1`;
- local de atendimento UBS com ID `1` durante a criação do atendimento.

Esses números são contratos observados da versão 5.5.22, não códigos nacionais.

## Ressalva de estabilidade

CNES, CBO e códigos de tipo de equipe derivam de catálogos nacionais. Isso não
torna todo o conjunto da tabela imutável nem prova estabilidade futura dos
identificadores internos do PEC. Os identificadores textuais e IDs de enums
da aplicação devem ser tratados como presos à versão `5.5.22` e revalidados
sempre que o JAR ou o banco mudar.

## Consequência para a fábrica

O manifesto registrará a versão e o fingerprint dos catálogos resolvidos. O
gerador nunca continuará silenciosamente quando um código esperado estiver
ausente, duplicado ou apontar para descrição incompatível.

# Prompt 01c — códigos naturais operacionais do PEC 5.5.22

Faça somente leitura. Não retorne dados pessoais, clínicos, credenciais,
instituição ou infraestrutura. Não repita DDL.

O relatório anterior confundiu PKs internas com códigos naturais. Preencha a
tabela abaixo usando a coluna indicada. Não substitua a coluna por uma coluna
de nome. Se não houver código natural estável, escreva `SEM CÓDIGO NATURAL` e
explique como resolver o registro sem hardcode de PK.

| Uso | Tabela | Coluna obrigatória | Valor técnico | Descrição |
| --- | --- | --- | --- | --- |
| UBS | `tb_tipo_unidade_saude` | `co_tipo_unidade_cnes` |  |  |
| Atenção Básica | `tb_complexidade` | `sg_complexidade` |  |  |
| Equipe Saúde da Família | `tb_tipo_equipe` | `nu_ms` |  |  |
| Médico de Família e Comunidade | `tb_cbo` | `co_cbo_2002` |  |  |
| Enfermeiro | `tb_cbo` | `co_cbo_2002` |  |  |
| Atendimento finalizado | `tb_status_atend` | `no_identificador` |  |  |
| Atendimento profissional finalizado | `tb_status_atend_prof` | código natural ou `SEM CÓDIGO NATURAL` |  |  |
| Consulta programada | `tb_tipo_atend` | `no_identificador` |  |  |
| Atendimento individual | `tb_tipo_atend_prof` | código natural ou `SEM CÓDIGO NATURAL` |  |  |
| Local UBS | `tb_local_atend` | código natural ou `SEM CÓDIGO NATURAL` |  |  |
| Retorno programado | `tb_cds_tipo_conduta` | `no_identificador` |  |  |
| Serviço de consulta | `tb_tipo_servico` | unique natural ou `SEM CÓDIGO NATURAL` |  |  |

Para cada linha, informe também a PK correspondente apenas como evidência,
marcada explicitamente como `PK INTERNA`. Confirme se o código natural é
estável entre instalações 5.5.22. Não proponha INSERTs.

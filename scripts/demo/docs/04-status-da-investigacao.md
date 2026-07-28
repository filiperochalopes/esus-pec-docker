# Status da investigação

Data: 2026-07-26.

## Confirmado

- O alvo atual do gerador é o PEC 5.5.22, cujo JAR está presente no pacote
  local.
- A instância inspecionada confirmou PEC/banco 5.5.22, PostgreSQL 17.10 e tipo
  de instalação `PRONTUARIO`.
- Essa instância está em modo de produção/atendimento e permanece somente como
  referência de leitura. A fábrica será executada em uma instalação 5.5.22
  nova, isolada e preferencialmente de treinamento.
- O codebase local foi regenerado a partir do JAR 5.5.22.
- O instalador suporta modo treinamento e restauração de backup.
- A versão do JAR e `VERSAOBANCODADOS` precisam coincidir.
- A documentação oficial orienta importar XML/CNES no wizard municipal.
- O modo treinamento mantém funcionalidades e impede envio ao Siaps.
- O backend 5.4.38 aceita CNES XSD 2.1, 3.0 e 3.1.
- O XML fornecido valida contra o XSD 3.1 embarcado.
- A importação CNES executa validações de schema e de negócio.
- Profissional novo recebe usuário com CPF como login.
- O usuário criado pelo CNES começa sem senha.
- O formato atual de senha é PBKDF2-HMAC-SHA-256 com salt de 24 bytes,
  64.000 iterações e 32 bytes de saída.
- Acesso assistencial depende da cadeia usuário, profissional, ator/papel,
  lotação, unidade, CBO e perfis.
- As quatro tabelas SOAP usam `CO_ATEND_PROF` como chave compartilhada quando
  a respectiva linha existe.
- As quatro linhas SOAP não são todas obrigatórias pelo comando. Para o demo,
  S/O/A/P completos são uma decisão de cobertura funcional.
- O healthcheck da instância em execução passou para o banco `esus`; a
  inspeção subsequente foi limitada a metadados de schema.
- Foram confirmadas colunas e chaves estrangeiras dos núcleos CNES/acesso,
  cidadão/prontuário e atendimento/SOAP da versão 5.5.22.
- `tb_lotacao.co_ator_papel` referencia `tb_ator_papel.co_seq_ator_papel` e é
  a chave usada por `tb_atend_prof.co_lotacao`.
- `tb_atend` e `tb_atend_prof` formam um ciclo referencial.
- `tb_prontuario.co_cidadao` liga o cidadão ao prontuário, e
  `tb_atend.co_prontuario` liga o atendimento ao prontuário.
- Um índice único em `tb_prontuario.co_cidadao` confirma no máximo um
  prontuário por cidadão.
- CPF, CNS e `co_unico_cidadao` não têm unique constraint física confirmada;
  a deduplicação de CPF/CNS pertence ao serviço.
- `tb_usuario.co_ator -> tb_ator.co_seq_ator` foi confirmado como ramo legado.
- `tb_adm_geral` e `tb_adm_municipal` usam PK/FK compartilhada com
  `tb_ator_papel`.
- `Faker` e `validate-docbr` requerem Python 3.10 ou superior nas versões
  atuais avaliadas.
- As credenciais de todos os profissionais sintéticos serão geradas e
  provisionadas no mesmo processo e publicadas localmente em
  `demo_credentials.txt`.
- Os códigos naturais do Prompt 01c foram reconciliados com o codebase 5.5.22.
- O fluxo oficial confirmado usa as mutations `salvarAtendimento`,
  `realizarAtendimentoIndividual` e `salvarAtendimentoIndividual`.
- Atendimento realizado usa status `4`, profissional finalizado `2`, consulta
  profissional `1` e problema ativo `0` na versão 5.5.22.
- O `build.sh -r` restaura archive custom apenas em banco local, recria o
  banco e chama `pg_restore -1 --no-owner --no-acl`.
- O scaffold Python e o gerador CNES 3.1 estão implementados.
- A seed inicial produz duas UBS, duas equipes, três profissionais e quatro
  lotações, incluindo um profissional com duas lotações e dois CBOs.
- A suíte inicial possui 16 testes e valida o XML contra
  `cnes/cnes_3.1.xsd` do backend 5.5.22.

## Limites desta inspeção

Por solicitação, nenhum conteúdo das tabelas foi consultado. Os scripts
permitidos confirmaram tabelas, colunas, nulabilidade, tipos e chaves
estrangeiras. Ainda não foram confirmados:

- PKs correspondentes a alguns códigos naturais do Prompt 01c;
- vínculo exato entre os catálogos operacionais e as dimensões `tb_dim_*`
  citadas no primeiro relatório externo;
- tabelas derivadas obrigatórias para histórico e relatórios;
- round trip de restauração.

## Questões em aberto

1. O artefato principal deve ser treinamento, production-like isolado, ou
   ambos?
2. O usuário de teste precisa realmente ter vários CBOs ou somente vários
   perfis/acessos?
3. Quais telas e automações precisam funcionar no MVP?
4. Os atendimentos devem alimentar apenas o prontuário ou também fatos e
   relatórios gerenciais?
5. É aceitável criar os cenários pela API e exportar o dump, ou há exigência de
   gerar um overlay SQL sem executar o PEC?

## Próximo gate

Os prompts 01c, 02b e 03b estão encerrados. O 01c foi reconciliado em
[`11-codigos-naturais-operacionais-5.5.22.md`](11-codigos-naturais-operacionais-5.5.22.md);
02b e 03b foram reconciliados em
[`10-fechamento-prompts-02b-03b-schema-5.5.22.md`](10-fechamento-prompts-02b-03b-schema-5.5.22.md).
O contrato de identidade e credenciais já foi confirmado em
[`09-identidade-acessos-credenciais-codebase-5.5.22.md`](09-identidade-acessos-credenciais-codebase-5.5.22.md).
O contrato de aplicação já foi confirmado em
[`08-contrato-cidadao-prontuario-codebase-5.5.22.md`](08-contrato-cidadao-prontuario-codebase-5.5.22.md).
O fluxo SOAP e a restauração foram auditados localmente em
[`12-fluxo-atendimento-soap-codebase-5.5.22.md`](12-fluxo-atendimento-soap-codebase-5.5.22.md)
e
[`13-backup-restauracao-e-integridade-local-5.5.22.md`](13-backup-restauracao-e-integridade-local-5.5.22.md).

O próximo trabalho é importar o ZIP em uma instalação 5.5.22 sintética,
acompanhar o processamento e provisionar/validar credenciais e perfis. Os
prompts 04 e 05 são complementos opcionais somente de schema, a executar
apenas se uma lacuna concreta bloquear a implementação. A triagem anterior está em
[`07-revisao-prompts-01b-02-03.md`](07-revisao-prompts-01b-02-03.md).

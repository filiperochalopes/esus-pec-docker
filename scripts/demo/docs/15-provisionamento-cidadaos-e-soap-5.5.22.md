# Provisionamento de cidadãos e SOAP no PEC 5.5.22

Data: 2026-07-27.

## Resultado validado

A seed `5522` foi executada contra uma instalação isolada do PEC 5.5.22 após
a importação oficial do CNES sintético:

- 10 cidadãos de demonstração em faixas representativas do ciclo de vida;
- 10 atendimentos médicos finalizados;
- 10 atendimentos de enfermagem finalizados;
- 2 UBS e 2 equipes distintas;
- médico de família e comunidade, CBO `225130`;
- enfermeiro, CBO `223505`;
- CIAP A98, vacinação em dia e retorno para cuidado continuado;
- textos S/O/A/P individualizados por cenário demográfico;
- procedimento automático adequado ao CBO selecionado.

A interface do histórico longitudinal confirmou a exibição dos quatro blocos
SOAP, CIAP, procedimento, conduta, profissional, CNES e INE.

O backup canônico contém também um atendimento médico sintético adicional no
primeiro cidadão. Ele foi criado para capturar e validar o contrato oficial da
mutation antes da automação e foi preservado como evidência de comparação.
Assim, o gerador controla 20 encontros pelo manifesto e a base entregue exibe
21 registros clínicos no total.

## Estratégia de persistência

Não há `INSERT` direto nas tabelas clínicas. O cliente Python replica o
contrato de operações do cliente web:

1. autenticar e selecionar uma lotação;
2. resolver o cidadão sintético pelo CPF;
3. executar `SalvarAtendimento`;
4. executar `Atender`;
5. resolver CIAP e procedimento automático no contexto da lotação;
6. executar `SalvarAtendimentoIndividual` com finalização.

Esse caminho deixa o PEC aplicar validações, auditoria, ciclo de atendimento e
processamentos próprios da aplicação.

## Payload clínico mínimo reproduzido

Cada encontro contém:

- `subjetivo.texto`, `objetivo.texto`, `avaliacao.texto` e `plano.texto` em
  HTML simples;
- `objetivo.medicoes.vacinacaoEmDia = true`;
- `avaliacao.problemasCondicoesAvaliadas` com o identificador interno da CIAP
  A98 resolvido em tempo de execução;
- procedimento administrativo automático resolvido pela lotação;
- `tipoAtendimento = CONSULTA_NO_DIA`;
- `condutas = [RETORNO_PARA_CUIDADO_CONTINUADO_PROGRAMADO]`;
- participação presencial;
- cidadão removido da lista após a finalização.

Os códigos SIGTAP observados no PEC 5.5.22 são:

- médico: `0301010064`;
- enfermagem: `0301010030`.

O gerador não fixa os IDs internos desses catálogos. Ele consulta a aplicação
depois de selecionar a lotação correta e falha se o contrato esperado não for
resolvido.

## Diversificação da coorte

Os dez arquétipos cobrem lactente, criança, adolescente, adulto jovem,
gestante, puérpera, adulto com risco cardiovascular, trabalhador, pessoa
idosa e pessoa muito idosa. A idade é derivada da data de referência da seed.

Cada arquétipo recebe um encontro médico e um de enfermagem. Os textos
incluem um marcador `DEMO-SOAP-...` para facilitar auditoria visual sem
depender de identificadores internos do banco.

## Idempotência e recuperação

O cadastro de cidadãos consulta o CPF antes de criar. O provisionamento
clínico usa `output/clinical_manifest.json`, gravado de forma atômica após
cada atendimento concluído. Ao repetir a execução:

- cidadãos existentes são validados e reutilizados;
- atendimentos já registrados no manifesto não são duplicados;
- uma interrupção retoma do primeiro encontro ainda ausente.

O manifesto contém somente identificadores sintéticos e IDs técnicos da
instalação. Ele não contém senhas.

## Limite conhecido

O manifesto é a chave de idempotência dos atendimentos. Excluí-lo e executar
novamente cria novos atendimentos legítimos para a mesma coorte. Portanto ele
deve acompanhar o ciclo de geração até a exportação do backup.

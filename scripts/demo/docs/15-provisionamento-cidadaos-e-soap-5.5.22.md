# Provisionamento de cidadãos e SOAP no PEC 5.5.22

Data: 2026-07-27.

## Resultado validado

A seed `5522` foi executada contra uma instalação isolada do PEC 5.5.22 após
a importação oficial do CNES sintético:

- 10 cidadãos de demonstração em faixas representativas do ciclo de vida;
- 60 atendimentos finalizados, com 2 a 10 registros por cidadão;
- 2 UBS e 2 equipes distintas;
- médico de família e comunidade, CBO `225130`;
- enfermeiro, CBO `223505`;
- CIAP A98, sequências clínicas de CID-10, lista longitudinal de problemas,
  vacinação em dia e retorno para cuidado continuado;
- antropometria e sinais vitais plausíveis por faixa etária, incluindo
  cenários de sobrepeso e obesidade, com preenchimento completo, parcial ou
  ausente conforme a consulta;
- prescrições estruturadas em parte das consultas e medicamentos de uso
  contínuo nos cenários de hipertensão e diabetes;
- textos S/O/A/P individualizados por cenário demográfico;
- procedimento automático adequado ao CBO selecionado.

A interface do histórico longitudinal confirmou a exibição dos quatro blocos
SOAP, CIAP, procedimento, conduta, profissional, CNES e INE.

O manifesto clínico desta coorte é a versão 4. Manifestações anteriores não
devem ser reaproveitadas, pois misturariam coortes com regras clínicas
diferentes. O backup deve ser regenerado a partir da base factory limpa.

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
- `objetivo.medicoes` alternando registros completos, parciais e ausentes;
- `avaliacao.problemasCondicoesAvaliadas` com CIAP A98 e, nas consultas
  médicas, CID-10 resolvido em tempo de execução;
- avaliações médicas selecionadas incluídas na lista longitudinal de
  problemas/condições em situação ativa;
- evolução de problemas agudos previamente registrados para `RESOLVIDO`,
  usando o mesmo `problemaId`, sem criar duplicatas;
- `plano.prescricaoMedicamento` em consultas selecionadas, resolvendo
  medicamento, via e unidade no catálogo do PEC;
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

Cada arquétipo recebe entre 2 e 10 encontros, alternando médico e enfermagem.
Os textos incluem um marcador `DEMO-SOAP-...` para facilitar auditoria visual
sem depender de identificadores internos do banco.

Cada paciente possui uma trajetória clínica própria. Condições crônicas, como
hipertensão, diabetes, obesidade, asma, fragilidade e osteoporose, permanecem
ativas. Episódios agudos, como infecção respiratória, tontura e queixas
musculoesqueléticas, podem ser encerrados em consultas posteriores.
Cada paciente conserva ao menos uma condição longitudinal em aberto; algumas
representam problemas persistentes e outras reproduzem o encerramento
imperfeito observado em prontuários reais.

A codificação é deliberadamente incompleta para representar o uso real do
prontuário:

- algumas consultas médicas têm CID-10 apenas na avaliação, sem inclusão na
  lista de problemas;
- outras incluem o CID-10 como problema longitudinal;
- atendimentos de enfermagem usam CIAP por restrição do perfil padrão;
- existem encontros sem novo CID-10, embora o texto SOAP e as medições estejam
  preenchidos.

Os atendimentos são criados em ordem cronológica por paciente. Antes de
encerrar uma condição, o gerador consulta o problema ativo pelo prontuário e
pelo CID-10 e reutiliza seu identificador na evolução `RESOLVIDO`.

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

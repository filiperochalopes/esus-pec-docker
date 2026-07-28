# Contrato do XML CNES

## Evidências usadas

- [manual oficial do PEC, capítulo de instalação](https://sisaps.saude.gov.br/sistemas/esusaps/docs/manual/PEC/PEC_02_instalacao/),
  consultado em 2026-07-25;
- arquivo `XmlParaESUS31_150030.zip`, inspecionado somente de forma agregada;
- XSD `cnes/cnes_3.1.xsd` embarcado no `backend-5.4.38.jar`, usado como
  referência temporária para o alvo 5.5.22;
- classes descompiladas do módulo
  `br.ufsc.bridge.pec.backend.module.cnes`.

O arquivo fornecido validou integralmente contra o XSD 3.1 embarcado. Nenhum
valor pessoal do arquivo foi transcrito para este estudo.

## Estrutura mínima

```text
ImportarXMLCNES
└── IDENTIFICACAO
    ├── ESTABELECIMENTOS
    │   └── DADOS_GERAIS_ESTABELECIMENTOS *
    │       ├── ENDERECO / DADOS_ENDERECO
    │       ├── COMPLEXIDADE / DADOS_COMPLEXIDADE +
    │       └── EQUIPES / DADOS_EQUIPES *
    └── PROFISSIONAIS
        └── DADOS_PROFISSIONAIS *
            ├── ENDERECO / DADOS_ENDERECO ?
            └── LOTACOES / DADOS_LOTACOES *
```

## Identificação

Para XSD 3.1:

- `DATA`: data ISO;
- `ORIGEM`: valor fixo `PORTAL`;
- `DESTINO`: valor fixo `ESUS_AB`;
- `CO_IBGE_MUN`: sete dígitos;
- `VERSAO_XSD`: valor fixo `3.1`.

O código 5.4.38 aceita as versões 2.1, 3.0 e 3.1. Antes de processar, escolhe o
XSD embarcado correspondente e valida o documento inteiro. O gerador para
5.5.22 deverá extrair e usar o XSD do próprio JAR 5.5.22, mesmo que o contrato
seja idêntico, evitando assumir compatibilidade apenas pela versão anterior.

## Unidade

Campos obrigatórios de negócio, além do XSD:

- nome fantasia;
- CNPJ válido;
- CNES de sete dígitos;
- tipo e descrição da unidade;
- ao menos uma complexidade reconhecida;
- endereço completo no mesmo município do arquivo.

O tipo de unidade e a complexidade precisam existir nos catálogos da base. O
primeiro gerador deve consultar os catálogos da versão-alvo e usar uma unidade
de APS conhecida, em vez de presumir IDs.

## Equipe

Campos centrais:

- tipo de equipe;
- sigla, nome e descrição;
- INE de dez dígitos;
- área;
- data de desativação vazia para equipe ativa.

O tipo precisa ser compatível com o catálogo. Vínculos entre equipes são
opcionais e devem ficar fora da primeira versão.

## Profissional

Campos essenciais:

- nome sintético marcado como demo;
- CPF válido;
- CNS válido;
- nascimento e sexo coerentes;
- lotação em CNES existente;
- CBO existente e elegível;
- INE vazio ou pertencente à mesma combinação unidade/equipe.

Conselho profissional, endereço, telefone e e-mail são opcionais no XSD e
podem ser omitidos na primeira versão, salvo se o CBO ou algum fluxo do PEC
exigir o conselho.

## Comportamento do importador

O módulo:

1. aceita `.xml` ou `.zip`;
2. exige exatamente um XML dentro do ZIP;
3. valida o XSD;
4. confirma que o município do XML é o município selecionado;
5. impede regressão da versão CNES já importada;
6. desativa unidades, equipes e lotações anteriores do município;
7. persiste unidades/equipes antes de profissionais/lotações;
8. cria usuário para profissional novo usando o CPF como login;
9. cria lotação ativa e marcada como importada;
10. atualiza históricos, dimensões e estruturas derivadas.

Esse comportamento é a principal razão para importar o XML pela aplicação, em
vez de reproduzir diretamente todos os `INSERTs` do CNES.

## Perfil agregado do exemplo fornecido

O arquivo analisado contém 38 unidades, 20 pares unidade/equipe, 312
profissionais e 342 lotações. Todos os CPFs, CNSs e CNPJs passaram nos
respectivos dígitos verificadores; todas as lotações resolveram CNES e, quando
presente, o par CNES/INE. Esses números servem apenas para validar o inspetor;
o arquivo real não deve virar template de dados.

# Arquitetura proposta

## Decisão principal

Separar a fábrica em sete fases reproduzíveis:

```text
instalador oficial
  -> base limpa e versionada
  -> importação CNES sintética pelo PEC
  -> provisionamento de acessos e senha
  -> cenários sintéticos via serviços/API do PEC
  -> dump completo + restauração + smoke tests
```

O Python será o orquestrador. Um único comando deve gerar identificadores e
fixtures, importar/provisionar profissionais, configurar senhas e perfis,
criar os cenários, validar os logins e empacotar os artefatos. SQL será um
produto intermediário ou uma camada de overlay, não a fonte de verdade do
schema.

## Dependências Python selecionadas

Versões avaliadas em 2026-07-25: `Faker==40.36.0` e
`validate-docbr==2.0.0`, ambas para Python 3.10 ou superior.

- `Faker`, com locale `pt_BR`, produzirá nomes, datas e campos demográficos.
  A instância deve usar `seed_instance(seed)` e a versão deve ficar presa ao
  patch: a própria documentação alerta que os datasets podem mudar entre
  versões patch, alterando a saída para a mesma seed.
- `validate-docbr` produzirá e validará CPF, CNS e CNPJ. O pacote expõe
  `generate`, `generate_list`, `validate` e `validate_list` para esses
  documentos.
- CNES e INE continuarão em um módulo próprio, porque `validate-docbr` não os
  cobre e o PEC aplica regras de negócio adicionais.

Determinismo não deve depender apenas da seed das bibliotecas. O manifesto
final guardará os identificadores gerados, e a validação de documentos será
reexecutada antes de emitir qualquer XML, SQL ou backup.

## Fase 0 — contrato da versão

Entradas:

- versão exata do JAR, inicialmente 5.5.22;
- checksum do JAR;
- modo treinamento ou variante isolada;
- seed determinística;
- município do catálogo da instalação limpa.

Preflight obrigatório:

- comparar a versão esperada com `VERSAOBANCODADOS`;
- confirmar schema, sequences, constraints e catálogos esperados;
- comparar o fingerprint do ambiente-alvo com o inventário 5.5.22 e abortar
  diante de divergência relevante;
- recusar execução em host/banco não marcado como demo.

## Fase 1 — base limpa

Usar o instalador oficial para criar schema, migrações e catálogos. A fábrica
não deve manter DDL paralelo.

Guardar um snapshot intermediário “clean”, criado sem dados reais, para tornar
as execuções mais rápidas.

## Fase 2 — CNES sintético

Gerar:

- CNPJs com dígito válido;
- dois CNES de sete dígitos;
- dois INEs de dez dígitos;
- pelo menos três profissionais com CPF e CNS válidos;
- duas unidades e duas equipes marcadas como demo;
- pelo menos quatro lotações com CBOs selecionados por código natural;
- ao menos um profissional com duas lotações, para exercitar seleção e troca
  de acesso.

Validar localmente contra o XSD embarcado e depois importar pelo endpoint/UI
oficial do PEC. Aguardar a conclusão assíncrona e reprovar qualquer detalhe de
importação.

## Fase 3 — autenticação e acessos

O CNES cria a cadeia básica:

`usuario -> profissional -> ator_papel/lotacao -> unidade/CBO`

Ainda será necessário confirmar:

- como conceder administrador geral/municipal/instalador;
- quais perfis padrão devem ser vinculados à lotação;
- quais flags do usuário permitem login automatizado sem wizard inesperado;
- se um único profissional pode portar todos os acessos desejados sem
  inconsistência semântica.

O seed deve resolver perfis por nome/código estável e nunca por ID presumido.
O schema confirmou que `tb_lotacao.co_ator_papel` é também a identidade da
lotação, herdada de `tb_ator_papel`; não há um ID independente de lotação.

Na mesma execução, após a importação CNES:

1. localizar cada usuário criado pelo CPF sintético;
2. gerar a senha demo;
3. gravar o hash no formato esperado pelo PEC;
4. conceder papéis, perfis e lotações;
5. validar o login e a seleção de acesso;
6. escrever `demo_credentials.txt` com CPF, senha e acessos.

Se qualquer profissional falhar, o arquivo de credenciais não deve ser
publicado como completo.

## Fase 4 — dez cenários clínicos

Coorte inicial:

1. lactente em puericultura;
2. criança pequena com episódio respiratório e retorno;
3. escolar com asma;
4. adolescente em cuidado preventivo e episódio agudo resolvido;
5. adulto jovem em cuidado preventivo;
6. adulto em acompanhamento de saúde da mulher ou outro cenário equivalente
   suportado pelo MVP;
7. adulto com hipertensão e obesidade;
8. adulto com diabetes e dislipidemia;
9. pessoa idosa com multimorbidade;
10. pessoa muito idosa com fragilidade e cuidado compartilhado.

Cada cenário deve ter pelo menos três atendimentos em datas distintas, com
média-alvo de cinco e variação de três a oito conforme a complexidade. A base
deverá totalizar aproximadamente 45 a 55 atendimentos distribuídos por cerca
de 18 meses. Deve haver alternância coerente entre profissionais, unidades,
equipes e lotações, incluindo retornos, cuidado compartilhado e condições
ativas e resolvidas.

Os textos serão escritos como fixtures clínicas deliberadamente sintéticas;
Faker será usado para dados demográficos, não para inventar condutas clínicas
livres.

Preferência de persistência:

1. serviço/GraphQL/REST oficial do PEC;
2. automação de UI apenas quando não houver contrato estável;
3. SQL direto somente após provar o grafo mínimo e as atualizações derivadas.

Se o fallback SQL for necessário, haverá pelo menos um vínculo em duas etapas:
`tb_atend.co_atend_prof` aponta para `tb_atend_prof`, enquanto
`tb_atend_prof.co_atend` aponta de volta para `tb_atend`. A estratégia terá de
criar o atendimento, criar o atendimento profissional e só então preencher a
referência reversa, dentro de transação.

## Fase 5 — exportação

Artefatos:

- `pec-demo-<versao>.backup`: formato custom, preferido para restauração;
- `pec-demo-<versao>.sql.gz`: opcional, para inspeção e ambientes que exigem
  SQL;
- `manifest.json`: versão, seed, checksums e resumo, sem senha;
- `demo_credentials.txt`: CPF/login, senha, perfis e lotações de cada
  profissional; gerado localmente e ignorado pelo Git;
- `validation.json`: resultados dos testes.

O dump completo deve vir exclusivamente da base sintética criada a partir da
instalação limpa.

Formato humano sugerido:

```text
PEC DEMO — NÃO USAR EM PRODUÇÃO
versao=5.5.22

[profissional_01]
nome=PROFISSIONAL MÉDICO DEMO
cpf_login=<CPF sintético>
senha=<senha demo>
perfis=<perfis concedidos>
lotacoes=<unidade/equipe/CBO>
```

## Fase 6 — validação

Restaurar em banco novo e confirmar:

- startup sem erro de versão;
- login com a credencial demo;
- seleção de todos os acessos esperados;
- unidade, equipe, CBO e perfis visíveis;
- dez cidadãos localizáveis;
- histórico e SOAP completos;
- problemas ativos coerentes;
- zero referências órfãs nas tabelas incluídas;
- integrações externas desabilitadas;
- nenhum marcador ou identificador proveniente do arquivo CNES real.

## Forma do futuro pacote Python

```text
scripts/demo/
├── pyproject.toml
├── src/pec_demo/
│   ├── cli.py
│   ├── identifiers.py
│   ├── cnes.py
│   ├── pec_client.py
│   ├── provisioning.py
│   ├── scenarios.py
│   ├── export.py
│   └── validate.py
├── scenarios/
├── tests/
├── demo_credentials.txt   # saída local, ignorada pelo Git
└── tools/
```

Não criar essa implementação completa antes de fechar os relatórios dos
prompts de investigação.

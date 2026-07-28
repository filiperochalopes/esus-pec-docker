# Escopo e segurança

## Escopo funcional inicial

A primeira versão da fábrica deve criar uma instalação pequena, porém útil:

- um município já existente no catálogo da base limpa;
- duas unidades de saúde;
- duas equipes;
- pelo menos três profissionais sintéticos;
- pelo menos quatro lotações, com um profissional portando duas delas;
- acessos administrativos e assistenciais necessários aos testes;
- pelo menos dez cidadãos sintéticos em faixas etárias representativas;
- pelo menos três atendimentos SOAP longitudinais por cidadão, com média-alvo
  de cinco;
- problemas/condições suficientes para testar histórico, resumo e chat;
- uma credencial conhecida para cada profissional sintético;
- `demo_credentials.txt` com os logins, senhas, perfis e lotações gerados.

Agenda, vacinação, odontologia, pré-natal, exames, prescrições e relatórios
gerenciais ficam fora do primeiro corte, salvo quando forem dependências
obrigatórias do fluxo mínimo.

## Regras invioláveis

1. A base de origem deve ser criada por uma instalação nova do PEC. Nunca usar
   um backup real como template, mesmo que se pretenda apagar os pacientes.
2. Nenhum nome, CPF, CNS, endereço, telefone, e-mail ou texto clínico real pode
   ser copiado para fixtures, logs, relatórios ou commits.
3. CPF, CNS e CNPJ com dígito verificador válido não são garantia de número
   desocupado. Eles só podem existir em ambiente isolado de demonstração.
4. A saída recomendada deve usar o instalador em modo treinamento, pois a
   documentação oficial afirma que esse modo impede o envio ao Siaps.
5. Uma variante “production-like” só poderá existir com bloqueio de saída de
   rede e integrações externas desligadas, além de uma confirmação explícita.
6. Todo nome visível deve carregar uma marca inequívoca, como `DEMO` ou
   `SINTÉTICO`.
7. Não desabilitar constraints, triggers ou integridade referencial para fazer
   a carga “passar”.
8. Não usar IDs fixos de catálogos. Resolver referências por códigos naturais
   estáveis e abortar quando houver zero ou mais de um resultado.
9. O seed deve começar validando a versão exata do banco.
10. A restauração só é considerada pronta após smoke tests de aplicação.

## Riscos conhecidos

- O schema e os catálogos mudam entre versões do PEC.
- O CNES válido no XSD ainda pode falhar nas validações de negócio.
- Criar somente as tabelas SOAP pode omitir dimensões, auditoria, fatos,
  históricos ou caches atualizados pelos serviços da aplicação.
- Um dump SQL completo é portável apenas dentro da versão de banco suportada
  pelo JAR correspondente.
- Uma única pessoa com ocupações incompatíveis pode facilitar testes técnicos,
  mas produzir um cenário clinicamente incoerente. Perfis de permissão e CBOs
  devem ser tratados como conceitos diferentes.

## Política de credenciais demo

As credenciais fazem parte do produto da fábrica e devem ser criadas no mesmo
processo que provisiona os profissionais. Para cada profissional, o arquivo
`scripts/demo/demo_credentials.txt` deve expor:

- nome sintético;
- CPF usado como login;
- senha em texto claro;
- papéis/perfis concedidos;
- unidade, equipe, CBO e lotações disponíveis.

O arquivo deve começar com uma marca inequívoca de uso exclusivo em
demonstração, ser reescrito atomicamente a cada geração e receber permissão
local `0600`. Ele fica ignorado pelo Git, mas não é tratado como segredo dentro
do ambiente demo.

As senhas podem ser derivadas deterministicamente de uma sub-seed de
credenciais para que a mesma seed produza os mesmos logins. Elas nunca devem
ser reutilizadas fora do laboratório. O hash precisa reproduzir o formato do
PEC:

`sha256:64000:32:<salt-base64>:<hash-base64>`

O código analisado usa PBKDF2-HMAC-SHA-256, salt de 24 bytes, 64.000 iterações
e saída de 32 bytes. O CPF importado pelo CNES vira o login do profissional,
mas o usuário inicialmente pode ser criado sem senha; a mesma execução da
fábrica deverá provisioná-la, controlar os flags de primeiro acesso, validar o
login e somente então publicar `demo_credentials.txt`.

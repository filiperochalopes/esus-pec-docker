# Prompts para investigação autorizada

Execute um prompt por vez no agente que pode acessar a instância. A divisão
reduz o volume de contexto e permite revisar cada grafo antes do próximo.

O alvo atual, o schema inspecionado e o codebase local são do PEC 5.5.22.

Ordem:

1. `01-base-versao-e-catalogos.md` — executado;
2. `01b-lacunas-schema-e-catalogos-5.5.22.md` — executado com lacunas;
3. `02-cnes-autenticacao-e-acessos.md` — executado com inconsistências;
4. `03-cidadao-e-prontuario.md` — executado com inferências não provadas;
5. `01c-codigos-naturais-5.5.22.md` — executado e revisado;
6. `02b-identidade-acessos-credenciais.md` — executado e revisado;
7. `03b-contrato-cidadao-prontuario.md` — executado e revisado;
8. `04-atendimento-soap.md` — substituído por complemento opcional, somente
   metadados de schema;
9. `05-restauracao-e-integridade.md` — substituído por complemento opcional,
   somente metadados estruturais.

O agente pode ler dados sensíveis para investigar, mas o relatório devolvido
não pode conter nomes, CPFs, CNSs, endereços, telefones, e-mails, textos
clínicos reais ou URLs/credenciais da instalação.

Não envie perguntas de codebase, JAR, endpoints, serviços, mutations ou
scripts do repositório a esse agente. Esses itens são investigados localmente.
Os prompts 04 e 05 não são gates para iniciar o scaffold; serão usados apenas
se a implementação encontrar uma lacuna estrutural concreta.

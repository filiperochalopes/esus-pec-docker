# Prompt 03 — cidadão e prontuário mínimos

Você está investigando uma instância e-SUS PEC para apoiar um gerador de base
100% sintética. Pode ler registros reais, mas o relatório NÃO PODE conter dados
pessoais, endereços ou textos clínicos.

Objetivo: descobrir o menor grafo válido para cadastrar cinco cidadãos
sintéticos que apareçam corretamente na busca e possuam prontuário na versão
5.5.22. O gerador final usará pelo menos dez; cinco aqui são suficientes para
comparar variações estruturais.

Faça somente leitura. Se usar cidadãos existentes como referência, reporte
somente:

- nomes de tabelas/colunas;
- nulabilidade e defaults;
- códigos técnicos;
- padrão de presença/ausência;
- cardinalidades e invariantes.

Nunca reporte valores dos campos pessoais.

Investigue:

- `tb_cidadao`;
- `tb_prontuario`;
- endereço embutido ou relacionado;
- nacionalidade, país, localidade, raça/cor, etnia, escolaridade e sexo;
- vínculo cidadão-unidade/equipe, se obrigatório;
- UUIDs e filtros normalizados;
- unificação e flags CADSUS;
- dimensões, auditoria, histórico e índices de busca atualizados no cadastro.

Responda:

1. Quais campos são realmente obrigatórios no banco e na regra de negócio?
2. Qual combinação mínima faz o cidadão aparecer na busca do PEC?
3. O prontuário nasce junto com o cidadão ou sob demanda?
4. Como `tb_cidadao` se relaciona a `tb_prontuario` e qual é a cardinalidade?
5. Quais campos normalizados precisam ser calculados?
6. CPF e CNS são ambos opcionais para cidadão? Quais regras de unicidade e
   dígito verificador existem?
7. Que UUIDs/códigos únicos são esperados e em qual formato?
8. Quais referências de catálogo devem ser resolvidas por código natural?
9. Há triggers, listeners ou serviços que SQL direto deixaria de executar?
10. Qual endpoint GraphQL/REST/comando interno cria o cidadão de modo completo?

Entregue:

- DDL relevante;
- grafo mínimo em ordem de persistência;
- cinco arquétipos demográficos sem valores identificáveis;
- queries SELECT de pós-condição;
- recomendação de persistência;
- lacunas restantes.

Não investigue SOAP ainda.
